/**
 * 两色混合工具页。
 *
 * ## 布局：双色输入 + 步数 + 渐变色带（色块行 + hex 行）
 *
 * @module tools/color-blend/ColorBlendPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { toolStateStore } from '../../core/ToolStateStore';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { ToolUiKit } from '../../ui/ToolUiKit';
import { BlendFailureCode, BlendResult, BlendSwatch, blendColors } from './ColorBlendLogic';

const TOOL_ID: string = 'color-blend';
const DRAFT_DEBOUNCE_MS: number = 500;

@Builder
export function buildColorBlendPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildBlendContent })
}

@Builder
function buildBlendContent() {
  BlendToolBody()
}

@Component
struct BlendToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private aText: string = '';
  @State private bText: string = '';
  @State private stepsText: string = '6';
  @State private result: BlendResult | null = null;
  @State private errorText: string = '';
  @State private copied: boolean = false;
  private draftTimer: number = -1;

  private onHistoryPick(): void {
  }

  aboutToAppear(): void {
    const saved: string = toolStateStore.readDraft(TOOL_ID);
    if (saved.length > 0) {
      this.aText = saved;
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
    toolStateStore.writeDraft(TOOL_ID, this.aText);
  }

  private run(): void {
    const steps: number = parseInt(this.stepsText, 10);
    const r: BlendResult = blendColors(this.aText, this.bText, isNaN(steps) ? 6 : steps);
    if (r.ok) {
      this.errorText = '';
      this.result = r;
    } else {
      this.result = null;
      this.errorText = r.failure.code === BlendFailureCode.EMPTY_INPUT
        ? ToolUiKit.text($r('app.string.cb2_err_empty'))
        : ToolUiKit.text($r('app.string.cb2_err_color'));
    }
    this.scheduleDraftSave();
  }

  build() {
    Column({ space: 16 }) {
      Column({ space: 10 }) {
        Row({ space: 10 }) {
          TextInput({ text: this.aText, placeholder: $r('app.string.cb2_label_a') })
            .layoutWeight(1)
            .fontSize(scaled(13))
            .backgroundColor(colorOf(NGFColorToken.SURFACE))
            .borderRadius(10)
            .onChange((v: string) => {
              this.aText = v;
              this.scheduleDraftSave();
            })
          TextInput({ text: this.bText, placeholder: $r('app.string.cb2_label_b') })
            .layoutWeight(1)
            .fontSize(scaled(13))
            .backgroundColor(colorOf(NGFColorToken.SURFACE))
            .borderRadius(10)
            .onChange((v: string) => {
              this.bText = v;
              this.scheduleDraftSave();
            })
        }
        .width('100%')
        TextInput({ text: this.stepsText, placeholder: $r('app.string.cb2_label_steps') })
          .width('100%')
          .fontSize(scaled(13))
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(10)
          .onChange((v: string) => {
            this.stepsText = v;
            this.scheduleDraftSave();
          })
        Row({ space: 12 }) {
          Button($r('app.string.cb2_action_blend'))
            .layoutWeight(1)
            .onClick(() => {
              this.run();
              this.flushDraft();
            })
          Button($r('app.string.cb2_action_clear'))
            .buttonStyle(ButtonStyleMode.NORMAL)
            .controlSize(ControlSize.NORMAL)
            .layoutWeight(1)
            .onClick(() => {
              this.aText = '';
              this.bText = '';
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
            Text($r('app.string.cb2_label_band'))
              .fontSize(scaled(12))
              .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
              .layoutWeight(1)
            Text(this.copied ? $r('app.string.cb2_copied') : $r('app.string.cb2_action_copy'))
              .fontSize(scaled(12))
              .fontColor(colorOf(NGFColorToken.PRIMARY))
              .accessibilityText(ToolUiKit.text($r('app.string.copied_common')))
              .onClick(() => {
                const hexes: Array<string> = [];
                for (let i = 0; i < (this.result === null ? 0 : this.result.swatches.length); i++) {
                  hexes.push(this.result === null ? '' : this.result.swatches[i].hex);
                }
                ToolUiKit.copyText(hexes.join(', '), ToolUiKit.text($r('app.string.cb2_copied')));
                this.copied = true;
                setTimeout((): void => {
                  this.copied = false;
                }, 1500);
              })
          }
          .width('100%')
          Row() {
            ForEach(this.result.swatches, (s: BlendSwatch) => {
              Column() {}
                .layoutWeight(1)
                .height(44)
                .backgroundColor(s.hex)
            }, (s: BlendSwatch) => s.hex)
          }
          .width('100%')
          .borderRadius(8)
          .clip(true)
          ForEach(this.result.swatches, (s: BlendSwatch) => {
            Text(s.hex)
              .fontSize(scaled(10))
              .fontFamily('monospace')
              .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
              .layoutWeight(1)
              .textAlign(TextAlign.Center)
          }, (s: BlendSwatch) => s.hex)
        }
        .width('100%')
        .padding(12)
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(12)
        .alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
