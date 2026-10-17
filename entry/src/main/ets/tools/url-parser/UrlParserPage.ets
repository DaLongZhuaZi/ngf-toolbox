/**
 * URL 解析器工具页。
 *
 * ## 布局：输入 + 七段结果行 + query 参数卡
 *
 * 与 ip-cidr 的速查表同构（标签+值+复制行）。
 *
 * @module tools/url-parser/UrlParserPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { toolStateStore } from '../../core/ToolStateStore';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { ToolUiKit } from '../../ui/ToolUiKit';
import { parseUrl, UrlParseResult, UrlParseFailureCode, UrlQueryPair } from './UrlParser';
import { MOTION_FEEDBACK_MS } from '../../ui/Motion';

const TOOL_ID: string = 'url-parser';
const DRAFT_DEBOUNCE_MS: number = 500;

@Builder
export function buildUrlParserPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildUrlParserContent })
}

@Builder
function buildUrlParserContent() {
  UrlParserToolBody()
}

@Component
struct UrlParserToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private input: string = '';
  @State private result: UrlParseResult | null = null;
  @State private errorText: string = '';
  @State private copied: string = '';
  private draftTimer: number = -1;

  private onHistoryPick(): void {
    const restored: string = toolStateStore.readDraft(TOOL_ID);
    if (restored.length === 0) {
      return;
    }
    this.input = restored;
    this.run();
  }

  aboutToAppear(): void {
    const saved: string = toolStateStore.readDraft(TOOL_ID);
    if (saved.length > 0) {
      this.input = saved;
      this.run();
    }
  }

  aboutToDisappear(): void {
    this.flushDraft();
  }

  private scheduleDraftSave(): void {
    if (this.draftTimer >= 0) {
      clearTimeout(this.draftTimer);
    }
    this.draftTimer = setTimeout((): void => {
      this.flushDraft();
    }, DRAFT_DEBOUNCE_MS);
  }

  private flushDraft(): void {
    if (this.draftTimer >= 0) {
      clearTimeout(this.draftTimer);
      this.draftTimer = -1;
    }
    toolStateStore.writeDraft(TOOL_ID, this.input);
  }

  private run(): void {
    const r: UrlParseResult = parseUrl(this.input);
    if (r.ok) {
      this.errorText = '';
      this.result = r;
    } else {
      this.errorText = r.failure.code === UrlParseFailureCode.EMPTY_INPUT ? '' :
        ToolUiKit.text($r('app.string.up_err_no_scheme')) + '';
      this.result = null;
      if (r.failure.code === UrlParseFailureCode.EMPTY_INPUT) {
        this.errorText = '';
      }
    }
    this.scheduleDraftSave();
  }

  private copyWith(label: string, value: string): void {
    ToolUiKit.copyText(value, ToolUiKit.text($r('app.string.up_copied')));
    this.copied = label;
    setTimeout((): void => {
      this.copied = '';
    }, 1500);
  }

  build() {
    Column({ space: 16 }) {
      Column({ space: 10 }) {
        TextInput({ text: this.input, placeholder: $r('app.string.up_placeholder_input') })
          .width('100%')
          .fontSize(scaled(13))
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(10)
          .onChange((v: string) => {
            this.input = v;
            const r: UrlParseResult = parseUrl(this.input);
            if (r.ok) {
              this.result = r;
              this.errorText = '';
            } else if (this.input.trim().length > 0) {
              this.result = null;
              this.errorText = ToolUiKit.text($r('app.string.up_err_no_scheme')) + '';
            } else {
              this.result = null;
              this.errorText = '';
            }
            this.scheduleDraftSave();
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      if (this.errorText.length > 0) {
        Text(this.errorText)
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.WARNING))
          .width('100%')
          .padding(10)
          .backgroundColor(colorOf(NGFColorToken.WARNING_CONTAINER))
          .borderRadius(10)
      }

      if (this.result !== null) {
        Column({ space: 8 }) {
          this.infoRow('scheme', this.result.scheme)
          if (this.result.userinfo.length > 0) {
            this.infoRow('userinfo', this.result.userinfo)
          }
          this.infoRow('host', this.result.host)
          this.infoRow('port', this.result.effectivePort)
          if (this.result.path.length > 0) {
            this.infoRow('path', this.result.path)
          }
          if (this.result.query.length > 0) {
            this.infoRow('query', this.result.query)
          }
          if (this.result.fragment.length > 0) {
            this.infoRow('fragment', this.result.fragment)
          }
        }
        .width('100%')
        .padding(12)
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(12)
        .alignItems(HorizontalAlign.Start)

        if (this.result.queryPairs.length > 0) {
          Column({ space: 6 }) {
            ForEach(this.result.queryPairs, (pair: UrlQueryPair, idx: number) => {
              Row({ space: 8 }) {
                Text(pair.key)
                  .fontSize(scaled(12))
                  .fontWeight(FontWeight.Medium)
                  .fontColor(colorOf(NGFColorToken.PRIMARY))
                Text(pair.value)
                  .fontSize(scaled(12))
                  .fontColor(colorOf(NGFColorToken.ON_SURFACE))
                  .layoutWeight(1)
                  .maxLines(2)
              }
              .width('100%')
              .padding(8)
              .backgroundColor(colorOf(NGFColorToken.SURFACE))
              .borderRadius(8)
              .alignItems(VerticalAlign.Center)
              .accessibilityText(pair.key + ': ' + pair.value)
            }, (pair: UrlQueryPair, idx: number) => idx + ':' + pair.rawKey)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private infoRow(label: string, value: string) {
    Row({ space: 10 }) {
      Text(label)
        .fontSize(scaled(12))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        .width(70)
      Text(value)
        .fontSize(scaled(13))
        .fontWeight(FontWeight.Medium)
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))
        .layoutWeight(1)
        .maxLines(2)
      Text(this.copied === label ? $r('app.string.up_copied') : $r('app.string.up_action_copy'))
        .fontSize(scaled(12))
        .fontColor(colorOf(NGFColorToken.PRIMARY))
          .scale({ x: this.copied !== '' ? 1.08 : 1, y: this.copied !== '' ? 1.08 : 1 })
          .animation({ duration: MOTION_FEEDBACK_MS, curve: Curve.EaseOut })
        .onClick(() => {
          this.copyWith(label, value);
        })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .accessibilityText(label + ': ' + value)
  }
}
