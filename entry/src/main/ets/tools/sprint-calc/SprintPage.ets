/**
 * 迭代计算工具页。
 *
 * ## 布局：日期 + 天数 + 结果（日期/星期/自然日）+ 节假日提示
 *
 * @module tools/sprint-calc/SprintPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { toolStateStore } from '../../core/ToolStateStore';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { ToolUiKit } from '../../ui/ToolUiKit';
import { addWorkdays, SprintFailureCode, SprintResult } from './SprintLogic';
import { MOTION_DURATION_MS, MOTION_SLIDE_VP } from '../../ui/Motion';

const TOOL_ID: string = 'sprint-calc';
const DRAFT_DEBOUNCE_MS: number = 500;

@Builder
export function buildSprintPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildSprintContent })
}

@Builder
function buildSprintContent() {
  SprintToolBody()
}

@Component
struct SprintToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private dateText: string = '';
  @State private daysText: string = '10';
  @State private result: SprintResult | null = null;
  @State private errorText: string = '';
  private draftTimer: number = -1;

  private onHistoryPick(): void {
  }

  aboutToAppear(): void {
    const saved: string = toolStateStore.readDraft(TOOL_ID);
    if (saved.length > 0) {
      this.dateText = saved;
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
    toolStateStore.writeDraft(TOOL_ID, this.dateText);
  }

  private run(): void {
    const r: SprintResult = addWorkdays(this.dateText, this.daysText);
    if (r.ok) {
      this.errorText = '';
      this.result = r;
    } else {
      this.result = null;
      if (r.failure.code === SprintFailureCode.EMPTY_INPUT) {
        this.errorText = ToolUiKit.text($r('app.string.sc_err_empty'));
      } else if (r.failure.code === SprintFailureCode.BAD_DATE) {
        this.errorText = ToolUiKit.text($r('app.string.sc_err_date'));
      } else {
        this.errorText = ToolUiKit.text($r('app.string.sc_err_days'));
      }
    }
    this.scheduleDraftSave();
  }

  private weekdayText(code: number): string {
    if (code === 0) { return ToolUiKit.text($r('app.string.sc_wd_0')); }
    if (code === 1) { return ToolUiKit.text($r('app.string.sc_wd_1')); }
    if (code === 2) { return ToolUiKit.text($r('app.string.sc_wd_2')); }
    if (code === 3) { return ToolUiKit.text($r('app.string.sc_wd_3')); }
    if (code === 4) { return ToolUiKit.text($r('app.string.sc_wd_4')); }
    if (code === 5) { return ToolUiKit.text($r('app.string.sc_wd_5')); }
    return ToolUiKit.text($r('app.string.sc_wd_6'));
  }

  build() {
    Column({ space: 16 }) {
      Column({ space: 10 }) {
        TextInput({ text: this.dateText, placeholder: $r('app.string.sc_label_date') })
          .width('100%')
          .fontSize(scaled(13))
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(10)
          .onChange((v: string) => {
            this.dateText = v;
            this.scheduleDraftSave();
          })
        TextInput({ text: this.daysText, placeholder: $r('app.string.sc_label_days') })
          .width('100%')
          .fontSize(scaled(13))
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(10)
          .onChange((v: string) => {
            this.daysText = v;
            this.scheduleDraftSave();
          })
        Row({ space: 12 }) {
          Button($r('app.string.sc_action_calc'))
            .layoutWeight(1)
            .onClick(() => {
              this.run();
              this.flushDraft();
            })
          Button($r('app.string.sc_action_clear'))
            .layoutWeight(1)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .controlSize(ControlSize.NORMAL)
            .onClick(() => {
              this.dateText = '';
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
          Row({ space: 10 }) {
            Text($r('app.string.sc_label_result'))
              .fontSize(scaled(12))
              .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
            Text(this.result.resultDate)
              .fontSize(scaled(18))
              .fontWeight(FontWeight.Bold)
              .fontColor(colorOf(NGFColorToken.PRIMARY))
            Text(this.weekdayText(this.result.resultWeekday))
              .fontSize(scaled(13))
              .fontColor(colorOf(NGFColorToken.ON_SURFACE))
            Text('')
            Text(ToolUiKit.text($r('app.string.sc_label_natural')) + ': ' + String(this.result.naturalDays))
              .fontSize(scaled(12))
              .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
        .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: MOTION_SLIDE_VP })))
        .animation({ duration: MOTION_DURATION_MS, curve: Curve.EaseOut })
        }
        .width('100%')
        .padding(12)
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(12)
        .alignItems(HorizontalAlign.Start)

        Text($r('app.string.sc_hint_holiday'))
          .fontSize(scaled(11))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}