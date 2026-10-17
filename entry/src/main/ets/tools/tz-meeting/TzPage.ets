/**
 * 时区会议工具页。
 *
 * ## 布局：时刻输入 + 八城市对照行（时间 + 合理性徽标）
 *
 * @module tools/tz-meeting/TzPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { toolStateStore } from '../../core/ToolStateStore';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { currentLocale } from '../../ui/LocaleSource';
import { ToolUiKit } from '../../ui/ToolUiKit';
import { meetingTimes, TzCityRow, TzFailureCode, TzResult } from './TzLogic';
import { MOTION_DURATION_MS, MOTION_SLIDE_VP } from '../../ui/Motion';

const TOOL_ID: string = 'tz-meeting';
const DRAFT_DEBOUNCE_MS: number = 500;

@Builder
export function buildTzPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildTzContent })
}

@Builder
function buildTzContent() {
  TzToolBody()
}

@Component
struct TzToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  private locale: string = currentLocale();
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private timeText: string = '';
  @State private result: TzResult | null = null;
  @State private errorText: string = '';
  private draftTimer: number = -1;

  private onHistoryPick(): void {
  }

  aboutToAppear(): void {
    const saved: string = toolStateStore.readDraft(TOOL_ID);
    if (saved.length > 0) {
      this.timeText = saved;
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
    toolStateStore.writeDraft(TOOL_ID, this.timeText);
  }

  private run(): void {
    const r: TzResult = meetingTimes(this.timeText, 480);
    if (r.ok) {
      this.errorText = '';
      this.result = r;
    } else {
      this.result = null;
      this.errorText = r.failure.code === TzFailureCode.EMPTY_INPUT

        ? ToolUiKit.text($r('app.string.tz_err_empty'))
        : ToolUiKit.text($r('app.string.tz_err_time'));
    }
    this.scheduleDraftSave();
  }

  build() {
    Column({ space: 16 }) {
      Column({ space: 10 }) {
        TextInput({ text: this.timeText, placeholder: $r('app.string.tz_placeholder_time') })
          .width('100%')
          .fontSize(scaled(13))
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(10)
          .onChange((v: string) => {
            this.timeText = v;
            this.run();
          })
        Button($r('app.string.tz_action_clear'))
          .width('100%')
          .buttonStyle(ButtonStyleMode.NORMAL)
          .controlSize(ControlSize.NORMAL)
          .onClick(() => {
            this.timeText = '';
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
        Column({ space: 6 }) {
          ForEach(this.result.rows, (row: TzCityRow, idx: number) => {
            Row({ space: 10 }) {
              Text(row.city.forLocale(this.locale))
                .fontSize(scaled(13))
                .fontColor(colorOf(NGFColorToken.ON_SURFACE))
                .layoutWeight(1)
              Text(row.timeText)
                .fontSize(scaled(16))
                .fontWeight(FontWeight.Bold)
                .fontColor(colorOf(NGFColorToken.PRIMARY))
              Text(row.reasonable ? $r('app.string.tz_reasonable') : $r('app.string.tz_unreasonable'))
                .fontSize(scaled(11))
                .fontColor(row.reasonable ? colorOf(NGFColorToken.SUCCESS) : colorOf(NGFColorToken.ON_SURFACE_VARIANT))
            }
            .width('100%')
            .padding(10)
            .backgroundColor(colorOf(NGFColorToken.SURFACE))
            .borderRadius(10)
            .alignItems(VerticalAlign.Center)
        .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: MOTION_SLIDE_VP })))
        .animation({ duration: MOTION_DURATION_MS, curve: Curve.EaseOut })
            .accessibilityText(row.city.forLocale(this.locale) + ' ' + row.timeText)
          }, (row: TzCityRow, idx: number) => row.city.forLocale(this.locale))
        }
        .width('100%')
        .padding(12)
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(12)
        .alignItems(HorizontalAlign.Start)

        Text($r('app.string.tz_hint_dst'))
          .fontSize(scaled(11))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}