/**
 * CSV 与 JSON 互转工具页。
 *
 * ## 布局：一个输入框 + 两个方向按钮 + 结果区
 *
 * 两个方向共用一个输入框（自动按按钮判断口径），结果区带行×列统计。
 * 与 url-codec 同构的三段节奏。
 *
 * @module tools/csv-json/CsvJsonPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { toolStateStore } from '../../core/ToolStateStore';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { ToolUiKit } from '../../ui/ToolUiKit';
import { CsvToJsonResult, JsonToCsvResult, csvToJson, jsonToCsv } from './CsvJson';
import { csvJsonFailureText } from './CsvJsonMessages';
import { MOTION_FEEDBACK_MS } from '../../ui/Motion';

const TOOL_ID: string = 'csv-json';
const DRAFT_DEBOUNCE_MS: number = 500;

@Builder
export function buildCsvJsonPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildCsvJsonContent })
}

@Builder
function buildCsvJsonContent() {
  CsvJsonToolBody()
}

@Component
struct CsvJsonToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private input: string = '';
  @State private jsonResult: CsvToJsonResult | null = null;
  @State private csvResult: JsonToCsvResult | null = null;
  @State private errorText: string = '';
  @State private copied: boolean = false;
  private draftTimer: number = -1;

  private onHistoryPick(): void {
    const restored: string = toolStateStore.readDraft(TOOL_ID);
    if (restored.length === 0) {
      return;
    }
    this.input = restored;
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

  private clearAll(): void {
    this.input = '';
    this.jsonResult = null;
    this.csvResult = null;
    this.errorText = '';
    this.flushDraft();
  }

  private resultText(): string {
    if (this.jsonResult !== null) {
      return this.jsonResult.json;
    }
    if (this.csvResult !== null) {
      return this.csvResult.csv;
    }
    return '';
  }

  private statText(): string {
    if (this.jsonResult !== null) {
      return ToolUiKit.stringOf($r('app.string.cj_stats'),
        [String(this.jsonResult.rowCount), String(this.jsonResult.columnCount)]);
    }
    if (this.csvResult !== null) {
      return ToolUiKit.stringOf($r('app.string.cj_stats'),
        [String(this.csvResult.rowCount), String(this.csvResult.columnCount)]);
    }
    return '';
  }

  private runToJson(): void {
    const r: CsvToJsonResult = csvToJson(this.input);
    if (r.ok) {
      this.errorText = '';
      this.jsonResult = r;
      this.csvResult = null;
    } else {
      this.errorText = csvJsonFailureText(r.failure);
      this.jsonResult = null;
      this.csvResult = null;
    }
    this.scheduleDraftSave();
  }

  private runToCsv(): void {
    const r: JsonToCsvResult = jsonToCsv(this.input);
    if (r.ok) {
      this.errorText = '';
      this.csvResult = r;
      this.jsonResult = null;
    } else {
      this.errorText = csvJsonFailureText(r.failure);
      this.csvResult = null;
      this.jsonResult = null;
    }
    this.scheduleDraftSave();
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
      if (this.jsonResult !== null || this.csvResult !== null) {
        this.buildResultSection()
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildInputSection() {
    Column({ space: 10 }) {
      Text($r('app.string.cj_label_input'))
        .fontSize(scaled(14))
        .fontWeight(FontWeight.Medium)
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))
      TextArea({ text: this.input, placeholder: $r('app.string.cj_placeholder_csv') })
        .width('100%')
        .height(130)
        .fontSize(scaled(13))
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(12)
        .onChange((next: string) => {
          this.input = next;
          this.scheduleDraftSave();
        })
      Row({ space: 12 }) {
        Button($r('app.string.cj_action_to_json'))
          .layoutWeight(1)
          .onClick(() => {
            this.runToJson();
            this.flushDraft();
          })
        Button($r('app.string.cj_action_to_csv'))
          .layoutWeight(1)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .controlSize(ControlSize.NORMAL)
          .onClick(() => {
            this.runToCsv();
            this.flushDraft();
          })
        Button($r('app.string.cj_action_clear'))
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
  private buildResultSection() {
    Column({ space: 6 }) {
      Row() {
        Text(this.statText())
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE))
          .layoutWeight(1)
        Text(this.copied ? $r('app.string.cj_copied') : $r('app.string.cj_action_copy'))
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.PRIMARY))
          .accessibilityText(ToolUiKit.text($r('app.string.copied_common')))
            .scale({ x: this.copied ? 1.08 : 1, y: this.copied ? 1.08 : 1 })
            .animation({ duration: MOTION_FEEDBACK_MS, curve: Curve.EaseOut })
          .onClick(() => {
            ToolUiKit.copyText(this.resultText(), ToolUiKit.text($r('app.string.cj_copied')));
            this.copied = true;
            setTimeout((): void => {
              this.copied = false;
            }, 1500);
          })
      }
      .width('100%')
      Text($r('app.string.cj_label_result'))
        .fontSize(scaled(12))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
      Text(this.resultText())
        .fontSize(scaled(13))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))
        .width('100%')
        .padding(12)
        .constraintSize({ maxHeight: 300 })
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(12)
        .copyOption(CopyOptions.LocalDevice)
        .accessibilityText(this.statText() + ': ' + this.resultText())
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
