/**
 * 文本自动换行工具页。
 *
 * ## 布局：文本 + 宽度 + 输出（等宽）+ 行数
 *
 * @module tools/word-wrap/WordWrapPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { toolStateStore } from '../../core/ToolStateStore';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { ToolUiKit } from '../../ui/ToolUiKit';
import { WrapFailureCode, WrapResult, wrapText } from './WordWrapLogic';

const TOOL_ID: string = 'word-wrap';
const DRAFT_DEBOUNCE_MS: number = 500;

@Builder
export function buildWordWrapPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildWrapContent })
}

@Builder
function buildWrapContent() {
  WrapToolBody()
}

@Component
struct WrapToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private input: string = '';
  @State private widthText: string = '80';
  @State private result: WrapResult | null = null;
  @State private errorText: string = '';
  @State private copied: boolean = false;
  private draftTimer: number = -1;

  private onHistoryPick(): void {
  }

  aboutToAppear(): void {
    const saved: string = toolStateStore.readDraft(TOOL_ID);
    if (saved.length > 0) {
      this.input = saved;
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
    const r: WrapResult = wrapText(this.input, this.widthText);
    if (r.ok) {
      this.errorText = '';
      this.result = r;
    } else {
      this.result = null;
      this.errorText = r.failure.code === WrapFailureCode.EMPTY_INPUT
        ? ToolUiKit.text($r('app.string.ww_err_empty'))
        : ToolUiKit.text($r('app.string.ww_err_width'));
    }
    this.scheduleDraftSave();
  }

  build() {
    Column({ space: 16 }) {
      Column({ space: 10 }) {
        TextArea({ text: this.input, placeholder: $r('app.string.ww_label_input') })
          .width('100%')
          .height(110)
          .fontSize(scaled(12))
          .fontFamily('monospace')
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(12)
          .onChange((v: string) => {
            this.input = v;
            this.scheduleDraftSave();
          })
        TextInput({ text: this.widthText, placeholder: $r('app.string.ww_label_width') })
          .width('100%')
          .fontSize(scaled(13))
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(10)
          .onChange((v: string) => {
            this.widthText = v;
            this.scheduleDraftSave();
          })
        Row({ space: 12 }) {
          Button($r('app.string.ww_action_wrap'))
            .layoutWeight(1)
            .onClick(() => {
              this.run();
              this.flushDraft();
            })
          Button($r('app.string.ww_action_clear'))
            .buttonStyle(ButtonStyleMode.NORMAL)
            .controlSize(ControlSize.NORMAL)
            .layoutWeight(1)
            .onClick(() => {
              this.input = '';
              this.result = null;
              this.errorText = '';
              this.flushDraft();
            })
        }
        .width('100%')
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
            Text($r('app.string.ww_label_output'))
              .fontSize(scaled(12))
              .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
              .layoutWeight(1)
            Text(ToolUiKit.text($r('app.string.ww_label_lines')) + ': ' + String(this.result.lineCount))
              .fontSize(scaled(12))
              .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
            Text(this.copied ? $r('app.string.ww_copied') : $r('app.string.ww_action_copy'))
              .fontSize(scaled(12))
              .fontColor(colorOf(NGFColorToken.PRIMARY))
              .accessibilityText(ToolUiKit.text($r('app.string.copied_common')))
              .margin({ left: 12 })
              .onClick(() => {
                ToolUiKit.copyText(this.result === null ? '' : this.result.output,
                  ToolUiKit.text($r('app.string.ww_copied')));
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
}
