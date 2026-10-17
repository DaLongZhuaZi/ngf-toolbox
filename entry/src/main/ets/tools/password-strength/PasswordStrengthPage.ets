/**
 * 密码强度评估工具页（薄封装 uuid-password 的评估器）。
 *
 * ## 布局：密码输入（可切换明文）+ 三档总结 + 熵值 + 建议列表
 *
 * @module tools/password-strength/PasswordStrengthPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { toolStateStore } from '../../core/ToolStateStore';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { ToolUiKit } from '../../ui/ToolUiKit';
import { PasswordAdvice } from '../uuid-password/UuidPasswordLogic';
import { evaluateWithSummary, StrengthReport, StrengthSummary } from './PasswordStrengthLogic';
import { passwordAdviceList, strengthLevelText } from '../uuid-password/UuidPasswordMessages';

const TOOL_ID: string = 'password-strength';
const DRAFT_DEBOUNCE_MS: number = 500;

@Builder
export function buildPasswordStrengthPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildStrengthContent })
}

@Builder
function buildStrengthContent() {
  StrengthToolBody()
}

@Component
struct StrengthToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private input: string = '';
  @State private showPlain: boolean = false;
  @State private report: StrengthReport | null = null;
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
    this.report = evaluateWithSummary(this.input);
    this.scheduleDraftSave();
  }

  private summaryText(): string {
    if (this.report === null) {
      return '';
    }
    if (this.report.summary === StrengthSummary.STRONG) {
      return ToolUiKit.text($r('app.string.ps_summary_strong'));
    }
    if (this.report.summary === StrengthSummary.MEDIUM) {
      return ToolUiKit.text($r('app.string.ps_summary_medium'));
    }
    return ToolUiKit.text($r('app.string.ps_summary_weak'));
  }

  private summaryColor(): ResourceColor {
    if (this.report !== null && this.report.summary === StrengthSummary.STRONG) {
      return colorOf(NGFColorToken.SUCCESS);
    }
    if (this.report !== null && this.report.summary === StrengthSummary.MEDIUM) {
      return colorOf(NGFColorToken.WARNING);
    }
    return colorOf(NGFColorToken.ON_SURFACE_VARIANT);
  }

  build() {
    Column({ space: 16 }) {
      Column({ space: 10 }) {
        Row({ space: 8 }) {
        if (this.showPlain) {
          TextInput({ text: this.input, placeholder: $r('app.string.ps_label_input') })
            .layoutWeight(1)
            .fontSize(scaled(13))
            .backgroundColor(colorOf(NGFColorToken.SURFACE))
            .borderRadius(10)
            .onChange((v: string) => {
              this.input = v;
              this.run();
            })
        } else {
          TextInput({ text: this.input, placeholder: $r('app.string.ps_label_input') })
            .layoutWeight(1)
            .fontSize(scaled(13))
            .backgroundColor(colorOf(NGFColorToken.SURFACE))
            .borderRadius(10)
            .type(InputType.Password)
            .onChange((v: string) => {
              this.input = v;
              this.run();
            })
        }
          Toggle({ type: ToggleType.Checkbox, isOn: this.showPlain })
            .onChange((on: boolean) => {
              this.showPlain = on;
            })
            .accessibilityText($r('app.string.ps_label_input'))
        }
        .width('100%')
        Button($r('app.string.ps_action_clear'))
          .width('100%')
          .buttonStyle(ButtonStyleMode.NORMAL)
          .controlSize(ControlSize.NORMAL)
          .onClick(() => {
            this.input = '';
            this.report = null;
            this.flushDraft();
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      if (this.report !== null) {
        Row({ space: 12 }) {
          Column({ space: 4 }) {
            Text($r('app.string.ps_summary_strong') === null ? '' : this.summaryText())
              .fontSize(scaled(20))
              .fontWeight(FontWeight.Bold)
              .fontColor(this.summaryColor())
            Text(strengthLevelText(this.report.strength.level))
              .fontSize(scaled(12))
              .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          Column({ space: 4 }) {
            Text($r('app.string.ps_label_entropy'))
              .fontSize(scaled(12))
              .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
            Text(String(this.report.strength.entropyBits) + ' bits')
              .fontSize(scaled(14))
              .fontWeight(FontWeight.Medium)
              .fontColor(colorOf(NGFColorToken.ON_SURFACE))
          }
          .alignItems(HorizontalAlign.End)
        }
        .width('100%')
        .padding(12)
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(12)
        .alignItems(VerticalAlign.Center)

        if (this.report.strength.suggestions.length > 0) {
          Column({ space: 6 }) {
            Text($r('app.string.ps_label_advice'))
              .fontSize(scaled(12))
              .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
            ForEach(passwordAdviceList(this.report.strength, 0), (advice: string, idx: number) => {
              Text(advice)
                .fontSize(scaled(13))
                .fontColor(colorOf(NGFColorToken.ON_SURFACE))
                .width('100%')
            }, (advice: string, idx: number) => idx + ':' + advice)
          }
          .width('100%')
          .padding(12)
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(12)
          .alignItems(HorizontalAlign.Start)
        }

        Text($r('app.string.ps_hint_offline'))
          .fontSize(scaled(11))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}