/**
 * JSON 点路径取值工具页。
 *
 * ## 布局：JSON 输入 + 路径输入 + 结果（值 + 类型）
 *
 * @module tools/json-path/JsonPathPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { toolStateStore } from '../../core/ToolStateStore';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { ToolUiKit } from '../../ui/ToolUiKit';
import { queryJsonPath, JsonPathResult } from './JsonPath';
import { jsonPathFailureText } from './JsonPathMessages';
import { MOTION_FEEDBACK_MS } from '../../ui/Motion';
import { MOTION_DURATION_MS, MOTION_SLIDE_VP } from '../../ui/Motion';

const TOOL_ID: string = 'json-path';
const DRAFT_DEBOUNCE_MS: number = 500;

@Builder
export function buildJsonPathPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildJsonPathContent })
}

@Builder
function buildJsonPathContent() {
  JsonPathToolBody()
}

@Component
struct JsonPathToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private jsonText: string = '';
  @State private pathText: string = '';
  @State private result: JsonPathResult | null = null;
  @State private errorText: string = '';
  @State private copied: boolean = false;
  private draftTimer: number = -1;

  private onHistoryPick(): void {
  }

  aboutToAppear(): void {
    const saved: string = toolStateStore.readDraft(TOOL_ID);
    if (saved.length > 0) {
      this.jsonText = saved;
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
    toolStateStore.writeDraft(TOOL_ID, this.jsonText);
  }

  private run(): void {
    const r: JsonPathResult = queryJsonPath(this.jsonText, this.pathText);
    if (r.ok) {
      this.errorText = '';
      this.result = r;
    } else {
      this.errorText = jsonPathFailureText(r.failure);
      this.result = null;
    }
    this.scheduleDraftSave();
  }

  build() {
    Column({ space: 16 }) {
      Column({ space: 10 }) {
        Text($r('app.string.jp_label_json'))
          .fontSize(scaled(12))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        TextArea({ text: this.jsonText, placeholder: $r('app.string.jp_label_json') })
          .width('100%')
          .height(120)
          .fontSize(scaled(13))
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(12)
          .onChange((v: string) => {
            this.jsonText = v;
            this.scheduleDraftSave();
          })
        Text($r('app.string.jp_label_path'))
          .fontSize(scaled(12))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        TextInput({ text: this.pathText, placeholder: $r('app.string.jp_placeholder_path') })
          .width('100%')
          .fontSize(scaled(13))
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(10)
          .onChange((v: string) => {
            this.pathText = v;
            this.scheduleDraftSave();
          })
        Row({ space: 12 }) {
          Button($r('app.string.jp_action_query'))
            .layoutWeight(1)
            .onClick(() => {
              this.run();
              this.flushDraft();
            })
          Button($r('app.string.jp_action_clear'))
            .layoutWeight(1)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .controlSize(ControlSize.NORMAL)
            .onClick(() => {
              this.jsonText = '';
              this.pathText = '';
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
        Row({ space: 10 }) {
          Column({ space: 4 }) {
            Text($r('app.string.jp_label_type'))
              .fontSize(scaled(12))
              .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
            Text(this.result.type)
              .fontSize(scaled(14))
              .fontWeight(FontWeight.Medium)
              .fontColor(colorOf(NGFColorToken.PRIMARY))
          }
          .alignItems(HorizontalAlign.Start)
        .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: MOTION_SLIDE_VP })))
        .animation({ duration: MOTION_DURATION_MS, curve: Curve.EaseOut })
          Text(this.result.valueText)
            .fontSize(scaled(13))
            .fontColor(colorOf(NGFColorToken.ON_SURFACE))
            .layoutWeight(1)
            .constraintSize({ maxHeight: 200 })
            .copyOption(CopyOptions.LocalDevice)
          Text(this.copied ? $r('app.string.jp_copied') : $r('app.string.jp_action_copy'))
            .fontSize(scaled(12))
            .fontColor(colorOf(NGFColorToken.PRIMARY))
            .accessibilityText(ToolUiKit.text($r('app.string.copied_common')))
            .scale({ x: this.copied ? 1.08 : 1, y: this.copied ? 1.08 : 1 })
            .animation({ duration: MOTION_FEEDBACK_MS, curve: Curve.EaseOut })
            .onClick(() => {
              ToolUiKit.copyText(this.result === null ? '' : this.result.valueText,
                ToolUiKit.text($r('app.string.jp_copied')));
              this.copied = true;
              setTimeout((): void => {
                this.copied = false;
              }, 1500);
            })
        }
        .width('100%')
        .padding(12)
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(12)
        .alignItems(VerticalAlign.Top)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
