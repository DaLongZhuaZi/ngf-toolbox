import {
  BlurStrategy,
  hdsMaterial,
  HdsNavigationBackgroundStyle,
  HdsNavigationTitle,
  HdsNavigationTitleBarOptions,
  HdsNavigationTitleBarStyle,
  HdsNavigationTitleStyle,
  HdsTitleBarContentStyle,
  ScrollEffectOptions,
  ScrollEffectType,
  SystemMaterialParams,
  TitleBarContentOptions,
  TitleBarStyleOptions
} from '@kit.UIDesignKit';
import { NGFHdsEffectPresetFactory } from './NGFHdsEffectPresets';

class NGFHdsNavigationTitle implements HdsNavigationTitle {
  mainTitle: ResourceStr;
  subTitle?: ResourceStr;

  constructor(mainTitle: ResourceStr, subTitle?: ResourceStr) {
    this.mainTitle = mainTitle;
    if (subTitle !== undefined) {
      this.subTitle = subTitle;
    }
  }
}

class NGFHdsNavigationBackgroundStyle implements HdsNavigationBackgroundStyle {
  backgroundColor?: ResourceColor;
  maskExtraHeight?: number;
  blurRadius?: number;

  constructor(backgroundColor: ResourceColor, blurRadius: number) {
    this.backgroundColor = backgroundColor;
    this.maskExtraHeight = 28;
    this.blurRadius = blurRadius;
  }
}

class NGFHdsNavigationTitleStyle implements HdsNavigationTitleStyle {
  mainTitleColor?: ResourceColor;
  subTitleColor?: ResourceColor;
  mainTitleShadowColor?: ResourceColor;
  subTitleShadowColor?: ResourceColor;

  constructor(mainTitleColor: ResourceColor, subTitleColor: ResourceColor) {
    this.mainTitleColor = mainTitleColor;
    this.subTitleColor = subTitleColor;
    this.mainTitleShadowColor = $r('app.color.circle_shadow_light');
    this.subTitleShadowColor = $r('app.color.card_shadow_light');
  }
}

class NGFHdsTitleBarContentStyle implements HdsTitleBarContentStyle {
  titleStyle?: HdsNavigationTitleStyle;

  constructor(titleStyle: HdsNavigationTitleStyle) {
    this.titleStyle = titleStyle;
  }
}

class NGFHdsNavigationTitleBarStyle implements HdsNavigationTitleBarStyle {
  backgroundStyle?: HdsNavigationBackgroundStyle;
  contentStyle?: HdsTitleBarContentStyle;

  constructor(backgroundStyle: HdsNavigationBackgroundStyle, contentStyle: HdsTitleBarContentStyle) {
    this.backgroundStyle = backgroundStyle;
    this.contentStyle = contentStyle;
  }
}

class NGFHdsScrollEffectOptions implements ScrollEffectOptions {
  enableScrollEffect?: boolean;
  scrollEffectType?: ScrollEffectType;

  constructor(scrollEffectType: ScrollEffectType) {
    this.enableScrollEffect = true;
    this.scrollEffectType = scrollEffectType;
  }
}

class NGFHdsTitleBarStyleOptions implements TitleBarStyleOptions {
  scrollEffectOpts?: ScrollEffectOptions;
  originalStyle?: HdsNavigationTitleBarStyle;
  scrollEffectStyle?: HdsNavigationTitleBarStyle;
  blurStrategy?: BlurStrategy;
  thermoCtrl?: boolean;
  systemMaterialEffect?: SystemMaterialParams;

  constructor(
    originalStyle: HdsNavigationTitleBarStyle,
    scrollEffectStyle: HdsNavigationTitleBarStyle,
    systemMaterialEffect: SystemMaterialParams
  ) {
    this.scrollEffectOpts = new NGFHdsScrollEffectOptions(ScrollEffectType.GRADIENT_BLUR);
    this.originalStyle = originalStyle;
    this.scrollEffectStyle = scrollEffectStyle;
    this.blurStrategy = BlurStrategy.ADAPTIVE;
    this.thermoCtrl = false;
    this.systemMaterialEffect = systemMaterialEffect;
  }
}

class NGFHdsTitleBarContentOptions implements TitleBarContentOptions {
  title?: HdsNavigationTitle;

  constructor(title: HdsNavigationTitle) {
    this.title = title;
  }
}

class NGFHdsNavigationTitleBarOptions implements HdsNavigationTitleBarOptions {
  style?: TitleBarStyleOptions;
  content?: TitleBarContentOptions;
  enableHoverMode?: boolean;
  avoidLayoutSafeArea?: boolean;
  enableComponentSafeArea?: boolean;

  constructor(
    content: TitleBarContentOptions,
    style: TitleBarStyleOptions,
    avoidLayoutSafeArea: boolean,
    enableComponentSafeArea: boolean
  ) {
    this.content = content;
    this.style = style;
    this.enableHoverMode = false;
    this.avoidLayoutSafeArea = avoidLayoutSafeArea;
    this.enableComponentSafeArea = enableComponentSafeArea;
  }
}

