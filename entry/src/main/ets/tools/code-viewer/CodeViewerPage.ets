/**
 * 代码查看工具页。
 *
 * ## 分层
 *
 * 语言识别、逐行分词、显示截断全在 {@link CodeHighlight}（纯逻辑、有单测）。
 * 本文件里只有两处用到平台能力，且都是框架已封装好的：
 * - {@link ngfMediaPickerFacade}.pickDocuments() 选文件（系统安全选择器，**不需要存储权限**）；
 * - {@link FileUtils}.readText() 读内容（其内部已支持 file:// 形式的路径）。
 *
 * 这两处合起来只有几行，是刻意的：本机无法编译验证平台调用，
 * 因此把它们压到最小、并复用框架已有的门面（而不是自己拼 fileIo 与 picker），
 * 是降低「只能在 CI 上发现问题」这件事的唯一办法。
 *
 * ## 渲染
 *
 * 每一行源码渲染成一个 Row（行号 + 若干着色片段）。为避免「几千行同时建组件」，
 * 显示行数由 {@link MAX_RENDER_LINES} 限制，且用 List 而不是 Column——
 * List 会按需创建可见项，滚动大文件时不会一次建出全部行。
 *
 * @module tools/code-viewer/CodeViewerPage
 */

import { NGFControlStyleTokens } from 'ngf_framework';
import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import {
  NGFColorToken, logger } from 'ngf_framework';
import { ngfMediaPickerFacade } from 'ngf_framework';
import { FileUtils } from 'ngf_framework';
import { ToolPageParams } from '../../core/ToolPageContract';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { ToolUiKit } from '../../ui/ToolUiKit';
import {
  CodeDocument,
  CodeLanguage,
  CodeToken,
  CodeTokenKind,
  fileNameFromUri,
  makeDocument,

  tokenizeLine
} from './CodeHighlight';
import { codeViewerUnnamedFile, describeDocument, fileTooLarge, fileTooLargeText } from './CodeViewerMessages';

const TAG: string = 'CodeViewerPage';

/** 工具 id（本工具不存草稿：文件内容来自选择器，草稿没有意义） */
const TOOL_ID: string = 'code-viewer';

/** 行号列宽度（vp）：5 位数够用到 9 万行 */
const LINE_NUMBER_WIDTH: number = 44;

/** 行高（vp）：固定行高让 List 的滚动定位更稳定 */
const LINE_HEIGHT: number = 20;

@Builder
export function buildCodeViewerPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildCodeViewerContent })
}

@Builder
function buildCodeViewerContent() {
  CodeViewerToolBody()
}

/** 一行源码的分词结果（含行号），缓存起来避免每次重绘都重新分词 */
class RenderedLine {
  readonly number: number;
  readonly tokens: Array<CodeToken>;

  constructor(number: number, tokens: Array<CodeToken>) {
    this.number = number;
    this.tokens = tokens;
  }
}

@Component
struct CodeViewerToolBody {
  /** 订阅主题深浅；本字段本身不用，作用是在主题切换时触发本组件重渲染。 */
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  /** 订阅字体缩放；本字段不用，作用是切字号时触发本组件重渲染。 */
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  @State private document: CodeDocument | null = null;
  @State private renderedLines: Array<RenderedLine> = [];
  @State private message: string = '';
  @State private errorText: string = '';
  @State private loading: boolean = false;
  @State private showLineNumbers: boolean = true;

