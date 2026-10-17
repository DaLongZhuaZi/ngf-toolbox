/**
 * 收藏 / 最近使用 / 输入草稿的持久化门面。
 *
 * 存储介质用 NGF 框架的 {@link ngfSettingsStoreFacade}（底层是 HarmonyOS Preferences），
 * 而不是自己再开一套 RDB：这几份数据都是**小、结构固定、按 key 读写**的形态，
 * Preferences 正好；引入关系库只会让样板代码变重。这也是产品定义稿
 * §三「框架级功能（data 层）」要求演示的那一层。
 *
 * ## 一个必须小心的坑：isReady
 *
 * `SettingsManager.initialize()` 是**异步**的，而框架在 `onBootstrapped()` 里
 * 用 `void` 调用它（不 await）。所以「bootstrap 返回了」不等于「设置读得出来了」。
 * 如果不区分这一点，启动后立刻读收藏会得到空列表，界面显示「没有收藏」，
 * 然后在第一次写入时把用户**真实的**收藏数据覆盖掉。
 *
 * 因此本类的读操作在存储未就绪时返回 {@link ToolStateStore.isLoaded} = false，
 * **不返回默认值**；调用方必须先确认已加载再展示，写操作在未就绪时拒绝执行。
 *
 * @module core/ToolStateStore
 */

import { logger, ngfSettingsStoreFacade } from 'ngf_framework';
import { parseToolUseState, serializeToolUseState, ToolUseState } from './ToolStateModel';

const TAG: string = 'ToolToolStateStore';

/** 存储 key。加前缀避免与其它功能挤在同一个 Preferences 库里时撞名。 */
const KEY_TOOL_USE_STATE: string = 'toolbox.tool_use_state';

/** 单个工具的输入草稿 key 前缀；完整 key 形如 toolbox.draft.<toolId> */
const DRAFT_KEY_PREFIX: string = 'toolbox.draft.';

/**
 * 单件工具输入草稿的保存上限（字符数）。
 *
 * 为什么要设上限：Preferences 单条 value 不宜过大，而工具输入框允许粘贴
 * 长文本（JSON、日志、代码）。若不设限，用户粘一份几 MB 的日志会拖慢启动，
 * 而他下次打开时多半也不需要完整恢复那份日志。超限时保留**尾部**——
 * 尾部通常是用户最近在改的部分，比开头更有用。
 */
export const DRAFT_MAX_LENGTH: number = 100000;

/** 单件工具的输入历史条数上限。10 条足够「找回上一次那串」，再多就要滚动找了。 */
export const HISTORY_MAX_ENTRIES: number = 10;

/**
 * 一个输入值要「定型」多久才算一次历史。
 *
 * 为什么要这个：草稿是**逐字符**写的（输入框 onChange），不能每次按键都记一条，
 * 否则历史里全是「{」「{"」「{"a」这种半成品。
 * 判据不是定时器，而是**惰性比较时间戳**——读取历史时看该值多久没变过，
 * 这样不需要在数据层跑 timer（也就不会因为页面销毁而泄漏）。
 */
export const HISTORY_SETTLE_MS: number = 1500;

/** 短于这个长度的值不进历史（单个字符、纯空白没有回填价值）。 */
export const HISTORY_MIN_LENGTH: number = 2;

/** 单件工具输入历史的 key 前缀；完整 key 形如 toolbox.history.<toolId> */
const HISTORY_KEY_PREFIX: string = 'toolbox.history.';

/**
 * 覆盖草稿之前，要不要把**上一个值**结算进历史？
 *
 * 抽成纯函数是因为这条判据有三个容易写错的边界，而它们都不报错：
 *
 * - 没有上一个值（首次输入）→ **不**结算。漏了这个判断会把空串当历史记进去。
 * - 上一个值还没定型 → **不**结算。漏了它，历史里会塞满逐字符的半成品。
 * - 新值和上一个值相同 → **不**结算。漏了它，光标来回移动就会刷出一堆重复项。
 *
 * @param lastAt 上一个值的写入时刻；`undefined` 表示还没有上一个值
 * @param lastValue 上一个值；`undefined` 表示还没有上一个值
 * @param nextText 即将写入的新值
 * @param now 当前时刻
 */
export function shouldCommitPrevious(lastAt: number | undefined, lastValue: string | undefined,
  nextText: string, now: number): boolean {
  if (lastAt === undefined || lastValue === undefined) {
    return false;
  }
  if (now - lastAt < HISTORY_SETTLE_MS) {
    return false;
  }
  return lastValue !== nextText;
}

