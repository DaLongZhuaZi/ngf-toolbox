/**
 * 进制转换工具页。
 *
 * 两个分区刻意分开：上半是「转换」，下半是「位运算」。它们的输入同一个（当前输入框的值），
 * 但位运算多一个操作数、一个位宽语义，混在一张表单里会让"这个结果是谁算的"变得含糊。
 *
 * 位运算结果旁边必须显示**截断标记**：64 位有符号语义下，超过位宽的输入是被截断的，
 * 不标出来就等于让用户以为超长输入也参与了运算。
 *
 * @module tools/radix-convert/RadixConvertPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { toolStateStore } from '../../core/ToolStateStore';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { ToolUiKit } from '../../ui/ToolUiKit';
import { radixFailureText } from './RadixConvertMessages';
import {
  BITWISE_WIDTH,
  bitwiseOperation,
  convertRadix,
  isValidRadix,
  NGFBitwiseOperation,
  RADIX_MAX,
  RADIX_MIN,
  RadixConvertResult
} from './RadixConvert';

/** 工具 id：草稿按它存取，必须与 ToolsCatalog 里登记的 id 一致 */
const TOOL_ID: string = 'radix-convert';

/** 草稿写入防抖（毫秒） */
const DRAFT_DEBOUNCE_MS: number = 400;

/** 常用进制快捷选项（其余进制用自定义输入） */
const COMMON_RADIXES: number[] = [2, 8, 10, 16, 36];

/** 位运算快捷选项（NOT 与移位只用左操作数） */
const OPERATIONS: string[] = [NGFBitwiseOperation.AND, NGFBitwiseOperation.OR, NGFBitwiseOperation.XOR,
  NGFBitwiseOperation.NOT, NGFBitwiseOperation.SHIFT_LEFT, NGFBitwiseOperation.SHIFT_RIGHT];

@Builder
export function buildRadixConvertPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildRadixConvertContent })
}

@Builder
function buildRadixConvertContent() {
  RadixConvertToolBody()
}

@Component
struct RadixConvertToolBody {
  /** 订阅主题深浅；本字段本身不用，作用是在主题切换时触发本组件重渲染。 */
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  /** 订阅字体缩放；本字段不用，作用是切字号时触发本组件重渲染。 */
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  /** 历史回填序号；变化时由 @Watch 触发 onHistoryPick（见 ui/HistoryPick.ets） */
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private input: string = '';
  @State private sourceRadix: number = 10;
  @State private targetRadix: number = 16;
  @State private customSource: string = '';
  @State private customTarget: string = '';
  @State private resultText: string = '';
  /** 失败文案。已由 RadixConvertMessages 解析成成品字符串，页面不再关心资源细节 */
  @State private resultError: string = '';
  /** 位运算区 */
  @State private rightOperand: string = '';
  @State private operation: string = NGFBitwiseOperation.AND;
  @State private shiftText: string = '1';
  @State private bitwiseText: string = '';
  /** 失败文案，同上 */
  @State private bitwiseError: string = '';
  @State private bitwiseTruncated: boolean = false;
  private draftTimer: number = -1;

  /** 用户在壳层选中一条历史 → 从草稿重读本次输入（见 ui/HistoryPick.ets） */

  private onHistoryPick(): void {

    const restored: string = toolStateStore.readDraft(TOOL_ID);

    if (restored.length === 0) {

      return;

    }

    this.input = restored;

  }


  aboutToAppear(): void {
    const saved: string = toolStateStore.readDraft(TOOL_ID);
    if (saved.length > 0) {
      this.input = saved;
      this.convert();
    }
  }

  aboutToDisappear(): void {
    this.flushDraft();
  }

