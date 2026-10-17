/**
 * 文本 Diff 工具页。
 *
 * ## 布局取舍：上下堆叠，不做左右并排
 *
 * 桌面上的 diff 工具习惯左右并排。但本 App 的主要形态是手机竖屏：
 * 在 360vp 宽度里塞两列文本，每列只剩约 170vp，中文一行放不下十个字，
 * 结果两侧都被折行，反而看不出差异在哪。
 *
 * 因此这里改成**上下两块输入 + 下方统一的差异视图**：
 * 差异视图用「旧行号 / 新行号 / 标记 / 内容」四列对齐显示，
 * 这才是手机上真正能读的 diff 形态。
 *
 * ## 草稿
 *
 * 两侧内容分别存草稿（key 为 toolbox.draft.text-diff 与 ...text-diff.right）。
 * 用户对比到一半切走再回来，两侧都还在——这是「杀进程不丢」的落点。
 *
 * @module tools/text-diff/TextDiffPage
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
  buildHunks,
  DIFF_CONTEXT_LINES,
  DiffDocument,
  DiffHunk,
  DiffLine,
  DiffLineKind,
  diffLines,
  DiffResult,
  diffSummaryFacts,
  toDocument,
  toUnifiedText
} from './TextDiff';
import {
  diffFailureText,
  lineEndingNotice,
  summarizeDiff,
  trailingNewlineNotice,
  unifiedSummaryOf
} from './TextDiffMessages';
import { MOTION_DURATION_MS, MOTION_SLIDE_VP } from '../../ui/Motion';

/** 工具 id：草稿按它存取，必须与 ToolsCatalog 里登记的 id 一致 */
const TOOL_ID: string = 'text-diff';

/** 右侧内容的草稿 key（左侧用工具 id 本身的草稿位） */
const RIGHT_DRAFT_KEY: string = TOOL_ID + '.right';

/** 草稿写入防抖（毫秒） */
const DRAFT_DEBOUNCE_MS: number = 500;

@Builder
export function buildTextDiffPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildTextDiffContent })
}

@Builder
function buildTextDiffContent() {
  TextDiffToolBody()
}

@Component
struct TextDiffToolBody {
  /** 订阅主题深浅；本字段本身不用，作用是在主题切换时触发本组件重渲染。 */
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  /** 订阅字体缩放；本字段不用，作用是切字号时触发本组件重渲染。 */
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  /** 历史回填序号；变化时由 @Watch 触发 onHistoryPick（见 ui/HistoryPick.ets） */
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private leftText: string = '';
  @State private rightText: string = '';
  @State private result: DiffResult | null = null;
  @State private hunks: Array<DiffHunk> = [];
  @State private summary: string = '';
  @State private notices: Array<string> = [];
  @State private unified: string = '';
  /** 是否显示未变的上下文行；关掉后只留差异，便于快速扫读 */
  @State private showContext: boolean = true;

  private draftTimer: number = -1;

  /** 用户在壳层选中一条历史 → 从草稿重读本次输入（见 ui/HistoryPick.ets） */

  private onHistoryPick(): void {

    const restored: string = toolStateStore.readDraft(TOOL_ID);

    if (restored.length === 0) {

      return;

    }

    this.leftText = restored;

  }


  aboutToAppear(): void {
    const savedLeft: string = toolStateStore.readDraft(TOOL_ID);
    const savedRight: string = toolStateStore.readDraft(RIGHT_DRAFT_KEY);
    if (savedLeft.length > 0) {
      this.leftText = savedLeft;
    }
    if (savedRight.length > 0) {
      this.rightText = savedRight;
    }
    if (savedLeft.length > 0 || savedRight.length > 0) {
      this.compare();
    }
  }

  aboutToDisappear(): void {
    this.flushDraft();
  }

