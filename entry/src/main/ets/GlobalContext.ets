/**
 * 工具箱全局上下文。
 *
 * ## 为什么需要一个「弱类型」的上下文持有者
 *
 * NGF 框架的 `SettingsManager`、`StorageProviderFacade` 等门面在初始化时需要一个
 * `common.UIAbilityContext`。而它们被调用的地方（工具纯逻辑、藏得较深的数据层）
 * 拿不到 Ability 实例——Ability 只在 EntryAbility 里存在。
 *
 * 于是需要一个进程级的持有者：EntryAbility 在 onCreate 塞进来，其余代码按需取。
 * 这与 airwavefootprints 仓的 GlobalContext 是同一套写法（框架样板的一致性要求）。
 *
 * ## 为什么只暴露 filesDir 而不是整个 UIAbilityContext
 *
 * `NGFAbilityContextLike` 只声明我们真正依赖的字段。这样调用方**不可能**
 * 顺手去用 context 上其它能力（例如启动别的 Ability），
 * 依赖面越小，越不容易在将来出现「某处偷偷做了不该做的事」。
 *
 * @module GlobalContext
 */

/**
 * 工具箱需要的 Ability 上下文的最小形状。
 *
 * 只声明 filesDir：这是 NGF 数据层初始化 Preferences 时的必需项。
 * 刻意不声明 startAbility 之类的能力——本 App 不需要启动任何其它 Ability。
 */
export interface NGFAbilityContextLike {
  filesDir: string;
}

/**
 * 全局上下文持有者（进程内单例）。
 *
 * 不用 AppStorage 存：AppStorage 是按 UI 实例隔离的，而数据层初始化
 * 发生在 UI 之前，取不到也不该取。
 */
class GlobalContextHolder {
  private static instance: GlobalContextHolder | null = null;
  private abilityContext: NGFAbilityContextLike | null = null;

  static getInstance(): GlobalContextHolder {
    if (!GlobalContextHolder.instance) {
      GlobalContextHolder.instance = new GlobalContextHolder();
    }
    return GlobalContextHolder.instance;
  }

  setContext(context: NGFAbilityContextLike): void {
    this.abilityContext = context;
  }

  clearContext(): void {
    this.abilityContext = null;
  }

  isInitialized(): boolean {
    return this.abilityContext !== null;
  }

  /**
   * 取上下文。
   *
   * 未初始化时**抛异常**而不是返回 null：调用它的一定是需要上下文的初始化流程，
   * 静默返回 null 只会把错误推到更远的地方、变得更难查。
   */
  getNGFContext(): NGFAbilityContextLike {
    const context = this.abilityContext;
    if (context === null) {
      throw new Error('工具箱全局上下文尚未初始化（EntryAbility.onCreate 未执行）');
    }
    return context;
  }
}

const globalContextHolder: GlobalContextHolder = GlobalContextHolder.getInstance();

/** 记录 Ability 上下文。EntryAbility.onCreate 的第一件事。 */
export function setContext(context: NGFAbilityContextLike): void {
  globalContextHolder.setContext(context);
}

/** 清除 Ability 上下文。EntryAbility.onDestroy 调用，避免持有已销毁的上下文。 */
export function clearContext(): void {
  globalContextHolder.clearContext();
}

/** 上下文是否已就绪 */
export function isInitialized(): boolean {
  return globalContextHolder.isInitialized();
}

/**
 * 取工具箱全局 Ability 上下文。
 * @throws Error 上下文未初始化时抛出
 */
export function getNGFContext(): NGFAbilityContextLike {
  return globalContextHolder.getNGFContext();
}
