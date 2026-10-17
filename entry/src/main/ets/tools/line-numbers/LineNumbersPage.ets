/**
 * 行号添加器工具页。
 *
 * ## 布局：文本 + 样式/起始号 + 输出（等宽）
 *
 * @module tools/line-numbers/LineNumbersPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { toolStateStore } from '../../core/ToolStateStore';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { ToolUiKit } from '../../ui/ToolUiKit';
import { addLineNumbers, LineNumFailureCode, LineNumResult, LineNumStyle } from './LineNumbersLogic';

const TOOL_ID: string = 'line-numbers';
const DRAFT_DEBOUNCE_MS: number = 500;

@Builder
export function buildLineNumbersPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildLineNumContent })
}

@Builder
function buildLineNumContent() {
  LineNumToolBody()
}

@Component
struct LineNumToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private input: string = '';
  @State private style: LineNumStyle = LineNumStyle.DOT;
  @State private startText: string = '1';
  @State private result: LineNumResult | null = null;
  @State private errorText: string = '';
  @State private copied: boolean = false;
  private draftTimer: number = -1;

  private onHistoryPick(): void {
  }

  aboutToAppear(): void {
    const saved: string = toolStateStore.readDraft(TOOL_ID);
    if (saved.length > 0) {
      this.input = saved;
      this.run();
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

  private run(): void {
    const start: number = parseInt(this.startText, 10);
    const r: LineNumResult = addLineNumbers(this.input, this.style, isNaN(start) ? 1 : start);
    if (r.ok) {
      this.errorText = '';
      this.result = r;
    } else {
      this.result = null;
      this.errorText = ToolUiKit.text($r('app.string.ln_err_empty'));
    }
    this.scheduleDraftSave();
  }

  build() {
    Column({ space: 16 }) {
      Column({ space: 10 }) {
        TextArea({ text: this.input, placeholder: $r('app.string.ln_label_input') })
          .width('100%')
          .height(110)
          .fontSize(scaled(12))
          .fontFamily('monospace')
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(12)
          .onChange((v: string) => {
            this.input = v;
            this.run();
          })
        Row({ space: 10 }) {
          this.chip($r('app.string.ln_style_dot'), LineNumStyle.DOT)
          this.chip($r('app.string.ln_style_bracket'), LineNumStyle.BRACKET)
          this.chip($r('app.string.ln_style_colon'), LineNumStyle.COLON)
          TextInput({ text: this.startText, placeholder: $r('app.string.ln_label_start') })
            .layoutWeight(1)
            .fontSize(scaled(13))
            .backgroundColor(colorOf(NGFColorToken.SURFACE))
            .borderRadius(10)
            .onChange((v: string) => {
              this.startText = v;
              this.run();
            })
        }
        .width('100%')
        Button($r('app.string.ln_action_clear'))
          .width('100%')
          .buttonStyle(ButtonStyleMode.NORMAL)
          .controlSize(ControlSize.NORMAL)
          .onClick(() => {
            this.input = '';
            this.result = null;
            this.errorText = '';
            this.flushDraft();
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      if (this.errorText.length > 0) {
        Text(this.errorText)
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.WARNING))
          .width('100%')
          .padding(10)
          .backgroundColor(colorOf(NGFColorToken.WARNING_CONTAINER))
          .borderRadius(10)
      }

      if (this.result !== null) {
        Column({ space: 8 }) {
          Row() {
            Text($r('app.string.ln_label_output'))
              .fontSize(scaled(12))
              .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
              .layoutWeight(1)
            Text(this.copied ? $r('app.string.ln_copied') : $r('app.string.ln_action_copy'))
              .fontSize(scaled(12))
              .fontColor(colorOf(NGFColorToken.PRIMARY))
              .accessibilityText(ToolUiKit.text($r('app.string.copied_common')))
              .onClick(() => {
                ToolUiKit.copyText(this.result === null ? '' : this.result.output,
                  ToolUiKit.text($r('app.string.ln_copied')));
                this.copied = true;
                setTimeout((): void => {
                  this.copied = false;
                }, 1500);
              })
          }
          .width('100%')
          Text(this.result.output)
            .fontSize(scaled(12))
            .fontFamily('monospace')
            .fontColor(colorOf(NGFColorToken.ON_SURFACE))
            .width('100%')
            .constraintSize({ maxHeight: 240 })
            .copyOption(CopyOptions.LocalDevice)
        }
        .width('100%')
        .padding(12)
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(12)
        .alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private chip(label: ResourceStr, style: LineNumStyle) {
    Text(label)
      .fontSize(scaled(12))
      .fontColor(this.style === style ? colorOf(NGFColorToken.ON_PRIMARY) : colorOf(NGFColorToken.ON_SURFACE))
      .backgroundColor(this.style === style ? colorOf(NGFColorToken.PRIMARY) : colorOf(NGFColorToken.SURFACE))
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .borderRadius(16)
      .margin(2)
      .onClick(() => {
        this.style = style;
        this.run();
      })
      .accessibilityText(ToolUiKit.text(label))
  }
}
