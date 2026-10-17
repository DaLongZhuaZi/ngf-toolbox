/**
 * 文本行工具页：去重 / 排序 / 统计。
 *
 * ## 布局：选项区在上（开关 + 排序选择），结果与统计在下
 *
 * 五个排序模式用一行分段按钮放不下（六个中文标签），改成两行 wrap 的胶囊；
 * 结果文本区可整体复制；统计用两列小卡。
 *
 * @module tools/text-toolkit/TextToolkitPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { toolStateStore } from '../../core/ToolStateStore';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { ToolUiKit } from '../../ui/ToolUiKit';
import { LineSortMode, processLines, TextToolkitResult } from './TextToolkit';
import { textToolkitFailureText } from './TextToolkitMessages';
import { MOTION_FEEDBACK_MS } from '../../ui/Motion';
import { MOTION_DURATION_MS, MOTION_SLIDE_VP } from '../../ui/Motion';

const TOOL_ID: string = 'text-toolkit';
const DRAFT_DEBOUNCE_MS: number = 500;

@Builder
export function buildTextToolkitPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildTextToolkitContent })
}

@Builder
function buildTextToolkitContent() {
  TextToolkitToolBody()
}

@Component
struct TextToolkitToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private input: string = '';
  @State private sortMode: LineSortMode = LineSortMode.ORIGINAL;
  @State private dedupe: boolean = true;
  @State private trimLines: boolean = false;
  @State private dropEmpty: boolean = true;
  @State private result: TextToolkitResult | null = null;
  @State private errorText: string = '';
  @State private copied: boolean = false;
  private draftTimer: number = -1;

  private onHistoryPick(): void {
    const restored: string = toolStateStore.readDraft(TOOL_ID);
    if (restored.length === 0) {
      return;
    }
    this.input = restored;
    this.run();
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
    const r: TextToolkitResult = processLines(this.input, this.sortMode, this.dedupe, this.trimLines, this.dropEmpty);
    if (r.ok) {
      this.errorText = '';
      this.result = r;
    } else {
      this.errorText = textToolkitFailureText(r.failure);
      this.result = null;
    }
    this.scheduleDraftSave();
  }

  private resultText(): string {
    return this.result === null ? '' : this.result.lines.join(String.fromCharCode(10));
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
      if (this.result !== null) {
        this.buildResultSection()
        this.buildStatsSection()
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
        .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: MOTION_SLIDE_VP })))
        .animation({ duration: MOTION_DURATION_MS, curve: Curve.EaseOut })
  }

  @Builder
  private buildInputSection() {
    Column({ space: 10 }) {
      Text($r('app.string.tk_label_input'))
        .fontSize(scaled(14))
        .fontWeight(FontWeight.Medium)
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))
      TextArea({ text: this.input, placeholder: $r('app.string.tk_placeholder_input') })
        .width('100%')
        .height(130)
        .fontSize(scaled(13))
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(12)
        .onChange((next: string) => {
          this.input = next;
          this.scheduleDraftSave();
        })
      this.buildOptionsSection()
      Row({ space: 12 }) {
        Button($r('app.string.tk_action_run'))
          .layoutWeight(1)
          .onClick(() => {
            this.run();
            this.flushDraft();
          })
        Button($r('app.string.tk_action_clear'))
          .layoutWeight(1)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .controlSize(ControlSize.NORMAL)
          .onClick(() => {
            this.input = '';
            this.result = null;
            this.errorText = '';
            this.flushDraft();
          })
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 三个开关 + 五个排序胶囊（wrap 两行放得下） */
  @Builder
  private buildOptionsSection() {
    Column({ space: 10 }) {
      Row({ space: 16 }) {
        Text($r('app.string.tk_label_dedupe'))
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE))
        Toggle({ type: ToggleType.Checkbox, isOn: this.dedupe })
          .onChange((on: boolean) => {
            this.dedupe = on;
          })
          .accessibilityText($r('app.string.tk_label_dedupe'))
        Text($r('app.string.tk_label_trim'))
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE))
        Toggle({ type: ToggleType.Checkbox, isOn: this.trimLines })
          .onChange((on: boolean) => {
            this.trimLines = on;
          })
          .accessibilityText($r('app.string.tk_label_trim'))
        Text($r('app.string.tk_label_drop_empty'))
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE))
        Toggle({ type: ToggleType.Checkbox, isOn: this.dropEmpty })
          .onChange((on: boolean) => {
            this.dropEmpty = on;
          })
          .accessibilityText($r('app.string.tk_label_drop_empty'))
      }
      .width('100%')

      Flex({ wrap: FlexWrap.Wrap }) {
        this.sortChip($r('app.string.tk_sort_original'), LineSortMode.ORIGINAL)
        this.sortChip($r('app.string.tk_sort_lexical'), LineSortMode.LEXICAL)
        this.sortChip($r('app.string.tk_sort_length_asc'), LineSortMode.LENGTH_ASC)
        this.sortChip($r('app.string.tk_sort_length_desc'), LineSortMode.LENGTH_DESC)
        this.sortChip($r('app.string.tk_sort_reverse'), LineSortMode.REVERSE)
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private sortChip(label: ResourceStr, mode: LineSortMode) {
    Text(label)
      .fontSize(scaled(12))
      .fontColor(this.sortMode === mode ? colorOf(NGFColorToken.ON_PRIMARY) : colorOf(NGFColorToken.ON_SURFACE))
      .backgroundColor(this.sortMode === mode ? colorOf(NGFColorToken.PRIMARY) : colorOf(NGFColorToken.SURFACE))
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .borderRadius(16)
      .onClick(() => {
        this.sortMode = mode;
        if (this.input.trim().length > 0) {
          this.run();
        }
      })
      .accessibilityText(ToolUiKit.text(label))
  }

  @Builder
  private buildResultSection() {
    Column({ space: 6 }) {
      Row() {
        Text(this.result === null ? '' :
          ToolUiKit.stringOf($r('app.string.tk_result_removed'),
            [String(this.result.removedDuplicates)]))
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE))
          .layoutWeight(1)
        Text(this.copied ? $r('app.string.tk_copied') : $r('app.string.tk_action_copy'))
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.PRIMARY))
          .accessibilityText(ToolUiKit.text($r('app.string.copied_common')))
            .scale({ x: this.copied ? 1.08 : 1, y: this.copied ? 1.08 : 1 })
            .animation({ duration: MOTION_FEEDBACK_MS, curve: Curve.EaseOut })
          .onClick(() => {
            ToolUiKit.copyText(this.resultText(), ToolUiKit.text($r('app.string.tk_copied')));
            this.copied = true;
            setTimeout((): void => {
              this.copied = false;
            }, 1500);
          })
      }
      .width('100%')

      Text(this.resultText())
        .fontSize(scaled(13))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))
        .width('100%')
        .padding(12)
        .constraintSize({ maxHeight: 260 })
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(12)
        .copyOption(CopyOptions.LocalDevice)
        .accessibilityText(this.resultText())
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildStatsSection() {
    Column({ space: 8 }) {
      Text($r('app.string.tk_stats_title'))
        .fontSize(scaled(14))
        .fontWeight(FontWeight.Medium)
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))
      Row({ space: 10 }) {
        this.statCard($r('app.string.tk_stats_lines'),
          (this.result === null ? '' : String(this.result.stats.nonEmptyLines)) + ' / ' +
          (this.result === null ? '' : String(this.result.stats.totalLines)))
        this.statCard($r('app.string.tk_stats_words'),
          this.result === null ? '' : String(this.result.stats.words))
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      Row({ space: 10 }) {
        this.statCard($r('app.string.tk_stats_chars'),
          this.result === null ? '' : String(this.result.stats.chars))
        this.statCard($r('app.string.tk_stats_eol'),
          (this.result === null ? '' : String(this.result.stats.crlfLines)) + ' / ' +
          (this.result === null ? '' : String(this.result.stats.lfLines)))
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private statCard(label: ResourceStr, value: string) {
    Column({ space: 4 }) {
      Text(value)
        .fontSize(scaled(18))
        .fontWeight(FontWeight.Medium)
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))
      Text(label)
        .fontSize(scaled(12))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
    }
    .layoutWeight(1)
    .padding(12)
    .backgroundColor(colorOf(NGFColorToken.SURFACE))
    .borderRadius(12)
    .alignItems(HorizontalAlign.Start)
    .accessibilityText(label + ': ' + value)
  }
}
