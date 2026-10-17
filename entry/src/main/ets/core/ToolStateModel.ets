/**
 * 收藏 / 最近使用的**纯逻辑**部分。
 *
 * 拆出来的理由：这一层里真正会出 bug 的是「顺序、去重、上限、边界」这几个点
 * （例如：重复点收藏会不会出现两条？最近使用超上限时砍哪一头？
 * 取消收藏后最近使用里还在不在？）。这些逻辑不需要设备、不需要真实存储，
 * 却决定了用户会不会觉得「这 App 记不住事」。因此它必须是纯函数并配有单测。
 *
 * 持久化在 {@link ToolStateStore} 里，本文件不认识任何存储 API。
 *
 * @module core/ToolStateModel
 */


/**
 * 最近使用列表的上限。
 *
 * 为什么是 8：首页「最近使用」是一行横向卡片，再多就需要滚动，
 * 而「最近使用」的价值恰恰是**一眼可及**；超过一屏它就退化成第二个工具列表了。
 */
export const RECENT_TOOL_LIMIT: number = 8;

/**
 * 不可变的收藏/最近使用状态。
 *
 * 刻意**不可变**（所有变更方法返回新实例而不是原地改）：
 * 首页的 UI 状态直接引用它，原地改会让「值变了但引用没变」，
 * ArkTS 的状态观察器就侦测不到刷新——这类 bug 在真机上表现为
 * 「点了收藏但图标不变」，非常难查。不可变让每次变更都是新引用，天然可观察。
 */
export class ToolUseState {
  /** 收藏的工具 id，按用户添加顺序排列（新加的追加在末尾） */
  readonly favorites: Array<string>;
  /** 最近使用的工具 id，最近的在最前 */
  readonly recents: Array<string>;

  constructor(favorites: Array<string>, recents: Array<string>) {
    this.favorites = favorites;
    this.recents = recents;
  }

  /** 空状态 */
  static empty(): ToolUseState {
    return new ToolUseState([], []);
  }

  /** 复制一份（避免把内部数组交给调用方后被外部改掉） */
  static copyIds(source: Array<string>): Array<string> {
    const copied: Array<string> = [];
    for (let i: number = 0; i < source.length; i++) {
      copied.push(source[i]);
    }
    return copied;
  }

  isFavorite(id: string): boolean {
    return this.favorites.indexOf(id) >= 0;
  }

  withFavorite(id: string): ToolUseState {
    const trimmed: string = id.trim();
    if (trimmed.length === 0 || this.isFavorite(trimmed)) {
      return this;
    }
    const nextFavorites: Array<string> = ToolUseState.copyIds(this.favorites);
    nextFavorites.push(trimmed);
    return new ToolUseState(nextFavorites, ToolUseState.copyIds(this.recents));
  }

  /**
   * 取消收藏。
   *
   * 刻意**不动**最近使用：收藏是「我常驻想要它」，最近使用是「我刚用过」，
   * 两者语义不同。取消收藏时顺手把最近使用也删掉，会让用户
   * 「刚用完想再点一次却找不到了」。
   */
  withoutFavorite(id: string): ToolUseState {
    const trimmed: string = id.trim();
    if (!this.isFavorite(trimmed)) {
      return this;
    }
    const nextFavorites: Array<string> = [];
    for (let i: number = 0; i < this.favorites.length; i++) {
      if (this.favorites[i] !== trimmed) {
        nextFavorites.push(this.favorites[i]);
      }
    }
    return new ToolUseState(nextFavorites, ToolUseState.copyIds(this.recents));
  }

  /** 收藏开关，返回新状态 */
  toggledFavorite(id: string): ToolUseState {
    return this.isFavorite(id) ? this.withoutFavorite(id) : this.withFavorite(id);
  }

  /**
   * 记录一次使用：把 id 提到最前。
   *
   * 已在列表里的会被**移动**而不是重复插入（这正是需要单测的点之一：
   * 重复插入会让「最近使用」很快被同一个工具占满）。
   */
  withRecentUse(id: string): ToolUseState {
    const trimmed: string = id.trim();
    if (trimmed.length === 0) {
      return this;
    }
    const nextRecents: Array<string> = [trimmed];
    for (let i: number = 0; i < this.recents.length; i++) {
      if (this.recents[i] !== trimmed && nextRecents.length < RECENT_TOOL_LIMIT) {
        nextRecents.push(this.recents[i]);
      }
    }
    return new ToolUseState(ToolUseState.copyIds(this.favorites), nextRecents);
  }

  /** 清空最近使用（设置页提供） */
  clearedRecents(): ToolUseState {
    return new ToolUseState(ToolUseState.copyIds(this.favorites), []);
  }

  /** 把两个列表都裁到合法范围：去掉空串与重复项，最近使用截到上限 */
  static sanitize(favorites: Array<string>, recents: Array<string>): ToolUseState {
    const safeFavorites: Array<string> = ToolUseState.dedupe(favorites, -1);
    // 最近使用的上限是硬约束，越界数据（例如旧版本写入的）在这里被裁掉。
    const safeRecents: Array<string> = ToolUseState.dedupe(recents, RECENT_TOOL_LIMIT);
    return new ToolUseState(safeFavorites, safeRecents);
  }

  /** 去重并丢弃空串；limit 为负表示不限 */
  private static dedupe(source: Array<string>, limit: number): Array<string> {
    const result: Array<string> = [];
    const seen: Set<string> = new Set<string>();
    for (let i: number = 0; i < source.length; i++) {
      const id: string = source[i].trim();
      if (id.length === 0 || seen.has(id)) {
        continue;
      }
      if (limit >= 0 && result.length >= limit) {
        break;
      }
      seen.add(id);
      result.push(id);
    }
    return result;
  }
}

/** 序列化用的中间结构（与 JSON 字段一一对应，字段名短以省存储） */
export class ToolUseStateDto {
  favorites: Array<string> = [];
  recents: Array<string> = [];
}

/**
 * 反序列化。任何损坏的输入都退化为空状态而不抛异常。
 *
 * 为什么宽容：这份数据存在设备上，可能被旧版本写过、可能被手工改过。
 * 因为一份可选功能（收藏）的数据坏了就让首页打不开，是错误的取舍。
 */
export function parseToolUseState(raw: string): ToolUseState {
  const text: string = raw.trim();
  if (text.length === 0) {
    return ToolUseState.empty();
  }
  try {
    const dto: ToolUseStateDto = JSON.parse(text) as ToolUseStateDto;
    const favorites: Array<string> = dto.favorites ? dto.favorites : [];
    const recents: Array<string> = dto.recents ? dto.recents : [];
    return ToolUseState.sanitize(favorites, recents);
  } catch (error) {
    return ToolUseState.empty();
  }
}

/** 序列化 */
export function serializeToolUseState(state: ToolUseState): string {
  const dto: ToolUseStateDto = new ToolUseStateDto();
  dto.favorites = ToolUseState.copyIds(state.favorites);
  dto.recents = ToolUseState.copyIds(state.recents);
  return JSON.stringify(dto);
}