/**
 * 十六进制转储工具页。
 *
 * ## 布局：文本输入 + 转储输出（等宽）+ 字节数
 *
 * @module tools/hex-dump/HexDumpPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { toolStateStore } from '../../core/ToolStateStore';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { ToolUiKit } from '../../ui/ToolUiKit';
import { HexDumpFailureCode, HexDumpResult, hexDump } from './HexDumpLogic';

const TOOL_ID: string = 'hex-dump';
const DRAFT_DEBOUNCE_MS: number = 500;

@Builder
export function buildHexDumpPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildHexContent })
}

@Builder
function buildHexContent() {
  HexToolBody()
}

@Component
struct HexToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private input: string = '';
  @State private result: HexDumpResult | null = null;
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
    const r: HexDumpResult = hexDump(this.input);
    if (r.ok) {
      this.errorText = '';
      this.result = r;
    } else {
      this.result = null;
      this.errorText = ToolUiKit.text($r('app.string.hd_err_empty'));
    }
    this.scheduleDraftSave();
  }

  build() {
    Column({ space: 16 }) {
      Column({ space: 10 }) {
        TextArea({ text: this.input, placeholder: $r('app.string.hd_label_input') })
          .width('100%')
          .height(100)
          .fontSize(scaled(12))
          .fontFamily('monospace')
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(12)
          .onChange((v: string) => {
            this.input = v;
            this.run();
          })
        Row({ space: 12 }) {
          Button($r('app.string.hd_action_dump'))
            .layoutWeight(1)
            .onClick(() => {
              this.run();
              this.flushDraft();
            })
          Button($r('app.string.hd_action_clear'))
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
            Text($r('app.string.hd_label_output'))
              .fontSize(scaled(12))
              .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
              .layoutWeight(1)
            Text(ToolUiKit.text($r('app.string.hd_label_bytes')) + ': ' + String(this.result.byteCount))
              .fontSize(scaled(12))
              .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
            Text(this.copied ? $r('app.string.hd_copied') : $r('app.string.hd_action_copy'))
              .fontSize(scaled(12))
              .fontColor(colorOf(NGFColorToken.PRIMARY))
              .accessibilityText(ToolUiKit.text($r('app.string.copied_common')))
              .margin({ left: 12 })
              .onClick(() => {
                ToolUiKit.copyText(this.result === null ? '' : this.result.dump,
                  ToolUiKit.text($r('app.string.hd_copied')));
                this.copied = true;
                setTimeout((): void => {
                  this.copied = false;
                }, 1500);
              })
          }
          .width('100%')
          Text(this.result.dump)
            .fontSize(scaled(11))
            .fontFamily('monospace')
            .fontColor(colorOf(NGFColorToken.ON_SURFACE))
            .width('100%')
            .constraintSize({ maxHeight: 280 })
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
