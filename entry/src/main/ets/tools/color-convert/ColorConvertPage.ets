/**
 * 颜色转换工具页。
 *
 * ## 为什么提供「色板」而不只靠输入框
 *
 * 手机上敲十六进制色值很别扭（要不停切键盘）。而颜色工具的高频用法是
 * 「我看到一个颜色，想看看它的其它表示」——没有取色器可用时，
 * 一排常用色板能让用户两下就点到自己想要的那类颜色，再去微调数字。
 * 真正的屏幕取色需要平台能力，本工具不做（已写在工具边界里）。
 *
 * ## 为什么明暗调整用一排按钮而不是滑杆
 *
 * 滑杆在手机上容易误触、也难以回到「上一档」。设计工作里调明暗本来就是**分档**行为
 * （浅一档、深一档），因此用固定的几档按钮，点一下就是确定的一步。
 *
 * @module tools/color-convert/ColorConvertPage
 */

import { toolboxPalette } from '../../core/ToolboxPalette';
import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../../ui/FontScaleSource';
import { TOOLBOX_HISTORY_PICK_SEQ } from '../../ui/HistoryPick';
import {
  NGFColorValue, NGFColorToken } from 'ngf_framework';
import { colorOf, TOOLBOX_DARK_KEY } from '../../ui/ThemeSource';
import { ToolPageParams } from '../../core/ToolPageContract';
import { toolStateStore } from '../../core/ToolStateStore';
import { ToolScaffold } from '../../ui/ToolScaffold';
import { ToolUiKit } from '../../ui/ToolUiKit';
import { currentLocale, FALLBACK_LOCALE } from '../../ui/LocaleSource';
import {
  adjustLightness,
  buildReport,
  ColorParseResult,
  evaluateContrast,
  harmony,
  harmonyOptions,
  lightnessScale,
  NGFColor,
  NGFColorReport,
  NGFHarmonyOption,
  parseColor,
  readableTextColor,
  toHex
} from './ColorConvert';
import {
  colorNoticeTexts,
  colorParseFailureText,
  contrastVerdictText,
  copiedColorText,
  copiedLabelText,
  formatColorText,
  harmonyLabel,
  lightnessStepText
} from './ColorConvertMessages';

/** 工具 id：草稿按它存取，必须与 ToolsCatalog 里登记的 id 一致 */
const TOOL_ID: string = 'color-convert';

/** 草稿写入防抖（毫秒） */
const DRAFT_DEBOUNCE_MS: number = 400;

/** 色板：常用颜色，点一下即填入 */
const SWATCHES: Array<string> = [
  '#0962F2', '#1F8A4C', '#D94838', '#F0B457', '#7B5BF2', '#0FA3A3',
  '#FF6B9D', '#8B5E3C', '#182431', '#6B7787', '#E4E7EB', '#FFFFFF'
];

/** 明暗调整档位（比例，正数调亮） */
const LIGHTNESS_STEPS: Array<number> = [-0.3, -0.15, 0.15, 0.3];

/** 结果里的一行 */
class ColorRow {
  /** 行标签走资源键，所以是 ResourceStr */
  readonly label: ResourceStr;
  readonly value: string;

  constructor(label: ResourceStr, value: string) {
    this.label = label;
    this.value = value;
  }
}

@Builder
export function buildColorConvertPage(params: ToolPageParams) {
  ToolScaffold({ context: params.context, content: buildColorConvertContent })
}

@Builder
function buildColorConvertContent() {
  ColorConvertToolBody()
}

@Component
struct ColorConvertToolBody {
  /** 订阅主题深浅；本字段本身不用，作用是在主题切换时触发本组件重渲染。 */
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  /** 订阅字体缩放；本字段不用，作用是切字号时触发本组件重渲染。 */
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  /** 历史回填序号；变化时由 @Watch 触发 onHistoryPick（见 ui/HistoryPick.ets） */
  @StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch('onHistoryPick') historyPickSeq: number = 0;
  @State private input: string = '#0962F2';
  @State private errorText: string = '';
  @State private noticeText: string = '';
  @State private color: NGFColor = NGFColor.of(9, 98, 242);
  @State private report: NGFColorReport = buildReport(NGFColor.of(9, 98, 242));
  @State private harmonyKind: string = 'complementary';
  @State private harmonyColors: Array<NGFColor> = [];
  @State private scaleColors: Array<NGFColor> = [];
  @State private reportText: string = '';
  /** 当前语言：配色方案名是双语数据，按它取 */
  @State private locale: string = FALLBACK_LOCALE;