/**
 * 这个值值不值得进历史。
 *
 * 抽成纯函数是为了能单测：它是「历史里会不会塞满半成品」的唯一判据。
 */
export function isHistoryWorthy(text: string): boolean {
  if (text === undefined || text === null) {
    return false;
  }
  const trimmed: string = text.trim();
  return trimmed.length >= HISTORY_MIN_LENGTH;
}

/**
 * 安全解析历史 JSON。任何非法输入都返回空数组，不抛异常。
 *
 * 用 `Array<string>` 而不是自己造一个类：ArkTS 禁止结构化类型
 * （`arkts-no-structural-typing`），断言成自定义类在真机上可能取不到元素。
 */
export function parseHistory(raw: string): Array<string> {
  if (raw === undefined || raw === null || raw.length === 0) {
    return [];
  }
  try {
    const parsed: Array<string> = JSON.parse(raw) as Array<string>;
    if (parsed === undefined || parsed === null) {
      return [];
    }
    const result: Array<string> = [];
    for (let i = 0; i < parsed.length; i++) {
      const item: string = parsed[i];
      if (item !== undefined && item !== null && item.length > 0) {
        result.push(String(item));
      }
    }
    return result;
  } catch (error) {
    // 存坏了就当没有历史，而不是让工具页打不开
    return [];
  }
}

/**
 * 把一条输入并入历史：**去重（已有的提到最前）+ 截断到上限**。
 *
 * 「提到最前」而不是「跳过」：同一个值再次使用说明它是当前关心的那个，
 * 应该排在最上面。抽成纯函数是为了单测能覆盖去重与截断的边界。
 */
export function appendHistory(entries: Array<string>, text: string, max: number): Array<string> {
  if (!isHistoryWorthy(text)) {
    return entries;
  }
  const value: string = text;
  const next: Array<string> = [value];
  for (let i = 0; i < entries.length; i++) {
    if (entries[i] !== value) {
      next.push(entries[i]);
    }
  }
  if (next.length > max) {
    next.length = max;
  }
  return next;
}


/**
 * 取草稿实际保存的文本（超出上限时保留尾部）。
 *
 * 抽成独立函数是为了能单测：它决定了「杀进程后草稿恢复成什么样」，
 * 属于用户可感知行为，不该藏在 IO 方法里。
 */
export function clampDraft(text: string): string {
  if (text.length <= DRAFT_MAX_LENGTH) {
    return text;
  }
  return text.substring(text.length - DRAFT_MAX_LENGTH);
}

export class ToolStateStore {
  private state: ToolUseState = ToolUseState.empty();

  /**
   * 每件工具草稿的**最后变动时间**（毫秒）。用于判断一个输入是否已「定型」。
   *
   * 只在内存里：进程重启后草稿仍在（它落盘了），但「定型与否」重新计时——
   * 重启后第一次读历史不会把上次残留的草稿当成一条新历史。
   */
  private draftChangedAt: Map<string, number> = new Map<string, number>();

  /**
   * 每件工具**上一次写入的草稿值**（内存）。
   *
   * 与 `draftChangedAt` 配对使用：`writeDraft` 在覆盖草稿之前，要先知道
   * 「被覆盖掉的那个值是什么、它定型了没有」，才能把它记进历史。
   * 存内存而不是每次回读存储：`writeDraft` 是**逐字符**调用的，多一次读就是多一次 IO。
   */
  private draftLastValue: Map<string, string> = new Map<string, string>();
  private loaded: boolean = false;

  /**
   * 从存储加载。幂等；重复调用不会重复读盘。
   *
   * @returns 是否加载成功。false 表示存储未就绪或读取失败，
   *          此时 {@link isLoaded} 仍为 false，调用方**不要**据此认为「用户没有收藏」。
   */
  load(): boolean {
    if (this.loaded) {
      return true;
    }
    try {
      if (!ngfSettingsStoreFacade.isReady()) {
        // 存储还没就绪：保持 loaded=false，让调用方稍后重试。
        return false;
      }
      const raw: string = ngfSettingsStoreFacade.getString(KEY_TOOL_USE_STATE, '');
      this.state = parseToolUseState(raw);
      this.loaded = true;
      logger.info(TAG, '工具状态已加载：收藏=' + String(this.state.favorites.length)
        + ', 最近使用=' + String(this.state.recents.length));
      return true;
    } catch (error) {
      logger.warn(TAG, '工具状态加载失败，本次会话按空状态运行');
      return false;
    }
  }

