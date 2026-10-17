/**
 * 时间戳工具页。
 *
 * 页面只用一个输入框做**双向**转换：输入一串数字就按时间戳解释，输入带日期的
 * 文本就按日期解释，判定逻辑在 {@link interpretInput} 里（纯函数、有单测）。
 * 不做成「两个输入框 + 两个按钮」，是因为用户手上要么拿着时间戳、要么拿着日期，
 * 让他先选模式是多一步操作；自动识别错了也看得见（结果区会写明「按秒解释」）。
 *
 * 时区对照表默认用固定偏移时区（不含夏令时），本机时区随系统——理由见 TimestampLogic
 * 的文件头说明。
 *
 * @module tools/timestamp/TimestampPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { toolStateStore } from '../../core/ToolStateStore';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { ToolUiKit } from '../../ui/ToolUiKit';
import {
  InterpretKind,
  interpretInput,
  localOffsetMinutes,
  millisToSeconds,
  nowMilliseconds,
  offsetText,
  relativeTime,
  TimestampInterpretation,
  TimestampUnit,
  ZoneRow,
  zoneRows
} from './TimestampLogic';
import { currentLocale, FALLBACK_LOCALE } from '../../ui/LocaleSource';
import {
  interpretFailureText,
  relativeTimeText,
  weekdayText,
  zoneLabel,
  zoneWeekdayText
} from './TimestampMessages';

/** 工具 id：与目录名、注册表元数据一致（草稿按它存） */
const TOOL_ID: string = 'timestamp';

/** 草稿写入节流间隔（毫秒） */
const DRAFT_THROTTLE_MS: number = 800;

/** 「当前时间」的刷新间隔：秒级显示，一秒一次刚好 */
const CLOCK_INTERVAL_MS: number = 1000;

@Builder
export function buildTimestampPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildTimestampContent })
}

@Builder
function buildTimestampContent() {
  TimestampView({ toolId: TOOL_ID })
}

@Component
struct TimestampView {
  /** 订阅主题深浅；本字段本身不用，作用是在主题切换时触发本组件重渲染。 */
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  /** 订阅字体缩放；本字段不用，作用是切字号时触发本组件重渲染。 */
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  /** 历史回填序号；变化时由 @Watch 触发 onHistoryPick（见 ui/HistoryPick.ets） */
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  toolId: string = TOOL_ID;

  /** 当前语言：星期名与时区名是双语数据，按它取 */
  @State private locale: string = FALLBACK_LOCALE;
  @State private input: string = '';
  @State private nowMs: number = 0;

  private clockTimer: number = -1;
  private lastDraftSavedAt: number = 0;

  /** 用户在壳层选中一条历史 → 从草稿重读本次输入（见 ui/HistoryPick.ets） */

  private onHistoryPick(): void {

    const restored: string = toolStateStore.readDraft(this.toolId);

    if (restored.length === 0) {

      return;

    }

    this.input = restored;

  }


  aboutToAppear(): void {
    this.locale = currentLocale();
    this.input = toolStateStore.readDraft(this.toolId);
    this.nowMs = nowMilliseconds();
    this.clockTimer = setInterval(() => {
      this.nowMs = nowMilliseconds();
    }, CLOCK_INTERVAL_MS);
  }

  aboutToDisappear(): void {
    // 必须清：页面销毁后定时器还在跑会持续刷新已销毁的组件状态
    if (this.clockTimer !== -1) {
      clearInterval(this.clockTimer);
      this.clockTimer = -1;
    }
    this.saveDraft(true);
  }

  // ── 数据 ────────────────────────────────────────────────

  private localOffset(): number {
    return localOffsetMinutes(this.nowMs);
  }

  private interpretation(): TimestampInterpretation {
    return interpretInput(this.input, this.localOffset());
  }

  private hasResult(): boolean {
    const kind: InterpretKind = this.interpretation().kind;
    return kind === InterpretKind.TIMESTAMP || kind === InterpretKind.DATE;
  }

  private saveDraft(force: boolean): void {
    const now: number = Date.now();
    if (!force && now - this.lastDraftSavedAt < DRAFT_THROTTLE_MS) {
      return;
    }
    this.lastDraftSavedAt = now;
    toolStateStore.writeDraft(this.toolId, this.input);
  }

  private useNow(): void {
    this.input = String(nowMilliseconds());
    this.saveDraft(true);
  }

