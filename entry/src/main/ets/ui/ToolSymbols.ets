/**
 * 工具图标的资源解析表。
 *
 * ## 为什么需要这张表（这是一个真实的坑）
 *
 * ArkUI 的 `$r('sys.symbol.xxx')` **不是一个普通函数调用**：`ets-loader` 在构建期
 * 按**字符串字面量**把它静态改写成资源 ID。因此写成拼接表达式——
 *
 * ```typescript
 * SymbolGlyph($r('sys.symbol.' + meta.symbol))   // ✗ 编译期无法改写
 * ```
 *
 * ——是**无效**的：构建期看不到字面量，运行时拿不到 Resource。
 * 这类错误不会在纯逻辑单测里暴露，也不会被静态结构检查（check-pages.mjs）抓住，
 * 只会在编译或真机上表现为「图标不显示」。
 *
 * 所以正确做法只有一条：**把每个符号名写成字面量**，用一张表把
 * 「工具 id → 字面量 Resource」映射起来。工具元数据里仍然保存符号**名字**
 * （元数据必须保持纯数据、可被单测 import），运行时通过本表换成 Resource。
 *
 * ## 为什么放在 ui/ 而不是 core/
 *
 * `Resource` 是 ArkUI 的全局类型。一旦把它放进 core/，
 * core 的所有文件都会被迫依赖 ArkUI，注册表与状态模型就再也无法被
 * `entry/src/test` 的单测直接 import 了（见 AGENTS.md §3.1）。
 *
 * ## 新增一件工具时
 *
 * 在这里补一行 `TOOL_SYMBOLS.set('<toolId>', $r('sys.symbol.<symbol>'))`，
 * 与 `core/ToolModel.ets` 里元数据的 `symbol` 字段保持一致。
 * 漏补不会崩——会退化成默认图标（见 {@link toolSymbolOf}）。
 *
 * @module ui/ToolSymbols
 */

/**
 * 默认图标：某个工具没有登记符号时使用。
 *
 * 刻意选一个中性且一定存在的符号，而不是留空——空白图标会让用户以为界面坏了。
 */
const DEFAULT_SYMBOL: Resource = $r('sys.symbol.square_grid_2x2');

/** 工具 id → 图标资源（**全部是字面量**，见文件头说明） */
const TOOL_SYMBOLS: Map<string, Resource> = new Map<string, Resource>();

TOOL_SYMBOLS.set('regex-tester', $r('sys.symbol.magnifyingglass'));
TOOL_SYMBOLS.set('json-toolkit', $r('sys.symbol.list_square'));
TOOL_SYMBOLS.set('timestamp', $r('sys.symbol.clock'));
TOOL_SYMBOLS.set('codec-suite', $r('sys.symbol.arrow_left_arrow_right'));
TOOL_SYMBOLS.set('digest', $r('sys.symbol.lock_shield'));
TOOL_SYMBOLS.set('jwt-decoder', $r('sys.symbol.doc_text_badge_magnifyingglass'));
TOOL_SYMBOLS.set('cron-parser', $r('sys.symbol.calendar'));
TOOL_SYMBOLS.set('radix-convert', $r('sys.symbol.list_number'));
TOOL_SYMBOLS.set('date-calc', $r('sys.symbol.calendar_badge_checkmark'));
TOOL_SYMBOLS.set('uuid-password', $r('sys.symbol.lock'));
TOOL_SYMBOLS.set('subnet-calc', $r('sys.symbol.externaldrive'));
// 规划中（首页显示「建设中」）的 6 件也给图标，免得网格里空一格。
TOOL_SYMBOLS.set('qrcode', $r('sys.symbol.qrcode'));
TOOL_SYMBOLS.set('code-viewer', $r('sys.symbol.doc_text'));
TOOL_SYMBOLS.set('port-tester', $r('sys.symbol.network_acceleration'));
TOOL_SYMBOLS.set('subnet-calc', $r('sys.symbol.externaldrive'));
TOOL_SYMBOLS.set('color-convert', $r('sys.symbol.highlight_block'));
// 刻意与 codec-suite 区分开：两件工具图标相同会让用户以为点错了。
TOOL_SYMBOLS.set('text-diff', $r('sys.symbol.doc_text_on_doc_text'));

/**
 * 取某件工具的图标资源。
 *
 * @param toolId 工具 id
 * @returns 对应图标；未登记时返回 {@link DEFAULT_SYMBOL}（不抛异常——
 *          首页不能因为少配一个图标就整片网格白屏）
 */
export function toolSymbolOf(toolId: string): Resource {
  const symbol: Resource | undefined = TOOL_SYMBOLS.get(toolId.trim());
  return symbol === undefined ? DEFAULT_SYMBOL : symbol;
}

/**
 * 是否为端口测试那类「需要联网」的工具的辅助图标。
 *
 * 同样必须是字面量（理由见文件头）。
 */
export const NETWORK_BADGE_SYMBOL: Resource = $r('sys.symbol.network_acceleration');
