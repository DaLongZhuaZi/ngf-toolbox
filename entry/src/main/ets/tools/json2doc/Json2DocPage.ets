/**
 * JSON 转接口文档工具页。
 *
 * ## 布局：JSON 输入 + Markdown 输出（可复制）+ 字段数
 *
 * @module tools/json2doc/Json2DocPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { toolStateStore } from '../../core/ToolStateStore';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { currentLocale } from '../../ui/LocaleSource';
import { ToolUiKit } from '../../ui/ToolUiKit';
import { Json2DocFailureCode, Json2DocResult, jsonToDoc } from './Json2DocLogic';
import { MOTION_FEEDBACK_MS } from '../../ui/Motion';
import { MOTION_DURATION_MS, MOTION_SLIDE_VP } from '../../ui/Motion';

const TOOL_ID: string = 'json2doc';
const DRAFT_DEBOUNCE_MS: number = 500;

@Builder
export function buildJson2DocPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildDocContent })
}

@Builder
function buildDocContent() {
  DocToolBody()
}

@Component
struct DocToolBody {
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private input: string = '';
  @State private result: Json2DocResult | null = null;
  @State private errorText: string = '';
  @State private copied: boolean = false;
  private draftTimer: number = -1;

  private onHistoryPick(): void {
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
    const r: Json2DocResult = jsonToDoc(this.input, currentLocale().toLowerCase().indexOf('en') === 0);
    if (r.ok) {
      this.errorText = '';
      this.result = r;
    } else {
      this.errorText = r.failure.code === Json2DocFailureCode.EMPTY_INPUT
        ? ToolUiKit.text($r('app.string.jd_err_empty'))
        : ToolUiKit.text($r('app.string.jd_err_bad'));
      this.result = null;
    }
    this.scheduleDraftSave();
  }

  build() {
    Column({ space: 16 }) {
      Column({ space: 10 }) {
        Text($r('app.string.jd_label_input'))
          .fontSize(scaled(12))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        TextArea({ text: this.input, placeholder: $r('app.string.jd_label_input') })
          .width('100%')
          .height(120)
          .fontSize(scaled(13))
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(12)
          .onChange((v: string) => {
            this.input = v;
            this.scheduleDraftSave();
          })
        Row({ space: 12 }) {
          Button($r('app.string.jd_action_build'))
            .layoutWeight(1)
            .onClick(() => {
              this.run();
              this.flushDraft();
            })
          Button($r('app.string.jd_action_clear'))
            .layoutWeight(1)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .controlSize(ControlSize.NORMAL)
            .onClick(() => {
              this.input = '';
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
        Column({ space: 8 }) {
          Row() {
            Text($r('app.string.jd_label_output'))
              .fontSize(scaled(12))
              .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
              .layoutWeight(1)
            Text(ToolUiKit.text($r('app.string.jd_label_count')) + ': ' + String(this.result.fieldCount))
              .fontSize(scaled(12))
              .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
            Text(this.copied ? $r('app.string.jd_copied') : $r('app.string.jd_action_copy'))
              .fontSize(scaled(12))
              .fontColor(colorOf(NGFColorToken.PRIMARY))
              .accessibilityText(ToolUiKit.text($r('app.string.copied_common')))
            .scale({ x: this.copied ? 1.08 : 1, y: this.copied ? 1.08 : 1 })
            .animation({ duration: MOTION_FEEDBACK_MS, curve: Curve.EaseOut })
              .margin({ left: 12 })
              .onClick(() => {
                ToolUiKit.copyText(this.result === null ? '' : this.result.markdown,
                  ToolUiKit.text($r('app.string.jd_copied')));
                this.copied = true;
                setTimeout((): void => {
                  this.copied = false;
                }, 1500);
              })
          }
          .width('100%')
          Text(this.result.markdown)
            .fontSize(scaled(12))
            .fontFamily('monospace')
            .fontColor(colorOf(NGFColorToken.ON_SURFACE))
            .width('100%')
            .constraintSize({ maxHeight: 260 })
            .copyOption(CopyOptions.LocalDevice)
        }
        .width('100%')
        .padding(12)
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(12)
        .alignItems(HorizontalAlign.Start)
        .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: MOTION_SLIDE_VP })))
        .animation({ duration: MOTION_DURATION_MS, curve: Curve.EaseOut })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}