/**
 * 正则替换预览工具页。
 *
 * ## 布局：原文/正则/标志/替换 四输入 + 替换后文本 + 匹配清单
 *
 * @module tools/regex-replace/RegexReplacePage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { toolStateStore } from '../../core/ToolStateStore';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { ToolUiKit } from '../../ui/ToolUiKit';
import { RegexMatchItem, RegexReplaceFailureCode, RegexReplaceResult, replacePreview } from './RegexReplaceLogic';
import { MOTION_FEEDBACK_MS } from '../../ui/Motion';
import { MOTION_DURATION_MS, MOTION_SLIDE_VP } from '../../ui/Motion';

const TOOL_ID: string = 'regex-replace';
const DRAFT_DEBOUNCE_MS: number = 500;

@Builder
export function buildRegexReplacePage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildReplaceContent })
}

@Builder
function buildReplaceContent() {
  ReplaceToolBody()
}

@Component
struct ReplaceToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private input: string = '';
  @State private pattern: string = '';
  @State private flags: string = 'g';
  @State private replacement: string = '';
  @State private result: RegexReplaceResult | null = null;
  @State private errorText: string = '';
  @State private copied: boolean = false;
  private draftTimer: number = -1;

  private onHistoryPick(): void {
  }

  aboutToAppear(): void {
    const saved: string = toolStateStore.readDraft(TOOL_ID);
    if (saved.length > 0) {
      this.input = saved;
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
    const r: RegexReplaceResult = replacePreview(this.input, this.pattern, this.flags, this.replacement);
    if (r.ok) {
      this.errorText = '';
      this.result = r;
    } else {
      this.result = null;
      if (r.failure.code === RegexReplaceFailureCode.EMPTY_INPUT) {
        this.errorText = ToolUiKit.text($r('app.string.rr_err_input'));
      } else if (r.failure.code === RegexReplaceFailureCode.EMPTY_PATTERN) {
        this.errorText = ToolUiKit.text($r('app.string.rr_err_pattern'));
      } else {
        this.errorText = ToolUiKit.text($r('app.string.rr_err_regex'));
      }
    }
    this.scheduleDraftSave();
  }

  build() {
    Column({ space: 16 }) {
      Column({ space: 10 }) {
        Text($r('app.string.rr_label_input'))
          .fontSize(scaled(12))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        TextArea({ text: this.input, placeholder: $r('app.string.rr_label_input') })
          .width('100%')
          .height(100)
          .fontSize(scaled(13))
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(12)
          .onChange((v: string) => {
            this.input = v;
            this.scheduleDraftSave();
          })
        TextInput({ text: this.pattern, placeholder: $r('app.string.rr_label_pattern') })
          .width('100%')
          .fontSize(scaled(13))
          .fontFamily('monospace')
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(10)
          .onChange((v: string) => {
            this.pattern = v;
            this.run();
          })
        Row({ space: 10 }) {
          TextInput({ text: this.flags, placeholder: $r('app.string.rr_label_flags') })
            .layoutWeight(1)
            .fontSize(scaled(13))
            .backgroundColor(colorOf(NGFColorToken.SURFACE))
            .borderRadius(10)
            .onChange((v: string) => {
              this.flags = v;
              this.run();
            })
          TextInput({ text: this.replacement, placeholder: $r('app.string.rr_label_replacement') })
            .layoutWeight(2)
            .fontSize(scaled(13))
            .backgroundColor(colorOf(NGFColorToken.SURFACE))
            .borderRadius(10)
            .onChange((v: string) => {
              this.replacement = v;
              this.run();
            })
        }
        .width('100%')
        Button($r('app.string.rr_action_clear'))
          .width('100%')
          .buttonStyle(ButtonStyleMode.NORMAL)
          .controlSize(ControlSize.NORMAL)
          .onClick(() => {
            this.input = '';
            this.pattern = '';
            this.replacement = '';
            this.result = null;
            this.errorText = '';
            this.flushDraft();
          })
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
            Text($r('app.string.rr_label_output'))
              .fontSize(scaled(12))
              .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
              .layoutWeight(1)
            Text(ToolUiKit.stringOf($r('app.string.rr_label_matches'), [String(this.result.matches.length)]))
              .fontSize(scaled(12))
              .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
            Text(this.copied ? $r('app.string.rr_copied') : $r('app.string.rr_action_copy'))
              .fontSize(scaled(12))
              .fontColor(colorOf(NGFColorToken.PRIMARY))
              .accessibilityText(ToolUiKit.text($r('app.string.copied_common')))
            .scale({ x: this.copied ? 1.08 : 1, y: this.copied ? 1.08 : 1 })
            .animation({ duration: MOTION_FEEDBACK_MS, curve: Curve.EaseOut })
              .margin({ left: 12 })
              .onClick(() => {
                ToolUiKit.copyText(this.result === null ? '' : this.result.replaced,
                  ToolUiKit.text($r('app.string.rr_copied')));
                this.copied = true;
                setTimeout((): void => {
                  this.copied = false;
                }, 1500);
              })
          }
          .width('100%')
          Text(this.result.replaced)
            .fontSize(scaled(13))
            .fontColor(colorOf(NGFColorToken.ON_SURFACE))
            .width('100%')
            .constraintSize({ maxHeight: 160 })
            .copyOption(CopyOptions.LocalDevice)
        }
        .width('100%')
        .padding(12)
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(12)
        .alignItems(HorizontalAlign.Start)
        .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: MOTION_SLIDE_VP })))
        .animation({ duration: MOTION_DURATION_MS, curve: Curve.EaseOut })

        if (this.result.matches.length > 0) {
          Column({ space: 4 }) {
            ForEach(this.result.matches, (m: RegexMatchItem, idx: number) => {
              Text('[' + String(m.index) + '] ' + m.matched)
                .fontSize(scaled(12))
                .fontFamily('monospace')
                .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
                .width('100%')
            }, (m: RegexMatchItem, idx: number) => idx + ':' + m.index + ':' + m.matched)
          }
          .width('100%')
          .padding(12)
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(12)
          .alignItems(HorizontalAlign.Start)
        }
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}