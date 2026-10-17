/**
 * 单位换算工具页。
 *
 * ## 布局：类别胶囊 + 数值 + 双单位 Select + 换算按钮 + 温度独立区
 *
 * 比例换算与温度换算分开两个区（温度是仿射语义）。
 * 单位选择用系统 Select（options 由 unitsOf 动态生成）。
 *
 * @module tools/unit-convert/UnitConvertPage
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
  convertTemperature,
  convertUnit,
  TempConvertResult,
  TempUnit,
  UnitCategory,
  UnitConvertResult,
  unitsOf
} from './UnitConvert';
import { unitFailureText } from './UnitConvertMessages';
import { MOTION_DURATION_MS, MOTION_SLIDE_VP } from '../../ui/Motion';
import { MOTION_FEEDBACK_MS } from '../../ui/Motion';
/** Select 选项（ArkTS 要求显式类而不是对象字面量） */
class UnitOption {
  value: string;

  constructor(value: string) {
    this.value = value;
  }
}

function toSelectOptions(ids: Array<string>): Array<UnitOption> {
  const out: Array<UnitOption> = [];
  for (let i = 0; i < ids.length; i++) {
    out.push(new UnitOption(ids[i]));
  }
  return out;
}

const TEMP_OPTIONS: Array<UnitOption> = [
  new UnitOption('C'), new UnitOption('F'), new UnitOption('K')
];

const TOOL_ID: string = 'unit-convert';
const DRAFT_DEBOUNCE_MS: number = 500;

@Builder
export function buildUnitConvertPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildUnitContent })
}

@Builder
function buildUnitContent() {
  UnitToolBody()
}

@Component
struct UnitToolBody {
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private value: string = '';
  @State private category: UnitCategory = UnitCategory.DATA;
  @State private fromId: string = 'gb';
  @State private toId: string = 'mb';
  @State private ratioResult: UnitConvertResult | null = null;
  @State private tempFrom: TempUnit = TempUnit.CELSIUS;
  @State private tempTo: TempUnit = TempUnit.FAHRENHEIT;
  @State private tempValue: string = '';
  @State private tempResult: TempConvertResult | null = null;
  @State private errorText: string = '';
  @State private copied: boolean = false;
  private draftTimer: number = -1;

  private onHistoryPick(): void {
  }

