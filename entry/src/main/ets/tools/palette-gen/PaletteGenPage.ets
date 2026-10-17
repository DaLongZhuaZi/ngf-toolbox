/**
 * 色板生成工具页。
 *
 * ## 布局：输入 + 方案胶囊 + 分组色板（每组 5 档色块，可点复制 hex）
 *
 * 色块用 Column 渲染（SWATCH 类），点击复制 hex——设计工具的核心交互。
 *
 * @module tools/palette-gen/PaletteGenPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { toolStateStore } from '../../core/ToolStateStore';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { ToolUiKit } from '../../ui/ToolUiKit';
import { harmonyOptions, NGFHarmonyOption } from '../color-convert/ColorConvert';
import { generatePalette, PaletteResult } from './PaletteGen';
import { PaletteSwatch } from './PaletteGen';
import { paletteFailureText } from './PaletteGenMessages';
import { MOTION_DURATION_MS, MOTION_SLIDE_VP } from '../../ui/Motion';

const TOOL_ID: string = 'palette-gen';
const DRAFT_DEBOUNCE_MS: number = 500;

@Builder
export function buildPaletteGenPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildPaletteContent })
}

@Builder
function buildPaletteContent() {
  PaletteToolBody()
}

@Component
struct PaletteToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private input: string = '';
  @State private harmonyKind: string = 'complementary';
  @State private result: PaletteResult | null = null;
  @State private errorText: string = '';
  @State private copied: string = '';
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
    const r: PaletteResult = generatePalette(this.input, this.harmonyKind);
    if (r.ok) {
      this.errorText = '';
      this.result = r;
    } else {
      this.errorText = paletteFailureText(r.failure);
      this.result = null;
    }
    this.scheduleDraftSave();
  }

  private copySwatch(hex: string): void {
    ToolUiKit.copyText(hex, ToolUiKit.text($r('app.string.pg_copied')));
    this.copied = hex;
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
        ForEach(this.result.groups, (group: PaletteSwatch[], gi: number) => {
          Row({ space: 6 }) {
            ForEach(group, (swatch: PaletteSwatch, si: number) => {
              Column({ space: 4 }) {
                Column() {}
                  .width(52)
                  .height(52)
                  .borderRadius(10)
                  .backgroundColor(swatch.hex)
                  .border({ width: swatch.isBase ? 3 : 1,
                    color: swatch.isBase ? colorOf(NGFColorToken.ON_SURFACE)
                      : colorOf(NGFColorToken.ON_SURFACE_VARIANT) })
                Text(swatch.hex)
                  .fontSize(scaled(10))
                  .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
              }
              .onClick(() => {
                this.copySwatch(swatch.hex);
              })
              .accessibilityText(swatch.hex)
            }, (swatch: PaletteSwatch, si: number) => gi + '-' + si + '-' + swatch.hex)
          }
          .width('100%')
        }, (group: PaletteSwatch[], gi: number) => gi + ':' + group[2].hex)
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
      Column({ space: 4 }) {
        Text($r('app.string.pg_label_input'))
          .fontSize(scaled(12))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        TextInput({ text: this.input, placeholder: $r('app.string.pg_placeholder_input') })
          .width('100%')
          .fontSize(scaled(13))
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(10)
          .onChange((v: string) => {
            this.input = v;
            this.scheduleDraftSave();
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Column({ space: 6 }) {
        Text($r('app.string.pg_label_harmony'))
          .fontSize(scaled(12))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        Flex({ wrap: FlexWrap.Wrap }) {
          this.chip(ToolUiKit.text($r('app.string.pg_chip_luma')), '')
          ForEach(harmonyOptions(), (opt: NGFHarmonyOption) => {
            this.chip(opt.label.zh, opt.kind)
          }, (opt: NGFHarmonyOption) => opt.kind)
        }
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Row({ space: 12 }) {
        Button($r('app.string.pg_action_generate'))
          .layoutWeight(1)
          .onClick(() => {
            this.run();
            this.flushDraft();
          })
        Button($r('app.string.pg_action_clear'))
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
  private chip(label: string, kind: string) {
    Text(label)
      .fontSize(scaled(12))
      .fontColor(this.harmonyKind === kind ? colorOf(NGFColorToken.ON_PRIMARY) : colorOf(NGFColorToken.ON_SURFACE))
      .backgroundColor(this.harmonyKind === kind ? colorOf(NGFColorToken.PRIMARY) : colorOf(NGFColorToken.SURFACE))
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .borderRadius(16)
      .margin(2)
      .onClick(() => {
        this.harmonyKind = kind;
      })
      .accessibilityText(label)
  }
}
