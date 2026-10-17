/**
 * 命名风格转换工具页。
 *
 * ## 布局：一进六出
 *
 * 输入一个框，输出六行风格结果（每行「风格标签 + 结果 + 复制」）。
 * 六行用卡片列表而不是表格：手机竖屏宽度里表格会挤压，卡片行高可随关怀模式缩放。
 *
 * @module tools/case-convert/CaseConvertPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { toolStateStore } from '../../core/ToolStateStore';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { ToolUiKit } from '../../ui/ToolUiKit';
import { CaseConvertResult, convertCase } from './CaseConvert';
import { caseFailureText } from './CaseConvertMessages';
import { MOTION_DURATION_MS, MOTION_SLIDE_VP } from '../../ui/Motion';

const TOOL_ID: string = 'case-convert';
const DRAFT_DEBOUNCE_MS: number = 500;

@Builder
export function buildCaseConvertPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildCaseConvertContent })
}

@Builder
function buildCaseConvertContent() {
  CaseConvertToolBody()
}

@Component
struct CaseConvertToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private input: string = '';
  @State private result: CaseConvertResult | null = null;
  @State private errorText: string = '';
  @State private copiedLabel: string = '';
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
    const r: CaseConvertResult = convertCase(this.input);
    if (r.ok) {
      this.errorText = '';
      this.result = r;
    } else {
      this.errorText = caseFailureText(r.failure);
      this.result = null;
    }
    this.scheduleDraftSave();
  }

  private copyWith(label: string, value: string): void {
    ToolUiKit.copyText(value, ToolUiKit.text($r('app.string.case_copied')));
    this.copiedLabel = label;
    setTimeout((): void => {
      this.copiedLabel = '';
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
        this.buildResultRow($r('app.string.case_label_camel'), this.result.camel)
        this.buildResultRow($r('app.string.case_label_pascal'), this.result.pascal)
        this.buildResultRow($r('app.string.case_label_snake'), this.result.snake)
        this.buildResultRow($r('app.string.case_label_screaming'), this.result.screaming)
        this.buildResultRow($r('app.string.case_label_kebab'), this.result.kebab)
        this.buildResultRow($r('app.string.case_label_dot'), this.result.dot)
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
      Text($r('app.string.case_label_input'))
        .fontSize(scaled(14))
        .fontWeight(FontWeight.Medium)
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))
      TextInput({ text: this.input, placeholder: $r('app.string.case_placeholder_input') })
        .width('100%')
        .fontSize(scaled(13))
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(12)
        .onChange((next: string) => {
          this.input = next;
          this.scheduleDraftSave();
        })
      Text($r('app.string.case_hint_words'))
        .fontSize(scaled(12))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
      Row({ space: 12 }) {
        Button($r('app.string.case_action_convert'))
          .layoutWeight(1)
          .onClick(() => {
            this.run();
            this.flushDraft();
          })
        Button($r('app.string.case_action_clear'))
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
  private buildResultRow(label: ResourceStr, value: string) {
    Row({ space: 10 }) {
      Text(label)
        .fontSize(scaled(12))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        .width(150)
      Text(value)
        .fontSize(scaled(13))
        .fontWeight(FontWeight.Medium)
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))
        .layoutWeight(1)
        .maxLines(2)
      Text(this.copiedLabel === (value + '') ? $r('app.string.case_copied') : $r('app.string.case_action_copy'))
        .fontSize(scaled(12))
        .fontColor(colorOf(NGFColorToken.PRIMARY))
        .onClick(() => {
          this.copyWith(value, value);
        })
    }
    .width('100%')
    .padding(12)
    .backgroundColor(colorOf(NGFColorToken.SURFACE))
    .borderRadius(12)
    .alignItems(VerticalAlign.Center)
    .accessibilityText(label + ': ' + value)
  }
}
