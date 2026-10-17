/**
 * 百分比计算工具页。
 *
 * ## 布局：五个方向 Tab + 按方向切换的输入组 + 结果
 *
 * 每个方向输入字段不同（占比两个、求部分两个……），用 if 分支渲染对应输入组。
 * 「加减 %」用 Toggle 选增/减。
 *
 * @module tools/percent-calc/PercentCalcPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import { NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { toolStateStore } from '../../core/ToolStateStore';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { ToolUiKit } from '../../ui/ToolUiKit';
import {
  applyPercent,
  changeRate,
  partOfTotal,
  PercentResult,
  percentOf as percentOfFn,
  totalFromPart
} from './PercentCalc';
import { percentFailureText } from './PercentCalcMessages';
import { MOTION_DURATION_MS, MOTION_FEEDBACK_MS, MOTION_SLIDE_VP } from '../../ui/Motion';

const TOOL_ID: string = 'percent-calc';
const DRAFT_DEBOUNCE_MS: number = 500;

/** 五个方向的标识 */
enum PercentTab {
  OF = 'of',
  PART = 'part',
  RATE = 'rate',
  TOTAL = 'total',
  APPLY = 'apply'
}

@Builder
export function buildPercentCalcPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildPercentContent })
}

@Builder
function buildPercentContent() {
  PercentToolBody()
}

