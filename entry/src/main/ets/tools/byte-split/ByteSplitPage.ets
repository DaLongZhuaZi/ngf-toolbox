/**
 * 字节序演示工具页。
 *
 * ## 布局：整数输入 + 大端/小端两块对照（字节 + hex）
 *
 * @module tools/byte-split/ByteSplitPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { toolStateStore } from '../../core/ToolStateStore';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { ToolUiKit } from '../../ui/ToolUiKit';
import { ByteSplitFailureCode, ByteSplitResult, splitBytes } from './ByteSplitLogic';

const TOOL_ID: string = 'byte-split';
const DRAFT_DEBOUNCE_MS: number = 500;

@Builder
export function buildByteSplitPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildByteContent })
}

@Builder
function buildByteContent() {
  ByteToolBody()
}

@Component
struct ByteToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private input: string = '';
  @State private result: ByteSplitResult | null = null;
  @State private errorText: string = '';
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
    const r: ByteSplitResult = splitBytes(this.input);
    if (r.ok) {
      this.errorText = '';
      this.result = r;
    } else {
      this.result = null;
      this.errorText = r.failure.code === ByteSplitFailureCode.EMPTY_INPUT
        ? ToolUiKit.text($r('app.string.bs_err_empty'))
        : ToolUiKit.text($r('app.string.bs_err_range'));
    }
    this.scheduleDraftSave();
  }

  build() {
    Column({ space: 16 }) {
      Column({ space: 10 }) {
        TextInput({ text: this.input, placeholder: $r('app.string.bs_label_input') })
          .width('100%')
          .fontSize(scaled(13))
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(10)
          .onChange((v: string) => {
            this.input = v;
            this.scheduleDraftSave();
          })
        Row({ space: 12 }) {
          Button($r('app.string.bs_action_split'))
            .layoutWeight(1)
            .onClick(() => {
              this.run();
              this.flushDraft();
            })
          Button($r('app.string.bs_action_clear'))
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
          Text($r('app.string.bs_label_big'))
            .fontSize(scaled(12))
            .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
          Text(this.result.hexBigEndian)
            .fontSize(scaled(16))
            .fontFamily('monospace')
            .fontWeight(FontWeight.Bold)
            .fontColor(colorOf(NGFColorToken.PRIMARY))
          Text($r('app.string.bs_label_little'))
            .fontSize(scaled(12))
            .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
          Text(this.result.hexLittleEndian)
            .fontSize(scaled(16))
            .fontFamily('monospace')
            .fontWeight(FontWeight.Bold)
            .fontColor(colorOf(NGFColorToken.ON_SURFACE))
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
