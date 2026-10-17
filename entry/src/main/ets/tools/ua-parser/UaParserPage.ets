/**
 * UA 解析工具页。
 *
 * ## 布局：输入 + 三维结果卡（浏览器/引擎/OS）
 *
 * @module tools/ua-parser/UaParserPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { toolStateStore } from '../../core/ToolStateStore';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { ToolUiKit } from '../../ui/ToolUiKit';
import { parseUserAgent, UaParseResult } from './UaParser';

const TOOL_ID: string = 'ua-parser';
const DRAFT_DEBOUNCE_MS: number = 500;

@Builder
export function buildUaParserPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildUaContent })
}

@Builder
function buildUaContent() {
  UaToolBody()
}

@Component
struct UaToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private input: string = '';
  @State private result: UaParseResult | null = null;
  private draftTimer: number = -1;

  private onHistoryPick(): void {
  }

  aboutToAppear(): void {
    const saved: string = toolStateStore.readDraft(TOOL_ID);
    if (saved.length > 0) {
      this.input = saved;
      this.result = parseUserAgent(saved);
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

  private reparse(): void {
    this.result = parseUserAgent(this.input);
    this.scheduleDraftSave();
  }

  private clearAll(): void {
    this.input = '';
    this.result = null;
    this.flushDraft();
  }

  build() {
    Column({ space: 16 }) {
      Column({ space: 10 }) {
        TextInput({ text: this.input, placeholder: $r('app.string.uap_placeholder_input') })
          .width('100%')
          .fontSize(scaled(13))
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(10)
          .onChange((v: string) => {
            this.input = v;
            this.reparse();
          })
        Row({ space: 12 }) {
          Button($r('app.string.uap_action_clear'))
            .layoutWeight(1)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .controlSize(ControlSize.NORMAL)
            .onClick(() => {
              this.clearAll();
            })
        }
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      if (this.result !== null) {
        this.valueCard($r('app.string.uap_label_browser'), this.result.browser)
        this.valueCard($r('app.string.uap_label_engine'), this.result.engine)
        this.valueCard($r('app.string.uap_label_os'), this.result.os)
        if (this.result.partial) {
          Text($r('app.string.uap_hint_partial'))
            .fontSize(scaled(12))
            .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        }
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private valueCard(label: ResourceStr, value: string) {
    Row({ space: 10 }) {
      Text(label)
        .fontSize(scaled(12))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        .width(70)
      Text(value)
        .fontSize(scaled(15))
        .fontWeight(FontWeight.Medium)
        .fontColor(value === 'unknown' ? colorOf(NGFColorToken.ON_SURFACE_VARIANT)
          : colorOf(NGFColorToken.ON_SURFACE))
        .layoutWeight(1)
    }
    .width('100%')
    .padding(12)
    .backgroundColor(colorOf(NGFColorToken.SURFACE))
    .borderRadius(12)
    .alignItems(VerticalAlign.Center)
    .accessibilityText(ToolUiKit.text(label) + ': ' + value)
  }
}
