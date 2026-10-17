/**
 * 端口测试工具页 —— 本 App 唯一会联网的功能。
 *
 * ## 联网明示（产品定义稿 §四 + PR-002 的硬性要求）
 *
 * 页面顶部与操作按钮上方都有明确说明：这个工具会连接**用户自己输入的主机**。
 * 这不是可选的礼貌提示，而是隐私红线的一部分——本 App 其余部分完全不联网，
 * 用户有权在点下按钮之前就知道这一次会发出去网络请求。
 *
 * ## 分层：真正需要设备的只有一行
 *
 * 输入的解析、校验、重复检测、批量上限、错误翻译全在 {@link PortTester}（纯逻辑、有单测）。
 * 本文件里只有 {@link testOneTarget} 里那几行是设备能力（建立 TCP 连接）。
 * 这样切分的直接好处：**能离线判定为「不该连」的目标一个包都不会发出去**，
 * 而联网那一小段无论如何都要靠真机验证，缩小它是唯一能降低风险的办法。
 *
 * ## 并发
 *
 * 批量测试按 {@link CONCURRENCY} 个一组并发，而不是一次性全部发起：
 * 手机上同时开几十个 socket 会互相抢占，反而让每个都更容易超时，
 * 用户会觉得「明明通的结果却说不通」。
 *
 * @module tools/port-tester/PortTesterPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import {
  socket } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { logger, NGFColorToken } from 'ngf_framework';
import { ToolPageParams } from '../../core/ToolPageContract';
import { toolStateStore } from '../../core/ToolStateStore';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { ToolUiKit } from '../../ui/ToolUiKit';
import {
  clampTimeout,
  describeSocketError,
  SocketDetail,
  parseTargets,
  PortDetail,
  PortParseResult,
  PortPreset,
  PortResult,
  portPresets,
  PortState,
  PortSummary,
  PortTarget,
  preflightSkip,
  summarize,
  TIMEOUT_DEFAULT_MS,
  TIMEOUT_MAX_MS,
  TIMEOUT_MIN_MS
} from './PortTester';
import {
  portDetailText,
  portMarkText,
  portNoticeText,
  portParseFailureText,
  portResultsText,
  portSummaryText,
  presetLabelText
} from './PortMessages';
import { currentLocale, FALLBACK_LOCALE } from '../../ui/LocaleSource';

const TAG: string = 'PortTesterPage';

/** 工具 id：草稿按它存取，必须与 ToolsCatalog 里登记的 id 一致 */
const TOOL_ID: string = 'port-tester';

/** 草稿写入防抖（毫秒） */
const DRAFT_DEBOUNCE_MS: number = 400;

/** 并发数：3 是「够快」与「不互相抢带宽」的折中 */
const CONCURRENCY: number = 3;

/** 超时可选档位（毫秒） */
const TIMEOUT_CHOICES: Array<number> = [1000, 3000, 5000, TIMEOUT_MAX_MS];

/** 常用主机示例 */
const HOST_EXAMPLES: Array<string> = ['192.168.1.1:80', 'example.com:443', 'localhost:8080'];

@Builder
export function buildPortTesterPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildPortTesterContent })
}

@Builder
function buildPortTesterContent() {
  PortTesterToolBody()
}

@Component
struct PortTesterToolBody {
  /** 订阅主题深浅；本字段本身不用，作用是在主题切换时触发本组件重渲染。 */
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  /** 订阅字体缩放；本字段不用，作用是切字号时触发本组件重渲染。 */
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  /** 历史回填序号；变化时由 @Watch 触发 onHistoryPick（见 ui/HistoryPick.ets） */
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  /** 当前语言：端口用途名是双语数据，按它取 */
  @State private locale: string = FALLBACK_LOCALE;
  @State private input: string = '';
  @State private errorText: string = '';
  @State private noticeText: string = '';
  @State private timeoutMs: number = TIMEOUT_DEFAULT_MS;
  @State private results: Array<PortResult> = [];
  @State private summaryText: string = '';
  @State private testing: boolean = false;

  private draftTimer: number = -1;
  /** 让「停止」按钮能真正打断后续批次 */
  private cancelled: boolean = false;

