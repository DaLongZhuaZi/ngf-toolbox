/**
 * JSON 工具页。
 *
 * 页面按「输入 → 一键处理 → 输出 → 复制/清空」的统一模板组织（产品定义稿 §四），
 * 所有格式判断都交给 {@link JsonLogic} 的纯函数。这里只做三件 UI 上的决定：
 *
 * 1. **不自动格式化**。JSON 在输入过程中几乎总是「残缺」的，实时格式化会让红字
 *    在用户还没打完时就一直闪。用户点按钮才处理，是更安静也更符合直觉的交互。
 * 2. 缩进用一排可点的选项而不是滑杆：工具的实际选项只有 0/2/4/8 这四种，
 *    滑杆能拖出 3 或 7 这种没人想要的中间值。
 * 3. 错误一律就地红字并带上行列号（产品定义稿 §四 明确要求定位到位置）。
 *
 * @module tools/json-toolkit/JsonToolkitPage
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
  describeJsonRoot,
  uniqueDuplicateKeys,
  escapeJsonString,
  formatJson,
  JsonFormatResult,
  JsonParseResult,
  JSON_DEFAULT_INDENT,
  JsonStringResult,
  minifyJson,
  parseJson,
  unescapeJsonString
} from './JsonLogic';
import {
  jsonDuplicateHintText,
  jsonErrorTextOf,
  jsonStringFailureText,
  jsonSummaryText
} from './JsonMessages';

/** 工具 id：与目录名、注册表元数据一致（草稿按它存） */
const TOOL_ID: string = 'json-toolkit';

/** 草稿写入节流间隔（毫秒）：Preferences 是同步写盘，每个按键都写会拖慢输入 */
const DRAFT_THROTTLE_MS: number = 800;

/** 缩进可选项（与 JSON_MAX_INDENT 一致；写死在这里是为了让页面不依赖常量之外的口径） */
const INDENT_CHOICES: Array<number> = [0, 2, 4, 8];

@Builder
export function buildJsonToolkitPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildJsonToolkitContent })
}

@Builder
function buildJsonToolkitContent() {
  JsonToolkitView({ toolId: TOOL_ID })
}

@Component
struct JsonToolkitView {
  /** 订阅主题深浅；本字段本身不用，作用是在主题切换时触发本组件重渲染。 */
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  /** 订阅字体缩放；本字段不用，作用是切字号时触发本组件重渲染。 */
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  /** 历史回填序号；变化时由 @Watch 触发 onHistoryPick（见 ui/HistoryPick.ets） */
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  toolId: string = TOOL_ID;

  @State private input: string = '';
  @State private output: string = '';
  @State private statusText: string = '';
  @State private errorText: string = '';
  @State private indent: number = JSON_DEFAULT_INDENT;
  @State private escapeInput: string = '';
  @State private escapeOutput: string = '';
  @State private escapeError: string = '';

