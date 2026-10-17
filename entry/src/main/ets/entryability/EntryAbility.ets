import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want, common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { window } from '@kit.ArkUI';
import {
  crashAnalytics,
  logger,
  ngfScreenKeepAwakeFacade,
  ngfStarterKernel,
  uiContextManager
} from 'ngf_framework';
import { clearContext, NGFAbilityContextLike, setContext } from '../GlobalContext';
import { toolboxApplication } from '../application/ToolboxApplication';
import { initializeFontScale } from '../ui/FontScaleSource';
import { bindWindowChrome } from '../ui/WindowChrome';
import { initializeI18n, notifySystemLocale } from '../ui/LocaleSource';
import { initializeTheme, notifySystemColorMode } from '../ui/ThemeSource';

const TAG: string = 'EntryAbility';

/**
 * NGF 开发者工具箱主 Ability。
 *
 * ## 启动顺序（每一步都有理由，改动前请先读这里）
 *
 * `onCreate` 里的顺序不是随意的，它对应三条真实的依赖链：
 *
 * 1. **全局上下文最先**：框架的 `SettingsManager` 等门面后面要用文件目录，
 *    没有上下文它们只能失败或退化。
 * 2. **bootstrap 在上下文之后**：`ngfStarterKernel.bootstrap()` 会引导
 *    platform / theme / i18n / data / uiShell 等模块，其中 data 模块会去
 *    初始化 Preferences —— 那需要 UIAbilityContext。
 * 3. **工具箱自己的初始化最后**：工具清单要用框架的 logger，
 *    用户状态（收藏/最近使用）要用框架的 Preferences。
 *    任何一步提前，都会拿到「框架还没准备好」的空结果。
 *
 * ## 一个必须记住的时序陷阱
 *
 * `SettingsManager.initialize()` 是**异步**的，而框架在模块引导阶段用
 * `void` 调用它（不 await）。所以 `bootstrap()` 返回 **不代表** Preferences 已读完。
 * 用户状态因此不能在这里一次性读死，而是交给
 * `toolboxApplication.reloadUserState()` 反复尝试（首页会在首帧后再确认一次）。
 * 详见 application/ToolboxApplication.ets 里的说明。
 */
