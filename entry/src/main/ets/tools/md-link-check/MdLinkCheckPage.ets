/**
 * Markdown 链接检查工具页。
 *
 * ## 布局：输入 + 统计（链接数/重复/空 target）+ 链接清单（分类徽标）
 *
 * @module tools/md-link-check/MdLinkCheckPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { toolStateStore } from '../../core/ToolStateStore';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { checkLinks, MdLinkCheckResult, MdLinkItem, MdLinkKind } from './MdLinkCheckLogic';
import { ToolUiKit } from '../../ui/ToolUiKit';

const TOOL_ID: string = 'md-link-check';
const DRAFT_DEBOUNCE_MS: number = 500;

@Builder
export function buildMdLinkCheckPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildLinkCheckContent })
}

@Builder
function buildLinkCheckContent() {
  LinkCheckToolBody()
}

@Component
struct LinkCheckToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private input: string = '';
  @State private result: MdLinkCheckResult | null = null;
  @State private errorText: string = '';
  private draftTimer: number = -1;

  private onHistoryPick(): void {
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
    const r: MdLinkCheckResult = checkLinks(this.input);
    if (r.ok) {
      this.result = r;
    } else {
      this.result = null;
      this.errorText = 'empty';
    }
  }

  private kindText(kind: MdLinkKind): string {
    if (kind === MdLinkKind.ANCHOR) {
      return 'anchor';
    }
    if (kind === MdLinkKind.RELATIVE) {
      return 'relative';
    }
    if (kind === MdLinkKind.ABSOLUTE) {
      return 'absolute';
    }
    return 'other';
  }

  build() {
    Column({ space: 16 }) {
      Column({ space: 10 }) {
        TextArea({ text: this.input, placeholder: $r('app.string.ml_label_input') })
          .width('100%')
          .height(120)
          .fontSize(scaled(12))
          .fontFamily('monospace')
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(12)
          .onChange((v: string) => {
            this.input = v;
            this.scheduleDraftSave();
          })
        Button($r('app.string.ml_action_check'))
          .width('100%')
          .onClick(() => {
            this.run();
            this.flushDraft();
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      if (this.errorText.length > 0) {
        Text($r('app.string.ml_err_empty'))
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.WARNING))
          .width('100%')
          .padding(10)
          .backgroundColor(colorOf(NGFColorToken.WARNING_CONTAINER))
          .borderRadius(10)
      }

      if (this.result !== null) {
        Text($r('app.string.ml_label_links'))
          .fontSize(scaled(12))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))

        if (this.result.duplicates.length > 0) {
          Text(ToolUiKit.text($r('app.string.ml_label_duplicates')) + ': ' + this.result.duplicates.join(', '))
            .fontSize(scaled(12))
            .fontColor(colorOf(NGFColorToken.WARNING))
            .width('100%')
            .padding(10)
            .backgroundColor(colorOf(NGFColorToken.WARNING_CONTAINER))
            .borderRadius(10)
        }

        ForEach(this.result.links, (item: MdLinkItem) => {
          Column({ space: 4 }) {
            Row({ space: 8 }) {
              Text(this.kindText(item.kind))
                .fontSize(scaled(10))
                .fontColor(colorOf(NGFColorToken.PRIMARY))
                .layoutWeight(1)
              Text(item.isImage ? $r('app.string.ml_kind_image') : '')
                .fontSize(scaled(10))
                .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
            }
            .width('100%')
            Text(item.text + ' -> ' + item.target)
              .fontSize(scaled(12))
              .fontFamily('monospace')
              .fontColor(colorOf(NGFColorToken.ON_SURFACE))
              .width('100%')
              .maxLines(2)
          }
          .width('100%')
          .padding(10)
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(10)
          .alignItems(HorizontalAlign.Start)
          .accessibilityText(item.text)
        }, (item: MdLinkItem) => item.line + ':' + item.target)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
