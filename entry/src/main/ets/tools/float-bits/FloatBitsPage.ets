/**
 * IEEE-754 位分解工具页。
 *
 * ## 布局：输入 + 精度胶囊 + 三段位区（符号/指数/尾数）+ 位型十六进制 + 分类
 *
 * 位区用与 bit-ops 同款的格子渲染；指数/尾数分别上色，一眼看清三段边界。
 *
 * @module tools/float-bits/FloatBitsPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { toolStateStore } from '../../core/ToolStateStore';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { ToolUiKit } from '../../ui/ToolUiKit';
import { decomposeFloat, FloatBitsResult, FloatPrecision, FloatValueClass } from './FloatBits';
import { floatBitsFailureText } from './FloatBitsMessages';
import { MOTION_FEEDBACK_MS } from '../../ui/Motion';
import { MOTION_DURATION_MS, MOTION_SLIDE_VP } from '../../ui/Motion';

const TOOL_ID: string = 'float-bits';
const DRAFT_DEBOUNCE_MS: number = 500;

@Builder
export function buildFloatBitsPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildFloatBitsContent })
}

@Builder
function buildFloatBitsContent() {
  FloatBitsToolBody()
}

@Component
struct FloatBitsToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private input: string = '';
  @State private precision: FloatPrecision = FloatPrecision.SINGLE;
  @State private result: FloatBitsResult | null = null;
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
    const r: FloatBitsResult = decomposeFloat(this.input, this.precision);
    if (r.ok) {
      this.errorText = '';
      this.result = r;
    } else {
      this.errorText = floatBitsFailureText(r.failure);
      this.result = null;
    }
    this.scheduleDraftSave();
  }

  private classText(): string {
    if (this.result === null) {
      return '';
    }
    if (this.result.valueClass === FloatValueClass.NORMAL) {
      return ToolUiKit.text($r('app.string.fb_class_normal'));
    }
    if (this.result.valueClass === FloatValueClass.SUBNORMAL) {
      return ToolUiKit.text($r('app.string.fb_class_subnormal'));
    }
    if (this.result.valueClass === FloatValueClass.ZERO) {
      return ToolUiKit.text($r('app.string.fb_class_zero'));
    }
    if (this.result.valueClass === FloatValueClass.INFINITY) {
      return ToolUiKit.text($r('app.string.fb_class_infinity'));
    }
    return ToolUiKit.text($r('app.string.fb_class_nan'));
  }

  build() {
    Column({ space: 16 }) {
      this.buildInputSection()
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
        this.buildResultSection()
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
        .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: MOTION_SLIDE_VP })))
        .animation({ duration: MOTION_DURATION_MS, curve: Curve.EaseOut })
  }

  @Builder
  private buildInputSection() {
    Column({ space: 10 }) {
      Column({ space: 4 }) {
        Text($r('app.string.fb_label_input'))
          .fontSize(scaled(12))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        TextInput({ text: this.input, placeholder: $r('app.string.fb_label_input') })
          .width('100%')
          .fontSize(scaled(13))
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(10)
          .onChange((v: string) => {
            this.input = v;
            this.scheduleDraftSave();
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Column({ space: 6 }) {
        Text($r('app.string.fb_label_precision'))
          .fontSize(scaled(12))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        Row({ space: 8 }) {
          this.chip($r('app.string.fb_prec_single'), FloatPrecision.SINGLE)
          this.chip($r('app.string.fb_prec_double'), FloatPrecision.DOUBLE)
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Row({ space: 12 }) {
        Button($r('app.string.fb_action_parse'))
          .layoutWeight(1)
          .onClick(() => {
            this.run();
            this.flushDraft();
          })
        Button($r('app.string.fb_action_clear'))
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
  }

  @Builder
  private chip(label: ResourceStr, mode: FloatPrecision) {
    Text(label)
      .fontSize(scaled(12))
      .fontColor(this.precision === mode ? colorOf(NGFColorToken.ON_PRIMARY) : colorOf(NGFColorToken.ON_SURFACE))
      .backgroundColor(this.precision === mode ? colorOf(NGFColorToken.PRIMARY) : colorOf(NGFColorToken.SURFACE))
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .borderRadius(16)
      .onClick(() => {
        this.precision = mode;
        if (this.input.trim().length > 0) {
          this.run();
        }
      })
      .accessibilityText(ToolUiKit.text(label))
  }

  /** 位格子区（同 bit-ops 风格；colored 区分三段） */
  @Builder
  private buildBitsRow(label: ResourceStr, bits: Array<number>, highlight: NGFColorToken) {
    Column({ space: 6 }) {
      Text(label)
        .fontSize(scaled(12))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(bits, (bit: number, idx: number) => {
          Text(String(bit))
            .fontSize(scaled(11))
            .fontColor(colorOf(NGFColorToken.ON_SURFACE))
            .backgroundColor(colorOf(NGFColorToken.SURFACE))
            .width(26)
            .height(24)
            .textAlign(TextAlign.Center)
            .borderRadius(5)
            .margin(1)
            .border({ width: 1, color: colorOf(highlight) })
        }, (bit: number, idx: number) => idx + ':' + bit)
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildResultSection() {
    Column({ space: 12 }) {
      Row() {
        Text($r('app.string.fb_label_hex'))
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE))
          .layoutWeight(1)
        Text(this.copied ? $r('app.string.fb_copied') : $r('app.string.fb_action_copy'))
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.PRIMARY))
          .accessibilityText(ToolUiKit.text($r('app.string.copied_common')))
            .scale({ x: this.copied ? 1.08 : 1, y: this.copied ? 1.08 : 1 })
            .animation({ duration: MOTION_FEEDBACK_MS, curve: Curve.EaseOut })
          .onClick(() => {
            if (this.result !== null) {
              ToolUiKit.copyText(this.result.hex, ToolUiKit.text($r('app.string.fb_copied')));
              this.copied = true;
              setTimeout((): void => {
                this.copied = false;
              }, 1500);
            }
          })
      }
      .width('100%')

      Text(this.result === null ? '' : this.result.hex)
        .fontSize(scaled(15))
        .fontWeight(FontWeight.Medium)
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))
        .width('100%')
        .padding(12)
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(12)
        .copyOption(CopyOptions.LocalDevice)
        .accessibilityText(this.result === null ? '' : this.result.hex)

      Row({ space: 8 }) {
        Text($r('app.string.fb_label_class'))
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        Text(this.classText())
          .fontSize(scaled(13))
          .fontWeight(FontWeight.Medium)
          .fontColor(colorOf(NGFColorToken.PRIMARY))
      }
      .width('100%')

      this.buildBitsRow($r('app.string.fb_label_sign'),
        this.result === null ? [] : [this.result.sign], NGFColorToken.PRIMARY)
      this.buildBitsRow($r('app.string.fb_label_exponent'),
        this.result === null ? [] : this.result.exponentBits, NGFColorToken.WARNING)
      this.buildBitsRow($r('app.string.fb_label_mantissa'),
        this.result === null ? [] : this.result.mantissaBits, NGFColorToken.SUCCESS)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