export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // ── 1. 全局上下文：必须最先 ──────────────────────────────
    const abilityContext = this.context as NGFAbilityContextLike;
    setContext(abilityContext);
    uiContextManager.bindAbilityContext(this.context as common.UIAbilityContext);

    // ── 2. NGF 框架引导 ──────────────────────────────────────
    const bootstrapResult: boolean = ngfStarterKernel.bootstrap();
    if (!bootstrapResult) {
      // 引导失败不阻断启动：框架的模块是各自独立的，部分模块不可用时
      // 工具箱仍应能打开（工具本身是纯本地的，不依赖框架的联网能力）。
      logger.error(TAG, 'NGF 框架引导失败，工具箱将以降级模式启动');
    }
    logger.startup(TAG, 'NGF 引导完成', '成功=' + String(bootstrapResult));

    // ── 3. 屏幕常亮与崩溃日志 ────────────────────────────────
    // 屏幕常亮：本 App 的目的是「看一眼就走」，不该跟着系统熄屏策略走。
    void ngfScreenKeepAwakeFacade.initialize(this.context as common.UIAbilityContext);
    // 崩溃日志只写应用沙箱（crash_logs/），**不上报**。见隐私红线 PR-002。
    crashAnalytics.initialize();

    // ── 4. 工具箱应用层初始化 ────────────────────────────────
    // 登记工具清单（首页据此渲染网格）。放在 bootstrap 之后是因为
    // 注册表要用框架 logger；清单本身不依赖任何异步资源。
    toolboxApplication.initialize();
    // 尝试加载用户状态。多半这里还没就绪（Preferences 是异步初始化的），
    // 失败是预期行为，首页会在首帧后重试。
    toolboxApplication.reloadUserState();

    // ── 5. 主题与语言门面 ────────────────────────────────────
    // 主题：注册 Token 表（含本 App 调色板）+ 订阅变化 + 同步深浅到 AppStorage。
    // 收在 ThemeSource 里而不是直接调门面，是因为页面要跟着刷新，
    // 而刷新靠的是 ThemeSource 往 AppStorage 写的那个键。
    initializeTheme();
    // 关怀模式：把当前字号倍率写进 AppStorage 并订阅变化。
    // 页面的字号都走 scaled()，这个订阅保证切档时它们会重渲染。
    initializeFontScale();
    initializeI18n();
    // 工具箱**跟随系统**深/浅色（不像夜战类应用那样强制深色）：
    // 开发者白天在户外看工具，强制深色反而是错的。因此这里不调用 setThemeOverride。
    //
    // 注意颜色的解析方式已经变了：页面用的是**运行时 Token**（colorOf()），
    // 不再依赖 $r('app.color.x') + resources/dark 的资源限定符。
    // 所以「跟随系统」是靠 notifySystemColorMode() 把系统 colorMode 转达给
    // ThemeManager，再由它更新 isDarkMode()，页面凭 @StorageProp 重渲染。

    logger.lifecycle(TAG, '生命周期: onCreate');
  }

  onDestroy(): void {
    crashAnalytics.terminate();
    uiContextManager.clearAbilityContext();
    // 必须清：Ability 销毁后继续持有它的上下文会导致难以定位的泄漏与空引用。
    clearContext();
    logger.lifecycle(TAG, '生命周期: onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    logger.lifecycle(TAG, '生命周期: onWindowStageCreate');
    ngfScreenKeepAwakeFacade.onWindowStageCreate();

    // ── 窗口级沉浸式：必须在这里，不能更早 ────────────────────
    // 门面要靠 windowStage 拿 mainWindow；onCreate 阶段还没有窗口，
    // 那时设置只是记下策略。绑定之后门面会**自动重新应用**已激活的页面策略，
    // 所以 onCreate 里（经 ThemeSource）先调的那次不会白费。
    //
    // 少了这一步，窗口会被布局在状态栏**下方**，底板的 expandSafeArea 无处可扩——
    // 表现就是「状态栏一条底色，怎么调底板都不沉浸」。
    bindWindowChrome(windowStage);

    // 再确认一次用户状态：`SettingsManager.initialize` 是异步的，
    // onCreate 返回时它可能刚好读完，此时补读能避免首页第一帧闪一下「没有收藏」。
    toolboxApplication.reloadUserState();

    windowStage.loadContent('pages/Index', (err: BusinessError): void => {
      if (err.code !== 0) {
        logger.error(TAG, '加载首页失败: ' + JSON.stringify(err));
        return;
      }
      logger.info(TAG, '首页加载成功');
    });
  }

  onWindowStageDestroy(): void {
    ngfScreenKeepAwakeFacade.onWindowStageDestroy();
    logger.lifecycle(TAG, '生命周期: onWindowStageDestroy');
  }

  onForeground(): void {
    ngfScreenKeepAwakeFacade.onForeground();
    logger.lifecycle(TAG, '生命周期: onForeground');
  }

  onBackground(): void {
    ngfScreenKeepAwakeFacade.onBackground();
    logger.lifecycle(TAG, '生命周期: onBackground');
  }

  /**
   * 配置变化：系统深浅色或语言被改时，通知框架门面重新解析资源。
   *
   * 工具箱跟随系统，所以这里**不做任何强制覆盖**——只把变化转达给框架，
   * 由 uiTheme / i18n 门面决定如何刷新。
   */
  onConfigurationUpdate(config: Configuration): void {
    logger.info(TAG, '配置更新: colorMode=' + String(config.colorMode) + ', language=' + String(config.language));

    const colorMode: number | undefined = config.colorMode;
    if (colorMode !== undefined) {
      // 走 ThemeSource 而不是直接调门面：它会顺带把 isDarkMode() 同步进
      // AppStorage，订阅了 @StorageProp 的页面才会重渲染。
      notifySystemColorMode(colorMode);
    }
    const language: string | undefined = config.language;
    if (language !== undefined) {
      notifySystemLocale(language);
    }
  }
}