  /** 是否已完成首次加载。false 时 UI 不应展示「没有收藏」，而应等待。 */
  isLoaded(): boolean {
    return this.loaded;
  }

  /** 当前状态快照（不可变对象，可直接交给 UI 状态） */
  getState(): ToolUseState {
    return this.state;
  }

  isFavorite(id: string): boolean {
    return this.state.isFavorite(id);
  }

  /** 切换收藏并落盘。存储未就绪时返回 false 且不改内存状态，避免产生「假的已保存」。 */
  toggleFavorite(id: string): boolean {
    if (!this.ensureWritable()) {
      return false;
    }
    this.state = this.state.toggledFavorite(id);
    this.persistState();
    return true;
  }

  /** 记录一次工具使用（进工具页时调用），走到最近使用列表最前 */
  markUsed(id: string): boolean {
    if (!this.ensureWritable()) {
      return false;
    }
    const next: ToolUseState = this.state.withRecentUse(id);
    if (next === this.state) {
      return true;
    }
    this.state = next;
    this.persistState();
    return true;
  }

  /** 清空最近使用 */
  clearRecents(): boolean {
    if (!this.ensureWritable()) {
      return false;
    }
    this.state = this.state.clearedRecents();
    this.persistState();
    return true;
  }

  /** 读某件工具的输入草稿；无草稿或存储未就绪返回空串 */
  readDraft(toolId: string): string {
    const id: string = toolId.trim();
    if (id.length === 0) {
      return '';
    }
    try {
      return ngfSettingsStoreFacade.getString(DRAFT_KEY_PREFIX + id, '');
    } catch (error) {
      return '';
    }
  }

  /** 写某件工具的输入草稿（超长时保留尾部，见 {@link clampDraft}） */
  writeDraft(toolId: string, text: string): void {
    const id: string = toolId.trim();
    if (id.length === 0) {
      return;
    }
    if (!ngfSettingsStoreFacade.isReady()) {
      return;
    }
    const now: number = Date.now();
    // ── 先结算「被覆盖掉的那个值」 ──────────────────────────────
    //
    // 这一步是**必须**的：如果只在 readHistory 里结算，那么
    // 「输入 A → 停一会 → 改成 B → 关掉 app」这条最常见的路径上，
    // **A 永远不会进历史**（没人读过历史）——「最近输入」丢输入。
    // 放在覆盖之前结算，历史就能随使用自然累积。
    const lastValue: string | undefined = this.draftLastValue.get(id);
    if (shouldCommitPrevious(this.draftChangedAt.get(id), lastValue, text, now)
      && lastValue !== undefined) {
      this.commitToHistory(id, lastValue);
    }
    try {
      ngfSettingsStoreFacade.setString(DRAFT_KEY_PREFIX + id, clampDraft(text));
      this.draftChangedAt.set(id, now);
      this.draftLastValue.set(id, text);
    } catch (error) {
      logger.warn(TAG, '草稿写入失败：工具=' + id);
    }
  }

  /** 清空某件工具的草稿（用户点「清空」时调用） */
  clearDraft(toolId: string): void {
    const id: string = toolId.trim();
    if (id.length === 0) {
      return;
    }
    if (!ngfSettingsStoreFacade.isReady()) {
      return;
    }
    try {
      ngfSettingsStoreFacade.setString(DRAFT_KEY_PREFIX + id, '');
    } catch (error) {
      logger.warn(TAG, '草稿清除失败：工具=' + id);
    }
  }

  /**
   * 读某件工具的输入历史。
   *
   * ## 为什么在这里「惰性提交」而不是在 writeDraft 里提交
   *
   * 草稿是**逐字符**写的，而历史只该记「用户停下来之后留下的那个值」。
   * 判据是「该值已经 `HISTORY_SETTLE_MS` 没变过」——用一个时间戳比较就够了，
   * **不需要在数据层跑定时器**（定时器会随页面销毁泄漏，而且本机无法验证）。
   *
   * 提交后清掉时间戳，避免同一个值被反复记入。
   *
   * @param toolId 工具 id
   * @param now 当前时间戳（毫秒）。**由调用方传入**，这样单测能构造「已定型」场景，
   *            不必真的等 1.5 秒。
   */
  readHistory(toolId: string, now: number): Array<string> {
    const id: string = toolId.trim();
    if (id.length === 0) {
      return [];
    }
    let entries: Array<string> = [];
    try {
      entries = parseHistory(ngfSettingsStoreFacade.getString(HISTORY_KEY_PREFIX + id, ''));
    } catch (error) {
      return [];
    }
    const changedAt: number | undefined = this.draftChangedAt.get(id);
    if (changedAt === undefined) {
      return entries;
    }
    if (now - changedAt < HISTORY_SETTLE_MS) {
      return entries;
    }
    // 已定型：把当前草稿并入历史，并清掉时间戳（不重复提交）
    this.draftChangedAt.delete(id);
    const current: string = this.readDraft(id);
    this.commitToHistory(id, current);
    return this.readHistoryEntries(id);
  }