  build() {
    Column({ space: 16 }) {
      this.buildInputSection()
      if (this.result !== null) {
        this.buildSummarySection()
        this.buildDiffSection()
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
        .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: MOTION_SLIDE_VP })))
        .animation({ duration: MOTION_DURATION_MS, curve: Curve.EaseOut })
  }

  /** 输入区：上下两块 */
  @Builder
  private buildInputSection() {
    Column({ space: 10 }) {
      this.buildTextBox($r('app.string.diff_label_left'), this.leftText, true)
      this.buildTextBox($r('app.string.diff_label_right'), this.rightText, false)

      Row({ space: 12 }) {
        Button($r('app.string.diff_action_compare'))
          .layoutWeight(1)
          .onClick(() => {
            this.compare();
            this.flushDraft();
          })
        Button($r('app.string.diff_action_swap'))
          .layoutWeight(1)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .controlSize(ControlSize.NORMAL)
          .onClick(() => {
            const temp: string = this.leftText;
            this.leftText = this.rightText;
            this.rightText = temp;
            this.compare();
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

  /** 单个文本框（标签 + 多行输入） */
  @Builder
  private buildTextBox(label: ResourceStr, value: string, isLeft: boolean) {
    Column({ space: 6 }) {
      Row() {
        Text(label)
          .fontSize(scaled(14))
          .fontWeight(FontWeight.Medium)
          .fontColor(colorOf(NGFColorToken.ON_SURFACE))
        Blank()
          // 这里原本有一个「从剪贴板粘贴」按钮，已移除。
          //
          // 原因：读剪贴板需要 ohos.permission.READ_PASTEBOARD（API 12 起），
          // 而本 App 的权限红线是**只声明 INTERNET**（AGENTS.md §2）。
          // 不声明权限时 getDataSync() 必然抛异常，被 catch 后表现为
          // 「剪贴板为空」——一个点了没用、还不报错的按钮。
          //
          // 替代：系统输入框自带长按粘贴，那是用户显式操作，不需要 App 持有权限。
          // 若将来决定申请该权限，从这里恢复按钮并改回 ToolUiKit.readClipboardText()。
      }
      .width('100%')

      TextArea({
          text: value,
          placeholder: isLeft
            ? $r('app.string.diff_placeholder_left')
            : $r('app.string.diff_placeholder_right')
        })
        .width('100%')
        .height(140)
        .fontSize(scaled(13))
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(12)
        .onChange((next: string) => {
          if (isLeft) {
            this.leftText = next;
          } else {
            this.rightText = next;
          }
          this.scheduleDraftSave();
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 摘要区：一句话结论 + 提示 + 复制入口 */
  @Builder
  private buildSummarySection() {
    Column({ space: 8 }) {
      Row() {
        Text(this.summary)
          .fontSize(scaled(14))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE))
          .layoutWeight(1)
        Text($r('app.string.diff_action_copy_diff'))
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.PRIMARY))
          .accessibilityText(ToolUiKit.text($r('app.string.copied_common')))
          .onClick(() => {
            ToolUiKit.copyText(this.unified, ToolUiKit.text($r('app.string.diff_copied')));
          })
      }
      .width('100%')

      // 行尾/末尾换行这两类「看不见的差异」必须提示，否则用户会以为工具算错了
      ForEach(this.notices, (notice: string) => {
        Text(notice)
          .fontSize(scaled(12))
          .fontColor(colorOf(NGFColorToken.WARNING))
          .width('100%')
          .padding(10)
          .backgroundColor(colorOf(NGFColorToken.WARNING_CONTAINER))
          .borderRadius(10)
      }, (notice: string) => notice)

      Row({ space: 8 }) {
        Text(this.showContext
            ? $r('app.string.diff_hide_unchanged')
            : $r('app.string.diff_show_unchanged'))
          .fontSize(scaled(12))
          .fontColor(colorOf(NGFColorToken.PRIMARY))
          .accessibilityText(this.showContext ? ToolUiKit.text($r('app.string.diff_hide_unchanged')) : ToolUiKit.text($r('app.string.diff_show_unchanged')))
          .onClick(() => {
            this.showContext = !this.showContext;
            this.rebuildHunks();
          })
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .backgroundColor(colorOf(NGFColorToken.SURFACE_VARIANT))
    .borderRadius(12)
  }

  /** 差异视图：逐块渲染，块间标注略过的行数 */
  @Builder
  private buildDiffSection() {
    Column({ space: 12 }) {
      ForEach(this.hunks, (hunk: DiffHunk) => {
        this.buildHunk(hunk)
      }, (hunk: DiffHunk) => String(hunk.leftStart) + '-' + String(hunk.rightStart))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 一个差异块 */
  @Builder
  private buildHunk(hunk: DiffHunk) {
    Column({ space: 2 }) {
      Text(ToolUiKit.stringOf($r('app.string.diff_hunk_header'),
            [String(hunk.leftStart), String(hunk.rightStart)]))
        .fontSize(scaled(11))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        .width('100%')
        .padding({ bottom: 4 })

      ForEach(hunk.lines, (line: DiffLine) => {
        this.buildDiffLine(line)
      }, (line: DiffLine) => String(line.kind) + '-' + String(line.leftNumber) + '-'
        + String(line.rightNumber) + '-' + line.text)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(10)
    .backgroundColor(colorOf(NGFColorToken.SURFACE))
    .borderRadius(12)
  }

  /**
   * 单行差异。
   *
   * 行号列固定宽度并右对齐，这样「哪一行对哪一行」在视觉上能直接对齐——
   * diff 可读性的关键就在这里，而不是颜色。
   */
  @Builder
  private buildDiffLine(line: DiffLine) {
    Row({ space: 6 }) {
      Text(line.leftNumber > 0 ? String(line.leftNumber) : '')
        .fontSize(scaled(11))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        .width(28)
        .textAlign(TextAlign.End)
      Text(line.rightNumber > 0 ? String(line.rightNumber) : '')
        .fontSize(scaled(11))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        .width(28)
        .textAlign(TextAlign.End)
      Text(line.kind === DiffLineKind.REMOVE ? '-' : (line.kind === DiffLineKind.ADD ? '+' : ' '))
        .fontSize(scaled(12))
        .fontColor(this.markerColor(line.kind))
        .width(12)
      Text(line.text.length > 0 ? line.text : ' ')
        .fontSize(scaled(12))
        .fontColor(this.lineColor(line.kind))
        .layoutWeight(1)
        .textSelectable(TextSelectableMode.SELECTABLE_UNFOCUSABLE)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .backgroundColor(this.lineBackground(line.kind))
    .borderRadius(4)
    .padding({ top: 2, bottom: 2 })
  }

  private markerColor(kind: DiffLineKind): ResourceColor {
  // 返回 ResourceColor 而不是 Resource：颜色现在来自 uiTheme 的运行时 Token,
  // colorOf() 给的是 string，声明成 Resource 会类型不匹配。
    if (kind === DiffLineKind.REMOVE) {
      return colorOf(NGFColorToken.ERROR_COLOR);
    }
    if (kind === DiffLineKind.ADD) {
      return colorOf(NGFColorToken.SUCCESS);
    }
    return colorOf(NGFColorToken.ON_SURFACE_VARIANT);
  }

  private lineColor(kind: DiffLineKind): ResourceColor {
  // 返回 ResourceColor 而不是 Resource：颜色现在来自 uiTheme 的运行时 Token,
  // colorOf() 给的是 string，声明成 Resource 会类型不匹配。
    if (kind === DiffLineKind.KEEP) {
      return colorOf(NGFColorToken.ON_SURFACE_VARIANT);
    }
    return colorOf(NGFColorToken.ON_SURFACE);
  }

  private lineBackground(kind: DiffLineKind): ResourceColor {
  // 返回 ResourceColor 而不是 Resource：颜色现在来自 uiTheme 的运行时 Token,
  // colorOf() 给的是 string，声明成 Resource 会类型不匹配。
    if (kind === DiffLineKind.REMOVE) {
      return colorOf(NGFColorToken.ERROR_CONTAINER);
    }
    if (kind === DiffLineKind.ADD) {
      return colorOf(NGFColorToken.WARNING_CONTAINER);
    }
    return colorOf(NGFColorToken.SURFACE);
  }

  /** 执行对比 */
  private compare(): void {
    const left: DiffDocument = toDocument(this.leftText);
    const right: DiffDocument = toDocument(this.rightText);
    const result: DiffResult = diffLines(left, right);
    this.result = result;
    // 摘要与提示的**判断**在纯逻辑层（可单测），**措辞**在 Messages 层（可多语言）。
    // 失败时摘要为空，错误文案由下面单独取。
    this.summary = result.ok
      ? summarizeDiff(diffSummaryFacts(result, left, right))
      : diffFailureText(result.failure);
    this.unified = '';

    const notices: Array<string> = [];
    if (result.ok) {
      const ending: string = lineEndingNotice(left, right);
      if (ending.length > 0) {
        notices.push(ending);
      }
      const trailing: string = trailingNewlineNotice(left, right);
      if (trailing.length > 0) {
        notices.push(trailing);
      }
    }
    this.notices = notices;
    this.rebuildHunks();
  }

  /** 依当前「显示未变行」开关重建差异块 */
  private rebuildHunks(): void {
    const result: DiffResult | null = this.result;
    if (result === null || !result.ok) {
      this.hunks = [];
      // 失败时不把错误文案塞进「要复制走的差异文本」：那会让人误以为
      // 那段话也是差异内容。错误另有显示位置。
      this.unified = '';
      return;
    }
    // 「隐藏未变行」等价于上下文为 0，于是块里只剩变更行
    const context: number = this.showContext ? DIFF_CONTEXT_LINES : 0;
    this.hunks = buildHunks(result, context);
    this.unified = toUnifiedText(result, this.hunks,
        ToolUiKit.text($r('app.string.diff_label_left')),
        ToolUiKit.text($r('app.string.diff_label_right')),
        unifiedSummaryOf(result, toDocument(this.leftText), toDocument(this.rightText)));
  }

  /** 清空两侧与结果 */
  private clearAll(): void {
    if (this.draftTimer >= 0) {
      clearTimeout(this.draftTimer);
      this.draftTimer = -1;
    }
    this.leftText = '';
    this.rightText = '';
    this.result = null;
    this.hunks = [];
    this.summary = '';
    this.notices = [];
    this.unified = '';
    toolStateStore.clearDraft(TOOL_ID);
    toolStateStore.clearDraft(RIGHT_DRAFT_KEY);
  }

  /** 防抖写两侧草稿 */
  private scheduleDraftSave(): void {
    if (this.draftTimer >= 0) {
      clearTimeout(this.draftTimer);
    }
    this.draftTimer = setTimeout(() => {
      this.draftTimer = -1;
      this.writeBothDrafts();
    }, DRAFT_DEBOUNCE_MS);
  }

  /** 立即落盘 */
  private flushDraft(): void {
    if (this.draftTimer >= 0) {
      clearTimeout(this.draftTimer);
      this.draftTimer = -1;
    }
    this.writeBothDrafts();
  }

  private writeBothDrafts(): void {
    toolStateStore.writeDraft(TOOL_ID, this.leftText);
    toolStateStore.writeDraft(RIGHT_DRAFT_KEY, this.rightText);
  }
}