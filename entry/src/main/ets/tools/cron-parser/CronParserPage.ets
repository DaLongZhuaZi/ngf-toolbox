/**
 * Cron 解析工具页。
 *
 * 页面把「解析失败的原因」「人话描述」「接下来 5 次执行时间」三块摆在同一条视线里：
 * cron 的坑大多不是解析错误，而是**解析成功但语义与用户以为的不同**
 * （最典型的是「日」与「星期」同时限定时是「或」），所以 dayRuleNote 必须显眼地显示出来。
 *
 * @module tools/cron-parser/CronParserPage
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
  CronDescription,
  CronNextRunsResult,
  CronParseResult,
  formatCronRun,
  nextCronRuns,
  parseCronExpression
} from './CronParser';
import { cronDescriptionText, cronFailureText, cronWeekdayText } from './CronMessages';

/** 工具 id：草稿按它存取，必须与 ToolsCatalog 里登记的 id 一致 */
const TOOL_ID: string = 'cron-parser';

/** 草稿写入防抖（毫秒） */
const DRAFT_DEBOUNCE_MS: number = 400;

/** 页面固定展示未来 5 次（纯逻辑支持到 20 次，界面不铺开） */
const PREVIEW_COUNT: number = 5;

/** 常用表达式预设：用户多半是来验证这几个，省去手打 */
const PRESETS: string[] = ['*/5 * * * *', '0 * * * *', '0 3 * * *', '0 9 * * MON-FRI', '0 0 1 * *'];

@Builder
export function buildCronParserPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildCronParserContent })
}

@Builder
function buildCronParserContent() {
  CronParserToolBody()
}

@Component
struct CronParserToolBody {
  /** 订阅主题深浅；本字段本身不用，作用是在主题切换时触发本组件重渲染。 */
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  /** 订阅字体缩放；本字段不用，作用是切字号时触发本组件重渲染。 */
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  /** 历史回填序号；变化时由 @Watch 触发 onHistoryPick（见 ui/HistoryPick.ets） */
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private expression: string = '';
  @State private errorMessage: string = '';
  /** 描述的结构（措辞在渲染时取，这样切换语言后重新渲染就是新语言） */
  @State private description: CronDescription | null = null;
  /** 「日」与「星期」同时限定时是「或」关系 */
  @State private hasOrRule: boolean = false;
  @State private runs: string[] = [];
  @State private neverMatches: boolean = false;
  private draftTimer: number = -1;

  /** 用户在壳层选中一条历史 → 从草稿重读本次输入（见 ui/HistoryPick.ets） */

  private onHistoryPick(): void {

    const restored: string = toolStateStore.readDraft(TOOL_ID);

    if (restored.length === 0) {

      return;

    }

    this.expression = restored;

  }


  aboutToAppear(): void {
    const saved: string = toolStateStore.readDraft(TOOL_ID);
    if (saved.length > 0) {
      this.expression = saved;
      this.refresh();
    }
  }

  aboutToDisappear(): void {
    this.flushDraft();
  }