  private indentChoices: Array<number> = INDENT_CHOICES;
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
    this.input = toolStateStore.readDraft(this.toolId);
  }

  aboutToDisappear(): void {
    this.saveDraft(true);
  }

  // ── 输入与草稿 ──────────────────────────────────────────

  private saveDraft(force: boolean): void {
    const now: number = Date.now();
    if (!force && now - this.lastDraftSavedAt < DRAFT_THROTTLE_MS) {
      return;
    }
    this.lastDraftSavedAt = now;
    // 草稿就是输入原文（ToolStateStore 会按 100000 字符上限保留尾部），不必再包一层 JSON
    toolStateStore.writeDraft(this.toolId, this.input);
  }

  private hasInput(): boolean {
    return this.input.trim().length > 0;
  }

  private clearStatus(): void {
    this.statusText = '';
    this.errorText = '';
  }

  // ── 动作 ────────────────────────────────────────────────

  private doFormat(): void {
    if (!this.hasInput()) {
      this.output = '';
      this.clearStatus();
      this.statusText = ToolUiKit.text($r('app.string.json_status_need_input'));
      return;
    }
    const result: JsonFormatResult = formatJson(this.input, this.indent);
    if (!result.ok) {
      this.showFailure(jsonErrorTextOf(result.error));
      return;
    }
    this.output = result.text;
    this.showParseStatus(result.text.length);
  }

  private doMinify(): void {
    if (!this.hasInput()) {
      this.output = '';
      this.clearStatus();
      this.statusText = ToolUiKit.text($r('app.string.json_status_need_input'));
      return;
    }
    const result: JsonFormatResult = minifyJson(this.input);
    if (!result.ok) {
      this.showFailure(jsonErrorTextOf(result.error));
      return;
    }
    this.output = result.text;
    this.showParseStatus(result.text.length);
  }

  /** 只校验，不改写输出（用户可能只是想确认这段 JSON 是不是合法） */
  private doValidate(): void {
    if (!this.hasInput()) {
      this.output = '';
      this.clearStatus();
      this.statusText = ToolUiKit.text($r('app.string.json_status_need_input'));
      return;
    }
    const parsed: JsonParseResult = parseJson(this.input);
    if (!parsed.ok) {
      this.showFailure(jsonErrorTextOf(parsed.error));
      return;
    }
    this.output = '';
    this.errorText = '';
    this.statusText = ToolUiKit.stringOf($r('app.string.json_status_valid'),
        [jsonSummaryText(describeJsonRoot(parsed.root)), this.duplicateHintOf(parsed)]);
  }

  private showParseStatus(outputLength: number): void {
    const parsed: JsonParseResult = parseJson(this.input);
    this.errorText = '';
    let status: string = '';
    if (parsed.ok) {
      status = jsonSummaryText(describeJsonRoot(parsed.root)) + this.duplicateHintOf(parsed);
    }
    this.statusText = ToolUiKit.stringOf($r('app.string.json_status_output'),
      [status, String(outputLength)]);
  }

  private duplicateHintOf(parsed: JsonParseResult): string {
    const hint: string = jsonDuplicateHintText(uniqueDuplicateKeys(parsed.duplicateKeys));
    if (hint.length === 0) {
      return '';
    }
    return ' ' + hint;
  }

  /** 失败时清空输出：留着上一次的成功结果会让用户以为这次也成功了 */
  private showFailure(message: string): void {
    this.output = '';
    this.statusText = '';
    this.errorText = message;
  }

  private doEscape(): void {
    if (this.escapeInput.length === 0) {
      this.escapeOutput = '';
      this.escapeError = ToolUiKit.text($r('app.string.json_escape_need_input'));
      return;
    }
    this.escapeError = '';
    this.escapeOutput = escapeJsonString(this.escapeInput);
  }

  private doUnescape(): void {
    if (this.escapeInput.length === 0) {
      this.escapeOutput = '';
      this.escapeError = ToolUiKit.text($r('app.string.json_unescape_need_input'));
      return;
    }
    const result: JsonStringResult = unescapeJsonString(this.escapeInput);
    if (!result.ok) {
      this.escapeOutput = '';
      this.escapeError = jsonStringFailureText(result.failure, result.args);
      return;
    }
    this.escapeError = '';
    this.escapeOutput = result.text;
  }

  private copyOutput(): void {
    ToolUiKit.copyText(this.output, ToolUiKit.text($r('app.string.json_copied_output')));
  }

  private copyEscapeOutput(): void {
    ToolUiKit.copyText(this.escapeOutput, ToolUiKit.text($r('app.string.json_copied')));
  }

  private clearAll(): void {
    this.input = '';
    this.output = '';
    this.escapeInput = '';
    this.escapeOutput = '';
    this.clearStatus();
    this.escapeError = '';
    toolStateStore.clearDraft(this.toolId);
  }

  // ── UI ──────────────────────────────────────────────────

  build() {
    Column({ space: 0 }) {
      this.buildSectionLabel($r('app.string.json_label_input'))
      this.buildInput()
      this.buildIndentRow()
      this.buildActionRow()
      this.buildStatusArea()
      this.buildOutputArea()
      this.buildEscapeSection()
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
  private buildInput() {
    TextArea({ text: this.input, placeholder: $r('app.string.json_placeholder') })
      .width('100%')
      .height(180)
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
  private buildIndentRow() {
    Column({ space: 0 }) {
      Text($r('app.string.json_label_indent'))
        .fontSize(scaled(13))
        .fontWeight(FontWeight.Medium)
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        .width('100%')
        .margin({ top: 12, bottom: 6 })
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
        ForEach(this.indentChoices, (choice: number) => {
          Text(choice === 0
                ? $r('app.string.json_indent_none')
                : ToolUiKit.stringOf($r('app.string.json_indent_spaces'), [String(choice)]))
            .fontSize(scaled(13))
            .fontColor(choice === this.indent ? Color.White : colorOf(NGFColorToken.ON_SURFACE))
            .accessibilityText(choice === 0 ? ToolUiKit.text($r('app.string.json_indent_none')) : ToolUiKit.stringOf($r('app.string.json_indent_spaces'), [String(choice)]))
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor(choice === this.indent
              ? colorOf(NGFColorToken.PRIMARY)
              : colorOf(NGFColorToken.SURFACE))
            .borderRadius(14)
            .margin({ right: 8, bottom: 8 })
            .onClick(() => {
              this.indent = choice;
            })
        }, (choice: number) => 'indent-' + String(choice))
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildActionRow() {
    Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
      Button($r('app.string.json_action_format'))
        .fontSize(scaled(14))
        .type(ButtonType.Capsule)
        .backgroundColor(colorOf(NGFColorToken.PRIMARY))
        .fontColor(Color.White)
        .margin({ right: 8, bottom: 8 })
        .onClick(() => {
          this.doFormat();
        })
      Button($r('app.string.json_action_minify'))
        .fontSize(scaled(14))
        .type(ButtonType.Capsule)
        .backgroundColor(colorOf(NGFColorToken.PRIMARY_CONTAINER))
        .fontColor(colorOf(NGFColorToken.PRIMARY))
        .margin({ right: 8, bottom: 8 })
        .onClick(() => {
          this.doMinify();
        })
      Button($r('app.string.json_action_validate'))
        .fontSize(scaled(14))
        .type(ButtonType.Capsule)
        .backgroundColor(colorOf(NGFColorToken.PRIMARY_CONTAINER))
        .fontColor(colorOf(NGFColorToken.PRIMARY))
        .margin({ right: 8, bottom: 8 })
        .onClick(() => {
          this.doValidate();
        })
      Button($r('app.string.json_action_copy'))
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
        Text($r('app.string.json_label_output'))
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

  @Builder
  private buildEscapeSection() {
    Column({ space: 6 }) {
      Text($r('app.string.json_label_escape'))
        .fontSize(scaled(13))
        .fontWeight(FontWeight.Medium)
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        .width('100%')
      Text($r('app.string.json_escape_hint'))
        .fontSize(scaled(12))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        .width('100%')
      TextInput({ text: this.escapeInput, placeholder: $r('app.string.json_escape_placeholder') })
        .width('100%')
        .fontSize(scaled(14))
        .padding(12)
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(12)
        .onChange((value: string) => {
          this.escapeInput = value;
        })
      Row({ space: 8 }) {
        Button($r('app.string.json_action_escape'))
          .fontSize(scaled(14))
          .type(ButtonType.Capsule)
          .backgroundColor(colorOf(NGFColorToken.PRIMARY_CONTAINER))
          .fontColor(colorOf(NGFColorToken.PRIMARY))
          .onClick(() => {
            this.doEscape();
          })
        Button($r('app.string.json_action_unescape'))
          .fontSize(scaled(14))
          .type(ButtonType.Capsule)
          .backgroundColor(colorOf(NGFColorToken.PRIMARY_CONTAINER))
          .fontColor(colorOf(NGFColorToken.PRIMARY))
          .onClick(() => {
            this.doUnescape();
          })
      }
      .width('100%')

      if (this.escapeError.length > 0) {
        Text(this.escapeError)
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.ERROR_COLOR))
          .width('100%')
      }
      if (this.escapeOutput.length > 0) {
        Row({ space: 8 }) {
          Text(this.escapeOutput)
            .fontSize(scaled(14))
            .fontColor(colorOf(NGFColorToken.ON_SURFACE))
            .layoutWeight(1)
          Text($r('app.string.shell_action_copy'))
            .fontSize(scaled(13))
            .fontColor(colorOf(NGFColorToken.PRIMARY))
            .accessibilityText(ToolUiKit.text($r('app.string.shell_action_copy')))
            .onClick(() => {
              this.copyEscapeOutput();
            })
        }
        .width('100%')
        .padding(12)
        .backgroundColor(colorOf(NGFColorToken.SURFACE_VARIANT))
        .borderRadius(12)
        .alignItems(VerticalAlign.Center)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .backgroundColor(colorOf(NGFColorToken.SURFACE))
    .borderRadius(12)
    .margin({ top: 20 })
  }
}