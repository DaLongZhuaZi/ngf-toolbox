/**
 * 编解码套件页。
 *
 * 交互刻意是「手动转换」而不是实时转换：解码方向的输入在打字过程中几乎必然是
 * 残缺的（Base64 打一半时长度对 4 取余常常是 1），实时转换会让红字一直在闪，
 * 用户还没打完就先被骂一顿。点按钮才处理，是更安静也更符合直觉的交互。
 *
 * 模式与方向的说明都放在选择器下面（{@link codecModeHint}）：本工具最容易踩的坑
 * 不是算法，而是选错模式——把整段网址按参数值转义，参数里的 & 就会被转义掉，
 * 拿到后端才发现。把差异写在他点的地方，比写在文档里有用地多。
 *
 * @module tools/codec-suite/CodecSuitePage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { toolStateStore } from '../../core/ToolStateStore';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { ToolUiKit } from '../../ui/ToolUiKit';
import {
  CodecDirection,
  CodecMode,
  CodecResult,
  codecModes,
  runCodec
} from './CodecLogic';
import {
  codecFailureText,
  codecModeHintText,
  codecModeText,
  directionText
} from './CodecMessages';

/** 工具 id：与目录名、注册表元数据一致（草稿按它存） */
const TOOL_ID: string = 'codec-suite';

/** 草稿写入节流间隔（毫秒） */
const DRAFT_THROTTLE_MS: number = 800;

@Builder
export function buildCodecSuitePage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildCodecSuiteContent })
}

@Builder
function buildCodecSuiteContent() {
  CodecSuiteView({ toolId: TOOL_ID })
}

@Component
struct CodecSuiteView {
  /** 订阅主题深浅；本字段本身不用，作用是在主题切换时触发本组件重渲染。 */
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  /** 订阅字体缩放；本字段不用，作用是切字号时触发本组件重渲染。 */
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  /** 历史回填序号；变化时由 @Watch 触发 onHistoryPick（见 ui/HistoryPick.ets） */
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  toolId: string = TOOL_ID;

  @State private mode: CodecMode = CodecMode.BASE64;
    /** 注意：不能叫 direction —— CustomComponent 上已有同名属性（ArkUI 的方向属性），
  // 重名会得到「Property 'direction' is not assignable to the same property in base type」 */
  @State private codecDirection: CodecDirection = CodecDirection.ENCODE;
  @State private input: string = '';
  @State private output: string = '';
  @State private errorText: string = '';
  @State private statusText: string = '';

  private modes: Array<CodecMode> = codecModes();
  private lastDraftSavedAt: number = 0;

  /** 用户在壳层选中一条历史 → 从草稿重读本次输入（见 ui/HistoryPick.ets） */

  private onHistoryPick(): void {

    const restored: string = toolStateStore.readDraft(this.toolId);

    if (restored.length === 0) {

      return;

    }

    this.input = restored;

  }


  aboutToAppear(): void {
    // 草稿恢复后再算一次：用户上次的结果应当在他离开时的同一状态
    this.input = toolStateStore.readDraft(this.toolId);
    if (this.input.length > 0) {
      this.convert();
    }
  }

  aboutToDisappear(): void {
    this.saveDraft(true);
  }

  // ── 数据 ────────────────────────────────────────────────

  private saveDraft(force: boolean): void {
    const now: number = Date.now();
    if (!force && now - this.lastDraftSavedAt < DRAFT_THROTTLE_MS) {
      return;
    }
    this.lastDraftSavedAt = now;
    toolStateStore.writeDraft(this.toolId, this.input);
  }

  private convert(): void {
    const result: CodecResult = runCodec(this.mode, this.codecDirection, this.input);
    if (!result.ok) {
      this.output = '';
      this.statusText = '';
      this.errorText = codecFailureText(result.failure);
      return;
    }
    this.output = result.text;
    this.errorText = '';
    this.statusText = ToolUiKit.stringOf($r('app.string.codec_status_done'),
      [this.directionLabel(), codecModeText(this.mode), String(result.text.length)]);
  }

  private directionLabel(): string {
    return directionText(this.codecDirection);
  }

  private isEncode(): boolean {
    return this.codecDirection === CodecDirection.ENCODE;
  }

