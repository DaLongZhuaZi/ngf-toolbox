/**
 * 工具路由契约（**纯数据**，不依赖 ArkUI）。
 *
 * ## 为什么和 {@link ../core/ToolNavigator} 分开
 *
 * 「路由名 / 参数形状 / 编解码」是**契约**：跳转方与接收方必须用同一份。
 * 而真正发起跳转那一步需要 ArkUI（框架门面要读 AppStorage 里的导航栈）。
 * 把契约留在纯逻辑层之后：
 * - 两边引用同一个常量，改名不会漏改一边（漏改会得到一个静默失败的跳转——
 *   不报错、点了没反应，最难查的一类 bug）；
 * - 契约本身可以在 entry/src/test 里被单测覆盖。
 *
 * ## 从「页面路径」改成「路由名」
 *
 * 首版走的是页面 Router（\`router.pushUrl({ url: 'pages/ToolHostPage' })\`），
 * 切到框架的 \`ngfNavigationShellFacade\` 之后寻址方式是 **NavPathStack 的名字**，
 * 不再是页面文件路径。两者不能混用，所以这一版把常量一并改掉了。
 *
 * @module core/ToolRoutes
 */

/** 工具宿主的路由名；所有工具共用它（见 pages 里 destination 分发的说明）。 */
export const TOOL_HOST_ROUTE_NAME: string = 'tool-host';

/**
 * 关于页的路由名。
 *
 * 与工具路由分开命名而不是复用同一个常量：关于页**不是工具**
 * （它不在注册表里、没有工具元数据），硬塞进工具路由会让宿主去查一个不存在的 id。
 */
export const ABOUT_ROUTE_NAME: string = 'about';

/** 工具宿主的参数形状（会被序列化进信封的 payloadJson） */
export class ToolHostRouteParam {
  readonly toolId: string;

  constructor(toolId: string) {
    this.toolId = toolId;
  }
}

/** 把工具 id 编码成信封里的 payloadJson */
export function encodeToolRouteParam(toolId: string): string {
  return JSON.stringify(new ToolHostRouteParam(toolId));
}

/**
 * 从信封的 payloadJson 里安全取出工具 id。
 *
 * 抽成纯函数是为了能单测：这段输入来自**导航栈里的字符串**，
 * 可能是空串、可能不是 JSON、可能缺字段。这些分支在真机上极难复现，
 * 但它们的错误表现（点了工具没反应或跳到空白页）是用户直接可见的。
 *
 * 用 \`Record<string, string>\` 而不是 \`as ToolHostRouteParam\`：
 * ArkTS 禁止结构化类型（\`arkts-no-structural-typing\`），
 * 把 \`JSON.parse\` 的结果断言成一个类，在真机上可能拿不到字段。
 *
 * @param payloadJson 信封里的字符串；任何非法输入都返回空串
 */
export function readToolIdFromPayload(payloadJson: string): string {
  if (payloadJson === undefined || payloadJson === null || payloadJson.length === 0) {
    return '';
  }
  try {
    const parsed: Record<string, string> = JSON.parse(payloadJson) as Record<string, string>;
    if (parsed === undefined || parsed === null) {
      return '';
    }
    const id: string = parsed.toolId;
    if (id === undefined || id === null) {
      return '';
    }
    return String(id).trim();
  } catch (error) {
    // 不是合法 JSON：当作没有参数，让接收方走「建设中」而不是崩溃
    return '';
  }
}
