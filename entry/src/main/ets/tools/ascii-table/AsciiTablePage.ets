/**
 * ASCII 对照表工具页（本地表同构）。
 *
 * @module tools/ascii-table/AsciiTablePage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { currentLocale } from '../../ui/LocaleSource';
import { ToolUiKit } from '../../ui/ToolUiKit';
import { allAsciiEntries, AsciiEntry, asciiCategories, queryAscii } from './AsciiTableLogic';

@Builder
export function buildAsciiTablePage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildAsciiContent })
}

@Builder
function buildAsciiContent() {
  AsciiToolBody()
}

@Component
struct AsciiToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  private locale: string = currentLocale();
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private keyword: string = '';
  @State private categoryFilter: string | null = null;
  @State private entries: Array<AsciiEntry> = queryAscii('', null).entries;

  private onHistoryPick(): void {
  }

  private updateQuery(v: string): void {
    this.keyword = v;
    this.entries = queryAscii(v, this.categoryFilter).entries;
  }

  private updateCategory(c: string | null): void {
    this.categoryFilter = c;
    this.entries = queryAscii(this.keyword, c).entries;
  }

  private categoryLabelOf(cat: string): string {
    if (cat === 'ctrl') {
      return ToolUiKit.text($r('app.string.at_cat_ctrl'));
    }
    return ToolUiKit.text($r('app.string.at_cat_print'));
  }

  build() {
    Column({ space: 16 }) {
      Column({ space: 10 }) {
        TextInput({ text: this.keyword, placeholder: $r('app.string.at_placeholder_search') })
          .width('100%')
          .fontSize(scaled(13))
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(10)
          .onChange((v: string) => {
            this.updateQuery(v);
          })
        Flex({ wrap: FlexWrap.Wrap }) {
          this.chip($r('app.string.at_label_all'), null)
          ForEach(asciiCategories(), (cat: string) => {
            this.chip(this.categoryLabelOf(cat), cat)
          }, (cat: string) => cat)
        }
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      if (this.entries.length === 0) {
        Text($r('app.string.at_empty'))
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
          .width('100%')
          .padding(14)
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(12)
      } else {
        ForEach(this.entries, (e: AsciiEntry) => {
          Row({ space: 10 }) {
            Text(String(e.decimal))
              .fontSize(scaled(13))
              .fontFamily('monospace')
              .fontColor(colorOf(NGFColorToken.PRIMARY))
              .width(40)
            Text(e.hex)
              .fontSize(scaled(11))
              .fontFamily('monospace')
              .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
              .width(48)
            Text(e.char)
              .fontSize(scaled(14))
              .fontFamily('monospace')
              .fontColor(colorOf(NGFColorToken.ON_SURFACE))
              .width(28)
            Text(e.meaning.forLocale(this.locale))
              .fontSize(scaled(12))
              .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
              .layoutWeight(1)
          }
          .width('100%')
          .padding(10)
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(10)
          .alignItems(VerticalAlign.Center)
          .accessibilityText(String(e.decimal) + ' ' + e.meaning.forLocale(this.locale))
        }, (e: AsciiEntry) => e.category + ':' + e.decimal)
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
