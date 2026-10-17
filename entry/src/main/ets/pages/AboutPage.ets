/**
 * 关于页 —— 产品定义稿 §三 要求的「NGF 专区」。
 *
 * ## 这一页对样板应用的特殊意义
 *
 * 其他页面是**给用户用的**，这一页是**给读者读的**。产品定义稿把本 App 定位为
 * 「NGF 框架的官方样板」，那么它必须回答一个读者最关心的问题：
 * **这个框架到底提供了什么、这个 App 用到了哪些层**。
 * 因此这一页列出的框架能力清单刻意只写本 App 真的用到的层，
 * 不罗列框架里没用上的模块——列一堆没用到的东西会误导读者以为样板演示了它们。
 *
 * ## 两层文案，两种机制（这条边界值得记住）
 *
 * - **固定标签**（小标题、页脚、按钮、错误话术）走**资源键** \`$r('app.string.…')\`：
 *   它们本来就是 UI 的事，而且系统会按设备语言自动选表，不需要我们传 locale。
 * - **内容数据**（框架能力说明、隐私承诺、链接名）取自 {@link AppInfo}，
 *   那是**纯数据层**——纯数据不能 import ArkUI 的 \`$r\`，否则本机单测就构造不出来了。
 *   所以它们用 {@link NGFLocalizedText} 把两种语言带在身上，由本页按 locale 取用。
 *
 * 这个分工不是随手定的：它和工具元数据（\`core/ToolModel\`）用的是同一条规则——
 * **能进纯数据层的就带双语，只有 UI 自己的话才用资源键**。
 *
 * @module pages/AboutPage
 */

import { scaled, TOOLBOX_FONT_SCALE_KEY } from '../ui/FontScaleSource';
import { colorOf, TOOLBOX_DARK_KEY } from '../ui/ThemeSource';
import { barePageContentTop } from '../ui/ImmersiveChrome';
import { CONTENT_TOP_RESERVE, loadDynamicInsets } from '../ui/WindowChrome';
import {
  bundleManager, Want } from '@kit.AbilityKit';
import { logger, NGFColorToken, uiContextManager } from 'ngf_framework';
import {
  AppLink,
  allLinks,
  BUNDLE_NAME,
  CONTACT_EMAIL,
  feedbackLinks,
  formatVersion,
  frameworkCapabilities,
  FrameworkCapability,
  linkRejectReason,
  privacyPoints,
  REPOSITORY_URL,
  repositoryQrPayload,
  siblingProjects
} from '../about/AppInfo';
import { NGFLocalizedText } from '../core/ToolModel';
import { currentLocale, FALLBACK_LOCALE } from '../ui/LocaleSource';

const TAG: string = 'AboutPage';

/** 页面左右留白（vp），与首页一致 */
const PAGE_PADDING: number = 16;
/** 二维码边长（vp） */
const QR_SIZE: number = 160;

@Component
export struct AboutView {
  /** 订阅主题深浅；本字段本身不用，作用是在主题切换时触发本组件重渲染。 */
  @StorageProp(TOOLBOX_DARK_KEY) isDark: boolean = false;
  /** 订阅字体缩放；本字段不用，作用是切字号时触发本组件重渲染。 */
  @StorageProp(TOOLBOX_FONT_SCALE_KEY) fontScale: number = 1;
  /** 顶部内容避让（vp）＝实测状态栏高度 + 留白 */
  @State private topInsetVp: number = CONTENT_TOP_RESERVE;
  @State private versionText: string = '';
  /**
   * 版本读取是否已经失败。
   *
   * 需要这个标志而不能只看 \`versionText\` 是否为空：读取是异步的，
   * 刚进页面时它本来也是空串。只用空串判断的话，首帧会闪过「读取失败」——
   * 一个还没失败就先报失败的界面。
   */
  @State private versionFailed: boolean = false;
  @State private bundleName: string = BUNDLE_NAME;
  /** 内容数据取自纯数据层，按它取语言；固定标签由 $r() 自动跟随系统语言 */
  @State private locale: string = FALLBACK_LOCALE;

  aboutToAppear(): void {
    // 顶部避让用**实测**状态栏高度（各机型不同），不用写死的值
    // 顶栏由框架的 HdsNavDestination 渲染（返回按钮 + 「关于」标题都在那里），
    // 所以内容要让开「状态栏 + 顶栏文字区 + 顶栏背景多出的 28vp」。
    // 原先只让 top+12，真机上本页自己的标题被顶栏切掉一半。
    loadDynamicInsets(this.getUIContext(), 44, 0, (top: number, bottom: number): void => {
      this.topInsetVp = top + CONTENT_TOP_RESERVE;
    });
    this.locale = currentLocale();
    this.loadVersion();
  }

