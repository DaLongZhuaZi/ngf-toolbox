/**
 * 正则测试工具页。
 *
 * 页面只干两件事：把用户输入交给 {@link RegexLogic} 里的纯函数，
 * 再把结果画出来。所有会出错的判断（表达式合法性、错误位置、零宽推进、
 * 条数上限）都在纯逻辑里并有单测；页面这一层刻意不写任何正则相关的逻辑，
 * 这样真机上的问题只会是「画得不对」，不会是「算得不对」。
 *
 * ## 实时匹配与手动执行
 *
 * 输入很短时每次按键都重算，用户看到的是即时的；但测试文本可能被粘进
 * 十几万字符的日志，对每个按键都做一次全量正则扫描会让输入框明显卡顿。
 * 因此超过 {@link LIVE_MATCH_INPUT_LIMIT} 后**自动停止**实时匹配并提示用户
 * 手动点「执行匹配」——宁可少一次自动刷新，也不能让输入变卡。
 *
 * @module tools/regex-tester/RegexTesterPage
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
  RegexErrorKind,
  buildMatchReport,
  buildSegments,
  DEFAULT_MATCH_LIMIT,
  MAX_HIGHLIGHT_SEGMENTS,
  parseRegexDraft,
  RegexCapture,
  RegexCheatSheetItem,
  RegexFlag,
  RegexDraft,
  RegexMatch,
  RegexOptions,
  RegexPreset,
  RegexRunResult,
  RegexSegment,
  regexCheatSheet,
  regexPresets,
  runRegex,
  serializeRegexDraft,
  summarizeRun,
  RegexSummary
} from './RegexLogic';
import {
  regexBuildErrorText,
  regexCaptureText,
  regexCheatMeaning,
  regexFlagHintText,
  regexFlagsText,
  regexFlagText,
  regexMatchRangeText,
  regexPresetHint,
  regexPresetName,
  regexSummaryText
} from './RegexMessages';
import { currentLocale, FALLBACK_LOCALE } from '../../ui/LocaleSource';

/** 索引 → 标志码（开关行是按索引排的） */
function flagOfIndex(flagIndex: number): RegexFlag {
  if (flagIndex === 1) {
    return RegexFlag.IGNORE_CASE;
  }
  if (flagIndex === 2) {
    return RegexFlag.MULTILINE;
  }
  if (flagIndex === 3) {
    return RegexFlag.DOT_ALL;
  }
  if (flagIndex === 4) {
    return RegexFlag.UNICODE;
  }
  return RegexFlag.GLOBAL;
}

/** 工具 id：与目录名、注册表元数据一致（草稿按它存） */
const TOOL_ID: string = 'regex-tester';

/** 超过这个长度就停止实时匹配，改由用户点「执行匹配」触发 */
const LIVE_MATCH_INPUT_LIMIT: number = 20000;

/** 草稿写入节流间隔（毫秒）：Preferences 是同步写盘，每个按键都写会拖慢输入 */
const DRAFT_THROTTLE_MS: number = 800;

/** 匹配清单里单条匹配最多显示多少字符 */
const MATCH_PREVIEW_MAX: number = 80;

/** 速查表默认显示条数 */
const CHEAT_SHEET_PREVIEW_COUNT: number = 8;

@Builder
export function buildRegexTesterPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildRegexTesterContent })
}

@Builder
function buildRegexTesterContent() {
  RegexTesterView({ toolId: TOOL_ID })
}

@Component
struct RegexTesterView {
  /** 订阅主题深浅；本字段本身不用，作用是在主题切换时触发本组件重渲染。 */
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  /** 订阅字体缩放；本字段不用，作用是切字号时触发本组件重渲染。 */
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  /** 历史回填序号；变化时由 @Watch 触发 onHistoryPick（见 ui/HistoryPick.ets） */
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  toolId: string = TOOL_ID;

  /** 当前语言：预设名/说明与速查表是双语数据，按它取 */
  @State private locale: string = FALLBACK_LOCALE;
  @State private pattern: string = '';
  @State private subject: string = '';
  @State private options: RegexOptions = RegexOptions.defaults();
  @State private run: RegexRunResult = new RegexRunResult(true, RegexErrorKind.NONE, -1, [], false, 0);
  @State private segments: Array<RegexSegment> = [];
  @State private activePresetIndex: number = -1;
  /** 测试文本过长时暂停实时匹配，页面据此显示提示 */
  @State private livePaused: boolean = false;
  @State private cheatSheetExpanded: boolean = false;

