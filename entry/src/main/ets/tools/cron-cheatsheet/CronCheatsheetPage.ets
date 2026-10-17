/**
 * Cron 速查工具页（git-cheatsheet 同构）。
 *
 * @module tools/cron-cheatsheet/CronCheatsheetPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { currentLocale } from '../../ui/LocaleSource';
import { ToolUiKit } from '../../ui/ToolUiKit';
import { allCronEntries, CronEntry, cronCategories, queryCron } from './CronCheatsheetLogic';

@Builder
export function buildCronCheatsheetPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildCronContent })
}

@Builder
function buildCronContent() {
  CronToolBody()
}

@Component
struct CronToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  private locale: string = currentLocale();
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private keyword: string = '';
  @State private categoryFilter: string | null = null;
  @State private entries: Array<CronEntry> = queryCron('', null).entries;

  private onHistoryPick(): void {
  }

  private updateQuery(v: string): void {
    this.keyword = v;
    this.entries = queryCron(v, this.categoryFilter).entries;
  }

  private updateCategory(c: string | null): void {
    this.categoryFilter = c;
    this.entries = queryCron(this.keyword, c).entries;
  }

  private categoryLabelOf(cat: string): string {
    if (cat === 'minute') { return ToolUiKit.text($r('app.string.cc_cat_minute')); }
    if (cat === 'hour') { return ToolUiKit.text($r('app.string.cc_cat_hour')); }
    if (cat === 'day') { return ToolUiKit.text($r('app.string.cc_cat_day')); }
    if (cat === 'week') { return ToolUiKit.text($r('app.string.cc_cat_week')); }
    if (cat === 'month') { return ToolUiKit.text($r('app.string.cc_cat_month')); }
    if (cat === 'year') { return ToolUiKit.text($r('app.string.cc_cat_year')); }
    return ToolUiKit.text($r('app.string.cc_cat_special'));
  }

  build() {
    Column({ space: 16 }) {
      Column({ space: 10 }) {
        TextInput({ text: this.keyword, placeholder: $r('app.string.cc_placeholder_search') })
          .width('100%')
          .fontSize(scaled(13))
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(10)
          .onChange((v: string) => {
            this.updateQuery(v);
          })
        Flex({ wrap: FlexWrap.Wrap }) {
          this.chip($r('app.string.cc_label_all'), null)
          ForEach(cronCategories(), (cat: string) => {
            this.chip(this.categoryLabelOf(cat), cat)
          }, (cat: string) => cat)
        }
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      if (this.entries.length === 0) {
        Text($r('app.string.cc_empty'))
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
          .width('100%')
          .padding(14)
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(12)
      } else {
        ForEach(this.entries, (e: CronEntry) => {
          Column({ space: 4 }) {
            Row({ space: 8 }) {
              Text(e.expr)
                .fontSize(scaled(13))
                .fontFamily('monospace')
                .fontWeight(FontWeight.Medium)
                .fontColor(colorOf(NGFColorToken.PRIMARY))
                .layoutWeight(1)
              Text(this.categoryLabelOf(e.category))
                .fontSize(scaled(11))
                .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
            }
            .width('100%')
            Text(e.meaning.forLocale(this.locale))
              .fontSize(scaled(13))
              .fontColor(colorOf(NGFColorToken.ON_SURFACE))
          }
          .width('100%')
          .padding(12)
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(12)
          .alignItems(HorizontalAlign.Start)
          .accessibilityText(e.expr + ' ' + e.meaning.forLocale(this.locale))
        }, (e: CronEntry) => e.category + ':' + e.expr)
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