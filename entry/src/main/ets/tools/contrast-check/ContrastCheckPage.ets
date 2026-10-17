/**
 * WCAG 对比度检查工具页。
 *
 * ## 布局：双颜色输入 + 大文本 Toggle + 对比度/等级/建议
 *
 * 等级结果用色块底强调（达标绿/不达标红）；建议行直接告诉用户
 * 「这块背景上黑字还是白字」——比裸数字更可操作。
 *
 * @module tools/contrast-check/ContrastCheckPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { toolStateStore } from '../../core/ToolStateStore';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { ToolUiKit } from '../../ui/ToolUiKit';
import { checkContrast, ContrastCheckResult, WcagLevel } from './ContrastCheck';
import { contrastFailureText } from './ContrastCheckMessages';
import { MOTION_DURATION_MS, MOTION_SLIDE_VP } from '../../ui/Motion';

const TOOL_ID: string = 'contrast-check';
const DRAFT_DEBOUNCE_MS: number = 500;

@Builder
export function buildContrastCheckPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildContrastContent })
}

@Builder
function buildContrastContent() {
  ContrastToolBody()
}

@Component
struct ContrastToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private fg: string = '';
  @State private bg: string = '';
  @State private isLarge: boolean = false;
  @State private result: ContrastCheckResult | null = null;
  @State private errorText: string = '';
  @State private copied: boolean = false;
  private draftTimer: number = -1;

  private onHistoryPick(): void {
  }

  aboutToAppear(): void {
    const saved: string = toolStateStore.readDraft(TOOL_ID);
    if (saved.length > 0) {
      this.fg = saved;
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
    toolStateStore.writeDraft(TOOL_ID, this.fg);
  }

  private levelText(): string {
    if (this.result === null) {
      return '';
    }
    if (this.result.level === WcagLevel.AAA) {
      return ToolUiKit.text($r('app.string.cc_level_aaa'));
    }
    if (this.result.level === WcagLevel.AA) {
      return ToolUiKit.text($r('app.string.cc_level_aa'));
    }
    if (this.result.level === WcagLevel.AA_LARGE) {
      return ToolUiKit.text($r('app.string.cc_level_aa_large'));
    }
    return ToolUiKit.text($r('app.string.cc_level_fail'));
  }

  private levelOk(): boolean {
    return this.result !== null &&
      (this.result.level === WcagLevel.AAA || this.result.level === WcagLevel.AA ||
        this.result.level === WcagLevel.AA_LARGE);
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
      if (this.result !== null && this.result.ok) {
        this.buildResultSection()
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildInputSection() {
    Column({ space: 10 }) {
      Column({ space: 4 }) {
        Text($r('app.string.cc_label_fg'))
          .fontSize(scaled(12))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        TextInput({ text: this.fg, placeholder: $r('app.string.cc_placeholder_fg') })
          .width('100%')
          .fontSize(scaled(13))
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(10)
          .onChange((v: string) => {
            this.fg = v;
            this.scheduleDraftSave();
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Column({ space: 4 }) {
        Text($r('app.string.cc_label_bg'))
          .fontSize(scaled(12))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        TextInput({ text: this.bg, placeholder: $r('app.string.cc_placeholder_fg') })
          .width('100%')
          .fontSize(scaled(13))
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(10)
          .onChange((v: string) => {
            this.bg = v;
            this.scheduleDraftSave();
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Row({ space: 8 }) {
        Toggle({ type: ToggleType.Checkbox, isOn: this.isLarge })
          .onChange((on: boolean) => {
            this.isLarge = on;
          })
          .accessibilityText($r('app.string.cc_label_large'))
        Text($r('app.string.cc_label_large'))
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE))
          .layoutWeight(1)
      }
      .width('100%')

      Row({ space: 12 }) {
        Button($r('app.string.cc_action_check'))
          .layoutWeight(1)
          .onClick(() => {
            const r = checkContrast(this.fg, this.bg, this.isLarge);
            if (r.ok) {
              this.errorText = '';
              this.result = r;
            } else {
              this.errorText = contrastFailureText(r.failure);
              this.result = null;
            }
            this.flushDraft();
          })
        Button($r('app.string.cc_action_clear'))
          .layoutWeight(1)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .controlSize(ControlSize.NORMAL)
          .onClick(() => {
            this.fg = '';
            this.bg = '';
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
  private buildResultSection() {
    Column({ space: 12 }) {
      Row({ space: 10 }) {
        Column({ space: 4 }) {
          Text($r('app.string.cc_label_ratio'))
            .fontSize(scaled(12))
            .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
          Text(this.result === null ? '' : this.result.ratio.toFixed(2) + ':1')
            .fontSize(scaled(22))
            .fontWeight(FontWeight.Bold)
            .fontColor(this.levelOk() ? colorOf(NGFColorToken.SUCCESS)
              : colorOf(NGFColorToken.ON_SURFACE))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: MOTION_SLIDE_VP })))
        .animation({ duration: MOTION_DURATION_MS, curve: Curve.EaseOut })

        Text(this.levelText())
          .fontSize(scaled(14))
          .fontWeight(FontWeight.Medium)
          .fontColor(colorOf(NGFColorToken.ON_PRIMARY))
          .backgroundColor(this.levelOk() ? colorOf(NGFColorToken.SUCCESS)
            : colorOf(NGFColorToken.WARNING))
          .padding({ left: 14, right: 14, top: 8, bottom: 8 })
          .borderRadius(12)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(this.result === null ? '' :
        (this.result.preferDarkText
          ? ToolUiKit.text($r('app.string.cc_suggest_dark'))
          : ToolUiKit.text($r('app.string.cc_suggest_light'))))
        .fontSize(scaled(13))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))
        .width('100%')
        .padding(10)
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(10)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