  /**
   * 主题 Token 表（产品定义稿 §四 第 51 行：颜色转换顺带演示 uiTheme 的 Token 体系）。
   *
   * 是**普通字段**而不是 @State：色表本身不随时间变，变的是「当前哪个主题生效」，
   * 而那件事由 colorOf() 在取色时现算。放成 @State 只会白白多一次 diff。
   */
  private tokens: Array<NGFColorValue> = toolboxPalette();

  private draftTimer: number = -1;

  /** 用户在壳层选中一条历史 → 从草稿重读本次输入（见 ui/HistoryPick.ets） */

  private onHistoryPick(): void {

    const restored: string = toolStateStore.readDraft(TOOL_ID);

    if (restored.length === 0) {

      return;

    }

    this.input = restored;

  }


  aboutToAppear(): void {
    this.locale = currentLocale();
    const saved: string = toolStateStore.readDraft(TOOL_ID);
    // 只恢复**能解析**的草稿。
    //
    // 起因是真机上看到的一个状态：本工具打开后挂着红字「认不出这个写法」。
    // 复现路径是「粘进了坏值 → 离开 → 再打开」——草稿把那份解析不了的原文带了回来。
    //
    // ⚠️ 这里要老实说明一点：**根因没有完全查实**。
    // 当时的现场是「输入框显示 #0962F2（合法）而红字在」，两者对不上；
    // 而 `TextInput({ text: this.input })` 用的就是原文，本该显示那份坏草稿。
    // 所以「草稿是坏值」能解释红字，却解释不了输入框为什么显示的是合法值。
    // 无法再复现那个现场了，下面的改动**消除了症状**（真机验证：红字消失、
    // 四种表示形式照常输出），但**不能声称查清了根因**。
    //
    // 无论根因如何，这条规则本身成立：草稿的意义是「恢复没做完的活」，
    // 恢复一份解析不了的原文，只会让用户一打开工具就吃一个自己没造成的错。
    if (saved.length > 0 && parseColor(saved).ok) {
      this.input = saved;
    }
    this.recalculate();
  }

  aboutToDisappear(): void {
    this.flushDraft();
  }

