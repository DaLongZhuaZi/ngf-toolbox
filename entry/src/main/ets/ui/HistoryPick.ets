/**
 * 输入历史的**回填中转**（唯一出口）。
 *
 * ## 为什么需要这个中转
 *
 * 本仓的结构是「**壳层包着工具体**」：
 *
 * ```
 * buildXxxPage()  →  ToolScaffold({ content: buildXxxContent })   ← 历史按钮在壳层
 *                      └─ XxxToolBody()                            ← @State input 在这里
 * ```
 *
 * 壳层**够不着**工具体的 `@State`，所以「选中一条历史 → 回填输入框」不能直接调用。
 *
 * ## 怎么解决
 *
 * 分两步走，让两边各做自己知道的事：
 *
 * 1. 壳层把选中的那条历史**写进该工具的草稿**（`toolStateStore.writeDraft`）——
 *    草稿本来就是工具体的输入源，工具页启动时就是从这里恢复的；
 * 2. 壳层再**递增这个序号**。工具体用
 *    `@StorageProp(TOOLBOX_HISTORY_PICK_SEQ) @Watch(...)` 订阅它，
 *    序号一变就重新从草稿读一次输入。
 *
 * 值**不经过** AppStorage（只有序号经过），因为它可能很长；而且这样做的好处是
 * 回填复用「草稿恢复」这一条既有路径，不需要每个工具再实现一套赋值协议。
 *
 * ## 为什么不用定时器 / 回调注册
 *
 * 定时器会随页面销毁泄漏，而且本机无法验证；回调注册要求工具体把自己的
 * setter 注册上去，那等于每个工具都要写一遍注册代码，与本仓
 * 「底层支持而非页面级补丁」的取向相反。
 *
 * ## `AppStorage` 不要 import
 *
 * 它是**全局对象**，不是 `@kit.ArkUI` 的导出成员。
 * 写成 `import { AppStorage } from '@kit.ArkUI'` 会报
 * 「has no exported member named 'AppStorage'」。
 * 本仓 `pages/Index.ets` 也是直接用的全局 `AppStorage`。
 *
 * @module ui/HistoryPick
 */

/**
 * 历史回填的序号键。
 *
 * 每回填一次 +1。工具体只关心它**变了没有**，不关心值是多少。
 */
export const TOOLBOX_HISTORY_PICK_SEQ: string = 'toolbox_history_pick_seq';

/** 读当前序号（工具体的 @StorageProp 初始值用 0，不必调用它） */
export function currentHistoryPickSeq(): number {
  const value: number | undefined = AppStorage.get<number>(TOOLBOX_HISTORY_PICK_SEQ);
  return value === undefined ? 0 : value;
}

/** 发布一次回填：序号 +1，触发工具体重新从草稿读输入 */
export function publishHistoryPick(): void {
  AppStorage.setOrCreate<number>(TOOLBOX_HISTORY_PICK_SEQ, currentHistoryPickSeq() + 1);
}
