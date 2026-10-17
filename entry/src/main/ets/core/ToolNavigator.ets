/**
 * 工具跳转（需要框架门面的那一层）。
 *
 * 契约与参数编解码在 {@link ./ToolRoutes}（纯逻辑、可单测）；
 * 本文件只负责发起跳转。
 *
 * ## 为什么不自己拿 UIContext
 *
 * 首版这里每个函数都要调用方传 \`UIContext\`（因为弃用的全局 \`router\` 挂了）。
 * 改用 \`ngfNavigationShellFacade\` 之后**不需要了**：门面自己从
 * \`AppStorage['GlobalNavStack']\` 取导航栈，调用方只管给路由名与参数。
 *
 * @module core/ToolNavigator
 */

import { logger, ngfNavigationShellFacade } from 'ngf_framework';
import { ABOUT_ROUTE_NAME, encodeToolRouteParam, TOOL_HOST_ROUTE_NAME } from './ToolRoutes';

const TAG: string = 'ToolNavigator';

/**
 * 跳转到指定工具。
 *
 * @param toolId 工具 id；空串会被忽略
 *              （宁可什么都不做，也不要跳到一个必然空白的宿主页）
 */
export function openTool(toolId: string): void {
  const id: string = toolId.trim();
  if (id.length === 0) {
    logger.warn(TAG, '忽略空工具 id 的跳转请求');
    return;
  }
  const pushed: boolean = ngfNavigationShellFacade.push(TOOL_HOST_ROUTE_NAME, encodeToolRouteParam(id));
  if (!pushed) {
    // 入栈失败通常是「导航栈还没写进 AppStorage」——首页还没挂载完就点了工具。
    // 这里只记日志：门面内部已经记过一条 warn，用户侧表现为「点了没反应」，
    // 属于真机回归要盯的场景。
    logger.error(TAG, '跳转工具页失败: ' + id);
  }
}

/** 打开关于页（NGF 专区）。不带参数。 */
export function openAboutPage(): void {
  const pushed: boolean = ngfNavigationShellFacade.push(ABOUT_ROUTE_NAME, '');
  if (!pushed) {
    logger.error(TAG, '打开关于页失败');
  }
}
