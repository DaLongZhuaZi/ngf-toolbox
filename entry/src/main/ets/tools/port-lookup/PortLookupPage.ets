/**
 * 端口速查工具页（与 http-status 同构：搜索 + 结果卡片列表）。
 *
 * @module tools/port-lookup/PortLookupPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { currentLocale } from '../../ui/LocaleSource';
import { PortEntry, queryPorts } from './PortLookup';

@Builder
export function buildPortLookupPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildPortContent })
}

@Builder
function buildPortContent() {
  PortToolBody()
}

@Component
struct PortToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  private locale: string = currentLocale();
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private keyword: string = '';
  @State private entries: Array<PortEntry> = queryPorts('').entries;

  private onHistoryPick(): void {
  }

  private updateQuery(v: string): void {
    this.keyword = v;
    this.entries = queryPorts(v).entries;
  }

  build() {
    Column({ space: 16 }) {
      Column({ space: 10 }) {
        TextInput({ text: this.keyword, placeholder: $r('app.string.pl_placeholder_search') })
          .width('100%')
          .fontSize(scaled(13))
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(10)
          .onChange((v: string) => {
            this.updateQuery(v);
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      if (this.entries.length === 0) {
        Text($r('app.string.pl_empty'))
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
          .width('100%')
          .padding(14)
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(12)
      } else {
        ForEach(this.entries, (e: PortEntry) => {
          Row({ space: 10 }) {
            Text(String(e.port))
              .fontSize(scaled(16))
              .fontWeight(FontWeight.Bold)
              .fontColor(colorOf(NGFColorToken.PRIMARY))
              .width(70)
            Column({ space: 2 }) {
              Text(e.name.forLocale(this.locale))
                .fontSize(scaled(13))
                .fontWeight(FontWeight.Medium)
                .fontColor(colorOf(NGFColorToken.ON_SURFACE))
              Text(e.meaning.forLocale(this.locale))
                .fontSize(scaled(12))
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
          .accessibilityText(String(e.port) + ' ' + e.name.forLocale(this.locale) + ' ' + e.meaning.forLocale(this.locale))
        }, (e: PortEntry) => String(e.port))
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
