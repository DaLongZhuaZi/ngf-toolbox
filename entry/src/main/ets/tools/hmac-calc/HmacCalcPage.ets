/**
 * HMAC 计算工具页。
 *
 * ## 布局：算法胶囊单选 + 消息/密钥两个输入 + 结果
 *
 * 密钥输入用 TextField 而非密码框——开发者要看清楚自己粘的是什么；
 * 页脚明确「不会存储或上报」。三段节奏与现有工具一致。
 *
 * @module tools/hmac-calc/HmacCalcPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { toolStateStore } from '../../core/ToolStateStore';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { ToolUiKit } from '../../ui/ToolUiKit';
import { computeHmac, HmacAlgorithm, HmacResult } from './HmacCalc';
import { hmacFailureText } from './HmacCalcMessages';
import { MOTION_FEEDBACK_MS } from '../../ui/Motion';
import { MOTION_DURATION_MS, MOTION_SLIDE_VP } from '../../ui/Motion';

const TOOL_ID: string = 'hmac-calc';
const MSG_DRAFT: string = TOOL_ID + '.msg';
const KEY_DRAFT: string = TOOL_ID + '.key';

@Builder
export function buildHmacCalcPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildHmacContent })
}

@Builder
function buildHmacContent() {
  HmacToolBody()
}

@Component
struct HmacToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private algorithm: HmacAlgorithm = HmacAlgorithm.SHA256;
  @State private message: string = '';
  @State private keyText: string = '';
  @State private result: HmacResult | null = null;
  @State private errorText: string = '';
  @State private copied: boolean = false;

  private onHistoryPick(): void {
    // 结构化输入不适用历史回填，保留钩子
  }

  aboutToAppear(): void {
    const m: string = toolStateStore.readDraft(MSG_DRAFT);
    const k: string = toolStateStore.readDraft(KEY_DRAFT);
    if (m.length > 0) {
      this.message = m;
    }
    if (k.length > 0) {
      this.keyText = k;
    }
  }

  aboutToDisappear(): void {
    toolStateStore.writeDraft(MSG_DRAFT, this.message);
    toolStateStore.writeDraft(KEY_DRAFT, this.keyText);
  }

  private run(): void {
    const r: HmacResult = computeHmac(this.algorithm, this.message, this.keyText);
    if (r.ok) {
      this.errorText = '';
      this.result = r;
    } else {
      this.errorText = hmacFailureText(r.failure);
      this.result = null;
    }
  }

  private clearAll(): void {
    this.message = '';
    this.keyText = '';
    this.result = null;
    this.errorText = '';
    toolStateStore.writeDraft(MSG_DRAFT, '');
    toolStateStore.writeDraft(KEY_DRAFT, '');
  }

  build() {
    Column({ space: 16 }) {
      this.buildConfigSection()
      if (this.errorText.length > 0) {
        Text(this.errorText)
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.WARNING))
          .width('100%')
          .padding(10)
          .backgroundColor(colorOf(NGFColorToken.WARNING_CONTAINER))
          .borderRadius(10)
      }
      if (this.result !== null && this.result.ok) {
        this.buildResultSection()
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildConfigSection() {
    Column({ space: 10 }) {
      Column({ space: 6 }) {
        Text($r('app.string.hmac_label_algorithm'))
          .fontSize(scaled(12))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        Row({ space: 8 }) {
          this.chip('MD5', HmacAlgorithm.MD5)
          this.chip('SHA-1', HmacAlgorithm.SHA1)
          this.chip('SHA-256', HmacAlgorithm.SHA256)
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Column({ space: 4 }) {
        Text($r('app.string.hmac_label_message'))
          .fontSize(scaled(12))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        TextArea({ text: this.message, placeholder: $r('app.string.hmac_placeholder_message') })
          .width('100%')
          .height(90)
          .fontSize(scaled(13))
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(12)
          .onChange((v: string) => {
            this.message = v;
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Column({ space: 4 }) {
        Text($r('app.string.hmac_label_key'))
          .fontSize(scaled(12))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        TextInput({ text: this.keyText, placeholder: $r('app.string.hmac_placeholder_key') })
          .width('100%')
          .fontSize(scaled(13))
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(10)
          .onChange((v: string) => {
            this.keyText = v;
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Row({ space: 12 }) {
        Button($r('app.string.hmac_action_compute'))
          .layoutWeight(1)
          .onClick(() => {
            this.run();
          })
        Button($r('app.string.hmac_action_clear'))
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
  }

  @Builder
  private chip(label: string, mode: HmacAlgorithm) {
    Text(label)
      .fontSize(scaled(12))
      .fontColor(this.algorithm === mode ? colorOf(NGFColorToken.ON_PRIMARY) : colorOf(NGFColorToken.ON_SURFACE))
      .backgroundColor(this.algorithm === mode ? colorOf(NGFColorToken.PRIMARY) : colorOf(NGFColorToken.SURFACE))
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .borderRadius(16)
      .onClick(() => {
        this.algorithm = mode;
      })
      .accessibilityText(label)
  }

  @Builder
  private buildResultSection() {
    Column({ space: 6 }) {
      Row() {
        Text($r('app.string.hmac_label_result'))
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE))
          .layoutWeight(1)
        Text(this.copied ? $r('app.string.hmac_copied') : $r('app.string.hmac_action_copy'))
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.PRIMARY))
          .accessibilityText(ToolUiKit.text($r('app.string.copied_common')))
            .scale({ x: this.copied ? 1.08 : 1, y: this.copied ? 1.08 : 1 })
            .animation({ duration: MOTION_FEEDBACK_MS, curve: Curve.EaseOut })
          .onClick(() => {
            if (this.result !== null) {
              ToolUiKit.copyText(this.result.hex, ToolUiKit.text($r('app.string.hmac_copied')));
              this.copied = true;
              setTimeout((): void => {
                this.copied = false;
              }, 1500);
            }
          })
      }
      .width('100%')
      Text(this.result === null ? '' : this.result.hex)
        .fontSize(scaled(13))
        .fontWeight(FontWeight.Medium)
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))
        .width('100%')
        .padding(12)
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(12)
        .copyOption(CopyOptions.LocalDevice)
        .accessibilityText((this.result === null ? '' : this.result.hex))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
        .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: MOTION_SLIDE_VP })))
        .animation({ duration: MOTION_DURATION_MS, curve: Curve.EaseOut })
  }
}