  build() {
    Column({ space: 16 }) {
      this.buildInputSection()
      this.buildRadixSection()
      this.buildResultSection()
      this.buildBitwiseSection()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 输入区 */
  @Builder
  private buildInputSection() {
    Column({ space: 8 }) {
      Text($r('app.string.radix_label_input'))
        .fontSize(scaled(15))
        .fontWeight(FontWeight.Medium)
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))

      TextInput({ text: this.input, placeholder: $r('app.string.radix_placeholder_input') })
        .width('100%')
        .height(44)
        .fontSize(scaled(15))
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(12)
        .onChange((value: string) => {
          this.input = value;
          this.scheduleDraftSave(value);
          this.convert();
        })

      Row({ space: 12 }) {
        Button($r('app.string.radix_action_convert'))
          .layoutWeight(1)
          .onClick(() => {
            this.convert();
            this.flushDraft();
          })

        Button($r('app.string.shell_action_clear'))
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

  /** 进制选择区 */
  @Builder
  private buildRadixSection() {
    Column({ space: 8 }) {
      Text(ToolUiKit.stringOf($r('app.string.radix_label_radix_pair'),
          [String(this.sourceRadix), String(this.targetRadix)]))
        .fontSize(scaled(13))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))

      Row({ space: 8 }) {
        ForEach(COMMON_RADIXES, (radix: number) => {
          Text(String(radix))
            .fontSize(scaled(14))
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .padding(8)
            .borderRadius(8)
            .backgroundColor(this.sourceRadix === radix ? colorOf(NGFColorToken.PRIMARY_CONTAINER) : colorOf(NGFColorToken.SURFACE))
            .fontColor(this.sourceRadix === radix ? colorOf(NGFColorToken.PRIMARY) : colorOf(NGFColorToken.ON_SURFACE_VARIANT))
            .accessibilityText(ToolUiKit.text(String(radix)))
            .onClick(() => {
              this.sourceRadix = radix;
              this.customSource = '';
              this.convert();
            })
        }, (radix: number) => 'source-' + String(radix))
      }
      .width('100%')

      Row({ space: 8 }) {
        ForEach(COMMON_RADIXES, (radix: number) => {
          Text(String(radix))
            .fontSize(scaled(14))
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .padding(8)
            .borderRadius(8)
            .backgroundColor(this.targetRadix === radix ? colorOf(NGFColorToken.PRIMARY_CONTAINER) : colorOf(NGFColorToken.SURFACE))
            .fontColor(this.targetRadix === radix ? colorOf(NGFColorToken.PRIMARY) : colorOf(NGFColorToken.ON_SURFACE_VARIANT))
            .accessibilityText(ToolUiKit.text(String(radix)))
            .onClick(() => {
              this.targetRadix = radix;
              this.customTarget = '';
              this.convert();
            })
        }, (radix: number) => 'target-' + String(radix))
      }
      .width('100%')

      Row({ space: 12 }) {
        TextInput({
          text: this.customSource,
          placeholder: ToolUiKit.stringOf($r('app.string.radix_placeholder_source_radix'),
            [String(RADIX_MIN), String(RADIX_MAX)])
        })
          .layoutWeight(1)
          .height(40)
          .fontSize(scaled(14))
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(10)
          .onChange((value: string) => {
            this.customSource = value;
            this.applyCustomRadix(true);
          })

        TextInput({
          text: this.customTarget,
          placeholder: ToolUiKit.stringOf($r('app.string.radix_placeholder_target_radix'),
            [String(RADIX_MIN), String(RADIX_MAX)])
        })
          .layoutWeight(1)
          .height(40)
          .fontSize(scaled(14))
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(10)
          .onChange((value: string) => {
            this.customTarget = value;
            this.applyCustomRadix(false);
          })
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 转换结果区 */
  @Builder
  private buildResultSection() {
    Column({ space: 8 }) {
      if (this.resultError.length > 0) {
        Text(this.resultError)
          .fontSize(scaled(13))
          .lineHeight(20)
          .width('100%')
          .padding(12)
          .borderRadius(12)
          .backgroundColor(colorOf(NGFColorToken.ERROR_CONTAINER))
          .fontColor(colorOf(NGFColorToken.ERROR_COLOR))
      }

      if (this.resultText.length > 0) {
        Column({ space: 6 }) {
          Row() {
            Text(ToolUiKit.stringOf($r('app.string.radix_label_result'), [String(this.targetRadix)]))
              .fontSize(scaled(14))
              .fontWeight(FontWeight.Medium)
              .fontColor(colorOf(NGFColorToken.ON_SURFACE))
            Blank()
            Text($r('app.string.shell_action_copy'))
              .fontSize(scaled(13))
              .fontColor(colorOf(NGFColorToken.PRIMARY))
              .accessibilityText(ToolUiKit.text($r('app.string.copied_common')))
              .onClick(() => {
                ToolUiKit.copyText(this.resultText, ToolUiKit.text($r('app.string.radix_copied_result')));
              })
          }
          .width('100%')

          Text(this.resultText)
            .fontSize(scaled(15))
            .lineHeight(22)
            .width('100%')
            .fontColor(colorOf(NGFColorToken.ON_SURFACE))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(12)
        .backgroundColor(colorOf(NGFColorToken.SURFACE_VARIANT))
        .borderRadius(12)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 位运算区 */
  @Builder
  private buildBitwiseSection() {
    Column({ space: 8 }) {
      Text(ToolUiKit.stringOf($r('app.string.radix_label_bitwise'), [String(BITWISE_WIDTH)]))
        .fontSize(scaled(15))
        .fontWeight(FontWeight.Medium)
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))

      Text($r('app.string.radix_bitwise_hint'))
        .fontSize(scaled(13))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))

      Row({ space: 8 }) {
        ForEach(OPERATIONS, (operation: string) => {
          Text(operation)
            .fontSize(scaled(14))
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .padding(8)
            .borderRadius(8)
            .backgroundColor(this.operation === operation ? colorOf(NGFColorToken.PRIMARY_CONTAINER) : colorOf(NGFColorToken.SURFACE))
            .fontColor(this.operation === operation ? colorOf(NGFColorToken.PRIMARY) : colorOf(NGFColorToken.ON_SURFACE_VARIANT))
            .accessibilityText(ToolUiKit.text(operation))
            .onClick(() => {
              this.operation = operation;
            })
        }, (operation: string) => operation)
      }
      .width('100%')

      Row({ space: 12 }) {
        TextInput({ text: this.rightOperand, placeholder: $r('app.string.radix_placeholder_right_operand') })
          .layoutWeight(1)
          .height(40)
          .fontSize(scaled(14))
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(10)
          .onChange((value: string) => {
            this.rightOperand = value;
          })

        TextInput({ text: this.shiftText, placeholder: $r('app.string.radix_placeholder_shift') })
          .width(110)
          .height(40)
          .fontSize(scaled(14))
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(10)
          .onChange((value: string) => {
            this.shiftText = value;
          })
      }
      .width('100%')

      Button($r('app.string.radix_action_bitwise'))
        .width('100%')
        .onClick(() => {
          this.computeBitwise();
        })

      if (this.bitwiseError.length > 0) {
        Text(this.bitwiseError)
          .fontSize(scaled(13))
          .lineHeight(20)
          .width('100%')
          .padding(12)
          .borderRadius(12)
          .backgroundColor(colorOf(NGFColorToken.ERROR_CONTAINER))
          .fontColor(colorOf(NGFColorToken.ERROR_COLOR))
      }

      if (this.bitwiseText.length > 0) {
        Column({ space: 6 }) {
          Row() {
            Text($r('app.string.radix_label_bitwise_result'))
              .fontSize(scaled(14))
              .fontWeight(FontWeight.Medium)
              .fontColor(colorOf(NGFColorToken.ON_SURFACE))
            Blank()
            Text($r('app.string.shell_action_copy'))
              .fontSize(scaled(13))
              .fontColor(colorOf(NGFColorToken.PRIMARY))
              .accessibilityText(ToolUiKit.text($r('app.string.copied_common')))
              .onClick(() => {
                ToolUiKit.copyText(this.bitwiseText, ToolUiKit.text($r('app.string.radix_copied_bitwise')));
              })
          }
          .width('100%')

          Text(this.bitwiseText)
            .fontSize(scaled(15))
            .lineHeight(22)
            .width('100%')
            .fontColor(colorOf(NGFColorToken.ON_SURFACE))

          if (this.bitwiseTruncated) {
            Text($r('app.string.radix_truncated_notice'))
              .fontSize(scaled(12))
              .fontColor(colorOf(NGFColorToken.WARNING))
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(12)
        .backgroundColor(colorOf(NGFColorToken.SURFACE_VARIANT))
        .borderRadius(12)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 自定义进制输入：合法才生效，非法时忽略（不打断用户输入过程） */
  private applyCustomRadix(isSource: boolean): void {
    const text: string = isSource ? this.customSource : this.customTarget;
    const value: number = parseInt(text, 10);
    if (isNaN(value) || !isValidRadix(value)) {
      return;
    }
    if (isSource) {
      this.sourceRadix = value;
    } else {
      this.targetRadix = value;
    }
    this.convert();
  }

  /** 执行转换 */
  private convert(): void {
    const outcome: RadixConvertResult = convertRadix(this.input, this.sourceRadix, this.targetRadix);
    if (!outcome.ok) {
      // 输入为空时不报错（用户还没开始输入，一进页面就满屏红字最烦人）。
      // 纯逻辑返回的是失败码，这里翻译成人话——见 RadixConvertMessages 的说明。
      this.resultError = this.input.length === 0 ? '' : radixFailureText(outcome.failure);
      this.resultText = '';
      return;
    }
    this.resultError = '';
    // prefixed 已经按目标进制带了 0x/0b/0o 前缀与符号，页面不再二次拼装
    this.resultText = outcome.prefixed;
  }

  /** 执行位运算 */
  private computeBitwise(): void {
    const shift: number = parseInt(this.shiftText, 10);
    const outcome: RadixConvertResult = bitwiseOperation(this.input, this.rightOperand, this.operation,
      this.sourceRadix, isNaN(shift) ? 0 : shift);
    if (!outcome.ok) {
      this.bitwiseError = radixFailureText(outcome.failure);
      this.bitwiseText = '';
      this.bitwiseTruncated = false;
      return;
    }
    this.bitwiseError = '';
    this.bitwiseText = outcome.prefixed;
    this.bitwiseTruncated = outcome.truncated;
  }

  /** 清空输入与结果 */
  private clearAll(): void {
    if (this.draftTimer >= 0) {
      clearTimeout(this.draftTimer);
      this.draftTimer = -1;
    }
    this.input = '';
    this.resultText = '';
    this.resultError = '';
    this.rightOperand = '';
    this.bitwiseText = '';
    this.bitwiseError = '';
    this.bitwiseTruncated = false;
    toolStateStore.clearDraft(TOOL_ID);
  }

  /** 防抖写草稿 */
  private scheduleDraftSave(text: string): void {
    if (this.draftTimer >= 0) {
      clearTimeout(this.draftTimer);
    }
    this.draftTimer = setTimeout(() => {
      this.draftTimer = -1;
      toolStateStore.writeDraft(TOOL_ID, text);
    }, DRAFT_DEBOUNCE_MS);
  }

  /** 立即落盘 */
  private flushDraft(): void {
    if (this.draftTimer >= 0) {
      clearTimeout(this.draftTimer);
      this.draftTimer = -1;
    }
    toolStateStore.writeDraft(TOOL_ID, this.input);
  }
}