  private clearInput(): void {
    this.input = '';
    toolStateStore.clearDraft(this.toolId);
  }

  private kindLabel(): string {
    const result: TimestampInterpretation = this.interpretation();
    if (result.kind === InterpretKind.DATE) {
      return ToolUiKit.text($r('app.string.ts_interpret_date'));
    }
    if (result.kind === InterpretKind.TIMESTAMP) {
      return result.unit === TimestampUnit.SECONDS
        ? ToolUiKit.text($r('app.string.ts_interpret_seconds'))
        : ToolUiKit.text($r('app.string.ts_interpret_millis'));
    }
    return '';
  }

  private zoneRowsOfNow(): Array<ZoneRow> {
    return zoneRows(this.nowMs);
  }

  private zoneRowsOfResult(): Array<ZoneRow> {
    const result: TimestampInterpretation = this.interpretation();
    if (result.kind === InterpretKind.EMPTY || result.kind === InterpretKind.INVALID) {
      return [];
    }
    return zoneRows(result.milliseconds);
  }

  private weekdayOfNow(): string {
    const rows: Array<ZoneRow> = zoneRows(this.nowMs);
    for (let i: number = 0; i < rows.length; i++) {
      if (rows[i].isLocal) {
        return weekdayText(rows[i].weekdayIndex, this.locale);
      }
    }
    return '';
  }

  private localTextOfNow(): string {
    const rows: Array<ZoneRow> = zoneRows(this.nowMs);
    for (let i: number = 0; i < rows.length; i++) {
      if (rows[i].isLocal) {
        return rows[i].dateTimeText + ' ' + weekdayText(rows[i].weekdayIndex, this.locale)
        + ' ' + rows[i].offsetText;
      }
    }
    return '';
  }

  private copy(text: string, message: string): void {
    ToolUiKit.copyText(text, message);
  }

  // ── UI ──────────────────────────────────────────────────

  build() {
    Column({ space: 0 }) {
      this.buildSectionLabel($r('app.string.ts_label_current'))
      this.buildNowCard()
      this.buildSectionLabel($r('app.string.ts_label_input'))
      this.buildInputRow()
      this.buildResultArea()
      this.buildZoneSection()
      this.buildLegend()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildSectionLabel(label: ResourceStr) {
    Text(label)
      .fontSize(scaled(13))
      .fontWeight(FontWeight.Medium)
      .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
      .width('100%')
      .margin({ top: 16, bottom: 6 })
  }

  @Builder
  private buildNowCard() {
    Column({ space: 6 }) {
      Text(this.localTextOfNow())
        .fontSize(scaled(16))
        .fontWeight(FontWeight.Medium)
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))
        .width('100%')
      Text(ToolUiKit.stringOf($r('app.string.ts_now_seconds_millis'),
            [String(millisToSeconds(this.nowMs)), String(this.nowMs)]))
        .fontSize(scaled(13))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        .width('100%')
      Text(ToolUiKit.stringOf($r('app.string.ts_now_weekday'), [this.weekdayOfNow()]))
        .fontSize(scaled(13))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        .width('100%')
      Row({ space: 8 }) {
        Button($r('app.string.ts_action_fill_now'))
          .fontSize(scaled(13))
          .type(ButtonType.Capsule)
          .backgroundColor(colorOf(NGFColorToken.PRIMARY_CONTAINER))
          .fontColor(colorOf(NGFColorToken.PRIMARY))
          .onClick(() => {
            this.useNow();
          })
        Button($r('app.string.ts_action_copy_millis'))
          .fontSize(scaled(13))
          .type(ButtonType.Capsule)
          .backgroundColor(colorOf(NGFColorToken.PRIMARY_CONTAINER))
          .fontColor(colorOf(NGFColorToken.PRIMARY))
          .onClick(() => {
            this.copy(String(this.nowMs), ToolUiKit.text($r('app.string.ts_copied_millis')));
          })
        Button($r('app.string.ts_action_copy_seconds'))
          .fontSize(scaled(13))
          .type(ButtonType.Capsule)
          .backgroundColor(colorOf(NGFColorToken.PRIMARY_CONTAINER))
          .fontColor(colorOf(NGFColorToken.PRIMARY))
          .onClick(() => {
            this.copy(String(millisToSeconds(this.nowMs)),
        ToolUiKit.text($r('app.string.ts_copied_seconds')));
          })
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .backgroundColor(colorOf(NGFColorToken.SURFACE))
    .borderRadius(12)
  }

  @Builder
  private buildInputRow() {
    Row({ space: 8 }) {
      TextInput({ text: this.input, placeholder: $r('app.string.ts_placeholder_input') })
        .layoutWeight(1)
        .fontSize(scaled(14))
        .padding(12)
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(12)
        .onChange((value: string) => {
          this.input = value;
          this.saveDraft(false);
        })
      Button($r('app.string.shell_action_clear'))
        .fontSize(scaled(13))
        .type(ButtonType.Capsule)
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        .onClick(() => {
          this.clearInput();
        })
    }
    .width('100%')
  }

  @Builder
  private buildResultArea() {
    Column({ space: 8 }) {
      if (this.interpretation().kind === InterpretKind.INVALID) {
        Text(interpretFailureText(this.interpretation().failure))
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.ERROR_COLOR))
          .width('100%')
      } else if (this.interpretation().kind === InterpretKind.EMPTY) {
        Text($r('app.string.ts_empty_result'))
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
          .width('100%')
      } else {
        Text(this.kindLabel())
          .fontSize(scaled(12))
          .fontColor(colorOf(NGFColorToken.PRIMARY))
          .width('100%')
        this.buildResultRow($r('app.string.ts_row_seconds'), this.interpretation().secondsText)
        this.buildResultRow($r('app.string.ts_row_millis'), this.interpretation().millisecondsText)
        this.buildResultRow(ToolUiKit.stringOf($r('app.string.ts_row_local'),
          [offsetText(this.localOffset())]), this.interpretation().zoneText)
        this.buildResultRow($r('app.string.ts_row_utc'), this.interpretation().utcText)
        this.buildResultRow($r('app.string.ts_row_relative'),
          relativeTimeText(relativeTime(this.interpretation().milliseconds, this.nowMs)))
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: 8 })
  }