@Component
struct PercentToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private tab: PercentTab = PercentTab.OF;
  @State private a: string = '';
  @State private b: string = '';
  @State private positive: boolean = true;
  @State private result: PercentResult | null = null;
  @State private errorText: string = '';
  @State private copied: boolean = false;
  private draftTimer: number = -1;

  private onHistoryPick(): void {
  }

  aboutToAppear(): void {
    const saved: string = toolStateStore.readDraft(TOOL_ID);
    if (saved.length > 0) {
      this.a = saved;
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
    toolStateStore.writeDraft(TOOL_ID, this.a);
  }

  private run(): void {
    // 空输入也走 percentOf 的 EMPTY_INPUT 路径，不在此处构造失败对象
    let r: PercentResult = percentOfFn(this.a, this.b);
    if (this.tab === PercentTab.OF) {
      r = percentOfFn(this.a, this.b);
    } else if (this.tab === PercentTab.PART) {
      r = partOfTotal(this.a, this.b);
    } else if (this.tab === PercentTab.RATE) {
      r = changeRate(this.a, this.b);
    } else if (this.tab === PercentTab.TOTAL) {
      r = totalFromPart(this.a, this.b);
    } else {
      r = applyPercent(this.a, this.b, this.positive);
    }
    if (r.ok) {
      this.errorText = '';
      this.result = r;
    } else {
      this.errorText = percentFailureText(r.failure);
      this.result = null;
    }
  }

  private resultToText(result: PercentResult | null): string {
    return result === null ? '' : String(result.value);
  }

  build() {
    Column({ space: 16 }) {
      this.buildTabSection()
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
        Row({ space: 10 }) {
          Text($r('app.string.pc_label_result'))
            .fontSize(scaled(13))
            .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
          Text(this.resultToText(this.result))
            .fontSize(scaled(16))
            .fontWeight(FontWeight.Medium)
            .fontColor(colorOf(NGFColorToken.ON_SURFACE))
            .layoutWeight(1)
            .copyOption(CopyOptions.LocalDevice)
          Text(this.copied ? $r('app.string.pc_copied') : $r('app.string.pc_action_copy'))
            .fontSize(scaled(12))
            .fontColor(colorOf(NGFColorToken.PRIMARY))
            .accessibilityText(ToolUiKit.text($r('app.string.copied_common')))
            .scale({ x: this.copied ? 1.08 : 1, y: this.copied ? 1.08 : 1 })
            .animation({ duration: MOTION_FEEDBACK_MS, curve: Curve.EaseOut })
            .onClick(() => {
              ToolUiKit.copyText(this.resultToText(this.result), ToolUiKit.text($r('app.string.pc_copied')));
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
        .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: MOTION_SLIDE_VP })))
        .animation({ duration: MOTION_DURATION_MS, curve: Curve.EaseOut })
      }
      Text($r('app.string.pc_hint_asym'))
        .fontSize(scaled(12))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildTabSection() {
    Flex({ wrap: FlexWrap.Wrap }) {
      this.tabChip($r('app.string.pc_tab_of'), PercentTab.OF)
      this.tabChip($r('app.string.pc_tab_part'), PercentTab.PART)
      this.tabChip($r('app.string.pc_tab_rate'), PercentTab.RATE)
      this.tabChip($r('app.string.pc_tab_total'), PercentTab.TOTAL)
      this.tabChip($r('app.string.pc_tab_apply'), PercentTab.APPLY)
    }
    .width('100%')
  }

  @Builder
  private tabChip(label: ResourceStr, tab: PercentTab) {
    Text(label)
      .fontSize(scaled(12))
      .fontColor(this.tab === tab ? colorOf(NGFColorToken.ON_PRIMARY) : colorOf(NGFColorToken.ON_SURFACE))
      .backgroundColor(this.tab === tab ? colorOf(NGFColorToken.PRIMARY) : colorOf(NGFColorToken.SURFACE))
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .borderRadius(16)
      .margin(2)
      .onClick(() => {
        this.tab = tab;
        this.result = null;
        this.errorText = '';
      })
      .accessibilityText(ToolUiKit.text(label))
  }

  @Builder
  private inputField(label: ResourceStr, value: string, onChange: (v: string) => void) {
    Column({ space: 4 }) {
      Text(label)
        .fontSize(scaled(12))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
      TextInput({ text: value })
        .width('100%')
        .fontSize(scaled(13))
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(10)
        .type(InputType.Number)
        .onChange(onChange)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildInputSection() {
    Column({ space: 10 }) {
      if (this.tab === PercentTab.OF) {
        this.inputField($r('app.string.pc_of_part'), this.a, (v: string) => {
          this.a = v;
          this.scheduleDraftSave();
        })
        this.inputField($r('app.string.pc_of_total'), this.b, (v: string) => {
          this.b = v;
        })
      } else if (this.tab === PercentTab.PART) {
        this.inputField($r('app.string.pc_part_total'), this.a, (v: string) => {
          this.a = v;
          this.scheduleDraftSave();
        })
        this.inputField($r('app.string.pc_part_percent'), this.b, (v: string) => {
          this.b = v;
        })
      } else if (this.tab === PercentTab.RATE) {
        this.inputField($r('app.string.pc_rate_from'), this.a, (v: string) => {
          this.a = v;
          this.scheduleDraftSave();
        })
        this.inputField($r('app.string.pc_rate_to'), this.b, (v: string) => {
          this.b = v;
        })
      } else if (this.tab === PercentTab.TOTAL) {
        this.inputField($r('app.string.pc_total_part'), this.a, (v: string) => {
          this.a = v;
          this.scheduleDraftSave();
        })
        this.inputField($r('app.string.pc_total_percent'), this.b, (v: string) => {
          this.b = v;
        })
      } else {
        this.inputField($r('app.string.pc_apply_base'), this.a, (v: string) => {
          this.a = v;
          this.scheduleDraftSave();
        })
        this.inputField($r('app.string.pc_apply_percent'), this.b, (v: string) => {
          this.b = v;
        })
        Row({ space: 8 }) {
          Toggle({ type: ToggleType.Checkbox, isOn: this.positive })
            .onChange((on: boolean) => {
              this.positive = on;
            })
            .accessibilityText($r('app.string.pc_apply_percent'))
          Text(this.positive ? $r('app.string.pc_apply_up') : $r('app.string.pc_apply_down'))
            .fontSize(scaled(13))
            .fontColor(colorOf(NGFColorToken.ON_SURFACE))
        }
        .width('100%')
      }

      Row({ space: 12 }) {
        Button($r('app.string.pc_action_calc'))
          .layoutWeight(1)
          .onClick(() => {
            this.run();
            this.flushDraft();
          })
        Button($r('app.string.pc_action_clear'))
          .layoutWeight(1)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .controlSize(ControlSize.NORMAL)
          .onClick(() => {
            this.a = '';
            this.b = '';
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
}