  build() {
    Column({ space: 16 }) {
      this.buildPickerSection()
      if (this.errorText.length > 0) {
        this.buildError()
      }
      if (this.document !== null) {
        this.buildDocumentHeader()
        this.buildCodeList()
      } else if (this.message.length > 0) {
        this.buildEmptyHint()
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 选择文件 */
  @Builder
  private buildPickerSection() {
    Column({ space: 10 }) {
      Button(this.loading
        ? $r('app.string.codeview_reading')
        : $r('app.string.codeview_pick_file'))
        .buttonStyle(ButtonStyleMode.NORMAL)
        .controlSize(ControlSize.NORMAL)
        .width('100%')
        .height(NGFControlStyleTokens.NORMAL_BUTTON_HEIGHT)
        .enabled(!this.loading)
        .onClick(() => {
          this.pickFile();
        })

      Text($r('app.string.codeview_permission_note'))
        .fontSize(scaled(12))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildError() {
    Text(this.errorText)
      .fontSize(scaled(13))
      .fontColor(colorOf(NGFColorToken.ERROR_COLOR))
      .width('100%')
      .padding(12)
      .backgroundColor(colorOf(NGFColorToken.ERROR_CONTAINER))
      .borderRadius(12)
  }

  @Builder
  private buildEmptyHint() {
    Text(this.message)
      .fontSize(scaled(14))
      .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
      .width('100%')
      .padding(24)
      .backgroundColor(colorOf(NGFColorToken.SURFACE_VARIANT))
      .borderRadius(12)
      .textAlign(TextAlign.Center)
  }

  /** 文档信息条 */
  @Builder
  private buildDocumentHeader() {
    Column({ space: 8 }) {
      Row() {
        Column({ space: 4 }) {
          Text(this.document === null ? '' : this.document.fileName)
            .fontSize(scaled(15))
            .fontWeight(FontWeight.Medium)
            .fontColor(colorOf(NGFColorToken.ON_SURFACE))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
          Text(this.document === null ? '' : describeDocument(this.document))
            .fontSize(scaled(12))
            .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')

      Row({ space: 8 }) {
        Text(this.showLineNumbers
            ? $r('app.string.codeview_hide_line_numbers')
            : $r('app.string.codeview_show_line_numbers'))
          .fontSize(scaled(12))
          .fontColor(colorOf(NGFColorToken.PRIMARY))
          .accessibilityText(this.showLineNumbers ? ToolUiKit.text($r('app.string.codeview_hide_line_numbers')) : ToolUiKit.text($r('app.string.codeview_show_line_numbers')))
          .onClick(() => {
            this.showLineNumbers = !this.showLineNumbers;
          })
        Text($r('app.string.shell_action_copy_all'))
          .fontSize(scaled(12))
          .fontColor(colorOf(NGFColorToken.PRIMARY))
          .accessibilityText(ToolUiKit.text($r('app.string.shell_action_copy_all')))
          .onClick(() => {
            this.copyAll();
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

  /** 代码列表：用 List 按需创建行，避免一次建出几千个组件 */
  @Builder
  private buildCodeList() {
    List({ space: 0 }) {
      ForEach(this.renderedLines, (line: RenderedLine) => {
        ListItem() {
          this.buildLine(line)
        }
      }, (line: RenderedLine) => String(line.number))
    }
    .width('100%')
    .height(420)
    .scrollBar(BarState.Auto)
    .backgroundColor(colorOf(NGFColorToken.SURFACE))
    .borderRadius(12)
    .padding({ left: 8, right: 8, top: 8, bottom: 8 })
  }

  /** 一行：行号 + 片段 */
  @Builder
  private buildLine(line: RenderedLine) {
    Row({ space: 0 }) {
      if (this.showLineNumbers) {
        Text(String(line.number))
          .fontSize(scaled(11))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
          .width(LINE_NUMBER_WIDTH)
          .height(LINE_HEIGHT)
          .textAlign(TextAlign.End)
          .padding({ right: 8 })
      }
      // 行内片段横向排列；用 Flex 不换行，超出部分由父容器裁剪
      Flex({ wrap: FlexWrap.NoWrap }) {
        ForEach(line.tokens, (token: CodeToken) => {
          Text(token.text)
            .fontSize(scaled(12))
            .fontColor(tokenColor(token.kind))
            .height(LINE_HEIGHT)
        }, (token: CodeToken) => token.kind + token.text)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height(LINE_HEIGHT)
    .alignItems(VerticalAlign.Center)
  }

  /**
   * 选择并读取文件。
   *
   * 全流程共三步：系统选择器取 URI → 读文本 → 构造可查看文档。
   * 每一步的失败都给出**具体**原因（而不是统一「打开失败」），
   * 因为用户能采取的行动完全不同：重选文件、换个文件、还是文件太大。
   */
  private async pickFile(): Promise<void> {
    this.loading = true;
    this.errorText = '';
    this.message = '';
    try {
      const uris: Array<string> = await ngfMediaPickerFacade.pickDocuments();
      if (uris === undefined || uris === null || uris.length === 0) {
        // 用户取消：不是错误，安静地回到原状
        this.message = ToolUiKit.text($r('app.string.codeview_no_file_yet'));
        this.loading = false;
        return;
      }

      const uri: string = uris[0];
      // 取不到名字时用资源文案兜底（"未命名文件" 这句话也要能跟随系统语言）
      const rawName: string = fileNameFromUri(uri);
      const fileName: string = rawName.length > 0 ? rawName : codeViewerUnnamedFile();
      const content: string = FileUtils.readText(uri);

      if (content.length === 0) {
        this.errorText = ToolUiKit.text($r('app.string.codeview_unreadable'));
        this.document = null;
        this.renderedLines = [];
        this.loading = false;
        return;
      }

      if (fileTooLarge(content.length)) {
        this.errorText = fileTooLargeText(content.length);
        this.document = null;
        this.renderedLines = [];
        this.loading = false;
        return;
      }

      const doc: CodeDocument = makeDocument(fileName, content);
      this.document = doc;
      this.renderedLines = renderLines(doc);
      this.errorText = '';
      this.message = '';
      logger.info(TAG, '已打开文件: ' + fileName + '，' + String(doc.totalLines) + ' 行');
    } catch (error) {
      const detail: string = error instanceof Error ? error.message : String(error);
      logger.warn(TAG, '打开文件失败: ' + detail);
      this.errorText = ToolUiKit.stringOf($r('app.string.codeview_open_failed'), [detail]);
      this.document = null;
      this.renderedLines = [];
    }
    this.loading = false;
  }

  /** 复制整个文件内容 */
  private copyAll(): void {
    const doc: CodeDocument | null = this.document;
    if (doc === null) {
      return;
    }
    let text: string = '';
    for (let i: number = 0; i < doc.lines.length; i++) {
      text += doc.lines[i] + '\n';
    }
    const notice: string = doc.truncated
      ? ToolUiKit.stringOf($r('app.string.codeview_copied_truncated'), [String(doc.lines.length)])
      : ToolUiKit.text($r('app.string.codeview_copied'));
    ToolUiKit.copyText(text, notice);
  }
}

/** 把文档逐行分词，产出可渲染的行清单 */
function renderLines(doc: CodeDocument): Array<RenderedLine> {
  const result: Array<RenderedLine> = [];
  for (let i: number = 0; i < doc.lines.length; i++) {
    const raw: string = doc.lines[i];
    // 空行给一个空片段，否则这一行的 Flex 高度会塌掉、行号与内容错位
    const tokens: Array<CodeToken> = raw.length === 0
      ? [new CodeToken(' ', CodeTokenKind.PLAIN)]
      : tokenizeLine(raw, doc.language);
    result.push(new RenderedLine(i + 1, tokens));
  }
  return result;
}

/** 片段类型 → 颜色 */
function tokenColor(kind: CodeTokenKind): ResourceColor {
  // 返回 ResourceColor 而不是 Resource：颜色现在来自 uiTheme 的运行时 Token,
  // colorOf() 给的是 string，声明成 Resource 会类型不匹配。
  if (kind === CodeTokenKind.KEYWORD) {
    return colorOf(NGFColorToken.PRIMARY);
  }
  if (kind === CodeTokenKind.STRING) {
    return colorOf(NGFColorToken.SUCCESS);
  }
  if (kind === CodeTokenKind.COMMENT) {
    return colorOf(NGFColorToken.ON_SURFACE_VARIANT);
  }
  if (kind === CodeTokenKind.NUMBER) {
    return colorOf(NGFColorToken.WARNING);
  }
  if (kind === CodeTokenKind.TAG) {
    return colorOf(NGFColorToken.PRIMARY);
  }
  if (kind === CodeTokenKind.PROPERTY) {
    return colorOf(NGFColorToken.PRIMARY);
  }
  return colorOf(NGFColorToken.ON_SURFACE);
}