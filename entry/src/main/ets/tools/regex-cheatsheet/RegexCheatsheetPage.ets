/**
 * 正则速查表工具页（http-status 同构：搜索 + 分类胶囊 + 结果卡片列表）。
 *
 * @module tools/regex-cheatsheet/RegexCheatsheetPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { currentLocale } from '../../ui/LocaleSource';
import { ToolUiKit } from '../../ui/ToolUiKit';
import { queryRegex, regexCategories, RegexEntry } from './RegexCheatsheet';
import { regexEmptyText } from './RegexCheatsheetMessages';

@Builder
export function buildRegexCheatsheetPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildRegexContent })
}

@Builder
function buildRegexContent() {
  RegexToolBody()
}

@Component
struct RegexToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  private locale: string = currentLocale();
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private keyword: string = '';
  @State private categoryFilter: string | null = null;
  @State private entries: Array<RegexEntry> = queryRegex('', null).entries;

  private onHistoryPick(): void {
  }

  private updateQuery(v: string): void {
    this.keyword = v;
    this.entries = queryRegex(v, this.categoryFilter).entries;
  }

  private updateCategory(c: string | null): void {
    this.categoryFilter = c;
    this.entries = queryRegex(this.keyword, c).entries;
  }

  private categoryLabelOf(cat: string): string {
    if (cat === 'char') {
      return ToolUiKit.text($r('app.string.rc_cat_char'));
    }
    if (cat === 'quant') {
      return ToolUiKit.text($r('app.string.rc_cat_quant'));
    }
    if (cat === 'group') {
      return ToolUiKit.text($r('app.string.rc_cat_group'));
    }
    if (cat === 'anchor') {
      return ToolUiKit.text($r('app.string.rc_cat_anchor'));
    }
    if (cat === 'escape') {
      return ToolUiKit.text($r('app.string.rc_cat_escape'));
    }
    return ToolUiKit.text($r('app.string.rc_cat_flag'));
  }

  build() {
    Column({ space: 16 }) {
      Column({ space: 10 }) {
        TextInput({ text: this.keyword, placeholder: $r('app.string.rc_placeholder_search') })
          .width('100%')
          .fontSize(scaled(13))
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(10)
          .onChange((v: string) => {
            this.updateQuery(v);
          })
        Flex({ wrap: FlexWrap.Wrap }) {
          this.chip($r('app.string.rc_label_all'), null)
          ForEach(regexCategories(), (cat: string) => {
            this.chip(this.categoryLabelOf(cat), cat)
          }, (cat: string) => cat)
        }
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      if (this.entries.length === 0) {
        Text(regexEmptyText())
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
          .width('100%')
          .padding(14)
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(12)
      } else {
        ForEach(this.entries, (e: RegexEntry) => {
          Column({ space: 4 }) {
            Row({ space: 8 }) {
              Text(e.syntax)
                .fontSize(scaled(14))
                .fontWeight(FontWeight.Bold)
                .fontFamily('monospace')
                .fontColor(colorOf(NGFColorToken.PRIMARY))
                .layoutWeight(1)
                .maxLines(2)
              Text(this.categoryLabelOf(e.category))
                .fontSize(scaled(11))
                .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
            }
            .width('100%')
            Text(e.meaning.forLocale(this.locale))
              .fontSize(scaled(13))
              .fontColor(colorOf(NGFColorToken.ON_SURFACE))
            Text(e.example)
              .fontSize(scaled(11))
              .fontFamily('monospace')
              .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
              .maxLines(2)
          }
          .width('100%')
          .padding(12)
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(12)
          .alignItems(HorizontalAlign.Start)
          .accessibilityText(e.syntax + ' ' + e.meaning.forLocale(this.locale))
        }, (e: RegexEntry) => e.category + ':' + e.syntax)
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
