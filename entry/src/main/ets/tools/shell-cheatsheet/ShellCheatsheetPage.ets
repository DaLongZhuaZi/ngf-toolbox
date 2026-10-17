/**
 * Shell 速查工具页（本地表同构件，bash/pwsh 双栏对照）。
 *
 * @module tools/shell-cheatsheet/ShellCheatsheetPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { currentLocale } from '../../ui/LocaleSource';
import { ToolUiKit } from '../../ui/ToolUiKit';
import { allShellEntries, queryShell, ShellEntry, shellCategories } from './ShellCheatsheetLogic';

@Builder
export function buildShellCheatsheetPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildShellContent })
}

@Builder
function buildShellContent() {
  ShellToolBody()
}

@Component
struct ShellToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  private locale: string = currentLocale();
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private keyword: string = '';
  @State private categoryFilter: string | null = null;
  @State private entries: Array<ShellEntry> = queryShell('', null).entries;

  private onHistoryPick(): void {
  }

  private updateQuery(v: string): void {
    this.keyword = v;
    this.entries = queryShell(v, this.categoryFilter).entries;
  }

  private updateCategory(c: string | null): void {
    this.categoryFilter = c;
    this.entries = queryShell(this.keyword, c).entries;
  }

  private categoryLabelOf(cat: string): string {
    if (cat === 'file') {
      return ToolUiKit.text($r('app.string.sc_cat_file'));
    }
    if (cat === 'text') {
      return ToolUiKit.text($r('app.string.sc_cat_text'));
    }
    if (cat === 'sys') {
      return ToolUiKit.text($r('app.string.sc_cat_sys'));
    }
    if (cat === 'net') {
      return ToolUiKit.text($r('app.string.sc_cat_net'));
    }
    return ToolUiKit.text($r('app.string.sc_cat_git'));
  }

  build() {
    Column({ space: 16 }) {
      Column({ space: 10 }) {
        TextInput({ text: this.keyword, placeholder: $r('app.string.sc_placeholder_search') })
          .width('100%')
          .fontSize(scaled(13))
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(10)
          .onChange((v: string) => {
            this.updateQuery(v);
          })
        Flex({ wrap: FlexWrap.Wrap }) {
          this.chip($r('app.string.sc_label_all'), null)
          ForEach(shellCategories(), (cat: string) => {
            this.chip(this.categoryLabelOf(cat), cat)
          }, (cat: string) => cat)
        }
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      if (this.entries.length === 0) {
        Text($r('app.string.sc_empty'))
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
          .width('100%')
          .padding(14)
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(12)
      } else {
        ForEach(this.entries, (e: ShellEntry) => {
          Column({ space: 6 }) {
            Text(e.task.forLocale(this.locale))
              .fontSize(scaled(13))
              .fontWeight(FontWeight.Medium)
              .fontColor(colorOf(NGFColorToken.ON_SURFACE))
            Column({ space: 2 }) {
              Text(ToolUiKit.text($r('app.string.sc_label_bash')) + ': ' + e.bash)
                .fontSize(scaled(11))
                .fontFamily('monospace')
                .fontColor(colorOf(NGFColorToken.PRIMARY))
                .width('100%')
                .maxLines(2)
              Text(ToolUiKit.text($r('app.string.sc_label_pwsh')) + ': ' + e.pwsh)
                .fontSize(scaled(11))
                .fontFamily('monospace')
                .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
                .width('100%')
                .maxLines(2)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .padding(12)
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(12)
          .alignItems(HorizontalAlign.Start)
          .accessibilityText(e.task.forLocale(this.locale))
        }, (e: ShellEntry) => e.category + ':' + e.task.forLocale(this.locale))
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private chip(label: ResourceStr, cat: string | null) {
    Text(label)
      .fontSize(scaled(12))
      .fontColor(this.categoryFilter === cat ? colorOf(NGFColorToken.ON_PRIMARY) : colorOf(NGFColorToken.ON_SURFACE))
      .backgroundColor(this.categoryFilter === cat ? colorOf(NGFColorToken.PRIMARY) : colorOf(NGFColorToken.SURFACE))
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .borderRadius(16)
      .margin(2)
      .onClick(() => {
        this.updateCategory(cat);
      })
      .accessibilityText(ToolUiKit.text(label))
  }
}