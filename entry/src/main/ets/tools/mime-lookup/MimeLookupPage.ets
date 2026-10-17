/**
 * MIME 类型速查工具页（与 http-status 同构：搜索 + 结果卡片列表）。
 *
 * @module tools/mime-lookup/MimeLookupPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { lookupMime, MimeEntry } from './MimeLookup';

@Builder
export function buildMimeLookupPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildMimeContent })
}

@Builder
function buildMimeContent() {
  MimeToolBody()
}

@Component
struct MimeToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private keyword: string = '';
  @State private entry: MimeEntry | null = null;
  @State private hasResult: boolean = true;

  private onHistoryPick(): void {
  }

  private updateQuery(v: string): void {
    this.keyword = v;
    const r = lookupMime(v);
    this.entry = r.entry;
    this.hasResult = r.found;
  }

  build() {
    Column({ space: 16 }) {
      Column({ space: 10 }) {
        TextInput({ text: this.keyword, placeholder: $r('app.string.ml_placeholder_search') })
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

      if (this.hasResult && this.entry !== null) {
        Row({ space: 10 }) {
          Text(this.entry.extension)
            .fontSize(scaled(16))
            .fontWeight(FontWeight.Bold)
            .fontColor(colorOf(NGFColorToken.PRIMARY))
          Text(this.entry.mime)
            .fontSize(scaled(14))
            .fontWeight(FontWeight.Medium)
            .fontColor(colorOf(NGFColorToken.ON_SURFACE))
            .layoutWeight(1)
            .copyOption(CopyOptions.LocalDevice)
        }
        .width('100%')
        .padding(14)
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(12)
        .alignItems(VerticalAlign.Center)
        .accessibilityText(this.entry.extension + ': ' + this.entry.mime)
      } else if (this.keyword.trim().length > 0) {
        Text($r('app.string.ml_not_found'))
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
          .width('100%')
          .padding(14)
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(12)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
