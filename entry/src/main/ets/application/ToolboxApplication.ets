/**
 * 工具箱应用层初始化门面。
 *
 * ## 这里解决什么问题
 *
 * NGF 框架的 bootstrap 只负责「框架自己」：把 core / data / uiTheme / i18n 等模块
 * 拉起来。工具箱作为**应用**还有自己的启动事项，主要是两件：
 *
 * 1. **登记工具清单**（ToolsCatalog）——首页要据此渲染网格；
 * 2. **加载用户状态**（收藏 / 最近使用）——它存在框架的 Preferences 里。
 *
 * 第 2 件有一个必须小心的时序问题，见 {@link ToolboxApplication.reloadUserState}。
 *
 * @module application/ToolboxApplication
 */

import { logger } from 'ngf_framework';
import { ensureToolCatalogInstalled } from '../tools/ToolsCatalog';
import { toolRegistry } from '../core/ToolRegistry';
import { toolStateStore } from '../core/ToolStateStore';

const TAG: string = 'ToolboxApplication';

/** 应用层初始化状态（首页据此决定是「还没有工具」还是「还没加载完」） */
export enum ToolboxInitState {
  /** 尚未初始化 */
  IDLE = 'idle',
  /** 已登记工具清单，但用户状态还没读出来 */
  CATALOG_READY = 'catalog_ready',
  /** 完全就绪 */
  READY = 'ready'
}

class ToolboxApplication {
  private initState: ToolboxInitState = ToolboxInitState.IDLE;

  getInitState(): ToolboxInitState {
    return this.initState;
  }

  /**
   * 应用层初始化。必须在 `ngfStarterKernel.bootstrap()` **之后**调用。
   *
   * 顺序理由：工具清单本身不依赖框架，但**用户状态**依赖框架的 Preferences，
   * 而那要到 bootstrap 里 `ngfDataIntegrationFacade` 引导之后才会异步就绪。
   * 因此这里只登记清单，状态加载交给 {@link reloadUserState}。
   */
  initialize(): void {
    ensureToolCatalogInstalled();
    const total: number = toolRegistry.totalCount();
    const implemented: number = toolRegistry.implementedCount();
    this.initState = ToolboxInitState.CATALOG_READY;
    logger.info(TAG, '工具清单已登记：共=' + String(total) + ', 已实现=' + String(implemented));
  }

  /**
   * 加载用户的收藏 / 最近使用。
   *
   * ## 为什么需要「反复调用」
   *
   * `SettingsManager.initialize()` 是**异步**的，而框架在模块引导阶段用
   * `void` 调用它（不 await）。也就是说 `bootstrap()` 返回时，
   * Preferences 很可能**还没读完**。此时若直接读收藏，会拿到空列表，
   * 界面显示「没有收藏」，紧接着第一次写入就会把用户**真实的**收藏覆盖掉。
   *
   * 所以本方法可被安全地重复调用：加载成功返回 true 并停止重试；
   * 只要还没就绪就返回 false，让调用方（首页）稍后再试一次。
   *
   * @returns 用户状态是否已加载完成
   */
  reloadUserState(): boolean {
    if (this.initState === ToolboxInitState.READY) {
      return true;
    }
    const loaded: boolean = toolStateStore.load();
    if (loaded) {
      this.initState = ToolboxInitState.READY;
      logger.info(TAG, '用户状态已就绪：收藏=' + String(toolStateStore.getState().favorites.length)
        + ', 最近使用=' + String(toolStateStore.getState().recents.length));
    }
    return loaded;
  }
}

/** 进程内单例 */
export const toolboxApplication: ToolboxApplication = new ToolboxApplication();
