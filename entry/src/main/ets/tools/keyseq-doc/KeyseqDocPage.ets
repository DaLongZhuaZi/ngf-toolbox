/**
 * 快捷键速查工具页（git-cheatsheet 同构）。
 *
 * @module tools/keyseq-doc/KeyseqDocPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { currentLocale } from '../../ui/LocaleSource';
import { ToolUiKit } from '../../ui/ToolUiKit';
import { allKeyseqEntries, KeyseqEntry, keyseqCategories, queryKeyseq } from './KeyseqDocLogic';

@Builder
export function buildKeyseqDocPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildKeyseqContent })
}

@Builder
function buildKeyseqContent() {
  KeyseqToolBody()
}

@Component
struct KeyseqToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  private locale: string = currentLocale();
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private keyword: string = '';
  @State private categoryFilter: string | null = null;
  @State private entries: Array<KeyseqEntry> = queryKeyseq('', null).entries;

  private onHistoryPick(): void {
  }

  private updateQuery(v: string): void {
    this.keyword = v;
    this.entries = queryKeyseq(v, this.categoryFilter).entries;
  }

  private updateCategory(c: string | null): void {
    this.categoryFilter = c;
    this.entries = queryKeyseq(this.keyword, c).entries;
  }

  private categoryLabelOf(cat: string): string {
    if (cat === 'nav') {
      return ToolUiKit.text($r('app.string.ks_cat_nav'));
    }
    if (cat === 'edit') {
      return ToolUiKit.text($r('app.string.ks_cat_edit'));
    }
    if (cat === 'refactor') {
      return ToolUiKit.text($r('app.string.ks_cat_refactor'));
    }
    if (cat === 'run') {
      return ToolUiKit.text($r('app.string.ks_cat_run'));
    }
    return ToolUiKit.text($r('app.string.ks_cat_search'));
  }

  build() {
    Column({ space: 16 }) {
      Column({ space: 10 }) {
        TextInput({ text: this.keyword, placeholder: $r('app.string.ks_placeholder_search') })
          .width('100%')
          .fontSize(scaled(13))
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(10)
          .onChange((v: string) => {
            this.updateQuery(v);
          })
        Flex({ wrap: FlexWrap.Wrap }) {
          this.chip($r('app.string.ks_label_all'), null)
          ForEach(keyseqCategories(), (cat: string) => {
            this.chip(this.categoryLabelOf(cat), cat)
          }, (cat: string) => cat)
        }
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      if (this.entries.length === 0) {
        Text($r('app.string.ks_empty'))
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
          .width('100%')
          .padding(14)
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(12)
      } else {
        ForEach(this.entries, (e: KeyseqEntry) => {
          Row({ space: 10 }) {
            Text(e.keys)
              .fontSize(scaled(13))
              .fontFamily('monospace')
              .fontWeight(FontWeight.Medium)
              .fontColor(colorOf(NGFColorToken.PRIMARY))
              .width(130)
              .maxLines(2)
            Text(e.meaning.forLocale(this.locale))
              .fontSize(scaled(13))
              .fontColor(colorOf(NGFColorToken.ON_SURFACE))
              .layoutWeight(1)
          }
          .width('100%')
          .padding(12)
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(12)
          .alignItems(VerticalAlign.Center)
          .accessibilityText(e.keys + ' ' + e.meaning.forLocale(this.locale))
        }, (e: KeyseqEntry) => e.category + ':' + e.keys)
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