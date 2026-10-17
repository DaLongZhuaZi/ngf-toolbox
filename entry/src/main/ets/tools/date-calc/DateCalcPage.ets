/**
 * 日期计算工具页。
 *
 * 两种模式共用一份日期解析逻辑（{@link ./DateCalc}），页面只切换"问哪个问题"：
 * - **间隔**：两个日期差多少天/多少个工作日；
 * - **加减**：某个日期加减若干天/月/年。
 *
 * 加减月/年时如果发生了"夹到月末"（例如 1/31 加一个月），结果旁边必须显式提示，
 * 否则用户会以为工具算错了——其实是这个操作本身没有唯一正确答案，只能选一个并说清楚。
 *
 * @module tools/date-calc/DateCalcPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { toolStateStore } from '../../core/ToolStateStore';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { ToolUiKit } from '../../ui/ToolUiKit';
import { currentLocale, FALLBACK_LOCALE } from '../../ui/LocaleSource';
import {
  addDaysToDate,
  addMonthsToDate,
  addYearsToDate,
  DateDiffResult,
  DateShiftResult,
  diffDates,
  formatDateWithWeekday,
  NGFDate
} from './DateCalc';
import {
  dateDiffFailureText,
  dateGapText,
  dateShiftFailureText
} from './DateCalcMessages';

/** 工具 id：草稿按它存取，必须与 ToolsCatalog 里登记的 id 一致 */
const TOOL_ID: string = 'date-calc';

/** 草稿写入防抖（毫秒） */
const DRAFT_DEBOUNCE_MS: number = 400;

/** 模式标识 */
const MODE_GAP: string = 'gap';
const MODE_SHIFT: string = 'shift';

/** 加减单位标识 */
const UNIT_DAY: string = 'day';
const UNIT_MONTH: string = 'month';
const UNIT_YEAR: string = 'year';

/** 今天的本地日期（'YYYY-MM-DD'） */
function todayText(): string {
  const now: Date = new Date();
  const month: number = now.getMonth() + 1;
  const day: number = now.getDate();
  return String(now.getFullYear()) + '-' + (month < 10 ? '0' + String(month) : String(month))
    + '-' + (day < 10 ? '0' + String(day) : String(day));
}

@Builder
export function buildDateCalcPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildDateCalcContent })
}

@Builder
function buildDateCalcContent() {
  DateCalcToolBody()
}

@Component
struct DateCalcToolBody {
  /** 订阅主题深浅；本字段本身不用，作用是在主题切换时触发本组件重渲染。 */
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  /** 订阅字体缩放；本字段不用，作用是切字号时触发本组件重渲染。 */
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  /** 历史回填序号；变化时由 @Watch 触发 onHistoryPick（见 ui/HistoryPick.ets） */
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  /** 当前语言：结果里的星期名是双语数据，按它取 */
  @State private locale: string = FALLBACK_LOCALE;
  @State private mode: string = MODE_GAP;
  @State private startText: string = '';
  @State private endText: string = '';
  @State private excludeWeekends: boolean = true;
  @State private gapDays: number = 0;
  @State private gapWorkdays: number = 0;
  @State private gapMessage: string = '';
  @State private gapError: string = '';
  @State private gapDone: boolean = false;
  @State private baseText: string = '';
  @State private amountText: string = '1';
  @State private unit: string = UNIT_DAY;
  @State private shiftText: string = '';
  @State private shiftError: string = '';
  @State private shiftClamped: boolean = false;
  private draftTimer: number = -1;

  /** 用户在壳层选中一条历史 → 从草稿重读本次输入（见 ui/HistoryPick.ets） */

  private onHistoryPick(): void {

    const restored: string = toolStateStore.readDraft(TOOL_ID);

    if (restored.length === 0) {

      return;

    }

    this.startText = restored;

  }


  aboutToAppear(): void {
    this.locale = currentLocale();
    const saved: string = toolStateStore.readDraft(TOOL_ID);
    const today: string = todayText();
    this.startText = today;
    this.endText = today;
    this.baseText = today;
    if (saved.length > 0) {
      this.applyDraft(saved);
    }
  }

  aboutToDisappear(): void {
    this.flushDraft();
  }

