/**
 * 语言与文案解析的**唯一出口**（UI 层）。
 *
 * 它与 `ThemeSource` / `FontScaleSource` / `A11y` 是并列的四个基础能力出口：
 * 主题、关怀模式、无障碍、i18n。四者的形状刻意保持一致——
 * 都在 UI 层收口，纯逻辑层只通过参数接收结果。
 *
 * ## 为什么需要这个小模块
 *
 * 纯逻辑层（core / tools）不能读设备语言——那需要 import 框架门面，
 * 而纯逻辑模块的存在意义就是零设备依赖（能在本机跑单测）。
 * 所以「现在是什么语言」这件事必须由 UI 层读出来，再**作为参数**传进纯逻辑。
 *
 * 把门面收在一个模块里而不是让各处直接调，有三个好处：
 * 1. 将来换语言来源（例如加一个「在应用内切换语言」的设置项）只改这一处；
 * 2. 页面里出现 `ngfI18nManagerFacade` 的地方越少，越不容易有人图省事
 *    在纯逻辑里也去 import 它；
 * 3. 读语言、解析文案、生命周期三件事**职责不同但共用同一个门面**，
 *    分散在多个文件里时，改门面签名要满仓找调用点。
 *
 * @module ui/LocaleSource
 */

import { ngfI18nManagerFacade } from 'ngf_framework';

/** 无法读取时的回退语言。选中文而不是空串：中文是本 App 的第一语言。 */
export const FALLBACK_LOCALE: string = 'zh-CN';

/**
 * 读取当前系统语言。
 *
 * 读取失败时回退到 {@link FALLBACK_LOCALE}，**不抛异常**：
 * 语言只影响显示，不该让首页因此打不开。
 */
export function currentLocale(): string {
  try {
    const locale: string = ngfI18nManagerFacade.getCurrentLocale();
    return locale.length > 0 ? locale : FALLBACK_LOCALE;
  } catch (error) {
    return FALLBACK_LOCALE;
  }
}
/**
 * 解析一条本地化文案。
 *
 * @param key 资源引用（字面量 `$r('app.string.x')`）或资源裸名
 * @param args 占位符参数，顺序必须与资源文案里 `%s` 的出现顺序一致
 * @returns 解析结果；失败时返回 key 本身，便于一眼看出漏了哪条资源
 */
export function resolveText(key: string | Resource, args: Array<string | number>): string {
  try {
    if (args.length === 0) {
      return ngfI18nManagerFacade.resolveString(key);
    }
    return ngfI18nManagerFacade.resolveStringWithArgs(key, args);
  } catch (error) {
    return typeof key === 'string' ? key : 'Resource';
  }
}

/** 初始化 i18n。**App 启动时调一次**（EntryAbility.onCreate）。 */
export function initializeI18n(): void {
  try {
    ngfI18nManagerFacade.initializeDefaults();
  } catch (error) {
    // 初始化失败退化成资源表默认行为，不该让 App 起不来
  }
}

/**
 * 系统语言变化时由 UI 层转发进来（EntryAbility.onConfigurationUpdate）。
 *
 * 必须转发：框架不会自己去读系统配置，它等调用方告诉它。
 */
export function notifySystemLocale(language: string): void {
  try {
    ngfI18nManagerFacade.handleSystemLocaleChanged(language);
  } catch (error) {
  }
}
