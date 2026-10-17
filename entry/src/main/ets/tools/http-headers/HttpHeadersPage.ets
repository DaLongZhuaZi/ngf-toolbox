/**
 * HTTP 头速查工具页（与 http-status 同构）。
 *
 * ## 布局：搜索框 + 方向过滤胶囊 + 结果卡片（头名 + 方向 + 含义 + 示例）
 *
 * @module tools/http-headers/HttpHeadersPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { currentLocale } from '../../ui/LocaleSource';
import { ToolUiKit } from '../../ui/ToolUiKit';
import { HttpHeaderDirection, HttpHeaderEntry, queryHeaders } from './HttpHeaders';

@Builder
export function buildHttpHeadersPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildHeadersContent })
}

@Builder
function buildHeadersContent() {
  HeadersToolBody()
}

@Component
struct HeadersToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  private locale: string = currentLocale();
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private keyword: string = '';
  @State private directionFilter: HttpHeaderDirection | null = null;
  @State private entries: Array<HttpHeaderEntry> = queryHeaders('', null).entries;

  private onHistoryPick(): void {
  }

  private updateQuery(v: string): void {
    this.keyword = v;
    this.entries = queryHeaders(v, this.directionFilter).entries;
  }

  private updateDirection(d: HttpHeaderDirection | null): void {
    this.directionFilter = d;
    this.entries = queryHeaders(this.keyword, d).entries;
  }

  private directionText(d: HttpHeaderDirection): string {
    if (d === HttpHeaderDirection.REQUEST) {
      return ToolUiKit.text($r('app.string.hh_dir_request'));
    }
    if (d === HttpHeaderDirection.RESPONSE) {
      return ToolUiKit.text($r('app.string.hh_dir_response'));
    }
    return ToolUiKit.text($r('app.string.hh_dir_both'));
  }

  build() {
    Column({ space: 16 }) {
      Column({ space: 10 }) {
        TextInput({ text: this.keyword, placeholder: $r('app.string.hh_placeholder_search') })
          .width('100%')
          .fontSize(scaled(13))
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(10)
          .onChange((v: string) => {
            this.updateQuery(v);
          })
        Flex({ wrap: FlexWrap.Wrap }) {
          this.chip($r('app.string.hh_dir_all'), null as HttpHeaderDirection | null)
          this.chip($r('app.string.hh_dir_request'), HttpHeaderDirection.REQUEST)
          this.chip($r('app.string.hh_dir_response'), HttpHeaderDirection.RESPONSE)
          this.chip($r('app.string.hh_dir_both'), HttpHeaderDirection.BOTH)
        }
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      if (this.entries.length === 0) {
        Text($r('app.string.hh_empty'))
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
          .width('100%')
          .padding(14)
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(12)
      } else {
        ForEach(this.entries, (e: HttpHeaderEntry) => {
          Column({ space: 4 }) {
            Row({ space: 8 }) {
              Text(e.name)
                .fontSize(scaled(13))
                .fontWeight(FontWeight.Medium)
                .fontColor(colorOf(NGFColorToken.PRIMARY))
                .layoutWeight(1)
              Text(this.directionText(e.direction))
                .fontSize(scaled(11))
                .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
            }
            .width('100%')
            Text(e.meaning.forLocale(this.locale))
              .fontSize(scaled(13))
              .fontColor(colorOf(NGFColorToken.ON_SURFACE))
            Text(e.example)
              .fontSize(scaled(11))
              .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
              .maxLines(2)
          }
          .width('100%')
          .padding(12)
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(12)
          .alignItems(HorizontalAlign.Start)
          .accessibilityText(e.name + ' ' + e.meaning.forLocale(this.locale))
        }, (e: HttpHeaderEntry) => e.name)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private chip(label: ResourceStr, d: HttpHeaderDirection | null) {
    Text(label)
      .fontSize(scaled(12))
      .fontColor(this.directionFilter === d ? colorOf(NGFColorToken.ON_PRIMARY) : colorOf(NGFColorToken.ON_SURFACE))
      .backgroundColor(this.directionFilter === d ? colorOf(NGFColorToken.PRIMARY) : colorOf(NGFColorToken.SURFACE))
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .borderRadius(16)
      .margin(2)
      .onClick(() => {
        this.updateDirection(d);
      })
      .accessibilityText(ToolUiKit.text(label))
  }
}
