/**
 * URL 编解码工具页。
 *
 * ## 布局：三段节奏，与现有工具一致
 *
 * 输入区（一个 TextArea，编解码共用）→ 两个方向的结果（编码/解码并排不下，上下放）→
 * query 参数表（逐参数卡片，双口径并排）。手机竖屏里「两个口径」左右并排会各剩 ~170vp，
 * 中文一行放不下十个字，所以**上下放、各自带标签**。
 *
 * ## 双口径为什么两个都展示
 *
 * + 号在表单口径里是空格、在 RFC 3986 里是字面量，**都有真实场景**。
 * 工具不替用户猜，两版都给，并提示「字面加号请写 %2B」。
 *
 * @module tools/url-codec/UrlCodecPage
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
  decodeUrlText,
  decodeUrlTextLiteral,
  encodeUrlText,
  parseUrlQuery,
  UrlCodecParseTextResult,
  UrlQueryPart,
  UrlQueryParseResult
} from './UrlCodec';
import { urlCodecFailureText } from './UrlCodecMessages';
import { MOTION_FEEDBACK_MS } from '../../ui/Motion';

/** 工具 id：草稿按它存取，必须与 ToolsCatalog 里登记的 id 一致 */
const TOOL_ID: string = 'url-codec';

/** 草稿写入防抖（毫秒） */
const DRAFT_DEBOUNCE_MS: number = 500;

@Builder
export function buildUrlCodecPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildUrlCodecContent })
}

@Builder
function buildUrlCodecContent() {
  UrlCodecToolBody()
}

@Component
struct UrlCodecToolBody {
  /** 订阅主题深浅；本字段本身不用，作用是主题切换时触发重渲染。 */
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  /** 订阅字体缩放；本字段不用，作用是切字号时触发重渲染。 */
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  /** 历史回填序号；变化时由 @Watch 触发 onHistoryPick */
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private input: string = '';
  @State private encoded: string = '';
  @State private decodedForm: string = '';
  @State private decodedLiteral: string = '';
  @State private errorText: string = '';
  @State private parts: Array<UrlQueryPart> = [];
  @State private showParts: boolean = false;
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
    this.decodedForm = '';
    this.decodedLiteral = '';
    this.errorText = '';
    this.parts = [];
    this.showParts = false;
    this.flushDraft();
  }

  /** 解码：表单口径与字面口径并排算；顺带把 query 拆出来 */
  private runDecode(): void {
    const form: UrlCodecParseTextResult = decodeUrlText(this.input);
    const literal: UrlCodecParseTextResult = decodeUrlTextLiteral(this.input);
    if (!form.ok) {
      this.errorText = urlCodecFailureText(form.failure);
      this.decodedForm = '';
      this.decodedLiteral = '';
      this.parts = [];
      this.showParts = false;
      return;
    }
    this.errorText = '';
    this.decodedForm = form.text;
    this.decodedLiteral = literal.ok ? literal.text : form.text;
    const q: UrlQueryParseResult = parseUrlQuery(this.input);
    this.parts = q.parts;
    this.showParts = q.parts.length > 0;
  }

  private runEncode(): void {
    this.errorText = '';
    this.encoded = encodeUrlText(this.input);
    const q: UrlQueryParseResult = parseUrlQuery(this.input);
    this.parts = q.parts;
    this.showParts = q.parts.length > 0;
  }

  private copyWith(text: string): void {
    ToolUiKit.copyText(text, ToolUiKit.text($r('app.string.url_codec_copied')));
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
        this.buildResultBox($r('app.string.url_codec_label_encoded'), this.encoded)
      }
      if (this.decodedForm.length > 0) {
        this.buildResultBox($r('app.string.url_codec_label_decoded'), this.decodedForm)
        if (this.decodedLiteral !== this.decodedForm) {
          this.buildResultBox($r('app.string.url_codec_label_decoded_literal'), this.decodedLiteral)
        }
      }
      if (this.showParts) {
        this.buildPartsSection()
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 输入区：一个输入框 + 编/解/清三个动作 */
  @Builder
  private buildInputSection() {
    Column({ space: 10 }) {
      Text($r('app.string.url_codec_label_input'))
        .fontSize(scaled(14))
        .fontWeight(FontWeight.Medium)
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))

      TextArea({ text: this.input, placeholder: $r('app.string.url_codec_placeholder_input') })
        .width('100%')
        .height(120)
        .fontSize(scaled(13))
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(12)
        .onChange((next: string) => {
          this.input = next;
          this.scheduleDraftSave();
        })

      Text($r('app.string.url_codec_hint_plus'))
        .fontSize(scaled(12))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))

      Row({ space: 12 }) {
        Button($r('app.string.url_codec_action_encode'))
          .layoutWeight(1)
          .onClick(() => {
            this.runEncode();
            this.flushDraft();
          })
        Button($r('app.string.url_codec_action_decode'))
          .layoutWeight(1)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .controlSize(ControlSize.NORMAL)
          .onClick(() => {
            this.runDecode();
            this.flushDraft();
          })
        Button($r('app.string.url_codec_action_clear'))
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

  /** 结果块：标签 + 可复制文本 */
  @Builder
  private buildResultBox(label: ResourceStr, value: string) {
    Column({ space: 6 }) {
      Row() {
        Text(label)
          .fontSize(scaled(14))
          .fontWeight(FontWeight.Medium)
          .fontColor(colorOf(NGFColorToken.ON_SURFACE))
          .layoutWeight(1)
        Text(this.copied ? $r('app.string.url_codec_copied') : $r('app.string.url_codec_action_copy'))
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.PRIMARY))
          .accessibilityText(ToolUiKit.text($r('app.string.url_codec_copied')))
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
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(12)
        .copyOption(CopyOptions.LocalDevice)
        .accessibilityText(label + ': ' + value)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** query 参数表：逐参数一张卡，双口径并排 */
  @Builder
  private buildPartsSection() {
    Column({ space: 10 }) {
      Text($r('app.string.url_codec_label_query'))
        .fontSize(scaled(14))
        .fontWeight(FontWeight.Medium)
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))

      ForEach(this.parts, (part: UrlQueryPart, idx: number) => {
        Column({ space: 6 }) {
          Row({ space: 8 }) {
            Text(part.key + (part.valueless ? ' ' + ToolUiKit.text($r('app.string.url_codec_label_valueless')) : ''))
              .fontSize(scaled(13))
              .fontWeight(FontWeight.Medium)
              .fontColor(colorOf(NGFColorToken.PRIMARY))
              .layoutWeight(1)
          }
          .width('100%')

          this.buildPartRow($r('app.string.url_codec_label_raw'),
            part.valueless ? part.rawKey : part.rawValue)

          if (!part.valueless) {
            this.buildPartRow($r('app.string.url_codec_label_decoded'), part.value)
            if (part.valuePlusLiteral !== part.value) {
              this.buildPartRow($r('app.string.url_codec_label_decoded_literal'), part.valuePlusLiteral)
            }
          }
        }
        .width('100%')
        .padding(12)
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(12)
        .alignItems(HorizontalAlign.Start)
      }, (part: UrlQueryPart, idx: number) => idx + ':' + part.rawKey + '=' + part.rawValue)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 参数卡里的一行（标签 + 值） */
  @Builder
  private buildPartRow(label: ResourceStr, value: string) {
    Row({ space: 8 }) {
      Text(label)
        .fontSize(scaled(12))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        .width(84)
      Text(value)
        .fontSize(scaled(12))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))
        .layoutWeight(1)
        .maxLines(3)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }
}
