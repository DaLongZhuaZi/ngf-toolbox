/**
 * 校验和工具页。
 *
 * ## 布局：算法胶囊 + 输入 + 双行结果（十进制/十六进制）
 *
 * 页脚放「仅完整性校验」提示——这两个算法最容易被误当加密哈希用，
 * 页面必须把边界说清。
 *
 * @module tools/checksum/ChecksumPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { toolStateStore } from '../../core/ToolStateStore';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { ToolUiKit } from '../../ui/ToolUiKit';
import { ChecksumAlgorithm, ChecksumResult, computeChecksum } from './Checksum';
import { checksumFailureText } from './ChecksumMessages';
import { MOTION_FEEDBACK_MS } from '../../ui/Motion';
import { MOTION_DURATION_MS, MOTION_SLIDE_VP } from '../../ui/Motion';

const TOOL_ID: string = 'checksum';
const DRAFT_DEBOUNCE_MS: number = 500;

@Builder
export function buildChecksumPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildChecksumContent })
}

@Builder
function buildChecksumContent() {
  ChecksumToolBody()
}

@Component
struct ChecksumToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private algorithm: ChecksumAlgorithm = ChecksumAlgorithm.CRC32;
  @State private input: string = '';
  @State private result: ChecksumResult | null = null;
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
    const r: ChecksumResult = computeChecksum(this.algorithm, this.input);
    if (r.ok) {
      this.errorText = '';
      this.result = r;
    } else {
      this.errorText = checksumFailureText(r.failure);
      this.result = null;
    }
    this.scheduleDraftSave();
  }

  private copyWith(label: string, value: string): void {
    ToolUiKit.copyText(value, ToolUiKit.text($r('app.string.cs_copied')));
    this.copied = label;
    setTimeout((): void => {
      this.copied = '';
    }, 1500);
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
        this.buildResultRow($r('app.string.cs_label_decimal'), this.result.decimal)
        this.buildResultRow($r('app.string.cs_label_hex'), this.result.hex)
      }
      Text($r('app.string.cs_hint_scope'))
        .fontSize(scaled(12))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
        .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: MOTION_SLIDE_VP })))
        .animation({ duration: MOTION_DURATION_MS, curve: Curve.EaseOut })
  }

  @Builder
  private buildInputSection() {
    Column({ space: 10 }) {
      Column({ space: 6 }) {
        Text($r('app.string.cs_label_algorithm'))
          .fontSize(scaled(12))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        Row({ space: 8 }) {
          this.chip('CRC-32', ChecksumAlgorithm.CRC32)
          this.chip('Adler-32', ChecksumAlgorithm.ADLER32)
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Column({ space: 4 }) {
        Text($r('app.string.cs_label_input'))
          .fontSize(scaled(12))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        TextArea({ text: this.input, placeholder: $r('app.string.cs_label_input') })
          .width('100%')
          .height(90)
          .fontSize(scaled(13))
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(12)
          .onChange((v: string) => {
            this.input = v;
            this.scheduleDraftSave();
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Row({ space: 12 }) {
        Button($r('app.string.cs_action_compute'))
          .layoutWeight(1)
          .onClick(() => {
            this.run();
            this.flushDraft();
          })
        Button($r('app.string.cs_action_clear'))
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
  private chip(label: string, mode: ChecksumAlgorithm) {
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
  private buildResultRow(label: ResourceStr, value: string) {
    Row({ space: 10 }) {
      Text(label)
        .fontSize(scaled(12))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        .width(70)
      Text(value)
        .fontSize(scaled(14))
        .fontWeight(FontWeight.Medium)
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))
        .layoutWeight(1)
        .maxLines(2)
      Text(this.copied === value ? $r('app.string.cs_copied') : $r('app.string.cs_action_copy'))
        .fontSize(scaled(12))
        .fontColor(colorOf(NGFColorToken.PRIMARY))
          .scale({ x: this.copied !== '' ? 1.08 : 1, y: this.copied !== '' ? 1.08 : 1 })
          .animation({ duration: MOTION_FEEDBACK_MS, curve: Curve.EaseOut })
        .onClick(() => {
          this.copyWith(value, value);
        })
    }
    .width('100%')
    .padding(12)
    .backgroundColor(colorOf(NGFColorToken.SURFACE))
    .borderRadius(12)
    .alignItems(VerticalAlign.Center)
    .accessibilityText(ToolUiKit.text(label) + ': ' + value)
  }
}
