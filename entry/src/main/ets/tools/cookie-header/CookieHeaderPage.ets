/**
 * Cookie 头解析工具页。
 *
 * ## 布局：两个分区（请求侧键值对 / 响应侧属性表）
 *
 * @module tools/cookie-header/CookieHeaderPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { CookiePair, parseCookieHeader, parseSetCookie, SetCookieResult } from './CookieHeaderLogic';
import { ToolUiKit } from '../../ui/ToolUiKit';

@Builder
export function buildCookieHeaderPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildCookieContent })
}

@Builder
function buildCookieContent() {
  CookieToolBody()
}

@Component
struct CookieToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private reqText: string = '';
  @State private pairs: Array<CookiePair> = [];
  @State private resText: string = '';
  @State private setResult: SetCookieResult | null = null;
  @State private errorText: string = '';

  private onHistoryPick(): void {
  }

  private parseReq(v: string): void {
    this.reqText = v;
    const r = parseCookieHeader(v);
    if (r.ok) {
      this.pairs = r.pairs;
    } else {
      this.pairs = [];
    }
  }

  private parseRes(v: string): void {
    this.resText = v;
    const r = parseSetCookie(v);
    if (r.ok) {
      this.setResult = r;
    } else {
      this.setResult = null;
    }
  }

  build() {
    Column({ space: 16 }) {
      Column({ space: 10 }) {
        Text($r('app.string.ck_label_request'))
          .fontSize(scaled(13))
          .fontWeight(FontWeight.Medium)
          .fontColor(colorOf(NGFColorToken.ON_SURFACE))
        TextArea({ text: this.reqText, placeholder: $r('app.string.ck_label_request') })
          .width('100%')
          .height(64)
          .fontSize(scaled(12))
          .fontFamily('monospace')
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(10)
          .onChange((v: string) => {
            this.parseReq(v);
          })
        if (this.pairs.length > 0) {
          ForEach(this.pairs, (p: CookiePair) => {
            Row({ space: 8 }) {
              Text(p.name)
                .fontSize(scaled(12))
                .fontFamily('monospace')
                .fontColor(colorOf(NGFColorToken.PRIMARY))
              Text(p.value)
                .fontSize(scaled(12))
                .fontFamily('monospace')
                .fontColor(colorOf(NGFColorToken.ON_SURFACE))
                .layoutWeight(1)
              Text($r('app.string.ck_label_pairs'))
                .fontSize(scaled(10))
                .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
            }
            .width('100%')
            .padding(8)
            .backgroundColor(colorOf(NGFColorToken.SURFACE))
            .borderRadius(8)
            .accessibilityText(p.name)
          }, (p: CookiePair) => p.name)
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Column({ space: 10 }) {
        Text($r('app.string.ck_label_setcookie'))
          .fontSize(scaled(13))
          .fontWeight(FontWeight.Medium)
          .fontColor(colorOf(NGFColorToken.ON_SURFACE))
        TextArea({ text: this.resText, placeholder: $r('app.string.ck_label_setcookie') })
          .width('100%')
          .height(64)
          .fontSize(scaled(12))
          .fontFamily('monospace')
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(10)
          .onChange((v: string) => {
            this.parseRes(v);
          })
        if (this.setResult !== null) {
          Column({ space: 4 }) {
            Text(this.setResult.name + ' = ' + this.setResult.value)
              .fontSize(scaled(13))
              .fontFamily('monospace')
              .fontColor(colorOf(NGFColorToken.PRIMARY))
            Text(ToolUiKit.text($r('app.string.ck_label_attrs')) + ': ' + Array.from(this.setResult.attrs.keys()).join(', '))
              .fontSize(scaled(11))
              .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
          }
          .width('100%')
          .padding(10)
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(10)
          .alignItems(HorizontalAlign.Start)
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      if (this.errorText.length > 0) {
        Text($r('app.string.ck_err_empty'))
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.WARNING))
          .width('100%')
          .padding(10)
          .backgroundColor(colorOf(NGFColorToken.WARNING_CONTAINER))
          .borderRadius(10)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
