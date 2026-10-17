/**
 * Changelog 生成工具页。
 *
 * ## 布局：提交清单输入 + Markdown 输出 + 归类统计
 *
 * @module tools/changelog-gen/ChangelogPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { toolStateStore } from '../../core/ToolStateStore';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { ToolUiKit } from '../../ui/ToolUiKit';
import { ChangelogFailureCode, ChangelogResult, generateChangelog } from './ChangelogLogic';
import { MOTION_FEEDBACK_MS } from '../../ui/Motion';
import { MOTION_DURATION_MS, MOTION_SLIDE_VP } from '../../ui/Motion';

const TOOL_ID: string = 'changelog-gen';
const DRAFT_DEBOUNCE_MS: number = 500;

@Builder
export function buildChangelogGenPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildChangelogContent })
}

@Builder
function buildChangelogContent() {
  ChangelogToolBody()
}

@Component
struct ChangelogToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private input: string = '';
  @State private result: ChangelogResult | null = null;
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
    const r: ChangelogResult = generateChangelog(this.input);
    if (r.ok) {
      this.errorText = '';
      this.result = r;
    } else {
      this.errorText = ToolUiKit.text($r('app.string.cg_err_empty'));
      this.result = null;
    }
    this.scheduleDraftSave();
  }

  build() {
    Column({ space: 16 }) {
      Column({ space: 10 }) {
        Text($r('app.string.cg_label_input'))
          .fontSize(scaled(12))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        TextArea({ text: this.input, placeholder: $r('app.string.cg_placeholder_input') })
          .width('100%')
          .height(130)
          .fontSize(scaled(13))
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(12)
          .onChange((v: string) => {
            this.input = v;
            this.scheduleDraftSave();
          })
        Row({ space: 12 }) {
          Button($r('app.string.cg_action_build'))
            .layoutWeight(1)
            .onClick(() => {
              this.run();
              this.flushDraft();
            })
          Button($r('app.string.cg_action_clear'))
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
            Text($r('app.string.cg_label_output'))
              .fontSize(scaled(12))
              .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
              .layoutWeight(1)
            Text(ToolUiKit.stringOf($r('app.string.cg_label_stats'),
              [String(this.result.classifiedCount), String(this.result.otherCount)]))
              .fontSize(scaled(12))
              .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
            Text(this.copied ? $r('app.string.cg_copied') : $r('app.string.cg_action_copy'))
              .fontSize(scaled(12))
              .fontColor(colorOf(NGFColorToken.PRIMARY))
              .accessibilityText(ToolUiKit.text($r('app.string.copied_common')))
            .scale({ x: this.copied ? 1.08 : 1, y: this.copied ? 1.08 : 1 })
            .animation({ duration: MOTION_FEEDBACK_MS, curve: Curve.EaseOut })
              .margin({ left: 12 })
              .onClick(() => {
                ToolUiKit.copyText(this.result === null ? '' : this.result.markdown,
                  ToolUiKit.text($r('app.string.cg_copied')));
                this.copied = true;
                setTimeout((): void => {
                  this.copied = false;
                }, 1500);
              })
          }
          .width('100%')
          Text(this.result.markdown)
            .fontSize(scaled(12))
            .fontFamily('monospace')
            .fontColor(colorOf(NGFColorToken.ON_SURFACE))
            .width('100%')
            .constraintSize({ maxHeight: 260 })
            .copyOption(CopyOptions.LocalDevice)
        }
        .width('100%')
        .padding(12)
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(12)
        .alignItems(HorizontalAlign.Start)
        .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: MOTION_SLIDE_VP })))
        .animation({ duration: MOTION_DURATION_MS, curve: Curve.EaseOut })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}