  /** 标志位与顺序固定：0=g 1=i 2=m 3=s 4=u，用一个常量数组驱动渲染，避免在 build 里写数组字面量 */
  private flagIndexes: Array<number> = [0, 1, 2, 3, 4];
  private presets: Array<RegexPreset> = regexPresets();
  private cheatSheet: Array<RegexCheatSheetItem> = regexCheatSheet();
  private lastDraftSavedAt: number = 0;

  /** 用户在壳层选中一条历史 → 从草稿重读本次输入（见 ui/HistoryPick.ets） */

  private onHistoryPick(): void {

    const restored: string = toolStateStore.readDraft(this.toolId);

    if (restored.length === 0) {

      return;

    }

    this.pattern = restored;

  }


  aboutToAppear(): void {
    this.locale = currentLocale();
    // 草稿按工具 id 存：用户上次的表达式与测试文本不该因为退出应用而丢。
    const draft: RegexDraft = parseRegexDraft(toolStateStore.readDraft(this.toolId));
    this.pattern = draft.pattern;
    this.subject = draft.subject;
    this.options = RegexOptions.fromFlags(draft.flags);
    this.refreshLive();
  }

  aboutToDisappear(): void {
    // 离开页面时强制写一次，补上节流窗口里最后那几百毫秒的输入。
    this.saveDraft(true);
  }

  // ── 纯逻辑调用 ───────────────────────────────────────────

  /** 实时匹配：输入过长时跳过，保留上一次结果 */
  private refreshLive(): void {
    if (this.subject.length > LIVE_MATCH_INPUT_LIMIT) {
      this.livePaused = true;
      return;
    }
    this.livePaused = false;
    this.computeNow();
  }

  /** 强制算一次（用户点「执行匹配」） */
  private runNow(): void {
    this.livePaused = false;
    this.computeNow();
  }

  private computeNow(): void {
    if (this.pattern.length === 0) {
      // 空表达式在语法上是合法的（匹配任意位置），但当成「还没输入」处理更符合直觉，
      // 否则用户一进页面就会看到满屏零宽匹配。
      this.run = new RegexRunResult(true, RegexErrorKind.NONE, -1, [], false, this.subject.length);
      this.segments = [];
      return;
    }
    const result: RegexRunResult = runRegex(this.pattern, this.subject, this.options, DEFAULT_MATCH_LIMIT);
    this.run = result;
    this.segments = result.ok ? buildSegments(this.subject, result.matches, MAX_HIGHLIGHT_SEGMENTS) : [];
  }

  private saveDraft(force: boolean): void {
    const now: number = Date.now();
    if (!force && now - this.lastDraftSavedAt < DRAFT_THROTTLE_MS) {
      return;
    }
    this.lastDraftSavedAt = now;
    const draft: RegexDraft = new RegexDraft();
    draft.pattern = this.pattern;
    draft.subject = this.subject;
    draft.flags = this.options.toFlagString();
    toolStateStore.writeDraft(this.toolId, serializeRegexDraft(draft));
  }

  /** 切换标志位：选项对象不可变，每次切换都换新实例，UI 才会刷新 */
  private toggleFlag(flagIndex: number): void {
    if (flagIndex === 0) {
      this.options = this.options.withGlobal(!this.options.global);
    } else if (flagIndex === 1) {
      this.options = this.options.withIgnoreCase(!this.options.ignoreCase);
    } else if (flagIndex === 2) {
      this.options = this.options.withMultiline(!this.options.multiline);
    } else if (flagIndex === 3) {
      this.options = this.options.withDotAll(!this.options.dotAll);
    } else if (flagIndex === 4) {
      this.options = this.options.withUnicode(!this.options.unicode);
    }
    this.refreshLive();
    this.saveDraft(false);
  }

  private flagEnabled(flagIndex: number): boolean {
    if (flagIndex === 0) {
      return this.options.global;
    }
    if (flagIndex === 1) {
      return this.options.ignoreCase;
    }
    if (flagIndex === 2) {
      return this.options.multiline;
    }
    if (flagIndex === 3) {
      return this.options.dotAll;
    }
    return this.options.unicode;
  }

