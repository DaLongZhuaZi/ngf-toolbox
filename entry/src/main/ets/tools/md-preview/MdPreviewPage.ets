/**
 * Markdown 预览工具页。
 *
 * ## 布局：源文本在上、渲染结果在下；边输入边解析
 *
 * 结果区按块级节点渲染：标题加粗放大、列表带圆点/序号、引用左侧竖线、
 * 代码块等宽底色、水平线细分隔。全部走主题 Token 与 scaled()。
 *
 * @module tools/md-preview/MdPreviewPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { toolStateStore } from '../../core/ToolStateStore';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { ToolUiKit } from '../../ui/ToolUiKit';
import { MdBlock, MdBlockKind, MdInlineSpan, parseMarkdown } from './MdPreview';
import { mdEmptyText } from './MdPreviewMessages';

const TOOL_ID: string = 'md-preview';
const DRAFT_DEBOUNCE_MS: number = 500;

@Builder
export function buildMdPreviewPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildMdPreviewContent })
}

@Builder
function buildMdPreviewContent() {
  MdPreviewToolBody()
}

@Component
struct MdPreviewToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private input: string = '';
  @State private blocks: Array<MdBlock> = [];
  @State private hasInput: boolean = false;
  private draftTimer: number = -1;

  private onHistoryPick(): void {
    const restored: string = toolStateStore.readDraft(TOOL_ID);
    if (restored.length === 0) {
      return;
    }
    this.input = restored;
    this.reparse();
  }

  aboutToAppear(): void {
    const saved: string = toolStateStore.readDraft(TOOL_ID);
    if (saved.length > 0) {
      this.input = saved;
      this.reparse();
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

  private reparse(): void {
    const r = parseMarkdown(this.input);
    this.blocks = r.blocks;
    this.hasInput = this.input.trim().length > 0;
    this.scheduleDraftSave();
  }

  build() {
    Column({ space: 16 }) {
      this.buildInputSection()
      if (this.hasInput) {
        this.buildPreviewSection()
      } else {
        Text(mdEmptyText())
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
          .width('100%')
          .padding(14)
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(12)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildInputSection() {
    Column({ space: 10 }) {
      Row() {
        Text($r('app.string.md_label_input'))
          .fontSize(scaled(14))
          .fontWeight(FontWeight.Medium)
          .fontColor(colorOf(NGFColorToken.ON_SURFACE))
          .layoutWeight(1)
        Text($r('app.string.md_action_clear'))
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.PRIMARY))
          .accessibilityText(ToolUiKit.text($r('app.string.md_action_clear')))
          .onClick(() => {
            this.input = '';
            this.blocks = [];
            this.hasInput = false;
            this.flushDraft();
          })
      }
      .width('100%')
      TextArea({ text: this.input, placeholder: $r('app.string.md_placeholder_input') })
        .width('100%')
        .height(150)
        .fontSize(scaled(13))
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(12)
        .onChange((next: string) => {
          this.input = next;
          this.reparse();
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildPreviewSection() {
    Column({ space: 12 }) {
      Text($r('app.string.md_label_preview'))
        .fontSize(scaled(14))
        .fontWeight(FontWeight.Medium)
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))
      ForEach(this.blocks, (block: MdBlock, idx: number) => {
        this.buildBlock(block)
      }, (block: MdBlock, idx: number) => idx + ':' + block.kind + ':' + block.rawText.length)
    }
    .width('100%')
    .padding(14)
    .backgroundColor(colorOf(NGFColorToken.SURFACE))
    .borderRadius(12)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildBlock(block: MdBlock) {
    if (block.kind === MdBlockKind.HEADING) {
      // ⚠️ 不能写成 Text(x) { }——空块后缀会让内容渲染异常（真机只见首字符，
      // 与第一阶段的「裸 { } 不渲染」同族）。直接 Text(x) 不带块。
      Text(this.spansToText(block))
      .fontSize(scaled(block.level === 1 ? 22 : block.level === 2 ? 19 : 17))
      .fontWeight(FontWeight.Bold)
      .fontColor(colorOf(NGFColorToken.ON_SURFACE))
    } else if (block.kind === MdBlockKind.CODE) {
      Text(block.rawText)
        .fontSize(scaled(12))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))
        .width('100%')
        .padding(10)
        .backgroundColor(colorOf(NGFColorToken.BACKGROUND))
        .borderRadius(8)
    } else if (block.kind === MdBlockKind.HR) {
      Column() {}
        .width('100%')
        .height(1)
        .backgroundColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        .opacity(0.4)
    } else if (block.kind === MdBlockKind.QUOTE) {
      Row({ space: 8 }) {
        Column() {}
          .width(3)
          .height(scaled(20))
          .backgroundColor(colorOf(NGFColorToken.PRIMARY))
        Column({ space: 4 }) {
          ForEach(block.spans, (span: MdInlineSpan) => {
            Text(span.text)
              .fontSize(scaled(13))
              .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
              .fontWeight(span.bold ? FontWeight.Bold : FontWeight.Normal)
              .fontStyle(span.italic ? FontStyle.Italic : FontStyle.Normal)
          }, (span: MdInlineSpan, i2: number) => i2 + ':' + span.text)
        }
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    } else if (block.kind === MdBlockKind.LIST_ITEM) {
      Row({ space: 8 }) {
        Text(block.order > 0 ? block.order + '.' : String.fromCharCode(8226))
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.PRIMARY))
          .width(22)
        this.buildInlineText(block)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    } else {
      this.buildInlineText(block)
    }
  }

  /** 行内片段转多段 Text（粗体/斜体/代码） */
  @Builder
  private buildInlineText(block: MdBlock) {
    Text() {
      ForEach(block.spans, (span: MdInlineSpan) => {
        Span(span.text)
          .fontWeight(span.bold ? FontWeight.Bold : FontWeight.Normal)
          .fontStyle(span.italic ? FontStyle.Italic : FontStyle.Normal)
          .fontSize(scaled(span.code ? 12 : 14))
          .fontColor(span.code ? colorOf(NGFColorToken.PRIMARY) : colorOf(NGFColorToken.ON_SURFACE))
      }, (span: MdInlineSpan, i2: number) => i2 + ':' + span.text)
    }
    .width('100%')
  }

  private spansToText(block: MdBlock): string {
    let out: string = '';
    for (let i = 0; i < block.spans.length; i++) {
      out = out + block.spans[i].text;
    }
    return out;
  }
}