  /**
   * 读版本号。
   *
   * 版本号的**唯一源**是 AppScope/app.json5（PR-007），因此这里必须问系统要，
   * 而不是在代码里再写一份常量——写两份的结果是它们迟早不一致，
   * 而版本号不一致会让「用户报的版本」与「我们以为的版本」对不上。
   */
  private loadVersion(): void {
    try {
      bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION)
        .then((info: bundleManager.BundleInfo): void => {
          this.versionText = formatVersion(info.versionName, info.versionCode);
          if (info.name.length > 0) {
            this.bundleName = info.name;
          }
        })
        .catch((error: Error): void => {
          logger.warn(TAG, '读取版本信息失败: ' + error.message);
          this.versionText = '';
          this.versionFailed = true;
        });
    } catch (error) {
      this.versionText = '';
      this.versionFailed = true;
    }
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        this.buildHeader()
        this.buildRepositoryCard()
        this.buildFrameworkCard()
        this.buildPrivacyCard()
        this.buildSiblingCard()
        this.buildFeedbackCard()
        this.buildLicenseFooter()
        Blank().height(24)
      }
      .width('100%')
      // 顶部避让：开了窗口级沉浸（全屏布局）后，内容不再自动躲开状态栏。
      // 本页没有沉浸式底板，所以只需让开状态栏那一条。
      .padding({ left: PAGE_PADDING, right: PAGE_PADDING, top: this.topInsetVp })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .scrollBar(BarState.Auto)
    .edgeEffect(EdgeEffect.Spring)
    .backgroundColor(colorOf(NGFColorToken.BACKGROUND))
  }

  /** 标题区：名字、副标题、版本、包名 */
  @Builder
  private buildHeader() {
    Column({ space: 6 }) {
      Text($r('app.string.shell_app_name'))
        .fontSize(scaled(24))
        .fontWeight(FontWeight.Bold)
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))
        .maxFontSize(24)
        .minFontSize(18)
        .maxLines(2)
      Text($r('app.string.shell_app_subtitle'))
        .fontSize(scaled(13))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
      // 三种状态各有对应文案：读到了就显示版本号，读失败说明原因，
      // 还在读就给「正在读取」——不能把「还没读完」显示成「读取失败」。
      Text(this.versionText.length > 0
        ? this.versionText
        : (this.versionFailed
          ? $r('app.string.about_version_failed')
          : $r('app.string.about_reading_version')))
        .fontSize(scaled(13))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
      Text(this.bundleName)
        .fontSize(scaled(12))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        .textSelectable(TextSelectableMode.SELECTABLE_UNFOCUSABLE)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: 20, bottom: 8 })
  }

  /** 仓库二维码 */
  @Builder
  private buildRepositoryCard() {
    Column({ space: 12 }) {
      this.buildSectionTitle($r('app.string.about_section_repo'))
      Text($r('app.string.about_repo_intro'))
        .fontSize(scaled(12))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        .width('100%')

      Column({ space: 10 }) {
        QRCode(repositoryQrPayload())
          .width(QR_SIZE)
          .height(QR_SIZE)
          .color(Color.Black)
          .backgroundColor(Color.White)
        Text(REPOSITORY_URL)
          .fontSize(scaled(11))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
          .textSelectable(TextSelectableMode.SELECTABLE_UNFOCUSABLE)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .padding(12)
      .backgroundColor(Color.White)
      .borderRadius(12)

      this.buildWholeRowLink(REPOSITORY_URL, $r('app.string.about_open_in_browser'),
        $r('app.string.about_self_source_desc'))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .backgroundColor(colorOf(NGFColorToken.SURFACE_VARIANT))
    .borderRadius(12)
  }

  /** NGF 框架专区 */
  @Builder
  private buildFrameworkCard() {
    Column({ space: 10 }) {
      this.buildSectionTitle($r('app.string.about_section_framework'))
      Text($r('app.string.about_framework_intro'))
        .fontSize(scaled(13))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE))
        .lineHeight(20)
        .width('100%')

      Text($r('app.string.about_layers_used'))
        .fontSize(scaled(12))
        .fontWeight(FontWeight.Medium)
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        .width('100%')
        .margin({ top: 4 })

      ForEach(frameworkCapabilities(), (capability: FrameworkCapability) => {
        Row({ space: 10 }) {
          // 层名不翻译：它是框架的模块标识，开发者按它去翻框架源码
          Text(capability.name)
            .fontSize(scaled(12))
            .fontColor(colorOf(NGFColorToken.PRIMARY))
            .width(150)
          Text(capability.description.forLocale(this.locale))
            .fontSize(scaled(12))
            .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
            .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      }, (capability: FrameworkCapability) => capability.name)

      Text($r('app.string.about_layers_note'))
        .fontSize(scaled(11))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        .width('100%')
        .margin({ top: 4 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .backgroundColor(colorOf(NGFColorToken.SURFACE_VARIANT))
    .borderRadius(12)
  }

  /** 隐私承诺 */
  @Builder
  private buildPrivacyCard() {
    Column({ space: 8 }) {
      this.buildSectionTitle($r('app.string.about_section_privacy'))
      ForEach(privacyPoints(), (point: NGFLocalizedText) => {
        Row({ space: 8 }) {
          Text('·')
            .fontSize(scaled(13))
            .fontColor(colorOf(NGFColorToken.SUCCESS))
          Text(point.forLocale(this.locale))
            .fontSize(scaled(12))
            .fontColor(colorOf(NGFColorToken.ON_SURFACE))
            .layoutWeight(1)
            .lineHeight(18)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      }, (point: NGFLocalizedText) => point.zh)
      Text($r('app.string.about_privacy_note'))
        .fontSize(scaled(11))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        .width('100%')
        .margin({ top: 4 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .backgroundColor(colorOf(NGFColorToken.SURFACE_VARIANT))
    .borderRadius(12)
  }

  /** 同框架作品 */
  @Builder
  private buildSiblingCard() {
    Column({ space: 10 }) {
      this.buildSectionTitle($r('app.string.about_section_siblings'))
      ForEach(siblingProjects(), (link: AppLink) => {
        this.buildDataLinkRow(link)
      }, (link: AppLink) => link.url)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .backgroundColor(colorOf(NGFColorToken.SURFACE_VARIANT))
    .borderRadius(12)
  }

  /** 反馈 */
  @Builder
  private buildFeedbackCard() {
    Column({ space: 10 }) {
      this.buildSectionTitle($r('app.string.about_section_feedback'))
      Text($r('app.string.about_feedback_scope'))
        .fontSize(scaled(12))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
        .lineHeight(18)
        .width('100%')
      ForEach(feedbackLinks(), (link: AppLink) => {
        this.buildDataLinkRow(link)
      }, (link: AppLink) => link.url)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .backgroundColor(colorOf(NGFColorToken.SURFACE_VARIANT))
    .borderRadius(12)
  }

  /** 许可证页脚 */
  @Builder
  private buildLicenseFooter() {
    Column({ space: 4 }) {
      Text($r('app.string.about_license'))
        .fontSize(scaled(12))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
      Text($r('app.string.about_app_copyright'))
        .fontSize(scaled(12))
        .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .padding({ top: 8 })
  }

  /** 小标题 */
  @Builder
  private buildSectionTitle(label: ResourceStr) {
    Text(label)
      .fontSize(scaled(15))
      .fontWeight(FontWeight.Medium)
      .fontColor(colorOf(NGFColorToken.ON_SURFACE))
      .width('100%')
  }

  /** 链接行：文案来自纯数据层（双语），按 locale 取 */
  @Builder
  private buildDataLinkRow(link: AppLink) {
    Row({ space: 10 }) {
      Column({ space: 2 }) {
        Text(link.label.forLocale(this.locale))
          .fontSize(scaled(14))
          .fontColor(colorOf(NGFColorToken.PRIMARY))
          .width('100%')
        Text(link.description.forLocale(this.locale))
          .fontSize(scaled(11))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .onClick(() => {
      this.openUrl(link.url);
    })
  }

  /** 链接行：文案来自资源表（UI 自己的话），只需要一个地址 */
  @Builder
  private buildWholeRowLink(url: string, label: ResourceStr, description: ResourceStr) {
    Row({ space: 10 }) {
      Column({ space: 2 }) {
        Text(label)
          .fontSize(scaled(14))
          .fontColor(colorOf(NGFColorToken.PRIMARY))
          .width('100%')
        Text(description)
          .fontSize(scaled(11))
          .fontColor(colorOf(NGFColorToken.ON_SURFACE_VARIANT))
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .onClick(() => {
      this.openUrl(url);
    })
  }

  /**
   * 打开外部链接。
   *
   * 用系统标准的 viewData Want，而不是自己拼 http 请求：
   * 交给浏览器打开，本 App 不需要（也不申请）任何网络之外的额外能力。
   * 链接本身的合法性由 {@link linkRejectReason} 先挡一道——
   * 那是纯逻辑、有单测，任何一个地址写错都会在测试里暴露，而不是等到用户点了没反应。
   */
  private openUrl(url: string): void {
    const reason: string = linkRejectReason(url);
    if (reason.length > 0) {
      logger.warn(TAG, '链接不可用: ' + url + '，原因: ' + reason);
      return;
    }
    const context = uiContextManager.getFullAbilityContext();
    if (context === null) {
      logger.warn(TAG, '无能力上下文，无法打开链接');
      return;
    }
    try {
      const want: Want = {
        action: 'ohos.want.action.viewData',
        uri: url
      };
      context.startAbility(want).catch((error: Error): void => {
        logger.warn(TAG, '打开链接失败: ' + error.message);
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      logger.warn(TAG, '打开链接异常: ' + message);
    }
  }
}
