/**
 * HTTP 命令生成工具页。
 *
 * ## 布局：method/URL/头/体 + 双输出（cURL 与 HTTPie）
 *
 * @module tools/curl-builder/CurlBuilderPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { toolStateStore } from '../../core/ToolStateStore';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { ToolUiKit } from '../../ui/ToolUiKit';
import { buildHttpCommand, CurlFailureCode, CurlResult } from './CurlLogic';
import { MOTION_FEEDBACK_MS } from '../../ui/Motion';
import { MOTION_DURATION_MS, MOTION_SLIDE_VP } from '../../ui/Motion';

const TOOL_ID: string = 'curl-builder';
const DRAFT_DEBOUNCE_MS: number = 500;

@Builder
export function buildCurlBuilderPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildCurlContent })
}

@Builder
function buildCurlContent() {
  CurlToolBody()
}

@Component
struct CurlToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private method: string = 'GET';
  @State private url: string = '';
  @State private headers: string = '';
  @State private body: string = '';
  @State private result: CurlResult | null = null;
  @State private errorText: string = '';
  @State private copied: string = '';
  private draftTimer: number = -1;

  private onHistoryPick(): void {
  }

  aboutToAppear(): void {
    const saved: string = toolStateStore.readDraft(TOOL_ID);
    if (saved.length > 0) {
      this.url = saved;
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
    toolStateStore.writeDraft(TOOL_ID, this.url);
  }

  private run(): void {
    const r: CurlResult = buildHttpCommand(this.method, this.url, this.headers, this.body);
    if (r.ok) {
      this.errorText = '';
      this.result = r;
    } else {
      this.result = null;
      this.errorText = r.failure.code === CurlFailureCode.EMPTY_URL
        ? ToolUiKit.text($r('app.string.cb_err_url'))
        : ToolUiKit.text($r('app.string.cb_err_header'));
    }
    this.scheduleDraftSave();
  }

  private copyWith(label: string, value: string): void {
    ToolUiKit.copyText(value, ToolUiKit.text($r('app.string.cb_copied')));
    this.copied = label;
    setTimeout((): void => {
      this.copied = '';
    }, 1500);
  }

  build() {
    Column({ space: 16 }) {
      Column({ space: 10 }) {
        Flex({ wrap: FlexWrap.Wrap }) {
          this.chip('GET', 'GET')
          this.chip('POST', 'POST')
          this.chip('PUT', 'PUT')
          this.chip('DELETE', 'DELETE')
          this.chip('PATCH', 'PATCH')
        }
        .width('100%')
        TextInput({ text: this.url, placeholder: $r('app.string.cb_label_url') })
          .width('100%')
          .fontSize(scaled(13))
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(10)
          .onChange((v: string) => {
            this.url = v;
            this.scheduleDraftSave();
          })
        TextInput({ text: this.headers, placeholder: $r('app.string.cb_label_headers') })
          .width('100%')
          .fontSize(scaled(13))
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(10)
          .onChange((v: string) => {
            this.headers = v;
            this.scheduleDraftSave();
          })
        TextArea({ text: this.body, placeholder: $r('app.string.cb_label_body') })
          .width('100%')
          .height(80)
          .fontSize(scaled(13))
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(12)
          .onChange((v: string) => {
            this.body = v;
            this.scheduleDraftSave();
          })
        Row({ space: 12 }) {
          Button($r('app.string.cb_action_build'))
            .layoutWeight(1)
            .onClick(() => {
              this.run();
              this.flushDraft();
            })
          Button($r('app.string.cb_action_clear'))
            .layoutWeight(1)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .controlSize(ControlSize.NORMAL)
            .onClick(() => {
              this.url = '';
              this.headers = '';
              this.body = '';
              this.result = null;
              this.errorText = '';
              this.flushDraft();
            })
        }
        .width('100%')
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
        this.commandCard($r('app.string.cb_label_curl'), 'curl', this.result.curl)
        this.commandCard($r('app.string.cb_label_httpie'), 'httpie', this.result.httpie)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
        .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: MOTION_SLIDE_VP })))
        .animation({ duration: MOTION_DURATION_MS, curve: Curve.EaseOut })
  }

  @Builder
  private commandCard(label: ResourceStr, key: string, value: string) {
    Column({ space: 6 }) {
      Row() {
        Text(label)
          .fontSize(scaled(12))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
          .layoutWeight(1)
        Text(this.copied === key ? $r('app.string.cb_copied') : $r('app.string.cb_action_copy'))
          .fontSize(scaled(12))
          .fontColor(colorOf(NGFColorToken.PRIMARY))
          .accessibilityText(ToolUiKit.text($r('app.string.cb_copied')))
          .scale({ x: this.copied !== '' ? 1.08 : 1, y: this.copied !== '' ? 1.08 : 1 })
          .animation({ duration: MOTION_FEEDBACK_MS, curve: Curve.EaseOut })
          .onClick(() => {
            this.copyWith(key, value);
          })
      }
      .width('100%')
      Text(value)
        .fontSize(scaled(12))
        .fontFamily('monospace')
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))
        .width('100%')
        .copyOption(CopyOptions.LocalDevice)
    }
    .width('100%')
    .padding(12)
    .backgroundColor(colorOf(NGFColorToken.SURFACE))
    .borderRadius(12)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private chip(label: string, value: string) {
    Text(label)
      .fontSize(scaled(12))
      .fontColor(this.method === value ? colorOf(NGFColorToken.ON_PRIMARY) : colorOf(NGFColorToken.ON_SURFACE))
      .backgroundColor(this.method === value ? colorOf(NGFColorToken.PRIMARY) : colorOf(NGFColorToken.SURFACE))
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .borderRadius(16)
      .margin(2)
      .onClick(() => {
        this.method = value;
      })
      .accessibilityText(label)
  }
}