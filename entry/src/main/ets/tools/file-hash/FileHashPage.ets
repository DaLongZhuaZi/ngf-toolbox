/**
 * 文本哈希校验工具页。
 *
 * ## 布局：文本 + 期望值 + 四行哈希表 + 比对徽标
 *
 * @module tools/file-hash/FileHashPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { toolStateStore } from '../../core/ToolStateStore';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { ToolUiKit } from '../../ui/ToolUiKit';
import { FileHashResult, hashWithCompare } from './FileHashLogic';
import { MOTION_FEEDBACK_MS } from '../../ui/Motion';
import { MOTION_DURATION_MS, MOTION_SLIDE_VP } from '../../ui/Motion';

const TOOL_ID: string = 'file-hash';
const DRAFT_DEBOUNCE_MS: number = 500;

@Builder
export function buildFileHashPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildFileHashContent })
}

@Builder
function buildFileHashContent() {
  FileHashToolBody()
}

@Component
struct FileHashToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private text: string = '';
  @State private expected: string = '';
  @State private result: FileHashResult | null = null;
  @State private errorText: string = '';
  @State private copied: string = '';
  private draftTimer: number = -1;

  private onHistoryPick(): void {
    const restored: string = toolStateStore.readDraft(TOOL_ID);
    if (restored.length === 0) {
      return;
    }
    this.text = restored;
    this.run();
  }

  aboutToAppear(): void {
    const saved: string = toolStateStore.readDraft(TOOL_ID);
    if (saved.length > 0) {
      this.text = saved;
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
    toolStateStore.writeDraft(TOOL_ID, this.text);
  }

  private run(): void {
    const r: FileHashResult = hashWithCompare(this.text, this.expected);
    if (r.ok) {
      this.errorText = '';
      this.result = r;
    } else {
      this.errorText = ToolUiKit.text($r('app.string.fh_err_empty'));
      this.result = null;
    }
    this.scheduleDraftSave();
  }

  private copyWith(label: string, value: string): void {
    ToolUiKit.copyText(value, ToolUiKit.text($r('app.string.fh_copied')));
    this.copied = label;
    setTimeout((): void => {
      this.copied = '';
    }, 1500);
  }

  build() {
    Column({ space: 16 }) {
      Column({ space: 10 }) {
        Text($r('app.string.fh_label_text'))
          .fontSize(scaled(12))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        TextArea({ text: this.text, placeholder: $r('app.string.fh_label_text') })
          .width('100%')
          .height(100)
          .fontSize(scaled(13))
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(12)
          .onChange((v: string) => {
            this.text = v;
            this.scheduleDraftSave();
          })
        TextInput({ text: this.expected, placeholder: $r('app.string.fh_label_expected') })
          .width('100%')
          .fontSize(scaled(13))
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(10)
          .onChange((v: string) => {
            this.expected = v;
            this.scheduleDraftSave();
          })
        Row({ space: 12 }) {
          Button($r('app.string.fh_action_hash'))
            .layoutWeight(1)
            .onClick(() => {
              this.run();
              this.flushDraft();
            })
          Button($r('app.string.fh_action_clear'))
            .layoutWeight(1)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .controlSize(ControlSize.NORMAL)
            .onClick(() => {
              this.text = '';
              this.expected = '';
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
          this.hashRow('MD5', this.result.md5)
          this.hashRow('SHA-1', this.result.sha1)
          this.hashRow('SHA-256', this.result.sha256)
          this.hashRow('SHA-512', this.result.sha512)
        }
        .width('100%')
        .padding(12)
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(12)
        .alignItems(HorizontalAlign.Start)
        .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: MOTION_SLIDE_VP })))
        .animation({ duration: MOTION_DURATION_MS, curve: Curve.EaseOut })

        if (this.result.compareOutcome === 'match') {
          Text(ToolUiKit.stringOf($r('app.string.fh_compare_match'), [this.result.matchedAlgorithm]))
            .fontSize(scaled(13))
            .fontColor(colorOf(NGFColorToken.SUCCESS))
            .width('100%')
            .padding(10)
            .backgroundColor(colorOf(NGFColorToken.SURFACE))
            .borderRadius(10)
        } else if (this.result.compareOutcome === 'mismatch') {
          Text($r('app.string.fh_compare_mismatch'))
            .fontSize(scaled(13))
            .fontColor(colorOf(NGFColorToken.WARNING))
            .width('100%')
            .padding(10)
            .backgroundColor(colorOf(NGFColorToken.WARNING_CONTAINER))
            .borderRadius(10)
        }
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private hashRow(label: string, value: string) {
    Row({ space: 10 }) {
      Text(label)
        .fontSize(scaled(12))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        .width(70)
      Text(value)
        .fontSize(scaled(11))
        .fontFamily('monospace')
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))
        .layoutWeight(1)
        .maxLines(2)
        .copyOption(CopyOptions.LocalDevice)
      Text(this.copied === label ? $r('app.string.fh_copied') : $r('app.string.fh_action_copy'))
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