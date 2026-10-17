/**
 * HTML 实体编解码工具页。
 *
 * ## 布局：与 url-codec 同构（输入 → 编/解两个结果 → 统计条）
 *
 * 编码只有一个口径（保留字符集固定），所以不像 url-codec 那样双口径；
 * 扩展模式用 Toggle 开关。解码成功时显示替换次数——
 * 「替换了几处」是排查模板转义问题时最有用的数字。
 *
 * @module tools/html-entity/HtmlEntityPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { toolStateStore } from '../../core/ToolStateStore';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { ToolUiKit } from '../../ui/ToolUiKit';
import { decodeHtmlEntities, encodeHtmlEntities, HtmlEntityDecodeResult } from './HtmlEntity';
import { htmlEntityFailureText } from './HtmlEntityMessages';
import { MOTION_FEEDBACK_MS } from '../../ui/Motion';

const TOOL_ID: string = 'html-entity';
const DRAFT_DEBOUNCE_MS: number = 500;

@Builder
export function buildHtmlEntityPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildHtmlEntityContent })
}

@Builder
function buildHtmlEntityContent() {
  HtmlEntityToolBody()
}

@Component
struct HtmlEntityToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private input: string = '';
  @State private extended: boolean = false;
  @State private encoded: string = '';
  @State private decoded: HtmlEntityDecodeResult | null = null;
  @State private errorText: string = '';
  @State private copied: boolean = false;
  private draftTimer: number = -1;

  private onHistoryPick(): void {
    const restored: string = toolStateStore.readDraft(TOOL_ID);
    if (restored.length === 0) {
      return;
    }
    this.input = restored;
    this.runDecode();
  }

  aboutToAppear(): void {
    const saved: string = toolStateStore.readDraft(TOOL_ID);
    if (saved.length > 0) {
      this.input = saved;
      this.runDecode();
    }
  }

  aboutToDisappear(): void {
    this.flushDraft();
  }

  private scheduleDraftSave(): void {
    if (this.draftTimer >= 0) {
      clearTimeout(this.draftTimer);
    }
    this.draftTimer = setTimeout((): void => {
      this.flushDraft();
    }, DRAFT_DEBOUNCE_MS);
  }

  private flushDraft(): void {
    if (this.draftTimer >= 0) {
      clearTimeout(this.draftTimer);
      this.draftTimer = -1;
    }
    toolStateStore.writeDraft(TOOL_ID, this.input);
  }

  private clearAll(): void {
    this.input = '';
    this.encoded = '';
    this.decoded = null;
    this.errorText = '';
    this.flushDraft();
  }

  private runDecode(): void {
    const r: HtmlEntityDecodeResult = decodeHtmlEntities(this.input);
    if (r.ok) {
      this.errorText = '';
      this.decoded = r;
      this.encoded = '';
    } else {
      this.errorText = htmlEntityFailureText(r.failure);
      this.decoded = null;
    }
    this.scheduleDraftSave();
  }

  private runEncode(): void {
    this.errorText = '';
    this.encoded = encodeHtmlEntities(this.input, this.extended);
    this.decoded = null;
    this.scheduleDraftSave();
  }

  private copyWith(text: string): void {
    ToolUiKit.copyText(text, ToolUiKit.text($r('app.string.he_copied')));
    this.copied = true;
    setTimeout((): void => {
      this.copied = false;
    }, 1500);
  }

  build() {
    Column({ space: 16 }) {
      this.buildInputSection()
      if (this.errorText.length > 0) {
        Text(this.errorText)
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.WARNING))
          .width('100%')
          .padding(10)
          .backgroundColor(colorOf(NGFColorToken.WARNING_CONTAINER))
          .borderRadius(10)
      }
      if (this.encoded.length > 0) {
        this.buildResultBox($r('app.string.he_label_encoded'), this.encoded)
      }
      if (this.decoded !== null) {
        this.buildResultBox($r('app.string.he_label_decoded'), this.decoded.text)
        Text(ToolUiKit.stringOf($r('app.string.he_label_replaced'), [String(this.decoded.replaced)]))
          .fontSize(scaled(12))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildInputSection() {
    Column({ space: 10 }) {
      Text($r('app.string.he_label_input'))
        .fontSize(scaled(14))
        .fontWeight(FontWeight.Medium)
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))
      TextArea({ text: this.input, placeholder: $r('app.string.he_placeholder_input') })
        .width('100%')
        .height(110)
        .fontSize(scaled(13))
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(12)
        .onChange((next: string) => {
          this.input = next;
          this.scheduleDraftSave();
        })
      Row({ space: 8 }) {
        Toggle({ type: ToggleType.Checkbox, isOn: this.extended })
          .onChange((on: boolean) => {
            this.extended = on;
          })
          .accessibilityText(ToolUiKit.text($r('app.string.he_label_extended')))
        Text($r('app.string.he_label_extended'))
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE))
          .layoutWeight(1)
      }
      .width('100%')
      Row({ space: 12 }) {
        Button($r('app.string.he_action_encode'))
          .layoutWeight(1)
          .onClick(() => {
            this.runEncode();
            this.flushDraft();
          })
        Button($r('app.string.he_action_decode'))
          .layoutWeight(1)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .controlSize(ControlSize.NORMAL)
          .onClick(() => {
            this.runDecode();
            this.flushDraft();
          })
        Button($r('app.string.he_action_clear'))
          .layoutWeight(1)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .controlSize(ControlSize.NORMAL)
          .onClick(() => {
            this.clearAll();
          })
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildResultBox(label: ResourceStr, value: string) {
    Column({ space: 6 }) {
      Row() {
        Text(label)
          .fontSize(scaled(14))
          .fontWeight(FontWeight.Medium)
          .fontColor(colorOf(NGFColorToken.ON_SURFACE))
          .layoutWeight(1)
        Text(this.copied ? $r('app.string.he_copied') : $r('app.string.he_action_copy'))
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.PRIMARY))
          .accessibilityText(ToolUiKit.text($r('app.string.he_copied')))
            .scale({ x: this.copied ? 1.08 : 1, y: this.copied ? 1.08 : 1 })
            .animation({ duration: MOTION_FEEDBACK_MS, curve: Curve.EaseOut })
          .onClick(() => {
            this.copyWith(value);
          })
      }
      .width('100%')
      Text(value)
        .fontSize(scaled(13))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))
        .width('100%')
        .padding(12)
        .constraintSize({ maxHeight: 220 })
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(12)
        .copyOption(CopyOptions.LocalDevice)
        .accessibilityText(ToolUiKit.text(label) + ': ' + value)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
