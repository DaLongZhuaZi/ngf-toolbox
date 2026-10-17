/**
 * HTTP 状态码速查工具页。
 *
 * ## 布局：搜索框 + 结果卡片列表（码 + 名 + 含义 + 原因）
 *
 * 边输入边查（onChange 直接 queryStatus），结果为空显示空态。
 *
 * @module tools/http-status/HttpStatusPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { currentLocale } from '../../ui/LocaleSource';
import { ToolUiKit } from '../../ui/ToolUiKit';
import { HttpStatusEntry, queryStatus } from './HttpStatus';
import { httpStatusEmptyText } from './HttpStatusMessages';

const TOOL_ID: string = 'http-status';

@Builder
export function buildHttpStatusPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildHttpStatusContent })
}

@Builder
function buildHttpStatusContent() {
  HttpStatusToolBody()
}

@Component
struct HttpStatusToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  private locale: string = currentLocale();
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private keyword: string = '';
  @State private entries: Array<HttpStatusEntry> = queryStatus('').entries;

  private onHistoryPick(): void {
  }

  private updateQuery(v: string): void {
    this.keyword = v;
    const r = queryStatus(v);
    this.entries = r.entries;
  }

  build() {
    Column({ space: 16 }) {
      this.buildSearchSection()
      if (this.entries.length === 0) {
        Text(httpStatusEmptyText())
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
          .width('100%')
          .padding(14)
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(12)
      } else {
        ForEach(this.entries, (e: HttpStatusEntry) => {
          Column({ space: 4 }) {
            Row({ space: 8 }) {
              Text(String(e.code))
                .fontSize(scaled(16))
                .fontWeight(FontWeight.Bold)
                .fontColor(colorOf(NGFColorToken.PRIMARY))
              Text(e.name)
                .fontSize(scaled(13))
                .fontWeight(FontWeight.Medium)
                .fontColor(colorOf(NGFColorToken.ON_SURFACE))
                .layoutWeight(1)
            }
            .width('100%')
            Text(e.meaning.forLocale(this.locale))
              .fontSize(scaled(13))
              .fontColor(colorOf(NGFColorToken.ON_SURFACE))
            Text(e.cause.forLocale(this.locale))
              .fontSize(scaled(12))
              .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
          }
          .width('100%')
          .padding(12)
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(12)
          .alignItems(HorizontalAlign.Start)
          .accessibilityText(String(e.code) + ' ' + e.name + ' ' + e.meaning.forLocale(this.locale))
        }, (e: HttpStatusEntry) => String(e.code))
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildSearchSection() {
    Column({ space: 10 }) {
      Row() {
        Text($r('app.string.hs_label_search'))
          .fontSize(scaled(14))
          .fontWeight(FontWeight.Medium)
          .fontColor(colorOf(NGFColorToken.ON_SURFACE))
          .layoutWeight(1)
        Text($r('app.string.hs_action_clear'))
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.PRIMARY))
          .accessibilityText(ToolUiKit.text($r('app.string.hs_action_clear')))
          .onClick(() => {
            this.updateQuery('');
          })
      }
      .width('100%')
      TextInput({ text: this.keyword, placeholder: $r('app.string.hs_placeholder_search') })
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
  }
}