  /** 只读历史条目，不做任何「定型」判定（内部用） */
  private readHistoryEntries(id: string): Array<string> {
    try {
      return parseHistory(ngfSettingsStoreFacade.getString(HISTORY_KEY_PREFIX + id, ''));
    } catch (error) {
      return [];
    }
  }

  /** 显式把一条输入记入历史（工具想在「处理」时立刻记，可以调它）。 */
  pushHistory(toolId: string, text: string): boolean {
    const id: string = toolId.trim();
    if (id.length === 0 || !ngfSettingsStoreFacade.isReady()) {
      return false;
    }
    if (!isHistoryWorthy(text)) {
      return false;
    }
    try {
      const entries: Array<string> = parseHistory(ngfSettingsStoreFacade.getString(HISTORY_KEY_PREFIX + id, ''));
      this.persistHistory(id, appendHistory(entries, text, HISTORY_MAX_ENTRIES));
      return true;
    } catch (error) {
      logger.warn(TAG, '历史写入失败：工具=' + id);
      return false;
    }
  }

  /** 清空某件工具的输入历史 */
  clearHistory(toolId: string): boolean {
    const id: string = toolId.trim();
    if (id.length === 0 || !ngfSettingsStoreFacade.isReady()) {
      return false;
    }
    try {
      ngfSettingsStoreFacade.setString(HISTORY_KEY_PREFIX + id, '');
      this.draftChangedAt.delete(id);
      return true;
    } catch (error) {
      logger.warn(TAG, '历史清除失败：工具=' + id);
      return false;
    }
  }

  /**
   * 把一条值提交进历史（内部用）。
   *
   * 抽出来是因为有**两个**提交时机：`writeDraft` 覆盖前结算旧值、
   * `readHistory` 读取时结算当前值。两处必须走同一条路径，
   * 否则「去重 + 截断」的规则会在两处漂移。
   */
  private commitToHistory(id: string, value: string): void {
    if (!isHistoryWorthy(value)) {
      return;
    }
    try {
      const entries: Array<string> = parseHistory(ngfSettingsStoreFacade.getString(HISTORY_KEY_PREFIX + id, ''));
      this.persistHistory(id, appendHistory(entries, value, HISTORY_MAX_ENTRIES));
    } catch (error) {
      logger.warn(TAG, '历史提交失败：工具=' + id);
    }
  }

  /** 落盘历史（内部用，失败只记日志） */
  private persistHistory(id: string, entries: Array<string>): void {
    if (!ngfSettingsStoreFacade.isReady()) {
      return;
    }
    try {
      ngfSettingsStoreFacade.setString(HISTORY_KEY_PREFIX + id, JSON.stringify(entries));
    } catch (error) {
      logger.warn(TAG, '历史落盘失败：工具=' + id);
    }
  }


  /**
   * 测试用：直接注入状态，绕过存储。
   *
   * 生产代码不要调用。放在这里而不是做成 public setter 是因为
   * 单测需要构造「已加载且已有收藏」的场景，而真实存储依赖设备能力。
   */
  loadForTest(state: ToolUseState): void {
    this.state = state;
    this.loaded = true;
  }

  private ensureWritable(): boolean {
    if (!this.loaded) {
      // 先尝试一次惰性加载：调用方可能比首页更早触发了写操作。
      if (!this.load()) {
        logger.warn(TAG, '存储未就绪，本次写入被忽略（避免覆盖磁盘上的真实数据）');
        return false;
      }
    }
    return true;
  }

  private persistState(): void {
    try {
      ngfSettingsStoreFacade.setString(KEY_TOOL_USE_STATE, serializeToolUseState(this.state));
    } catch (error) {
      logger.warn(TAG, '工具状态写入失败');
    }
  }
}

/** 进程内单例：全局只有一份收藏/最近使用状态，避免两个页面各持一份而互相覆盖。 */
export const toolStateStore: ToolStateStore = new ToolStateStore();