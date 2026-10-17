/**
 * 字符频率统计工具页。
 *
 * ## 布局：文本 + 双开关 + 统计行 + 频率清单（字符/次数/占比）
 *
 * @module tools/char-frequency/CharFreqPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { toolStateStore } from '../../core/ToolStateStore';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { ToolUiKit } from '../../ui/ToolUiKit';
import { analyzeFrequency, CharFreqFailureCode, CharFreqItem, CharFreqResult } from './CharFreqLogic';

const TOOL_ID: string = 'char-frequency';
const DRAFT_DEBOUNCE_MS: number = 500;

@Builder
export function buildCharFreqPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildFreqContent })
}

@Builder
function buildFreqContent() {
  FreqToolBody()
}

@Component
struct FreqToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private input: string = '';
  @State private ignoreCase: boolean = false;
  @State private ignoreWs: boolean = true;
  @State private result: CharFreqResult | null = null;
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
    const r: CharFreqResult = analyzeFrequency(this.input, this.ignoreCase, this.ignoreWs);
    if (r.ok) {
      this.errorText = '';
      this.result = r;
    } else {
      this.result = null;
      this.errorText = ToolUiKit.text($r('app.string.cf_err_empty'));
    }
    this.scheduleDraftSave();
  }

  build() {
    Column({ space: 16 }) {
      Column({ space: 10 }) {
        TextArea({ text: this.input, placeholder: $r('app.string.cf_label_input') })
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
        Row({ space: 16 }) {
          Row({ space: 6 }) {
            Toggle({ type: ToggleType.Checkbox, isOn: this.ignoreCase })
              .onChange((on: boolean) => {
                this.ignoreCase = on;
                this.run();
              })
              .accessibilityText($r('app.string.cf_toggle_case'))
            Text($r('app.string.cf_toggle_case'))
              .fontSize(scaled(12))
              .fontColor(colorOf(NGFColorToken.ON_SURFACE))
          }
          Row({ space: 6 }) {
            Toggle({ type: ToggleType.Checkbox, isOn: this.ignoreWs })
              .onChange((on: boolean) => {
                this.ignoreWs = on;
                this.run();
              })
              .accessibilityText($r('app.string.cf_toggle_space'))
            Text($r('app.string.cf_toggle_space'))
              .fontSize(scaled(12))
              .fontColor(colorOf(NGFColorToken.ON_SURFACE))
          }
          Button($r('app.string.cf_action_clear'))
            .buttonStyle(ButtonStyleMode.NORMAL)
            .controlSize(ControlSize.NORMAL)
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
        Row({ space: 16 }) {
          Text(ToolUiKit.text($r('app.string.cf_label_total')) + ': ' + String(this.result.total))
            .fontSize(scaled(12))
            .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
          Text(ToolUiKit.text($r('app.string.cf_label_unique')) + ': ' + String(this.result.unique))
            .fontSize(scaled(12))
            .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        }
        .width('100%')

        ForEach(this.result.items, (item: CharFreqItem) => {
          Row({ space: 10 }) {
            Text(item.char)
              .fontSize(scaled(14))
              .fontFamily('monospace')
              .fontColor(colorOf(NGFColorToken.PRIMARY))
              .width(36)
            Text(String(item.count))
              .fontSize(scaled(13))
              .fontColor(colorOf(NGFColorToken.ON_SURFACE))
              .width(50)
            Text(item.percent + '%')
              .fontSize(scaled(12))
              .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
              .layoutWeight(1)
          }
          .width('100%')
          .padding(8)
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(8)
          .alignItems(VerticalAlign.Center)
          .accessibilityText(item.char + ' ' + String(item.count))
        }, (item: CharFreqItem) => item.char + ':' + item.count)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