  /** 每个模式给一段能立刻跑通的示例，用户不用自己想输入 */
  private sampleForMode(): string {
    // 示例走资源键而不是写死中文：英文环境下举「中文」的例子没有意义，
    // 而且编码示例必须与它的编码结果**自洽**（否则点「示例」再点「转换」会报错）。
    const encode: boolean = this.isEncode();
    if (this.mode === CodecMode.BASE64) {
      return ToolUiKit.text(encode
        ? $r('app.string.codec_ex_base64_encode')
        : $r('app.string.codec_ex_base64_decode'));
    }
    if (this.mode === CodecMode.URL) {
      return ToolUiKit.text(encode
        ? $r('app.string.codec_ex_url_encode')
        : $r('app.string.codec_ex_url_decode'));
    }
    if (this.mode === CodecMode.URL_COMPONENT) {
      return ToolUiKit.text(encode
        ? $r('app.string.codec_ex_urlcomp_encode')
        : $r('app.string.codec_ex_urlcomp_decode'));
    }
    if (this.mode === CodecMode.UNICODE) {
      return ToolUiKit.text(encode
        ? $r('app.string.codec_ex_unicode_encode')
        : $r('app.string.codec_ex_unicode_decode'));
    }
    return ToolUiKit.text(encode
      ? $r('app.string.codec_ex_hex_encode')
      : $r('app.string.codec_ex_hex_decode'));
  }

  private useSample(): void {
    this.input = this.sampleForMode();
    this.convert();
    this.saveDraft(true);
  }

  private swapDirection(): void {
    // 用户刚解码出东西、又想反过来做一遍是高频动作；
    // 顺手把结果搬到输入框，省一次复制粘贴。
    if (this.output.length > 0) {
      this.input = this.output;
      this.output = '';
    }
    this.codecDirection = this.isEncode() ? CodecDirection.DECODE : CodecDirection.ENCODE;
    this.errorText = '';
    this.statusText = this.input.length > 0
      ? ToolUiKit.text($r('app.string.codec_status_swapped'))
      : '';
    this.saveDraft(true);
  }

  private selectMode(mode: CodecMode): void {
    this.mode = mode;
    this.errorText = '';
    this.statusText = '';
    this.convert();
  }

  private selectDirection(direction: CodecDirection): void {
    this.codecDirection = direction;
    this.convert();
  }

  private copyOutput(): void {
    ToolUiKit.copyText(this.output, ToolUiKit.text($r('app.string.codec_copied')));
  }

  private clearAll(): void {
    this.input = '';
    this.output = '';
    this.errorText = '';
    this.statusText = '';
    toolStateStore.clearDraft(this.toolId);
  }

  // ── UI ──────────────────────────────────────────────────

  build() {
    Column({ space: 0 }) {
      this.buildSectionLabel($r('app.string.codec_label_mode'))
      this.buildModeRow()
      Text(codecModeHintText(this.mode))
        .fontSize(scaled(12))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        .width('100%')
        .margin({ bottom: 4 })

      this.buildSectionLabel($r('app.string.codec_label_direction'))
      this.buildDirectionRow()

      this.buildSectionLabel(this.isEncode()
        ? $r('app.string.codec_label_input_encode')
        : $r('app.string.codec_label_input_decode'))
      this.buildInput()

      this.buildActionRow()
      this.buildStatusArea()
      this.buildOutputArea()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildSectionLabel(label: ResourceStr) {
    Text(label)
      .fontSize(scaled(13))
      .fontWeight(FontWeight.Medium)
      .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
      .width('100%')
      .margin({ top: 16, bottom: 6 })
  }

  @Builder
  private buildModeRow() {
    Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
      ForEach(this.modes, (mode: CodecMode) => {
        Text(codecModeText(mode))
          .fontSize(scaled(13))
          .fontColor(mode === this.mode ? Color.White : colorOf(NGFColorToken.ON_SURFACE))
          .accessibilityText(ToolUiKit.text(codecModeText(mode)))
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor(mode === this.mode
            ? colorOf(NGFColorToken.PRIMARY)
            : colorOf(NGFColorToken.SURFACE))
          .borderRadius(14)
          .margin({ right: 8, bottom: 8 })
          .onClick(() => {
            this.selectMode(mode);
          })
      }, (mode: CodecMode) => mode)
    }
    .width('100%')
  }

  @Builder
  private buildDirectionRow() {
    Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
      Text($r('app.string.codec_dir_encode'))
        .fontSize(scaled(13))
        .fontColor(this.isEncode() ? Color.White : colorOf(NGFColorToken.ON_SURFACE))
        .accessibilityText(ToolUiKit.text($r('app.string.codec_dir_encode')))
        .padding({ left: 14, right: 14, top: 6, bottom: 6 })
        .backgroundColor(this.isEncode() ? colorOf(NGFColorToken.PRIMARY) : colorOf(NGFColorToken.SURFACE))
        .borderRadius(14)
        .margin({ right: 8, bottom: 8 })
        .onClick(() => {
          this.selectDirection(CodecDirection.ENCODE);
        })
      Text($r('app.string.codec_dir_decode'))
        .fontSize(scaled(13))
        .fontColor(!this.isEncode() ? Color.White : colorOf(NGFColorToken.ON_SURFACE))
        .accessibilityText(ToolUiKit.text($r('app.string.codec_dir_decode')))
        .padding({ left: 14, right: 14, top: 6, bottom: 6 })
        .backgroundColor(!this.isEncode() ? colorOf(NGFColorToken.PRIMARY) : colorOf(NGFColorToken.SURFACE))
        .borderRadius(14)
        .margin({ right: 8, bottom: 8 })
        .onClick(() => {
          this.selectDirection(CodecDirection.DECODE);
        })
      Text($r('app.string.codec_action_swap'))
        .fontSize(scaled(13))
        .fontColor(colorOf(NGFColorToken.PRIMARY))
        .accessibilityText(ToolUiKit.text($r('app.string.codec_action_swap')))
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .backgroundColor(colorOf(NGFColorToken.PRIMARY_CONTAINER))
        .borderRadius(14)
        .margin({ right: 8, bottom: 8 })
        .onClick(() => {
          this.swapDirection();
        })
    }
    .width('100%')
  }