  aboutToAppear(): void {
    const saved: string = toolStateStore.readDraft(TOOL_ID);
    if (saved.length > 0) {
      this.value = saved;
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
    toolStateStore.writeDraft(TOOL_ID, this.value);
  }

  private runRatio(): void {
    const r: UnitConvertResult = convertUnit(this.category, this.value, this.fromId, this.toId);
    if (r.ok) {
      this.errorText = '';
      this.ratioResult = r;
    } else {
      this.errorText = unitFailureText(r.failure);
      this.ratioResult = null;
    }
  }

  private runTemp(): void {
    const r: TempConvertResult = convertTemperature(this.tempValue, this.tempFrom, this.tempTo);
    if (r.ok) {
      this.errorText = '';
      this.tempResult = r;
    } else {
      this.errorText = unitFailureText(r.failure);
      this.tempResult = null;
    }
  }

  private switchCategory(cat: UnitCategory): void {
    this.category = cat;
    const units = unitsOf(cat);
    this.fromId = units[0].id;
    this.toId = units.length > 1 ? units[1].id : units[0].id;
    this.ratioResult = null;
  }

  private unitLabelOf(category: UnitCategory, id: string): string {
    const units = unitsOf(category);
    for (let i = 0; i < units.length; i++) {
      if (units[i].id === id) {
        return units[i].id;
      }
    }
    return id;
  }

  private unitOptions(category: UnitCategory): Array<string> {
    return unitsOf(category).map((u) => u.id);
  }

  build() {
    Column({ space: 16 }) {
      this.buildCategorySection()
      this.buildRatioSection()
      this.buildTempSection()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildCategorySection() {
    Flex({ wrap: FlexWrap.Wrap }) {
      this.catChip($r('app.string.uc_cat_data'), UnitCategory.DATA)
      this.catChip($r('app.string.uc_cat_length'), UnitCategory.LENGTH)
      this.catChip($r('app.string.uc_cat_time'), UnitCategory.TIME)
      this.catChip($r('app.string.uc_cat_weight'), UnitCategory.WEIGHT)
    }
    .width('100%')
  }

  @Builder
  private catChip(label: ResourceStr, cat: UnitCategory) {
    Text(label)
      .fontSize(scaled(12))
      .fontColor(this.category === cat ? colorOf(NGFColorToken.ON_PRIMARY) : colorOf(NGFColorToken.ON_SURFACE))
      .backgroundColor(this.category === cat ? colorOf(NGFColorToken.PRIMARY) : colorOf(NGFColorToken.SURFACE))
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .borderRadius(16)
      .margin(2)
      .onClick(() => {
        this.switchCategory(cat);
      })
      .accessibilityText(ToolUiKit.text(label))
  }

  @Builder
  private buildRatioSection() {
    Column({ space: 10 }) {
      TextInput({ text: this.value, placeholder: $r('app.string.uc_label_value') })
        .width('100%')
        .fontSize(scaled(13))
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(10)
        .type(InputType.Number)
        .onChange((v: string) => {
          this.value = v;
          this.scheduleDraftSave();
        })
      Row({ space: 10 }) {
        Column({ space: 4 }) {
          Text($r('app.string.uc_label_from'))
            .fontSize(scaled(12))
            .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
          Select(toSelectOptions(this.unitOptions(this.category)))
            .selected(this.indexOfUnit(this.category, this.fromId))
            .value(this.fromId)
            .onSelect((index: number) => {
              const opts = this.unitOptions(this.category);
              if (index < opts.length) {
                this.fromId = opts[index];
              }
            })
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Column({ space: 4 }) {
          Text($r('app.string.uc_label_to'))
            .fontSize(scaled(12))
            .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
          Select(toSelectOptions(this.unitOptions(this.category)))
            .selected(this.indexOfUnit(this.category, this.toId))
            .value(this.toId)
            .onSelect((index: number) => {
              const opts = this.unitOptions(this.category);
              if (index < opts.length) {
                this.toId = opts[index];
              }
            })
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Row({ space: 12 }) {
        Button($r('app.string.uc_action_convert'))
          .layoutWeight(1)
          .onClick(() => {
            this.runRatio();
            this.flushDraft();
          })
        Button($r('app.string.uc_action_clear'))
          .layoutWeight(1)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .controlSize(ControlSize.NORMAL)
          .onClick(() => {
            this.value = '';
            this.ratioResult = null;
            this.errorText = '';
            this.flushDraft();
          })
      }
      .width('100%')

      if (this.errorText.length > 0) {
        Text(this.errorText)
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.WARNING))
          .width('100%')
          .padding(10)
          .backgroundColor(colorOf(NGFColorToken.WARNING_CONTAINER))
          .borderRadius(10)
      }

      if (this.ratioResult !== null) {
        Row({ space: 10 }) {
          Text($r('app.string.uc_label_result'))
            .fontSize(scaled(12))
            .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
          Text(String(this.ratioResult.value))
            .fontSize(scaled(16))
            .fontWeight(FontWeight.Medium)
            .fontColor(colorOf(NGFColorToken.ON_SURFACE))
            .layoutWeight(1)
            .copyOption(CopyOptions.LocalDevice)
          Text(this.copied ? $r('app.string.uc_copied') : $r('app.string.uc_action_copy'))
            .fontSize(scaled(12))
            .fontColor(colorOf(NGFColorToken.PRIMARY))
            .accessibilityText(ToolUiKit.text($r('app.string.copied_common')))
            .scale({ x: this.copied ? 1.08 : 1, y: this.copied ? 1.08 : 1 })
            .animation({ duration: MOTION_FEEDBACK_MS, curve: Curve.EaseOut })
            .onClick(() => {
              ToolUiKit.copyText(String(this.ratioResult === null ? '' : this.ratioResult.value),
                ToolUiKit.text($r('app.string.uc_copied')));
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
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  private indexOfUnit(category: UnitCategory, id: string): number {
    const opts = this.unitOptions(category);
    for (let i = 0; i < opts.length; i++) {
      if (opts[i] === id) {
        return i;
      }
    }
    return 0;
  }

  @Builder
  private buildTempSection() {
    Column({ space: 10 }) {
      Text($r('app.string.uc_label_temp'))
        .fontSize(scaled(13))
        .fontWeight(FontWeight.Medium)
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))
      Row({ space: 10 }) {
        TextInput({ text: this.tempValue, placeholder: $r('app.string.uc_label_value') })
          .layoutWeight(1)
          .fontSize(scaled(13))
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(10)
          .type(InputType.Number)
          .onChange((v: string) => {
            this.tempValue = v;
          })
        Select(TEMP_OPTIONS)
          .selected(this.tempIndex())
          .value(this.tempLabel())
          .onSelect((index: number) => {
            if (index === 0) {
              this.tempFrom = TempUnit.CELSIUS;
            } else if (index === 1) {
              this.tempFrom = TempUnit.FAHRENHEIT;
            } else {
              this.tempFrom = TempUnit.KELVIN;
            }
          })
          .width(110)
        Select(TEMP_OPTIONS)
          .selected(this.tempOutIndex())
          .value(this.tempOutLabel())
          .onSelect((index: number) => {
            if (index === 0) {
              this.tempTo = TempUnit.CELSIUS;
            } else if (index === 1) {
              this.tempTo = TempUnit.FAHRENHEIT;
            } else {
              this.tempTo = TempUnit.KELVIN;
            }
          })
          .width(110)
        Button($r('app.string.uc_action_convert'))
          .onClick(() => {
            this.runTemp();
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)

      if (this.tempResult !== null) {
        Text(String(this.tempResult.value))
          .fontSize(scaled(14))
          .fontWeight(FontWeight.Medium)
          .fontColor(colorOf(NGFColorToken.ON_SURFACE))
          .width('100%')
          .padding(10)
          .backgroundColor(colorOf(NGFColorToken.SURFACE))
          .borderRadius(10)
          .copyOption(CopyOptions.LocalDevice)
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor(colorOf(NGFColorToken.SURFACE))
    .borderRadius(12)
    .alignItems(HorizontalAlign.Start)
  }

  private tempIndex(): number {
    if (this.tempFrom === TempUnit.CELSIUS) {
      return 0;
    }
    if (this.tempFrom === TempUnit.FAHRENHEIT) {
      return 1;
    }
    return 2;
  }

  private tempOutIndex(): number {
    if (this.tempTo === TempUnit.CELSIUS) {
      return 0;
    }
    if (this.tempTo === TempUnit.FAHRENHEIT) {
      return 1;
    }
    return 2;
  }

  private tempLabel(): string {
    if (this.tempFrom === TempUnit.CELSIUS) {
      return '°C';
    }
    if (this.tempFrom === TempUnit.FAHRENHEIT) {
      return '°F';
    }
    return 'K';
  }

  private tempOutLabel(): string {
    if (this.tempTo === TempUnit.CELSIUS) {
      return '°C';
    }
    if (this.tempTo === TempUnit.FAHRENHEIT) {
      return '°F';
    }
    return 'K';
  }
}