  build() {
    Column({ space: 16 }) {
      this.buildInputSection()

      if (this.expression.length === 0) {
        this.buildPresetSection()
      }

      if (this.errorMessage.length > 0) {
        this.buildErrorSection()
      }

      if (this.description !== null) {
        this.buildDescriptionSection()
      }

      if (this.runs.length > 0 || this.neverMatches) {
        this.buildRunSection()
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 输入区 */
  @Builder
  private buildInputSection() {
    Column({ space: 8 }) {
      Text($r('app.string.cron_label_expression'))
        .fontSize(scaled(15))
        .fontWeight(FontWeight.Medium)
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))

      TextInput({ text: this.expression, placeholder: $r('app.string.cron_placeholder') })
        .width('100%')
        .height(44)
        .fontSize(scaled(15))
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(12)
        .onChange((value: string) => {
          this.expression = value;
          this.scheduleDraftSave(value);
          this.refresh();
        })

      Row({ space: 12 }) {
        Button($r('app.string.cron_action_recalc'))
          .layoutWeight(1)
          .onClick(() => {
            this.refresh();
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
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 预设区：只在输入为空时出现，避免干扰已输入的表达式 */
  @Builder
  private buildPresetSection() {
    Column({ space: 8 }) {
      Text($r('app.string.cron_label_examples'))
        .fontSize(scaled(13))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))

      ForEach(PRESETS, (preset: string) => {
        Text(preset)
          .fontSize(scaled(14))
          .width('100%')
          .padding(10)
          .borderRadius(10)
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .fontColor(colorOf(NGFColorToken.PRIMARY))
          .accessibilityText(ToolUiKit.text(preset))
          .onClick(() => {
            this.expression = preset;
            this.refresh();
            this.flushDraft();
          })
      }, (preset: string) => preset)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 错误区（就地红字） */
  @Builder
  private buildErrorSection() {
    Text(this.errorMessage)
      .fontSize(scaled(13))
      .lineHeight(20)
      .width('100%')
      .padding(12)
      .borderRadius(12)
      .backgroundColor(colorOf(NGFColorToken.ERROR_CONTAINER))
      .fontColor(colorOf(NGFColorToken.ERROR_COLOR))
  }

  /**
   * 描述文案；没有描述时返回空串。
   *
   * **不能**把 `const` / `return` 写进 `@Builder` 里——Builder 体只允许 UI 组件语法，
   * 中间夹一句普通语句会得到「Only UI component syntax can be written here」。
   * 取值这类准备工作放到普通方法里，Builder 只负责摆 UI。
   */
  private descriptionText(): string {
    const desc: CronDescription | null = this.description;
    return desc === null ? '' : cronDescriptionText(desc);
  }

  /** 人话描述 + 「或」规则提示 */
  @Builder
  private buildDescriptionSection() {
    Column({ space: 8 }) {
      Text($r('app.string.cron_label_meaning'))
        .fontSize(scaled(15))
        .fontWeight(FontWeight.Medium)
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))

      Text(this.descriptionText())
        .fontSize(scaled(14))
        .lineHeight(22)
        .width('100%')
        .padding(12)
        .borderRadius(12)
        .backgroundColor(colorOf(NGFColorToken.SURFACE_VARIANT))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))

      if (this.hasOrRule) {
        Text($r('app.string.cron_day_rule_note'))
          .fontSize(scaled(13))
          .lineHeight(20)
          .width('100%')
          .padding(12)
          .borderRadius(12)
          .backgroundColor(colorOf(NGFColorToken.WARNING_CONTAINER))
          .fontColor(colorOf(NGFColorToken.WARNING))
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 接下来 N 次执行时间 */
  @Builder
  private buildRunSection() {
    Column({ space: 8 }) {
      Text(ToolUiKit.stringOf($r('app.string.cron_label_next_runs'), [String(PREVIEW_COUNT)]))
        .fontSize(scaled(15))
        .fontWeight(FontWeight.Medium)
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))

      if (this.neverMatches) {
        Text($r('app.string.cron_never_matches'))
          .fontSize(scaled(13))
          .lineHeight(20)
          .width('100%')
          .padding(12)
          .borderRadius(12)
          .backgroundColor(colorOf(NGFColorToken.WARNING_CONTAINER))
          .fontColor(colorOf(NGFColorToken.WARNING))
      } else {
        ForEach(this.runs, (item: string) => {
          Text(item)
            .fontSize(scaled(14))
            .width('100%')
            .padding(10)
            .borderRadius(10)
            .backgroundColor(colorOf(NGFColorToken.SURFACE_VARIANT))
            .fontColor(colorOf(NGFColorToken.ON_SURFACE))
        }, (item: string) => item)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 重新解析并计算接下来的执行时间 */
  private refresh(): void {
    const parsed: CronParseResult = parseCronExpression(this.expression);
    if (!parsed.ok) {
      this.errorMessage = cronFailureText(parsed.failure);
      this.description = null;
      this.hasOrRule = false;
      this.runs = [];
      this.neverMatches = false;
      return;
    }
    this.errorMessage = '';
    this.description = parsed.description;
    this.hasOrRule = parsed.hasOrRule;
    const result: CronNextRunsResult = nextCronRuns(this.expression, Date.now(), PREVIEW_COUNT);
    if (!result.ok) {
      this.errorMessage = '';
      this.runs = [];
      this.neverMatches = false;
      return;
    }
    this.neverMatches = result.neverMatches;
    const formatted: string[] = [];
    for (let i: number = 0; i < result.runs.length; i++) {
      // 星期名由 UI 层补（它是文案）；formatCronRun 只给日期与时刻
        formatted.push(formatCronRun(result.runs[i]) + ' '
          + cronWeekdayText(result.runs[i].getDay()));
    }
    this.runs = formatted;
  }

  /** 清空输入与结果 */
  private clearAll(): void {
    if (this.draftTimer >= 0) {
      clearTimeout(this.draftTimer);
      this.draftTimer = -1;
    }
    this.expression = '';
    this.errorMessage = '';
    this.description = null;
    this.hasOrRule = false;
    this.runs = [];
    this.neverMatches = false;
    toolStateStore.clearDraft(TOOL_ID);
  }

  /** 防抖写草稿 */
  private scheduleDraftSave(text: string): void {
    if (this.draftTimer >= 0) {
      clearTimeout(this.draftTimer);
    }
    this.draftTimer = setTimeout(() => {
      this.draftTimer = -1;
      toolStateStore.writeDraft(TOOL_ID, text);
    }, DRAFT_DEBOUNCE_MS);
  }

  /** 立即落盘 */
  private flushDraft(): void {
    if (this.draftTimer >= 0) {
      clearTimeout(this.draftTimer);
      this.draftTimer = -1;
    }
    toolStateStore.writeDraft(TOOL_ID, this.expression);
  }
}