  private flagLabel(flagIndex: number): string {
    return regexFlagText(flagOfIndex(flagIndex));
  }

  private flagDescription(flagIndex: number): string {
    return regexFlagHintText(flagOfIndex(flagIndex));
  }

  private applyPreset(index: number): void {
    const preset: RegexPreset = this.presets[index];
    this.pattern = preset.pattern;
    this.options = preset.options;
    this.activePresetIndex = index;
    this.runNow();
    this.saveDraft(true);
  }

  private presetName(index: number): string {
    return regexPresetName(this.presets[index], this.locale);
  }

  private activePresetHint(): string {
    if (this.activePresetIndex < 0) {
      return '';
    }
    return regexPresetHint(this.presets[this.activePresetIndex], this.locale);
  }

  private clearAll(): void {
    this.pattern = '';
    this.subject = '';
    this.activePresetIndex = -1;
    this.runNow();
    toolStateStore.clearDraft(this.toolId);
  }

  private copyReport(): void {
    // 报告的**格式**留在纯逻辑里（单测守着「一条匹配一行」），句子从这里注入
    ToolUiKit.copyText(
      buildMatchReport(this.run, regexSummaryText(summarizeRun(this.run)),
        regexBuildErrorText(this.run.errorKind, this.run.errorPosition)),
      ToolUiKit.text($r('app.string.regex_copied_report')));
  }

  /** 单条匹配的展示文本：过长就截断，换行转义成可见字符 */
  private matchPreview(match: RegexMatch): string {
    let text: string = match.value;
    text = text.split('\n').join('\\n');
    text = text.split('\r').join('\\r');
    text = text.split('\t').join('\\t');
    if (text.length > MATCH_PREVIEW_MAX) {
      return text.substring(0, MATCH_PREVIEW_MAX) + '…';
    }
    return text;
  }

  private positionText(match: RegexMatch): string {
    return regexMatchRangeText(match);
  }

  private captureText(capture: RegexCapture): string {
    const name: string = capture.name.length > 0 ? capture.name : String(capture.index);
    return regexCaptureText(name, capture.value);
  }

  private visibleCheatSheet(): Array<RegexCheatSheetItem> {
    if (this.cheatSheetExpanded) {
      return this.cheatSheet;
    }
    const limited: Array<RegexCheatSheetItem> = [];
    for (let i: number = 0; i < this.cheatSheet.length && i < CHEAT_SHEET_PREVIEW_COUNT; i++) {
      limited.push(this.cheatSheet[i]);
    }
    return limited;
  }

  // ── UI ──────────────────────────────────────────────────

