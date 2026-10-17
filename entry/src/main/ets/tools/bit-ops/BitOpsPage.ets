/**
 * 位运算器工具页。
 *
 * ## 布局：双操作数输入 + 六个操作胶囊 + 32 位面板 + 结果数
 *
 * 32 位格子用 Flex wrap（8 个一行、四行），bit31 在左上；
 * 点击格子翻转该位（核心交互，回写输入框 A）。
 *
 * @module tools/bit-ops/BitOpsPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { toolStateStore } from '../../core/ToolStateStore';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { ToolUiKit } from '../../ui/ToolUiKit';
import { BitOp, BitOpsResult, executeBitOp, flipBit, toBitPanel } from './BitOps';
import { bitOpsFailureText } from './BitOpsMessages';
import { MOTION_DURATION_MS, MOTION_SLIDE_VP } from '../../ui/Motion';

const TOOL_ID: string = 'bit-ops';
const LEFT_DRAFT: string = TOOL_ID + '.left';
const RIGHT_DRAFT: string = TOOL_ID + '.right';
const DRAFT_DEBOUNCE_MS: number = 500;

@Builder
export function buildBitOpsPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildBitOpsContent })
}

@Builder
function buildBitOpsContent() {
  BitOpsToolBody()
}

@Component
struct BitOpsToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private leftText: string = '';
  @State private rightText: string = '';
  @State private op: BitOp = BitOp.AND;
  @State private result: BitOpsResult | null = null;
  @State private errorText: string = '';
  private draftTimer: number = -1;

  private onHistoryPick(): void {
  }

  aboutToAppear(): void {
    const l: string = toolStateStore.readDraft(LEFT_DRAFT);
    const r: string = toolStateStore.readDraft(RIGHT_DRAFT);
    if (l.length > 0) {
      this.leftText = l;
    }
    if (r.length > 0) {
      this.rightText = r;
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
    toolStateStore.writeDraft(LEFT_DRAFT, this.leftText);
    toolStateStore.writeDraft(RIGHT_DRAFT, this.rightText);
  }

  private run(): void {
    const r: BitOpsResult = executeBitOp(this.op, this.leftText, this.rightText);
    if (r.ok) {
      this.errorText = '';
      this.result = r;
    } else {
      this.errorText = bitOpsFailureText(r.failure);
      this.result = null;
    }
  }

  private clearAll(): void {
    this.leftText = '';
    this.rightText = '';
    this.result = null;
    this.errorText = '';
    this.flushDraft();
  }

  private toggleBit(bitIndex: number): void {
    if (this.result === null) {
      return;
    }
    const v: number = flipBit(this.result.value, bitIndex);
    this.leftText = String(v);
    this.run();
    this.flushDraft();
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
      TextInput({ text: this.leftText, placeholder: $r('app.string.bo_label_left') })
        .width('100%')
        .fontSize(scaled(13))
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(10)
        .onChange((v: string) => {
          this.leftText = v;
          this.scheduleDraftSave();
        })
      TextInput({ text: this.rightText, placeholder: $r('app.string.bo_label_right') })
        .width('100%')
        .fontSize(scaled(13))
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(10)
        .onChange((v: string) => {
          this.rightText = v;
          this.scheduleDraftSave();
        })
      Flex({ wrap: FlexWrap.Wrap }) {
        this.chip($r('app.string.bo_op_and'), BitOp.AND)
        this.chip($r('app.string.bo_op_or'), BitOp.OR)
        this.chip($r('app.string.bo_op_xor'), BitOp.XOR)
        this.chip($r('app.string.bo_op_not'), BitOp.NOT)
        this.chip($r('app.string.bo_op_shl'), BitOp.SHL)
        this.chip($r('app.string.bo_op_shr'), BitOp.SHR)
      }
      .width('100%')
      Row({ space: 12 }) {
        Button($r('app.string.bo_action_run'))
          .layoutWeight(1)
          .onClick(() => {
            this.run();
            this.flushDraft();
          })
        Button($r('app.string.bo_action_clear'))
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
  private chip(label: ResourceStr, mode: BitOp) {
    Text(label)
      .fontSize(scaled(12))
      .fontColor(this.op === mode ? colorOf(NGFColorToken.ON_PRIMARY) : colorOf(NGFColorToken.ON_SURFACE))
      .backgroundColor(this.op === mode ? colorOf(NGFColorToken.PRIMARY) : colorOf(NGFColorToken.SURFACE))
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .borderRadius(16)
      .onClick(() => {
        this.op = mode;
      })
      .accessibilityText(ToolUiKit.text(label))
  }

  @Builder
  private buildResultSection() {
    Column({ space: 10 }) {
      Text($r('app.string.bo_label_result'))
        .fontSize(scaled(13))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.result === null ? [] : this.result.bits, (bit: number, idx: number) => {
          Text(String(bit))
            .fontSize(scaled(12))
            .fontColor(bit === 1 ? colorOf(NGFColorToken.ON_PRIMARY) : colorOf(NGFColorToken.ON_SURFACE_VARIANT))
            .backgroundColor(bit === 1 ? colorOf(NGFColorToken.PRIMARY) : colorOf(NGFColorToken.SURFACE))
            .width(38)
            .height(30)
            .textAlign(TextAlign.Center)
            .borderRadius(6)
            .margin(2)
            .onClick(() => {
              this.toggleBit(31 - idx);
            })
            .accessibilityText('bit' + (31 - idx) + ' = ' + bit)
        }, (bit: number, idx: number) => idx + ':' + bit)
      }
      .width('100%')

      Row({ space: 10 }) {
        this.valueCard($r('app.string.bo_label_hex'),
          '0x' + (this.result === null ? '' : this.result.value.toString(16).toUpperCase()))
        this.valueCard($r('app.string.bo_label_decimal'),
          this.result === null ? '' : String(this.result.value))
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Text($r('app.string.bo_hint_tap'))
        .fontSize(scaled(12))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
    }
    .width('100%')
    .padding(12)
    .backgroundColor(colorOf(NGFColorToken.BACKGROUND))
    .borderRadius(12)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private valueCard(label: ResourceStr, value: string) {
    Column({ space: 4 }) {
      Text(label)
        .fontSize(scaled(12))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
      Text(value)
        .fontSize(scaled(15))
        .fontWeight(FontWeight.Medium)
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))
        .copyOption(CopyOptions.LocalDevice)
    }
    .layoutWeight(1)
    .padding(10)
    .backgroundColor(colorOf(NGFColorToken.SURFACE))
    .borderRadius(10)
    .alignItems(HorizontalAlign.Start)
    .accessibilityText(ToolUiKit.text(label) + ': ' + value)
  }
}
