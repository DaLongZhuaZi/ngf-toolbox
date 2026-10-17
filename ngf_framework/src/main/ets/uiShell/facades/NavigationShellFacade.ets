import { logger } from '../../utils/Logger';
import { INavigationShell } from '../contracts/INavigationShell';
import { NGFRouteInterceptResult } from '../contracts/IRouteInterceptor';
import { ngfRouteInterceptorFacade } from './RouteInterceptorFacade';

const TAG: string = 'NGFNavigationShellFacade';

/**
 * 导航参数的**信封**。
 *
 * 参数不直接以对象形式入栈，而是包成 JSON 字符串——这样路由拦截器
 * （\`ngfRouteInterceptorFacade\`）可以在不改调用方签名的情况下审查/改写参数。
 *
 * ⚠️ \`export\` 是**本仓先行补充**，需回来源仓（airwavefootprints）同步：
 * 原先它不是导出的，于是接收方（NavDestination 的 builder）拿到的是 \`Object\`，
 * 在 ArkTS 里无法结构化地读 \`payloadJson\`（禁令 \`arkts-no-structural-typing\`），
 * 也就是**参数根本取不出来**。见 \`ngf_framework/VENDORED.md\`。
 */
export class NGFNavigationParamEnvelope {
  payloadJson: string;

  constructor(payloadJson: string) {
    this.payloadJson = payloadJson;
  }
}

export class NavigationShellFacade implements INavigationShell {
  push(pageName: string, paramsJson: string): boolean {
    const stack = this.resolveNavStack();
    if (!stack) {
      logger.warn(TAG, '页面入栈失败: 导航栈不可用, page=' + pageName);
      return false;
    }

    try {
      const navParam = this.buildNavigationParam(paramsJson);
      stack.pushPathByName(pageName, navParam ? navParam : null);
      logger.info(TAG, '页面入栈: page=' + pageName);
      return true;
    } catch (error) {
      logger.error(TAG, '页面入栈失败: page=' + pageName + ', error=' + this.errorToString(error as Object | string | number | boolean));
      return false;
    }
  }

  pop(): boolean {
    const stack = this.resolveNavStack();
    if (!stack) {
      logger.warn(TAG, '页面出栈失败: 导航栈不可用');
      return false;
    }

    try {
      const allPathName = stack.getAllPathName();
      if (allPathName.length <= 0) {
        logger.debug(TAG, '页面出栈已跳过: 导航栈为空');
        return false;
      }
      const pageName = allPathName[allPathName.length - 1];
      stack.pop();
      logger.info(TAG, '页面出栈: page=' + pageName);
      return true;
    } catch (error) {
      logger.error(TAG, '页面出栈失败: ' + this.errorToString(error as Object | string | number | boolean));
      return false;
    }
  }

  replace(pageName: string, paramsJson: string): boolean {
    const stack = this.resolveNavStack();
    if (!stack) {
      logger.warn(TAG, '页面替换失败: 导航栈不可用, page=' + pageName);
      return false;
    }

    try {
      const allPathName = stack.getAllPathName();
      if (allPathName.length > 0) {
        stack.pop();
      }
      const navParam = this.buildNavigationParam(paramsJson);
      stack.pushPathByName(pageName, navParam ? navParam : null);
      logger.info(TAG, '页面替换: page=' + pageName);
      return true;
    } catch (error) {
      logger.error(TAG, '页面替换失败: page=' + pageName + ', error=' + this.errorToString(error as Object | string | number | boolean));
      return false;
    }
  }

  currentPageName(): string {
    const stack = this.resolveNavStack();
    if (!stack) {
      logger.debug(TAG, '获取当前页面名称不可用: 导航栈缺失');
      return '';
    }

    try {
      const allPathName = stack.getAllPathName();
      if (allPathName.length <= 0) {
        logger.debug(TAG, '获取当前页面名称不可用: 导航栈为空');
        return '';
      }
      const pageName = allPathName[allPathName.length - 1];
      logger.debug(TAG, '当前页面名称: page=' + pageName);
      return pageName;
    } catch (error) {
      logger.error(TAG, '获取当前页面名称失败: ' + this.errorToString(error as Object | string | number | boolean));
      return '';
    }
  }

  async pushWithIntercept(pageName: string, paramsJson: string): Promise<boolean> {
    const result: NGFRouteInterceptResult = await ngfRouteInterceptorFacade.processNavigation(pageName, paramsJson);
    if (!result.proceed) {
      logger.info(TAG, '导航被拦截: page=' + pageName);
      return false;
    }
    const targetPage = result.redirectPage.length > 0 ? result.redirectPage : pageName;
    const targetParams = result.modifiedParams.length > 0 ? result.modifiedParams : paramsJson;
    return this.push(targetPage, targetParams);
  }

  async replaceWithIntercept(pageName: string, paramsJson: string): Promise<boolean> {
    const result: NGFRouteInterceptResult = await ngfRouteInterceptorFacade.processNavigation(pageName, paramsJson);
    if (!result.proceed) {
      logger.info(TAG, '导航被拦截: page=' + pageName);
      return false;
    }
    const targetPage = result.redirectPage.length > 0 ? result.redirectPage : pageName;
    const targetParams = result.modifiedParams.length > 0 ? result.modifiedParams : paramsJson;
    return this.replace(targetPage, targetParams);
  }

  private resolveNavStack(): NavPathStack | null {
    try {
      const globalStack = AppStorage.get<NavPathStack>('GlobalNavStack');
      if (globalStack) {
        return globalStack;
      }
      logger.debug(TAG, '解析导航栈未命中: 未找到 GlobalNavStack');
      return null;
    } catch (error) {
      logger.error(TAG, '解析导航栈失败: ' + this.errorToString(error as Object | string | number | boolean));
      return null;
    }
  }

  private buildNavigationParam(paramsJson: string): Object | null {
    if (paramsJson.trim().length <= 0) {
      return null;
    }
    const envelope = new NGFNavigationParamEnvelope(paramsJson);
    return envelope as Object;
  }

  private errorToString(error: Object | string | number | boolean): string {
    if (typeof error === 'string') {
      return error;
    }
    if (typeof error === 'number' || typeof error === 'boolean') {
      return String(error);
    }
    if (error instanceof Error) {
      return error.message;
    }
    return String(error);
  }
}

export const ngfNavigationShellFacade = new NavigationShellFacade();