  /** 用户在壳层选中一条历史 → 从草稿重读本次输入（见 ui/HistoryPick.ets） */

  private onHistoryPick(): void {

    const restored: string = toolStateStore.readDraft(TOOL_ID);

    if (restored.length === 0) {

      return;

    }

    this.input = restored;

  }


  aboutToAppear(): void {
    this.locale = currentLocale();
    const saved: string = toolStateStore.readDraft(TOOL_ID);
    if (saved.length > 0) {
      this.input = saved;
      this.refreshNotice();
    }
  }

  aboutToDisappear(): void {
    this.cancelled = true;
    this.flushDraft();
  }

  build() {
    Column({ space: 16 }) {
      this.buildNetworkDisclosure()
      this.buildInputSection()
      if (this.errorText.length > 0) {
        this.buildError()
      }
      this.buildPresetSection()
      this.buildTimeoutSection()
      this.buildActionSection()
      if (this.results.length > 0) {
        this.buildResultSection()
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 联网明示：必须在操作之前就能看到 */
  @Builder
  private buildNetworkDisclosure() {
    Row({ space: 8 }) {
      Column({ space: 4 }) {
        Text($r('app.string.port_label_online'))
          .fontSize(scaled(14))
          .fontWeight(FontWeight.Medium)
          .fontColor(colorOf(NGFColorToken.WARNING))
        // 不用 markdown 星号加粗：Text 是纯文本渲染，星号会原样显示出来。
        Text($r('app.string.port_online_note'))
          .fontSize(scaled(12))
          .fontColor(colorOf(NGFColorToken.WARNING))
          .lineHeight(18)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(12)
    .backgroundColor(colorOf(NGFColorToken.WARNING_CONTAINER))
    .borderRadius(12)
  }

  /** 输入区 */
  @Builder
  private buildInputSection() {
    Column({ space: 8 }) {
      Text($r('app.string.port_label_target'))
        .fontSize(scaled(15))
        .fontWeight(FontWeight.Medium)
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))

      TextInput({ text: this.input, placeholder: $r('app.string.port_placeholder') })
        .width('100%')
        .height(44)
        .fontSize(scaled(15))
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(12)
        .onChange((value: string) => {
          this.input = value;
          this.scheduleDraftSave(value);
          this.refreshNotice();
        })

      Text($r('app.string.port_input_hint'))
        .fontSize(scaled(12))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        .width('100%')

      if (this.noticeText.length > 0) {
        Text(this.noticeText)
          .fontSize(scaled(12))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
          .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildError() {
    Text(this.errorText)
      .fontSize(scaled(13))
      .fontColor(colorOf(NGFColorToken.ERROR_COLOR))
      .width('100%')
      .padding(12)
      .backgroundColor(colorOf(NGFColorToken.ERROR_CONTAINER))
      .borderRadius(12)
  }

  /** 常用端口：点一下追加到输入里 */
  @Builder
  private buildPresetSection() {
    Column({ space: 8 }) {
      Text($r('app.string.port_label_presets'))
        .fontSize(scaled(15))
        .fontWeight(FontWeight.Medium)
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(portPresets(), (preset: PortPreset) => {
          Text(String(preset.port) + ' ' + presetLabelText(preset, this.locale))
            .fontSize(scaled(12))
            .fontColor(colorOf(NGFColorToken.PRIMARY))
            .accessibilityText(String(preset.port) + ' ' + presetLabelText(preset, this.locale))
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor(colorOf(NGFColorToken.PRIMARY_CONTAINER))
            .borderRadius(14)
            .margin({ right: 8, bottom: 8 })
            .onClick(() => {
              this.appendPreset(preset.port);
            })
        }, (preset: PortPreset) => String(preset.port))
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 超时档位 */
  @Builder
  private buildTimeoutSection() {
    Column({ space: 8 }) {
      Text(ToolUiKit.stringOf($r('app.string.port_label_timeout'),
            [String(this.timeoutMs / 1000)]))
        .fontSize(scaled(15))
        .fontWeight(FontWeight.Medium)
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))

      Row({ space: 8 }) {
        ForEach(TIMEOUT_CHOICES, (choice: number) => {
          Text(String(choice / 1000) + 's')
            .fontSize(scaled(12))
            .fontColor(this.timeoutMs === choice
              ? colorOf(NGFColorToken.PRIMARY)
              : colorOf(NGFColorToken.ON_SURFACE_VARIANT))
              .accessibilityText(String(choice / 1000) + 's')
            .padding({ left: 14, right: 14, top: 6, bottom: 6 })
            .backgroundColor(this.timeoutMs === choice
              ? colorOf(NGFColorToken.PRIMARY_CONTAINER)
              : colorOf(NGFColorToken.SURFACE))
            .borderRadius(14)
            .onClick(() => {
              this.timeoutMs = clampTimeout(choice);
            })
        }, (choice: number) => String(choice))
      }
      .width('100%')

      Text(ToolUiKit.stringOf($r('app.string.port_timeout_note'),
          [String(TIMEOUT_MIN_MS / 1000)]))
        .fontSize(scaled(12))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 操作按钮 */
  @Builder
  private buildActionSection() {
    Row({ space: 12 }) {
      Button(this.testing
          ? $r('app.string.port_action_stop')
          : $r('app.string.port_action_start'))
        .layoutWeight(1)
        .backgroundColor(this.testing
          ? colorOf(NGFColorToken.ERROR_COLOR)
          : colorOf(NGFColorToken.PRIMARY))
        .onClick(() => {
          if (this.testing) {
            this.cancelled = true;
            return;
          }
          this.startTesting();
        })
      Button($r('app.string.shell_action_clear'))
        .layoutWeight(1)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .controlSize(ControlSize.NORMAL)
        .onClick(() => {
          this.clearAll();
        })
    }
    .width('100%')
  }

  /** 结果区 */
  @Builder
  private buildResultSection() {
    Column({ space: 10 }) {
      Row() {
        Text(this.summaryText)
          .fontSize(scaled(14))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE))
          .layoutWeight(1)
        Text($r('app.string.port_action_copy'))
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.PRIMARY))
          .accessibilityText(ToolUiKit.text($r('app.string.copied_common')))
          .onClick(() => {
            ToolUiKit.copyText(portResultsText(this.results, this.locale),
        ToolUiKit.text($r('app.string.port_copied_results')));
          })
      }
      .width('100%')

      ForEach(this.results, (result: PortResult) => {
        this.buildResultRow(result)
      }, (result: PortResult) => result.target.display)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .backgroundColor(colorOf(NGFColorToken.SURFACE_VARIANT))
    .borderRadius(12)
  }

  @Builder
  private buildResultRow(result: PortResult) {
    Row({ space: 8 }) {
      Text(stateMark(result.state))
        .fontSize(scaled(12))
        .fontColor(stateColor(result.state))
        .width(40)
      Column({ space: 2 }) {
        Text(result.target.display)
          .fontSize(scaled(14))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE))
          .width('100%')
        if (result.detail.length > 0) {
          Text(result.detail)
            .fontSize(scaled(12))
            .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
            .width('100%')
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ top: 6, bottom: 6 })
    .alignItems(VerticalAlign.Top)
  }

  /** 输入变化时刷新本地地址提示 */
  private refreshNotice(): void {
    const parsed: PortParseResult = parseTargets(this.input);
    if (!parsed.ok) {
      // 输入还没写完时不报错（用户正在打字），只清提示
      this.errorText = this.input.trim().length === 0 ? '' : '';
      this.noticeText = '';
      return;
    }
    this.noticeText = portNoticeText(parsed.targets[0].host);
  }

  /** 追加一个常用端口到输入框 */
  private appendPreset(port: number): void {
    const trimmed: string = this.input.trim();
    if (trimmed.length === 0) {
      // 还没填主机：只填端口没有意义，给一句提示而不是拼出一个半成品
      ToolUiKit.toast($r('app.string.port_toast_need_host'));
      return;
    }
    const next: string = trimmed + ',' + String(port);
    this.input = next;
    this.scheduleDraftSave(next);
    this.refreshNotice();
  }

  /** 开始测试 */
  private async startTesting(): Promise<void> {
    const parsed: PortParseResult = parseTargets(this.input);
    if (!parsed.ok) {
      this.errorText = portParseFailureText(parsed.failure, parsed.args);
      this.results = [];
      this.summaryText = '';
      return;
    }
    this.errorText = '';
    this.testing = true;
    this.cancelled = false;

    // 先离线自检：能判定的问题一个包都不发
    const skipped: Array<PortResult> = preflightSkip(parsed.targets);
    const skippedDisplays: Set<string> = new Set<string>();
    for (let i: number = 0; i < skipped.length; i++) {
      skippedDisplays.add(skipped[i].target.display);
    }
    const toTest: Array<PortTarget> = [];
    for (let i: number = 0; i < parsed.targets.length; i++) {
      if (!skippedDisplays.has(parsed.targets[i].display)) {
        toTest.push(parsed.targets[i]);
      }
    }

    // 初始化结果列表：先全部显示为「等待中」，让用户看到总量
    const initial: Array<PortResult> = [];
    for (let i: number = 0; i < skipped.length; i++) {
      initial.push(skipped[i]);
    }
    for (let i: number = 0; i < toTest.length; i++) {
      initial.push(new PortResult(toTest[i], PortState.PENDING, PortDetail.NONE, [], -1));
    }
    this.results = initial;
    this.refreshSummary();

    // 分批并发
    const timeout: number = clampTimeout(this.timeoutMs);
    for (let start: number = 0; start < toTest.length; start += CONCURRENCY) {
      if (this.cancelled) {
        break;
      }
      const batch: Array<PortTarget> = [];
      for (let k: number = start; k < start + CONCURRENCY && k < toTest.length; k++) {
        batch.push(toTest[k]);
      }
      const outcomes: Array<PortResult> = await this.runBatch(batch, timeout);
      this.mergeResults(outcomes);
      this.refreshSummary();
    }

    this.testing = false;
    this.refreshSummary();
  }

  /** 并发跑一批 */
  private async runBatch(batch: Array<PortTarget>, timeout: number): Promise<Array<PortResult>> {
    // 先把这一批标成「测试中」，用户能看到进度
    this.markRunning(batch);
    const promises: Array<Promise<PortResult>> = [];
    for (let i: number = 0; i < batch.length; i++) {
      promises.push(testOneTarget(batch[i], timeout));
    }
    return await Promise.all(promises);
  }

  /** 把一批目标标记为测试中 */
  private markRunning(batch: Array<PortTarget>): void {
    const running: Set<string> = new Set<string>();
    for (let i: number = 0; i < batch.length; i++) {
      running.add(batch[i].display);
    }
    const next: Array<PortResult> = [];
    for (let i: number = 0; i < this.results.length; i++) {
      const current: PortResult = this.results[i];
      if (running.has(current.target.display) && current.state === PortState.PENDING) {
        next.push(new PortResult(current.target, PortState.RUNNING, PortDetail.RUNNING, [], -1));
      } else {
        next.push(current);
      }
    }
    this.results = next;
  }

  /** 把新结果并回列表（保持原有顺序） */
  private mergeResults(outcomes: Array<PortResult>): void {
    const byDisplay: Map<string, PortResult> = new Map<string, PortResult>();
    for (let i: number = 0; i < outcomes.length; i++) {
      byDisplay.set(outcomes[i].target.display, outcomes[i]);
    }
    const next: Array<PortResult> = [];
    for (let i: number = 0; i < this.results.length; i++) {
      const current: PortResult = this.results[i];
      const updated: PortResult | undefined = byDisplay.get(current.target.display);
      next.push(updated === undefined ? current : updated);
    }
    this.results = next;
  }

  private refreshSummary(): void {
    const summary: PortSummary = summarize(this.results);
    this.summaryText = portSummaryText(summary);
  }

  private clearAll(): void {
    if (this.draftTimer >= 0) {
      clearTimeout(this.draftTimer);
      this.draftTimer = -1;
    }
    this.cancelled = true;
    this.input = '';
    this.errorText = '';
    this.noticeText = '';
    this.results = [];
    this.summaryText = '';
    this.testing = false;
    toolStateStore.clearDraft(TOOL_ID);
  }

  private scheduleDraftSave(text: string): void {
    if (this.draftTimer >= 0) {
      clearTimeout(this.draftTimer);
    }
    this.draftTimer = setTimeout(() => {
      this.draftTimer = -1;
      toolStateStore.writeDraft(TOOL_ID, text);
    }, DRAFT_DEBOUNCE_MS);
  }

  private flushDraft(): void {
    if (this.draftTimer >= 0) {
      clearTimeout(this.draftTimer);
      this.draftTimer = -1;
    }
    toolStateStore.writeDraft(TOOL_ID, this.input);
  }
}

/** 状态短标签（措辞在 PortMessages 层） */
function stateMark(state: PortState): string {
  return portMarkText(state);
}

function stateColor(state: PortState): ResourceColor {
  // 返回 ResourceColor 而不是 Resource：颜色现在来自 uiTheme 的运行时 Token,
  // colorOf() 给的是 string，声明成 Resource 会类型不匹配。
  if (state === PortState.OPEN) {
    return colorOf(NGFColorToken.SUCCESS);
  }
  if (state === PortState.CLOSED) {
    return colorOf(NGFColorToken.ERROR_COLOR);
  }
  return colorOf(NGFColorToken.ON_SURFACE_VARIANT);
}

/**
 * 测试一个目标 —— **本文件里唯一需要设备能力的地方**。
 *
 * 用最朴素的 TCP 连接来判断端口是否可达：连上就立刻关闭。
 * 刻意**不**发任何应用层数据（不做 HTTP 请求、不做 banner 抓取）：
 * 「能连上」已经回答了本工具的问题，多发一个字节都是多余的。
 *
 * 超时用「定时器主动关闭」实现，而不是依赖 socket 自身的超时参数：
 * 不同版本的系统 API 在这个参数上的行为不一致，自己关最可控。
 */
async function testOneTarget(target: PortTarget, timeoutMs: number): Promise<PortResult> {
  const startedAt: number = Date.now();
  let tcp: socket.TCPSocket | null = null;
  let timer: number = -1;
  let settled: boolean = false;

  const closeQuietly = (): void => {
    if (tcp !== null) {
      try {
        tcp.close();
      } catch (error) {
        // 已经关掉了，忽略
      }
      tcp = null;
    }
  };

  try {
    tcp = socket.constructTCPSocketInstance();
    const connection: socket.NetAddress = {
      address: target.host,
      port: target.port
    };

    const timeoutPromise: Promise<PortResult> = new Promise<PortResult>((resolve: (value: PortResult) => void) => {
      timer = setTimeout(() => {
        if (settled) {
          return;
        }
        settled = true;
        closeQuietly();
        resolve(new PortResult(target, PortState.CLOSED,
          PortDetail.ERR_TIMEOUT, [String(timeoutMs / 1000)], -1));
      }, timeoutMs);
    });

    const connectPromise: Promise<PortResult> = new Promise<PortResult>((resolve: (value: PortResult) => void) => {
      tcp?.connect({ address: connection }).then(() => {
        if (settled) {
          closeQuietly();
          return;
        }
        settled = true;
        const elapsed: number = Date.now() - startedAt;
        closeQuietly();
        resolve(new PortResult(target, PortState.OPEN, PortDetail.OPEN, [], elapsed));
      }).catch((error: BusinessError) => {
        if (settled) {
          return;
        }
        settled = true;
        closeQuietly();
        const detail: SocketDetail = describeSocketError(error.code, error.message);
        resolve(new PortResult(target, PortState.CLOSED, detail.kind, detail.args, -1));
      });
    });

    return await Promise.race([connectPromise, timeoutPromise]);
  } catch (error) {
    const businessError = error as BusinessError;
    logger.warn(TAG, '端口测试异常: ' + String(businessError.code));
    closeQuietly();
    const detail: SocketDetail = describeSocketError(businessError.code, businessError.message);
    return new PortResult(target, PortState.CLOSED, detail.kind, detail.args, -1);
  } finally {
    if (timer !== -1) {
      clearTimeout(timer);
    }
    closeQuietly();
  }
}