  build() {
    Column({ space: 16 }) {
      this.buildInputSection()
      if (this.errorText.length > 0) {
        this.buildError()
      }
      this.buildPreviewSection()
      this.buildValuesSection()
      this.buildLightnessSection()
      this.buildContrastSection()
      this.buildHarmonySection()
      this.buildScaleSection()
        this.buildTokenSection()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 输入区 + 色板 */
  @Builder
  private buildInputSection() {
    Column({ space: 8 }) {
      Text($r('app.string.color_label_input'))
        .fontSize(scaled(15))
        .fontWeight(FontWeight.Medium)
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))

      TextInput({ text: this.input, placeholder: $r('app.string.color_placeholder_input') })
        .width('100%')
        .height(44)
        .fontSize(scaled(15))
        .backgroundColor(colorOf(NGFColorToken.SURFACE))
        .borderRadius(12)
        .onChange((value: string) => {
          this.input = value;
          this.scheduleDraftSave(value);
          this.recalculate();
        })

      Text($r('app.string.color_input_hint'))
        .fontSize(scaled(12))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        .width('100%')

      // 色板
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(SWATCHES, (swatch: string) => {
          Stack() {
            // 用两层：外层是边框，内层是纯色块，避免白色色块在浅色背景上"消失"
          }
          .width(36)
          .height(36)
          .backgroundColor(swatch)
          .borderRadius(8)
          .border({ width: 1, color: colorOf(NGFColorToken.OUTLINE_VARIANT) })
          .margin({ right: 8, bottom: 8 })
          .accessibilityText(swatch + ' ' + ToolUiKit.text($r('app.string.color_swatch_pick')))
          .accessibilityLevel('yes')
          .onClick(() => {
            this.input = swatch;
            this.scheduleDraftSave(swatch);
            this.recalculate();
          })
        }, (swatch: string) => swatch)
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildError() {
    Text(this.errorText)
      .fontSize(scaled(13))
      .fontColor(colorOf(NGFColorToken.ERROR_COLOR))
      .width('100%')
      .padding(12)
      .backgroundColor(colorOf(NGFColorToken.ERROR_CONTAINER))
      .borderRadius(12)
  }

  /** 预览：大色块 + 建议前景色示意 */
  @Builder
  private buildPreviewSection() {
    Column({ space: 8 }) {
      Stack() {
        Text($r('app.string.color_label_preview'))
          .fontSize(scaled(14))
          .fontColor(toHex(readableTextColor(this.color)))
      }
      .width('100%')
      .height(96)
      .backgroundColor(this.inputForPreview())
      .borderRadius(12)
      .border({ width: 1, color: colorOf(NGFColorToken.OUTLINE_VARIANT) })

      if (this.noticeText.length > 0) {
        Text(this.noticeText)
          .fontSize(scaled(12))
          .fontColor(colorOf(NGFColorToken.WARNING))
          .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /**
   * 预览用的背景色字符串。
   *
   * 直接传用户输入的那段文本（例如 'hsl(217, 93%, 49%)'）而不是我们算出来的 HEX：
   * ArkUI 的 backgroundColor 能解析常见颜色字符串，用原文能让用户**立刻看到自己写的格式对不对**。
   * 解析失败时退化为已算出的 HEX（那时说明输入确实不合法，但预览不该消失）。
   */
  private inputForPreview(): string {
    return this.errorText.length > 0 ? toHex(this.color) : this.input;
  }

  /** 全部表示形式 */
  @Builder
  private buildValuesSection() {
    Column({ space: 10 }) {
      Row() {
        Text($r('app.string.color_label_forms'))
          .fontSize(scaled(15))
          .fontWeight(FontWeight.Medium)
          .fontColor(colorOf(NGFColorToken.ON_SURFACE))
        Blank()
        Text($r('app.string.shell_action_copy_all'))
          .fontSize(scaled(13))
          .fontColor(colorOf(NGFColorToken.PRIMARY))
          .accessibilityText(ToolUiKit.text($r('app.string.copied_common')))
          .onClick(() => {
            ToolUiKit.copyText(this.reportText, ToolUiKit.text($r('app.string.color_copied_report')));
          })
      }
      .width('100%')

      ForEach(this.valueRows(), (row: ColorRow) => {
        Row() {
          Text(row.label)
            .fontSize(scaled(13))
            .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
            .width(72)
          Text(row.value)
            .fontSize(scaled(14))
            .fontColor(colorOf(NGFColorToken.ON_SURFACE))
            .layoutWeight(1)
            .textSelectable(TextSelectableMode.SELECTABLE_UNFOCUSABLE)
          Text($r('app.string.shell_action_copy'))
            .fontSize(scaled(12))
            .fontColor(colorOf(NGFColorToken.PRIMARY))
            .accessibilityText(ToolUiKit.text($r('app.string.copied_common')))
            .onClick(() => {
              ToolUiKit.copyText(row.value, copiedLabelText(ToolUiKit.stringOf(row.label, [])));
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      }, (row: ColorRow) => ToolUiKit.text(row.label))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .backgroundColor(colorOf(NGFColorToken.SURFACE_VARIANT))
    .borderRadius(12)
  }

  /** 明暗调整 */
  @Builder
  private buildLightnessSection() {
    Column({ space: 8 }) {
      Text($r('app.string.color_label_lightness'))
        .fontSize(scaled(15))
        .fontWeight(FontWeight.Medium)
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))

      Row({ space: 8 }) {
        ForEach(LIGHTNESS_STEPS, (step: number) => {
          Button(lightnessStepText(step))
            .layoutWeight(1)
            .height(38)
            .fontSize(scaled(12))
            .backgroundColor(toHex(adjustLightness(this.color, step)))
            .fontColor(toHex(readableTextColor(adjustLightness(this.color, step))))
            .onClick(() => {
              const next: NGFColor = adjustLightness(this.color, step);
              this.input = toHex(next);
              this.scheduleDraftSave(this.input);
              this.recalculate();
            })
        }, (step: number) => String(step))
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 对比度与无障碍达标 */
  @Builder
  private buildContrastSection() {
    Column({ space: 8 }) {
      Text($r('app.string.color_label_contrast'))
        .fontSize(scaled(15))
        .fontWeight(FontWeight.Medium)
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))

      this.buildContrastRow($r('app.string.color_label_on_white'), this.report.contrastOnWhite,
        NGFColor.of(255, 255, 255))
      this.buildContrastRow($r('app.string.color_label_on_black'), this.report.contrastOnBlack,
        NGFColor.of(0, 0, 0))

      Text($r('app.string.color_contrast_hint'))
        .fontSize(scaled(12))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildContrastRow(label: ResourceStr, ratio: number, background: NGFColor) {
    Row({ space: 8 }) {
      Text(label)
        .fontSize(scaled(13))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        .width(56)
      Text(String(ratio) + ' : 1')
        .fontSize(scaled(14))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))
        .width(72)
      // 用实际达标结论而不是只给数字：用户要的是"能不能用"，不是"自己去比"
      Text(this.verdictText(background))
        .fontSize(scaled(12))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))
        .layoutWeight(1)
    }
    .width('100%')
    .padding(10)
    .backgroundColor(colorOf(NGFColorToken.SURFACE))
    .borderRadius(10)
  }

  /** 配色方案 */
  @Builder
  private buildHarmonySection() {
    Column({ space: 8 }) {
      Text($r('app.string.color_label_harmony'))
        .fontSize(scaled(15))
        .fontWeight(FontWeight.Medium)
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(harmonyOptions(), (option: NGFHarmonyOption) => {
          Text(harmonyLabel(option, this.locale))
            .fontSize(scaled(12))
            .fontColor(this.harmonyKind === option.kind
              ? colorOf(NGFColorToken.PRIMARY)
              : colorOf(NGFColorToken.ON_SURFACE_VARIANT))
              .accessibilityText(ToolUiKit.text(harmonyLabel(option, this.locale)))
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .backgroundColor(this.harmonyKind === option.kind
              ? colorOf(NGFColorToken.PRIMARY_CONTAINER)
              : colorOf(NGFColorToken.SURFACE))
            .borderRadius(14)
            .margin({ right: 8, bottom: 8 })
            .onClick(() => {
              this.harmonyKind = option.kind;
              this.rebuildDerived();
            })
        }, (option: NGFHarmonyOption) => option.kind)
      }
      .width('100%')

      Row({ space: 8 }) {
        ForEach(this.harmonyColors, (item: NGFColor) => {
          Column({ space: 4 }) {
            Stack() {
            }
            .width('100%')
            .height(56)
            .backgroundColor(toHex(item))
            .borderRadius(8)
            .border({ width: 1, color: colorOf(NGFColorToken.OUTLINE_VARIANT) })
            .accessibilityText(toHex(item) + ' ' + ToolUiKit.text($r('app.string.shell_action_copy')))
            .accessibilityLevel('yes')
            .onClick(() => {
              ToolUiKit.copyText(toHex(item), copiedColorText(toHex(item)));
            })
            Text(toHex(item))
              .fontSize(scaled(10))
              .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
          }
          .layoutWeight(1)
        }, (item: NGFColor) => toHex(item))
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 明暗阶梯 */
  @Builder
  private buildScaleSection() {
    Column({ space: 8 }) {
      Text($r('app.string.color_label_scale'))
        .fontSize(scaled(15))
        .fontWeight(FontWeight.Medium)
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))

      Row({ space: 4 }) {
        ForEach(this.scaleColors, (item: NGFColor) => {
          Stack() {
          }
          .layoutWeight(1)
          .height(48)
          .backgroundColor(toHex(item))
          .borderRadius(6)
          .accessibilityText(toHex(item) + ' ' + ToolUiKit.text($r('app.string.shell_action_copy')))
          .accessibilityLevel('yes')
          .onClick(() => {
            ToolUiKit.copyText(toHex(item), copiedColorText(toHex(item)));
          })
        }, (item: NGFColor) => toHex(item))
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /**
   * 主题 Token 区块。
   *
   * 产品定义稿 §四 第 51 行给颜色转换工具的定位是「uiTheme（顺带演示 Token 体系）」——
   * 这是**唯一一件挂了框架层能力**的工具，所以它要能让人一眼看懂 Token 是什么。
   *
   * 并排画明/暗两块色是刻意的：Token 的要点就是**一个名字带两套值**，
   * 只画当前主题那一套，反而看不出它和「直接写死一个色值」的区别。
   */
  @Builder
  private buildTokenSection() {
    Column({ space: 8 }) {
      Text($r('app.string.color_label_tokens'))
        .fontSize(scaled(15))
        .fontWeight(FontWeight.Medium)
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))

      Text($r('app.string.color_tokens_hint'))
        .fontSize(scaled(12))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))

      ForEach(this.tokens, (entry: NGFColorValue) => {
        this.buildTokenRow(entry)
      }, (entry: NGFColorValue) => entry.token)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildTokenRow(entry: NGFColorValue) {
    Row({ space: 8 }) {
      Stack() {
      }
      .width(22)
      .height(22)
      .backgroundColor(entry.light)
      .borderRadius(5)
      .border({ width: 1, color: colorOf(NGFColorToken.OUTLINE_VARIANT) })

      Stack() {
      }
      .width(22)
      .height(22)
      .backgroundColor(entry.dark)
      .borderRadius(5)
      .border({ width: 1, color: colorOf(NGFColorToken.OUTLINE_VARIANT) })

      Text(entry.token)
        .fontSize(scaled(12))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))
        .layoutWeight(1)

      Text(entry.light)
        .fontSize(scaled(11))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
    }
    .width('100%')
    .padding(8)
    .backgroundColor(colorOf(NGFColorToken.SURFACE))
    .borderRadius(8)
    // 成组：读屏一次念完「名字 + 明暗两值」，而不是逐个色块念
    .accessibilityGroup(true)
    .accessibilityText(entry.token + ' ' + entry.light + ' / ' + entry.dark)
  }

  /** 表示形式行 */
  private valueRows(): Array<ColorRow> {
    const rows: Array<ColorRow> = [];
    const report: NGFColorReport = this.report;
    rows.push(new ColorRow('HEX', report.hex));
    if (report.shortHex !== report.hex) {
      rows.push(new ColorRow($r('app.string.color_row_short_hex'), report.shortHex));
    }
    rows.push(new ColorRow('RGB', report.rgbText));
    rows.push(new ColorRow('HSL', report.hslText));
    rows.push(new ColorRow('HSV', report.hsvText));
    rows.push(new ColorRow('CMYK', report.cmykText));
    rows.push(new ColorRow($r('app.string.color_row_name'), report.nearestName));
    rows.push(new ColorRow($r('app.string.color_row_readable'), report.readableText));
    return rows;
  }

  /** 达标结论文案 */
  private verdictText(background: NGFColor): string {
    // 判断（三个档位布尔量）在纯逻辑层，措辞在 Messages 层
    return contrastVerdictText(evaluateContrast(this.color, background));
  }

  /** 重新计算全部结果 */
  private recalculate(): void {
    const parsed: ColorParseResult = parseColor(this.input);
    if (!parsed.ok) {
      // 输入不合法时保留上一次的颜色用于预览，只报错——清空预览会让页面闪
      this.errorText = colorParseFailureText(parsed.failure, parsed.args);
      this.noticeText = '';
      return;
    }
    this.errorText = '';
    const color: NGFColor = parsed.color as NGFColor;
    this.color = color;
    this.report = buildReport(color);
    this.reportText = formatColorText(this.report);
    this.noticeText = this.buildNotice(parsed, color);
    this.rebuildDerived();
  }

  /**
   * 提示文案。
   *
   * 三种提示都是「用户看不出但会影响结果」的情况：
   * 简写、通道被夹紧、输入带 alpha。
   */
  private buildNotice(parsed: ColorParseResult, color: NGFColor): string {
    // 判断（是否夹紧、是否带透明度）在 Messages 层用纯逻辑的字段做，措辞用资源键
    return colorNoticeTexts(color, parsed.shorthand).join(' ');
  }

  /** 重建配色与阶梯 */
  private rebuildDerived(): void {
    this.harmonyColors = harmony(this.color, this.harmonyKind);
    this.scaleColors = lightnessScale(this.color, 6);
  }

  /** 防抖写草稿 */
  private scheduleDraftSave(text: string): void {
    if (this.draftTimer >= 0) {
      clearTimeout(this.draftTimer);
    }
    this.draftTimer = setTimeout(() => {
      this.draftTimer = -1;
      toolStateStore.writeDraft(TOOL_ID, text);
    }, DRAFT_DEBOUNCE_MS);
  }

  /** 立即落盘 */
  private flushDraft(): void {
    if (this.draftTimer >= 0) {
      clearTimeout(this.draftTimer);
      this.draftTimer = -1;
    }
    toolStateStore.writeDraft(TOOL_ID, this.input);
  }
}