  @Builder
  private buildInput() {
    TextArea({
          text: this.input,
          placeholder: this.isEncode()
            ? $r('app.string.codec_placeholder_encode')
            : $r('app.string.codec_placeholder_decode')
        })
      .width('100%')
      .height(140)
      .fontSize(scaled(14))
      .padding(12)
      .backgroundColor(colorOf(NGFColorToken.SURFACE))
      .borderRadius(12)
      .onChange((value: string) => {
        this.input = value;
        this.saveDraft(false);
      })
  }

  @Builder
  private buildActionRow() {
    Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
      Button($r('app.string.codec_action_convert'))
        .fontSize(scaled(14))
        .type(ButtonType.Capsule)
        .backgroundColor(colorOf(NGFColorToken.PRIMARY))
        .fontColor(Color.White)
        .margin({ right: 8, bottom: 8 })
        .onClick(() => {
          this.convert();
        })
      Button($r('app.string.codec_action_example'))
        .fontSize(scaled(14))
        .type(ButtonType.Capsule)
        .backgroundColor(colorOf(NGFColorToken.PRIMARY_CONTAINER))
        .fontColor(colorOf(NGFColorToken.PRIMARY))
        .margin({ right: 8, bottom: 8 })
        .onClick(() => {
          this.useSample();
        })
      Button($r('app.string.codec_action_copy'))
        .fontSize(scaled(14))
        .type(ButtonType.Capsule)
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        .margin({ right: 8, bottom: 8 })
        .onClick(() => {
          this.copyOutput();
        })
      Button($r('app.string.shell_action_clear'))
        .fontSize(scaled(14))
        .type(ButtonType.Capsule)
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        .margin({ right: 8, bottom: 8 })
        .onClick(() => {
          this.clearAll();
        })
    }
    .width('100%')
    .margin({ top: 4 })
  }

  @Builder
  private buildStatusArea() {
    Column({ space: 6 }) {
      if (this.errorText.length > 0) {
        Text(this.errorText)
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.ERROR_COLOR))
          .width('100%')
      }
      if (this.statusText.length > 0) {
        Text(this.statusText)
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
          .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .margin({ top: 4 })
  }

  @Builder
  private buildOutputArea() {
    if (this.output.length > 0) {
      Column({ space: 6 }) {
        Text(this.isEncode()
          ? $r('app.string.codec_label_output_encode')
          : $r('app.string.codec_label_output_decode'))
          .fontSize(scaled(12))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        Text(this.output)
          .fontSize(scaled(14))
          .lineHeight(21)
          .fontColor(colorOf(NGFColorToken.ON_SURFACE))
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(12)
      .backgroundColor(colorOf(NGFColorToken.SURFACE_VARIANT))
      .borderRadius(12)
      .margin({ top: 12 })
    }
  }
}