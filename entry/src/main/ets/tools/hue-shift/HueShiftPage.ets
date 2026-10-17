/**
 * 色相微调工具页。
 *
 * ## 布局：色输入 + 两个偏移输入 + 结果色卡（hex 可复制）
 *
 * @module tools/hue-shift/HueShiftPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { toolStateStore } from '../../core/ToolStateStore';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { ToolUiKit } from '../../ui/ToolUiKit';
import { HueShiftFailureCode, HueShiftResult, shiftHue } from './HueShiftLogic';

const TOOL_ID: string = 'hue-shift';
const DRAFT_DEBOUNCE_MS: number = 500;

@Builder
export function buildHueShiftPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildHueContent })
}

@Builder
function buildHueContent() {
  HueToolBody()
}

@Component
struct HueToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private input: string = '';
  @State private hueText: string = '0';
  @State private lightText: string = '0';
  @State private result: HueShiftResult | null = null;
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
    const hue: number = parseInt(this.hueText, 10);
    const light: number = parseInt(this.lightText, 10);
    const r: HueShiftResult = shiftHue(this.input, isNaN(hue) ? 0 : hue, isNaN(light) ? 0 : light);
    if (r.ok) {
      this.errorText = '';
      this.result = r;
    } else {
      this.result = null;
      this.errorText = r.failure.code === HueShiftFailureCode.EMPTY_INPUT

        ? ToolUiKit.text($r('app.string.hs_err_empty'))
        : ToolUiKit.stringOf($r('app.string.hs_err_bad'), r.failure.args);
    }
    this.scheduleDraftSave();
  }

  build() {
    Column({ space: 16 }) {
      Column({ space: 10 }) {
        TextInput({ text: this.input, placeholder: $r('app.string.hs_label_color') })
          .width('100%')
          .fontSize(scaled(13))
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(10)
          .onChange((v: string) => {
            this.input = v;
            this.scheduleDraftSave();
          })
        Row({ space: 10 }) {
          TextInput({ text: this.hueText, placeholder: $r('app.string.hs_label_hue') })
            .layoutWeight(1)
            .fontSize(scaled(13))
            .backgroundColor(colorOf(NGFColorToken.SURFACE))
            .borderRadius(10)
            .onChange((v: string) => {
              this.hueText = v;
              this.scheduleDraftSave();
            })
          TextInput({ text: this.lightText, placeholder: $r('app.string.hs_label_light') })
            .layoutWeight(1)
            .fontSize(scaled(13))
            .backgroundColor(colorOf(NGFColorToken.SURFACE))
            .borderRadius(10)
            .onChange((v: string) => {
              this.lightText = v;
              this.scheduleDraftSave();
            })
        }
        .width('100%')
        Row({ space: 12 }) {
          Button($r('app.string.hs_action_apply'))
            .layoutWeight(1)
            .onClick(() => {
              this.run();
              this.flushDraft();
            })
          Button($r('app.string.hs_action_clear'))
            .buttonStyle(ButtonStyleMode.NORMAL)
            .controlSize(ControlSize.NORMAL)
            .layoutWeight(1)
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
        Row({ space: 12 }) {
          Column() {}
            .width(56)
            .height(56)
            .borderRadius(10)
            .backgroundColor(this.result.hex)
            .border({ width: 1, color: colorOf(NGFColorToken.OUTLINE_VARIANT) })
          Column({ space: 4 }) {
            Text(this.result.hex)
              .fontSize(scaled(16))
              .fontWeight(FontWeight.Bold)
              .fontColor(colorOf(NGFColorToken.ON_SURFACE))
              .copyOption(CopyOptions.LocalDevice)
            Text('H' + String(Math.round(this.result.hue)) + ' S' + String(Math.round(this.result.saturation)) + '% L' + String(Math.round(this.result.lightness)) + '%')
              .fontSize(scaled(12))
              .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          Text(this.copied ? $r('app.string.hs_copied') : $r('app.string.hs_action_copy'))
            .fontSize(scaled(12))
            .fontColor(colorOf(NGFColorToken.PRIMARY))
            .accessibilityText(ToolUiKit.text($r('app.string.hs_action_copy')))
            .onClick(() => {
              ToolUiKit.copyText(this.result === null ? '' : this.result.hex,
                ToolUiKit.text($r('app.string.hs_copied')));
              this.copied = true;
              setTimeout((): void => {
                this.copied = false;
              }, 1500);
            })
        }
        .width('100%')
        .padding(12)
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(12)
        .alignItems(VerticalAlign.Center)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}