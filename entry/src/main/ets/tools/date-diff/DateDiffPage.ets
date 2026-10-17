/**
 * 日期差计算工具页。
 *
 * ## 布局：双日期输入 + 三行结果（自然日/工作日/周数）
 *
 * @module tools/date-diff/DateDiffPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { toolStateStore } from '../../core/ToolStateStore';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { ToolUiKit } from '../../ui/ToolUiKit';
import { DateDiffFailureCode, DateDiffResult, diffDates } from './DateDiffLogic';

const TOOL_ID: string = 'date-diff';
const DRAFT_DEBOUNCE_MS: number = 500;

@Builder
export function buildDateDiffPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildDiffContent })
}

@Builder
function buildDiffContent() {
  DiffToolBody()
}

@Component
struct DiffToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private startText: string = '';
  @State private endText: string = '';
  @State private result: DateDiffResult | null = null;
  @State private errorText: string = '';
  private draftTimer: number = -1;

  private onHistoryPick(): void {
  }

  aboutToAppear(): void {
    const saved: string = toolStateStore.readDraft(TOOL_ID);
    if (saved.length > 0) {
      this.startText = saved;
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
    toolStateStore.writeDraft(TOOL_ID, this.startText);
  }
  private run(): void {
    const r: DateDiffResult = diffDates(this.startText, this.endText);
    if (r.ok) {
      this.errorText = '';
      this.result = r;
    } else {
      this.result = null;
      if (r.failure.code === DateDiffFailureCode.EMPTY_INPUT) {
        this.errorText = ToolUiKit.text($r('app.string.dd_err_empty'));
      } else {
        this.errorText = ToolUiKit.text($r('app.string.dd_err_date'));
      }
    }
    this.scheduleDraftSave();
  }

  @Builder
  private rowOf(label: ResourceStr, value: string) {
    Row({ space: 10 }) {
      Text(label)
        .fontSize(scaled(12))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        .width(70)
      Text(value)
        .fontSize(scaled(15))
        .fontWeight(FontWeight.Bold)
        .fontColor(colorOf(NGFColorToken.PRIMARY));
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .accessibilityText(ToolUiKit.text(label) + ': ' + value)
  }
  build() {
    Column({ space: 16 }) {
      Column({ space: 10 }) {
        TextInput({ text: this.startText, placeholder: $r('app.string.dd_label_start') })
          .width('100%')
          .fontSize(scaled(13))
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(10)
          .onChange((v: string) => {
            this.startText = v;
            this.scheduleDraftSave();
          })
        TextInput({ text: this.endText, placeholder: $r('app.string.dd_label_end') })
          .width('100%')
          .fontSize(scaled(13))
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(10)
          .onChange((v: string) => {
            this.endText = v;
            this.scheduleDraftSave();
          })
        Row({ space: 12 }) {
          Button($r('app.string.dd_action_calc'))
            .layoutWeight(1)
            .onClick(() => {
              this.run();
              this.flushDraft();
            })
          Button($r('app.string.dd_action_clear'))
            .buttonStyle(ButtonStyleMode.NORMAL)
            .controlSize(ControlSize.NORMAL)
            .layoutWeight(1)
            .onClick(() => {
              this.startText = '';
              this.endText = '';
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
          this.rowOf($r('app.string.dd_label_natural'), String(this.result.naturalDays))
          this.rowOf($r('app.string.dd_label_work'), String(this.result.workdays))
          this.rowOf($r('app.string.dd_label_weeks'), String(this.result.weeks))
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