export class NGFHdsTitleBarOptionsFactory {
  static build(
    mainTitle: ResourceStr,
    subTitle: ResourceStr,
    backgroundColor: ResourceColor,
    materialLevel: hdsMaterial.MaterialLevel,
    avoidLayoutSafeArea: boolean = false,
    enableComponentSafeArea: boolean = false
  ): HdsNavigationTitleBarOptions {
    const originalTitleStyle = new NGFHdsNavigationTitleStyle($r('app.color.text_white'), $r('app.color.glass_chip_overlay'));
    const scrollTitleStyle = new NGFHdsNavigationTitleStyle($r('app.color.text_white'), $r('app.color.text_white_medium'));
    const originalContentStyle = new NGFHdsTitleBarContentStyle(originalTitleStyle);
    const scrollContentStyle = new NGFHdsTitleBarContentStyle(scrollTitleStyle);
    const originalBackgroundStyle = new NGFHdsNavigationBackgroundStyle(backgroundColor, 18);
    const scrollBackgroundStyle = new NGFHdsNavigationBackgroundStyle(backgroundColor, 28);
    const originalBarStyle = new NGFHdsNavigationTitleBarStyle(originalBackgroundStyle, originalContentStyle);
    const scrollBarStyle = new NGFHdsNavigationTitleBarStyle(scrollBackgroundStyle, scrollContentStyle);
    const materialParams = NGFHdsEffectPresetFactory.buildSystemMaterialParams(hdsMaterial.MaterialType.IMMERSIVE, materialLevel);
    const content = new NGFHdsTitleBarContentOptions(new NGFHdsNavigationTitle(mainTitle, subTitle));
    const style = new NGFHdsTitleBarStyleOptions(originalBarStyle, scrollBarStyle, materialParams);
    return new NGFHdsNavigationTitleBarOptions(content, style, avoidLayoutSafeArea, enableComponentSafeArea);
  }

  /**
   * 主题自适应变体（2026-10-17，样板仓试验，见 VENDORED.md 追记）。
   *
   * 原 build() 把标题/副标题色写死成 app.color.text_white——那是「恒深底板 + 白字」的
   * 沉浸式形态，NGF 原版 MainMenuPage 的图片头页用它是合理的。但工具类列表页
   * 背景跟随系统深浅色时，浅色主题下白字压在浅底上读不出来，宿主被迫把底板
   * 染成恒深色，结果就是「顶部深块 + 内容浅底」的生硬分界（真机截图确认）。
   *
   * 本方法**不改原 build()**（保持来源仓行为不变），另给一条可用的路径：
   * 标题/副标题/背景（未滚动与滚动后）全部由调用方按主题传入，
   * 滚动光效与材质管线（GRADIENT_BLUR / IMMERSIVE）仍复用本类既有实现。
   */
  static buildAdaptive(
    mainTitle: ResourceStr,
    subTitle: ResourceStr,
    backgroundColor: ResourceColor,
    scrolledBackgroundColor: ResourceColor,
    titleColor: ResourceColor,
    subtitleColor: ResourceColor,
    materialLevel: hdsMaterial.MaterialLevel,
    avoidLayoutSafeArea: boolean = false,
    enableComponentSafeArea: boolean = false
  ): HdsNavigationTitleBarOptions {
    const originalTitleStyle = new NGFHdsNavigationTitleStyle(titleColor, subtitleColor);
    const scrollTitleStyle = new NGFHdsNavigationTitleStyle(titleColor, subtitleColor);
    const originalContentStyle = new NGFHdsTitleBarContentStyle(originalTitleStyle);
    const scrollContentStyle = new NGFHdsTitleBarContentStyle(scrollTitleStyle);
    const originalBackgroundStyle = new NGFHdsNavigationBackgroundStyle(backgroundColor, 18);
    const scrollBackgroundStyle = new NGFHdsNavigationBackgroundStyle(scrolledBackgroundColor, 28);
    const originalBarStyle = new NGFHdsNavigationTitleBarStyle(originalBackgroundStyle, originalContentStyle);
    const scrollBarStyle = new NGFHdsNavigationTitleBarStyle(scrollBackgroundStyle, scrollContentStyle);
    const materialParams = NGFHdsEffectPresetFactory.buildSystemMaterialParams(hdsMaterial.MaterialType.IMMERSIVE, materialLevel);
    const content = new NGFHdsTitleBarContentOptions(new NGFHdsNavigationTitle(mainTitle, subTitle));
    const style = new NGFHdsTitleBarStyleOptions(originalBarStyle, scrollBarStyle, materialParams);
    return new NGFHdsNavigationTitleBarOptions(content, style, avoidLayoutSafeArea, enableComponentSafeArea);
  }
}
