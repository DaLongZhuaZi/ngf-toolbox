/**
 * HTTP 方法速查工具页（http-status 同构）。
 *
 * @module tools/http-method/HttpMethodPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { ToolUiKit } from '../../ui/ToolUiKit';
import { currentLocale } from '../../ui/LocaleSource';
import { HttpMethodEntry, queryMethods } from './HttpMethodLogic';

@Builder
export function buildHttpMethodPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildMethodContent })
}

@Builder
function buildMethodContent() {
  MethodToolBody()
}

@Component
struct MethodToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  private locale: string = currentLocale();
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private keyword: string = '';
  @State private entries: Array<HttpMethodEntry> = queryMethods('').entries;

  private onHistoryPick(): void {
  }

  private updateQuery(v: string): void {
    this.keyword = v;
    this.entries = queryMethods(v).entries;
  }

  build() {
    Column({ space: 16 }) {
      TextInput({ text: this.keyword, placeholder: $r('app.string.hm_placeholder_search') })
        .width('100%')
        .fontSize(scaled(13))
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(10)
        .onChange((v: string) => {
          this.updateQuery(v);
        })

      if (this.entries.length === 0) {
        Text($r('app.string.hm_empty'))
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
          .width('100%')
          .padding(14)
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(12)
      } else {
        ForEach(this.entries, (e: HttpMethodEntry) => {
          Column({ space: 4 }) {
            Row({ space: 8 }) {
              Text(e.method)
                .fontSize(scaled(15))
                .fontWeight(FontWeight.Bold)
                .fontColor(colorOf(NGFColorToken.PRIMARY))
                .layoutWeight(1)
              Text(e.idempotent ? $r('app.string.hm_label_idempotent') : $r('app.string.hm_label_not_idempotent'))
                .fontSize(scaled(11))
                .fontColor(e.idempotent ? colorOf(NGFColorToken.SUCCESS) : colorOf(NGFColorToken.WARNING))
            }
            .width('100%')
            Text(e.meaning.forLocale(this.locale))
              .fontSize(scaled(13))
              .fontColor(colorOf(NGFColorToken.ON_SURFACE))
            Text(ToolUiKit.text($r('app.string.hm_label_status')) + ': ' + e.commonStatus)
              .fontSize(scaled(11))
              .fontFamily('monospace')
              .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
          }
          .width('100%')
          .padding(12)
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(12)
          .alignItems(HorizontalAlign.Start)
          .accessibilityText(e.method + ' ' + e.meaning.forLocale(this.locale))
        }, (e: HttpMethodEntry) => e.method)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}