  build() {
    Column({ space: 16 }) {
      this.buildModeSection()

      if (this.mode === MODE_GAP) {
        this.buildGapSection()
      } else {
        this.buildShiftSection()
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 模式切换 */
  @Builder
  private buildModeSection() {
    Row({ space: 8 }) {
      Text($r('app.string.date_label_diff'))
        .fontSize(scaled(14))
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .padding(10)
        .borderRadius(10)
        .backgroundColor(this.mode === MODE_GAP ? colorOf(NGFColorToken.PRIMARY_CONTAINER) : colorOf(NGFColorToken.SURFACE))
        .fontColor(this.mode === MODE_GAP ? colorOf(NGFColorToken.PRIMARY) : colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        .accessibilityText(ToolUiKit.text($r('app.string.date_label_diff')))
        .onClick(() => {
          this.mode = MODE_GAP;
          this.saveDraft();
        })

      Text($r('app.string.date_label_shift'))
        .fontSize(scaled(14))
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .padding(10)
        .borderRadius(10)
        .backgroundColor(this.mode === MODE_SHIFT ? colorOf(NGFColorToken.PRIMARY_CONTAINER) : colorOf(NGFColorToken.SURFACE))
        .fontColor(this.mode === MODE_SHIFT ? colorOf(NGFColorToken.PRIMARY) : colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        .accessibilityText(ToolUiKit.text($r('app.string.date_label_shift')))
        .onClick(() => {
          this.mode = MODE_SHIFT;
          this.saveDraft();
        })
    }
    .width('100%')
  }

  /** 间隔模式 */
  @Builder
  private buildGapSection() {
    Column({ space: 8 }) {
      Text($r('app.string.date_field_start')).fontSize(scaled(13)).fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
      TextInput({ text: this.startText, placeholder: $r('app.string.date_placeholder_start') })
        .width('100%')
        .height(44)
        .fontSize(scaled(15))
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(12)
        .onChange((value: string) => {
          this.startText = value;
          this.scheduleDraftSave();
        })

      Text($r('app.string.date_field_end')).fontSize(scaled(13)).fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
      TextInput({ text: this.endText, placeholder: $r('app.string.date_placeholder_end') })
        .width('100%')
        .height(44)
        .fontSize(scaled(15))
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(12)
        .onChange((value: string) => {
          this.endText = value;
          this.scheduleDraftSave();
        })

      Row() {
        Text($r('app.string.date_label_exclude_weekends')).fontSize(scaled(14)).fontColor(colorOf(NGFColorToken.ON_SURFACE))
        Blank()
        Toggle({ type: ToggleType.Switch, isOn: this.excludeWeekends })
          .accessibilityText(ToolUiKit.text($r('app.string.date_label_exclude_weekends')))
          .selectedColor(colorOf(NGFColorToken.PRIMARY))
          .onChange((isOn: boolean) => {
            this.excludeWeekends = isOn;
            this.saveDraft();
          })
      }
      .width('100%')

      Row({ space: 12 }) {
        Button($r('app.string.date_action_diff'))
          .layoutWeight(1)
          .onClick(() => {
            this.computeGap();
            this.flushDraft();
          })

        Button($r('app.string.shell_action_clear'))
          .layoutWeight(1)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .controlSize(ControlSize.NORMAL)
          .onClick(() => {
            this.clearAll();
          })
      }
      .width('100%')

      if (this.gapError.length > 0) {
        Text(this.gapError)
          .fontSize(scaled(13))
          .lineHeight(20)
          .width('100%')
          .padding(12)
          .borderRadius(12)
          .backgroundColor(colorOf(NGFColorToken.ERROR_CONTAINER))
          .fontColor(colorOf(NGFColorToken.ERROR_COLOR))
      }

      if (this.gapDone) {
        Column({ space: 6 }) {
          Row() {
            Text($r('app.string.date_label_result')).fontSize(scaled(14)).fontWeight(FontWeight.Medium).fontColor(colorOf(NGFColorToken.ON_SURFACE))
            Blank()
            Text($r('app.string.shell_action_copy'))
              .fontSize(scaled(13))
              .fontColor(colorOf(NGFColorToken.PRIMARY))
              .accessibilityText(ToolUiKit.text($r('app.string.copied_common')))
              .onClick(() => {
                ToolUiKit.copyText(this.gapMessage, ToolUiKit.text($r('app.string.date_copied_diff')));
              })
          }
          .width('100%')

          Text(this.gapMessage)
            .fontSize(scaled(15))
            .lineHeight(24)
            .width('100%')
            .fontColor(colorOf(NGFColorToken.ON_SURFACE))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(12)
        .backgroundColor(colorOf(NGFColorToken.SURFACE_VARIANT))
        .borderRadius(12)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 加减模式 */
  @Builder
  private buildShiftSection() {
    Column({ space: 8 }) {
      Text($r('app.string.date_field_base')).fontSize(scaled(13)).fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
      TextInput({ text: this.baseText, placeholder: $r('app.string.date_placeholder_base') })
        .width('100%')
        .height(44)
        .fontSize(scaled(15))
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(12)
        .onChange((value: string) => {
          this.baseText = value;
          this.scheduleDraftSave();
        })

      Text($r('app.string.date_field_amount')).fontSize(scaled(13)).fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
      TextInput({ text: this.amountText, placeholder: $r('app.string.date_placeholder_amount') })
        .width('100%')
        .height(44)
        .fontSize(scaled(15))
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(12)
        .onChange((value: string) => {
          this.amountText = value;
          this.scheduleDraftSave();
        })

      Row({ space: 8 }) {
        this.buildUnitChip($r('app.string.date_unit_day'), UNIT_DAY)
        this.buildUnitChip($r('app.string.date_unit_month'), UNIT_MONTH)
        this.buildUnitChip($r('app.string.date_unit_year'), UNIT_YEAR)
      }
      .width('100%')

      Row({ space: 12 }) {
        Button($r('app.string.date_action_shift'))
          .layoutWeight(1)
          .onClick(() => {
            this.computeShift();
            this.flushDraft();
          })

        Button($r('app.string.shell_action_clear'))
          .layoutWeight(1)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .controlSize(ControlSize.NORMAL)
          .onClick(() => {
            this.clearAll();
          })
      }
      .width('100%')

      if (this.shiftError.length > 0) {
        Text(this.shiftError)
          .fontSize(scaled(13))
          .lineHeight(20)
          .width('100%')
          .padding(12)
          .borderRadius(12)
          .backgroundColor(colorOf(NGFColorToken.ERROR_CONTAINER))
          .fontColor(colorOf(NGFColorToken.ERROR_COLOR))
      }

      if (this.shiftText.length > 0) {
        Column({ space: 6 }) {
          Row() {
            Text($r('app.string.date_label_result')).fontSize(scaled(14)).fontWeight(FontWeight.Medium).fontColor(colorOf(NGFColorToken.ON_SURFACE))
            Blank()
            Text($r('app.string.shell_action_copy'))
              .fontSize(scaled(13))
              .fontColor(colorOf(NGFColorToken.PRIMARY))
              .accessibilityText(ToolUiKit.text($r('app.string.copied_common')))
              .onClick(() => {
                ToolUiKit.copyText(this.shiftText, ToolUiKit.text($r('app.string.date_copied_shift')));
              })
          }
          .width('100%')

          Text(this.shiftText)
            .fontSize(scaled(16))
            .lineHeight(24)
            .width('100%')
            .fontColor(colorOf(NGFColorToken.ON_SURFACE))

          if (this.shiftClamped) {
            Text($r('app.string.date_notice_clamped'))
              .fontSize(scaled(12))
              .lineHeight(18)
              .fontColor(colorOf(NGFColorToken.WARNING))
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(12)
        .backgroundColor(colorOf(NGFColorToken.SURFACE_VARIANT))
        .borderRadius(12)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 单个单位选项 */
  @Builder
  private buildUnitChip(label: ResourceStr, value: string) {
    Text(label)
      .fontSize(scaled(14))
      .layoutWeight(1)
      .textAlign(TextAlign.Center)
      .padding(10)
      .borderRadius(10)
      .backgroundColor(this.unit === value ? colorOf(NGFColorToken.PRIMARY_CONTAINER) : colorOf(NGFColorToken.SURFACE))
      .fontColor(this.unit === value ? colorOf(NGFColorToken.PRIMARY) : colorOf(NGFColorToken.ON_SURFACE_VARIANT))
      .accessibilityText(ToolUiKit.text(label))
      .onClick(() => {
        this.unit = value;
        this.saveDraft();
      })
  }

  /** 计算间隔 */
  private computeGap(): void {
    const result: DateDiffResult = diffDates(this.startText, this.endText, this.excludeWeekends);
    if (!result.ok) {
      this.gapError = dateDiffFailureText(result);
      this.gapDone = false;
      this.gapMessage = '';
      return;
    }
    this.gapError = '';
    this.gapDone = true;
    // 叙述句在 Messages 层（措辞可多语言，判断在纯逻辑层）
    this.gapMessage = dateGapText(result, this.excludeWeekends);
  }

  /** 计算加减 */
  private computeShift(): void {
    const amount: number = parseInt(this.amountText, 10);
    if (isNaN(amount)) {
      this.shiftError = ToolUiKit.text($r('app.string.date_shift_not_integer'));
      this.shiftText = '';
      this.shiftClamped = false;
      return;
    }
    let result: DateShiftResult;
    if (this.unit === UNIT_MONTH) {
      result = addMonthsToDate(this.baseText, amount);
    } else if (this.unit === UNIT_YEAR) {
      result = addYearsToDate(this.baseText, amount);
    } else {
      result = addDaysToDate(this.baseText, amount);
    }
    if (!result.ok) {
      this.shiftError = dateShiftFailureText(result);
      this.shiftText = '';
      this.shiftClamped = false;
      return;
    }
    this.shiftError = '';
    // 结果文本按当前语言生成：'2024-01-08 周一' / '2024-01-08 Mon'。
    // 原先 result.text 在纯逻辑层拼好了「周X」，那是文案，不该待在那里。
    const date: NGFDate | null = result.date;
    this.shiftText = date === null ? '' : formatDateWithWeekday(date, this.locale);
    this.shiftClamped = result.clamped;
  }

  /** 清空输入与结果（保留今天的默认日期，否则用户要重新输一遍） */
  private clearAll(): void {
    if (this.draftTimer >= 0) {
      clearTimeout(this.draftTimer);
      this.draftTimer = -1;
    }
    const today: string = todayText();
    this.startText = today;
    this.endText = today;
    this.baseText = today;
    this.amountText = '1';
    this.gapError = '';
    this.gapMessage = '';
    this.gapDone = false;
    this.shiftError = '';
    this.shiftText = '';
    this.shiftClamped = false;
    toolStateStore.clearDraft(TOOL_ID);
  }

  /**
   * 草稿格式：按行存放（模式 / 起始 / 结束 / 是否排除周末 / 基准 / 数量 / 单位）。
   *
   * 用行分隔而不是 JSON：页面不引入 JSON 依赖，日期字段里也不可能出现换行，
   * 而且这份格式只被本页面的两个方法读写，看得见的就是全部。
   */
  private serializeDraft(): string {
    return this.mode + '\n' + this.startText + '\n' + this.endText + '\n'
      + (this.excludeWeekends ? '1' : '0') + '\n' + this.baseText + '\n' + this.amountText
      + '\n' + this.unit;
  }

  private applyDraft(raw: string): void {
    const parts: string[] = raw.split('\n');
    if (parts.length < 7) {
      return;
    }
    if (parts[0] === MODE_GAP || parts[0] === MODE_SHIFT) {
      this.mode = parts[0];
    }
    if (parts[1].length > 0) {
      this.startText = parts[1];
    }
    if (parts[2].length > 0) {
      this.endText = parts[2];
    }
    this.excludeWeekends = parts[3] === '1';
    if (parts[4].length > 0) {
      this.baseText = parts[4];
    }
    if (parts[5].length > 0) {
      this.amountText = parts[5];
    }
    if (parts[6] === UNIT_DAY || parts[6] === UNIT_MONTH || parts[6] === UNIT_YEAR) {
      this.unit = parts[6];
    }
  }

  private saveDraft(): void {
    toolStateStore.writeDraft(TOOL_ID, this.serializeDraft());
  }

  private scheduleDraftSave(): void {
    if (this.draftTimer >= 0) {
      clearTimeout(this.draftTimer);
    }
    this.draftTimer = setTimeout(() => {
      this.draftTimer = -1;
      this.saveDraft();
    }, DRAFT_DEBOUNCE_MS);
  }

  private flushDraft(): void {
    if (this.draftTimer >= 0) {
      clearTimeout(this.draftTimer);
      this.draftTimer = -1;
    }
    this.saveDraft();
  }
}