  @Builder
  private buildResultRow(label: ResourceStr, value: string) {
    Row({ space: 8 }) {
      Text(label)
        .fontSize(scaled(13))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        .width(140)
      Text(value)
        .fontSize(scaled(14))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))
        .layoutWeight(1)
      Text($r('app.string.shell_action_copy'))
        .fontSize(scaled(12))
        .fontColor(colorOf(NGFColorToken.PRIMARY))
        .accessibilityText(ToolUiKit.text($r('app.string.shell_action_copy')))
        .onClick(() => {
          this.copy(value, ToolUiKit.text($r('app.string.ts_copied')));
        })
    }
    .width('100%')
    .padding({ top: 6, bottom: 6 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildZoneSection() {
    Column({ space: 6 }) {
      Text(this.hasResult()
          ? $r('app.string.ts_label_zones_selected')
          : $r('app.string.ts_label_zones_now'))
        .fontSize(scaled(13))
        .fontWeight(FontWeight.Medium)
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        .width('100%')
      // 每个时区两行：窄屏（360vp 减去留白只剩 ~300vp）塞不下
      // 「时区 + 偏移 + 时间 + 星期」四列，硬塞会让列被压缩到读不出来。
      ForEach(this.hasResult() ? this.zoneRowsOfResult() : this.zoneRowsOfNow(),
        (row: ZoneRow) => {
          Column({ space: 2 }) {
            Row({ space: 8 }) {
              Text(zoneLabel(row.label, this.locale))
                .fontSize(scaled(13))
                .fontColor(row.isLocal ? colorOf(NGFColorToken.PRIMARY) : colorOf(NGFColorToken.ON_SURFACE))
                .layoutWeight(1)
              Text(row.offsetText)
                .fontSize(scaled(12))
                .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
                .width(88)
                .textAlign(TextAlign.End)
            }
            .width('100%')
            Text(row.dateTimeText + ' ' + zoneWeekdayText(row, this.locale))
              .fontSize(scaled(13))
              .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
              .width('100%')
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ top: 6, bottom: 6 })
        }, (row: ZoneRow) => zoneLabel(row.label, this.locale))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .backgroundColor(colorOf(NGFColorToken.SURFACE))
    .borderRadius(12)
    .margin({ top: 16 })
  }

  @Builder
  private buildLegend() {
    Text($r('app.string.ts_zone_note'))
      .fontSize(scaled(12))
      .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
      .width('100%')
      .lineHeight(18)
      .margin({ top: 12 })
  }
}