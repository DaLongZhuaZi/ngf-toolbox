import { describe, expect, it } from '@ohos/hypium';
import {
  ABOUT_ROUTE_NAME,
  encodeToolRouteParam,
  readToolIdFromPayload,
  TOOL_HOST_ROUTE_NAME
} from '../main/ets/core/ToolRoutes';

/**
 * 导航参数编解码的测试。
 *
 * ## 为什么这些分支必须被测
 *
 * `readToolIdFromPayload` 的输入是**导航栈里的一个字符串**——它由框架门面包过一层、
 * 可能来自任何调用方。手工构造的、旧版本残留的、被改坏的都可能传进来。
 * 这些非法分支在真机上极难复现，但错误表现（点了工具没反应、或跳到一张空白页）
 * 是用户直接可见的。
 *
 * 本仓的纯逻辑纪律是「逻辑与 UI 分离、纯逻辑必须有单测」（AGENTS.md §3）。
 * 本文件补的就是 ToolRoutes 一直缺的那部分——它此前只有一句
 * 「抽成纯函数是为了能单测」的注释，而测试从未写过。
 */
export default function toolRoutesTest() {
  describe('ToolRoutesTest', () => {
    it('两个路由名非空且互不相同', 0, () => {
      // 撞名的后果是「打开关于页却进了工具宿主」——两个 destination 抢同一个名字
      expect(TOOL_HOST_ROUTE_NAME.length > 0).assertTrue();
      expect(ABOUT_ROUTE_NAME.length > 0).assertTrue();
      expect(TOOL_HOST_ROUTE_NAME === ABOUT_ROUTE_NAME).assertFalse();
    });

    it('编码后再解码能拿回原 id', 0, () => {
      const id: string = 'text-diff';
      expect(readToolIdFromPayload(encodeToolRouteParam(id))).assertEqual(id);
    });

    it('id 两侧空白会被裁掉', 0, () => {
      expect(readToolIdFromPayload(encodeToolRouteParam('  digest  '))).assertEqual('digest');
    });

    it('空字符串载荷返回空串', 0, () => {
      // 门面在参数为空时**不**构造信封，接收方拿到的是空串
      expect(readToolIdFromPayload('')).assertEqual('');
    });

    it('非 JSON 文本返回空串而不是抛异常', 0, () => {
      expect(readToolIdFromPayload('not-json-at-all')).assertEqual('');
      expect(readToolIdFromPayload('{')).assertEqual('');
      expect(readToolIdFromPayload('pages/ToolHostPage')).assertEqual('');
    });

    it('合法 JSON 但缺字段时返回空串', 0, () => {
      expect(readToolIdFromPayload('{}')).assertEqual('');
      expect(readToolIdFromPayload('{"other":"x"}')).assertEqual('');
    });

    it('字段存在但为空或空白时返回空串', 0, () => {
      // 空 id 必须被挡在「打开宿主页」之前，否则用户看到一张空白页
      expect(readToolIdFromPayload('{"toolId":""}')).assertEqual('');
      expect(readToolIdFromPayload('{"toolId":"   "}')).assertEqual('');
    });

    it('JSON null 返回空串', 0, () => {
      expect(readToolIdFromPayload('null')).assertEqual('');
    });

    it('字段不是字符串时按字符串处理而不是崩掉', 0, () => {
      // 类型系统保证不了运行时：载荷是外部字符串，可能被写坏
      expect(readToolIdFromPayload('{"toolId":123}')).assertEqual('123');
    });

    it('编码结果是合法 JSON 且带 toolId 字段', 0, () => {
      const json: string = encodeToolRouteParam('qrcode');
      expect(json.indexOf('toolId') >= 0).assertTrue();
      expect(json.indexOf('qrcode') >= 0).assertTrue();
    });
  });
}