  build() {
    Column({ space: 0 }) {
      this.buildSectionLabel($r('app.string.regex_label_pattern'))
      this.buildPatternInput()
      this.buildFlagRow()
      this.buildPresets()
      this.buildSectionLabel($r('app.string.regex_label_subject'))
      this.buildSubjectInput()
      this.buildActionRow()
      this.buildStatusArea()
      this.buildHighlightArea()
      this.buildSectionLabel($r('app.string.regex_label_results'))
      this.buildMatchList()
      this.buildCheatSheet()
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
  private buildPatternInput() {
    TextInput({ text: this.pattern, placeholder: $r('app.string.regex_placeholder_pattern') })
      .width('100%')
      .fontSize(scaled(14))
      .padding(12)
      .backgroundColor(colorOf(NGFColorToken.SURFACE))
      .borderRadius(12)
      .onChange((value: string) => {
        this.pattern = value;
        this.activePresetIndex = -1;
        this.refreshLive();
        this.saveDraft(false);
      })
  }

  @Builder
  private buildFlagRow() {
    Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
      ForEach(this.flagIndexes, (flagIndex: number) => {
        Text(this.flagLabel(flagIndex))
          .fontSize(scaled(13))
          .fontColor(this.flagEnabled(flagIndex)
            ? colorOf(NGFColorToken.PRIMARY)
            : colorOf(NGFColorToken.ON_SURFACE_VARIANT))
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor(this.flagEnabled(flagIndex)
            ? colorOf(NGFColorToken.PRIMARY_CONTAINER)
            : colorOf(NGFColorToken.SURFACE))
          .borderRadius(14)
          .margin({ right: 8, bottom: 8 })
          .accessibilityText(this.flagLabel(flagIndex) + ToolUiKit.text($r('app.string.regex_label_separator')) + this.flagDescription(flagIndex))
          .onClick(() => {
            this.toggleFlag(flagIndex);
          })
      }, (flagIndex: number) => 'flag-' + String(flagIndex))
    }
    .width('100%')
    .margin({ top: 8 })
  }

  @Builder
  private buildPresets() {
    Column({ space: 0 }) {
      Text($r('app.string.regex_label_presets'))
        .fontSize(scaled(13))
        .fontWeight(FontWeight.Medium)
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        .width('100%')
        .margin({ top: 8, bottom: 6 })
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
        ForEach(this.presets, (preset: RegexPreset, index: number) => {
          Text(regexPresetName(preset, this.locale))
            .fontSize(scaled(13))
            .fontColor(index === this.activePresetIndex
              ? Color.White
              : colorOf(NGFColorToken.ON_SURFACE))
              .accessibilityText(ToolUiKit.text(regexPresetName(preset, this.locale)))
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor(index === this.activePresetIndex
              ? colorOf(NGFColorToken.PRIMARY)
              : colorOf(NGFColorToken.SURFACE))
            .borderRadius(14)
            .margin({ right: 8, bottom: 8 })
            .onClick(() => {
              this.applyPreset(index);
            })
        }, (preset: RegexPreset) => regexPresetName(preset, this.locale))
      }
      .width('100%')
      if (this.activePresetHint().length > 0) {
        Text(ToolUiKit.stringOf($r('app.string.regex_preset_hint'), [this.activePresetHint()]))
          .fontSize(scaled(12))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
          .width('100%')
          .margin({ bottom: 4 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildSubjectInput() {
    TextArea({ text: this.subject, placeholder: $r('app.string.regex_placeholder_subject') })
      .width('100%')
      .height(140)
      .fontSize(scaled(14))
      .padding(12)
      .backgroundColor(colorOf(NGFColorToken.SURFACE))
      .borderRadius(12)
      .onChange((value: string) => {
        this.subject = value;
        this.refreshLive();
        this.saveDraft(false);
      })
  }

  @Builder
  private buildActionRow() {
    Row({ space: 8 }) {
      Button($r('app.string.regex_action_run'))
        .fontSize(scaled(14))
        .type(ButtonType.Capsule)
        .backgroundColor(colorOf(NGFColorToken.PRIMARY))
        .fontColor(Color.White)
        .onClick(() => {
          this.runNow();
        })
      Button($r('app.string.regex_action_copy'))
        .fontSize(scaled(14))
        .type(ButtonType.Capsule)
        .backgroundColor(colorOf(NGFColorToken.PRIMARY_CONTAINER))
        .fontColor(colorOf(NGFColorToken.PRIMARY))
        .onClick(() => {
          this.copyReport();
        })
      Button($r('app.string.shell_action_clear'))
        .fontSize(scaled(14))
        .type(ButtonType.Capsule)
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        .onClick(() => {
          this.clearAll();
        })
    }
    .width('100%')
    .margin({ top: 12 })
  }

  @Builder
  private buildStatusArea() {
    Column({ space: 6 }) {
      if (!this.run.ok) {
        // 错误就地红字（产品定义稿 §四）：非法表达式要指到第几个字符
        Text(regexBuildErrorText(this.run.errorKind, this.run.errorPosition))
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.ERROR_COLOR))
          .width('100%')
      } else {
        Text(regexSummaryText(summarizeRun(this.run)))
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
          .width('100%')
      }
      if (this.livePaused) {
        Text(ToolUiKit.stringOf($r('app.string.regex_live_paused'),
              [String(LIVE_MATCH_INPUT_LIMIT)]))
          .fontSize(scaled(12))
          .fontColor(colorOf(NGFColorToken.WARNING))
          .width('100%')
      }
      Text(ToolUiKit.stringOf($r('app.string.regex_current_flags'),
              [this.options.toFlagString(), regexFlagsText(this.options.describe())]))
        .fontSize(scaled(12))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .margin({ top: 12 })
  }

  @Builder
  private buildHighlightArea() {
    if (this.run.ok && this.segments.length > 0) {
      Column({ space: 6 }) {
        Text($r('app.string.regex_label_highlight'))
          .fontSize(scaled(12))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
          ForEach(this.segments, (segment: RegexSegment) => {
            // 逐段渲染：命中段带底色，未命中段保持原色。
            // 代价是相邻两段之间不共享换行点（长行会提前折行），
            // 好处是不依赖任何第三方高亮 API，纯靠已冻结的 ArkUI 基础组件。
            Text(segment.text)
              .fontSize(scaled(14))
              .lineHeight(22)
              .fontColor(colorOf(NGFColorToken.ON_SURFACE))
              .backgroundColor(segment.matched ? colorOf(NGFColorToken.PRIMARY_CONTAINER) : Color.Transparent)
          }, (segment: RegexSegment) => String(segment.start) + '-' + String(segment.text.length)
            + (segment.matched ? '-m' : '-p'))
        }
        .width('100%')
        if (this.segments.length >= MAX_HIGHLIGHT_SEGMENTS) {
          // 与 buildSegments 的口径一致：超限时保留的是**尾部**，文案不能说成「前 N 段」
          Text(ToolUiKit.stringOf($r('app.string.regex_highlight_truncated'),
                [String(MAX_HIGHLIGHT_SEGMENTS)]))
            .fontSize(scaled(12))
            .fontColor(colorOf(NGFColorToken.WARNING))
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(12)
      .backgroundColor(colorOf(NGFColorToken.SURFACE_VARIANT))
      .borderRadius(12)
      .margin({ top: 12 })
    }
  }

  @Builder
  private buildMatchList() {
    Column({ space: 8 }) {
      if (!this.run.ok) {
        Text($r('app.string.regex_run_failed'))
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
          .width('100%')
      } else if (this.run.matches.length === 0) {
        Text($r('app.string.regex_run_empty'))
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
          .width('100%')
      } else {
        ForEach(this.run.matches, (match: RegexMatch) => {
          this.buildMatchRow(match)
        }, (match: RegexMatch) => String(match.ordinal))
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: 4 })
  }

  @Builder
  private buildMatchRow(match: RegexMatch) {
    Column({ space: 4 }) {
      Row({ space: 8 }) {
        Text('#' + String(match.ordinal))
          .fontSize(scaled(12))
          .fontColor(colorOf(NGFColorToken.PRIMARY))
        Text(this.positionText(match))
          .fontSize(scaled(12))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
          .layoutWeight(1)
      }
      .width('100%')

      Text(match.isZeroWidth()
                    ? $r('app.string.regex_zero_width_note')
                    : this.matchPreview(match))
        .fontSize(scaled(14))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))
        .width('100%')

      ForEach(match.captures, (capture: RegexCapture) => {
        Text(this.captureText(capture))
          .fontSize(scaled(12))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
          .width('100%')
      }, (capture: RegexCapture) => String(match.ordinal) + '-' + String(capture.index))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(10)
    .backgroundColor(colorOf(NGFColorToken.SURFACE))
    .borderRadius(10)
  }

  @Builder
  private buildCheatSheet() {
    Column({ space: 6 }) {
      Row() {
        Text($r('app.string.regex_label_cheatsheet'))
          .fontSize(scaled(13))
          .fontWeight(FontWeight.Medium)
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        Blank()
        Text(this.cheatSheetExpanded
              ? $r('app.string.regex_action_collapse')
              : $r('app.string.regex_action_expand'))
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.PRIMARY))
          .accessibilityText(this.cheatSheetExpanded ? ToolUiKit.text($r('app.string.regex_action_collapse')) : ToolUiKit.text($r('app.string.regex_action_expand')))
          .onClick(() => {
            this.cheatSheetExpanded = !this.cheatSheetExpanded;
          })
      }
      .width('100%')

      ForEach(this.visibleCheatSheet(), (item: RegexCheatSheetItem) => {
        Row({ space: 10 }) {
          Text(item.token)
            .fontSize(scaled(13))
            .fontColor(colorOf(NGFColorToken.PRIMARY))
            .width(110)
          Text(regexCheatMeaning(item, this.locale))
            .fontSize(scaled(13))
            .fontColor(colorOf(NGFColorToken.ON_SURFACE))
            .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      }, (item: RegexCheatSheetItem) => item.token)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .backgroundColor(colorOf(NGFColorToken.SURFACE))
    .borderRadius(12)
    .margin({ top: 20 })
  }
}