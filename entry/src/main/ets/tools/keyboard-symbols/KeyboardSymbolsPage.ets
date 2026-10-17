/**
 * 键盘符号速查工具页（本地表同构）。
 *
 * @module tools/keyboard-symbols/KeyboardSymbolsPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { currentLocale } from '../../ui/LocaleSource';
import { allKeySymbols, KeySymbolEntry, queryKeySymbols } from './KeyboardSymbolsLogic';

@Builder
export function buildKeyboardSymbolsPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildKeySymbolContent })
}

@Builder
function buildKeySymbolContent() {
  KeySymbolToolBody()
}

@Component
struct KeySymbolToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  private locale: string = currentLocale();
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private keyword: string = '';
  @State private entries: Array<KeySymbolEntry> = queryKeySymbols('').entries;

  private onHistoryPick(): void {
  }

  private updateQuery(v: string): void {
    this.keyword = v;
    this.entries = queryKeySymbols(v).entries;
  }

  build() {
    Column({ space: 16 }) {
      TextInput({ text: this.keyword, placeholder: $r('app.string.kbs_placeholder_search') })
        .width('100%')
        .fontSize(scaled(13))
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(10)
        .onChange((v: string) => {
          this.updateQuery(v);
        })

      if (this.entries.length === 0) {
        Text($r('app.string.kbs_empty'))
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
          .width('100%')
          .padding(14)
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(12)
      } else {
        ForEach(this.entries, (e: KeySymbolEntry) => {
          Row({ space: 12 }) {
            Text(e.symbol)
              .fontSize(scaled(20))
              .fontColor(colorOf(NGFColorToken.PRIMARY))
              .width(44)
            Column({ space: 2 }) {
              Text(e.name + ' / ' + e.nameZh.forLocale(this.locale))
                .fontSize(scaled(13))
                .fontColor(colorOf(NGFColorToken.ON_SURFACE))
              Text(e.winEquivalent.forLocale(this.locale))
                .fontSize(scaled(11))
                .fontFamily('monospace')
                .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .padding(12)
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(12)
          .alignItems(VerticalAlign.Center)
          .accessibilityText(e.name + ' ' + e.nameZh.forLocale(this.locale))
        }, (e: KeySymbolEntry) => e.symbol)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
