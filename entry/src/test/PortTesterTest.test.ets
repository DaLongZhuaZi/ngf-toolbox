import { describe, expect, it } from '@ohos/hypium';
import {
  BATCH_PORT_LIMIT,
  clampTimeout,
  describeSocketError,
  PortDetail,
  PortNotice,
  HOST_MAX_LENGTH,
  isValidHost,
  isValidPort,
  localAddressNotice,
  parseTargets,
  PortParseFailure,
  PortParseResult,
  PortPreset,
  PortResult,
  portPresets,
  PortState,
  PortSummary,
  PortTarget,
  preflightSkip,
  serviceLabelOf,
  summarize,
  TIMEOUT_DEFAULT_MS,
  TIMEOUT_MAX_MS,
  TIMEOUT_MIN_MS,
  SocketDetail,
} from '../main/ets/tools/port-tester/PortTester';

/**
 * 端口测试的单测。
 *
 * ## 重点不在「能不能连」，而在「什么时候不连」
 *
 * 本工具是全 App 唯一联网的功能（PR-002/PR-003）。真正需要设备的只有建立 TCP 连接
 * 那一步，其余全是可以离线判定的纯逻辑。因此这里的用例分两类：
 *
 * 1. **输入解析**：把用户从各处粘来的写法收进来，把明显不可能的挡在外面；
 * 2. **联网前自检**（{@link preflightSkip}）：能在离线阶段就判定出来的问题
 *    绝不发出去一个包——这是隐私红线在代码层面的落点，也是本文件最该被钉住的部分。
 */
export default function portTesterTest() {
  describe('portTesterTest', () => {
    // ── 主机与端口的基本判定 ────────────────────────────────

    it('端口范围边界', 0, () => {
      expect(isValidPort(1)).assertTrue();
      expect(isValidPort(65535)).assertTrue();
      expect(isValidPort(0)).assertFalse();
      expect(isValidPort(65536)).assertFalse();
      expect(isValidPort(-1)).assertFalse();
      // 小数端口不存在
      expect(isValidPort(80.5)).assertFalse();
      expect(isValidPort(NaN)).assertFalse();
    });

    it('主机名判定刻意宽松，但挡住明显不可能的东西', 0, () => {
      // 宽松是刻意的：内网主机名与容器服务名常含下划线，严格校验会误伤。
      expect(isValidHost('example.com')).assertTrue();
      expect(isValidHost('my_server')).assertTrue();
      expect(isValidHost('192.168.1.1')).assertTrue();
      expect(isValidHost('a')).assertTrue();
      expect(isValidHost('localhost')).assertTrue();

      expect(isValidHost('')).assertFalse();
      expect(isValidHost('   ')).assertFalse();
      // 含空格：基本是把两段输入粘在了一起
      expect(isValidHost('example com')).assertFalse();
      expect(isValidHost('example\tcom')).assertFalse();
      // 纯符号：没有任何字母数字
      expect(isValidHost('---')).assertFalse();
      expect(isValidHost('...')).assertFalse();
      // 超长
      let longHost: string = '';
      for (let i: number = 0; i <= HOST_MAX_LENGTH; i++) {
        longHost += 'a';
      }
      expect(isValidHost(longHost)).assertFalse();
    });

    it('超时被夹到允许范围，NaN 退化为默认值', 0, () => {
      expect(clampTimeout(3000)).assertEqual(3000);
      expect(clampTimeout(TIMEOUT_MIN_MS)).assertEqual(TIMEOUT_MIN_MS);
      expect(clampTimeout(TIMEOUT_MAX_MS)).assertEqual(TIMEOUT_MAX_MS);
      expect(clampTimeout(0)).assertEqual(TIMEOUT_MIN_MS);
      expect(clampTimeout(-100)).assertEqual(TIMEOUT_MIN_MS);
      expect(clampTimeout(999999)).assertEqual(TIMEOUT_MAX_MS);
      expect(clampTimeout(NaN)).assertEqual(TIMEOUT_DEFAULT_MS);
    });

    // ── 输入解析 ────────────────────────────────────────────

    it('解析单端口', 0, () => {
      const result: PortParseResult = parseTargets('example.com:443');
      expect(result.ok).assertTrue();
      expect(result.targets.length).assertEqual(1);
      expect(result.targets[0].host).assertEqual('example.com');
      expect(result.targets[0].port).assertEqual(443);
      expect(result.targets[0].display).assertEqual('example.com:443');
    });

    it('解析逗号分隔的多个端口', 0, () => {
      const result: PortParseResult = parseTargets('192.168.1.1:80,443,8080');
      expect(result.ok).assertTrue();
      expect(result.targets.length).assertEqual(3);
      expect(result.targets[0].port).assertEqual(80);
      expect(result.targets[2].port).assertEqual(8080);
      // 逗号间有空格也收
      expect(parseTargets('example.com: 80 , 443').targets.length).assertEqual(2);
    });

    it('解析端口范围', 0, () => {
      const result: PortParseResult = parseTargets('example.com:8000-8010');
      expect(result.ok).assertTrue();
      expect(result.targets.length).assertEqual(11);
      expect(result.targets[0].port).assertEqual(8000);
      expect(result.targets[10].port).assertEqual(8010);
    });

    it('空格分隔的写法也收（从文档里复制常带空格）', 0, () => {
      const result: PortParseResult = parseTargets('example.com 443');
      expect(result.ok).assertTrue();
      expect(result.targets[0].port).assertEqual(443);
    });

    it('IPv6 字面量需要用方括号，展示时也带方括号', 0, () => {
      const result: PortParseResult = parseTargets('[::1]:443');
      expect(result.ok).assertTrue();
      expect(result.targets[0].host).assertEqual('::1');
      expect(result.targets[0].display).assertEqual('[::1]:443');
    });

    it('没加方括号的 IPv6 给出针对性提示，而不是笼统的格式错', 0, () => {
      const result: PortParseResult = parseTargets('::1:443');
      expect(result.ok).assertFalse();
      // 没加方括号的 `::1:443` 会走「主机里多个冒号」那条（只有以 [ 开头才算 IPv6 字面量）
      expect(result.failure).assertEqual(PortParseFailure.MULTIPLE_COLONS);
    });

    it('带协议前缀的输入被明确拒绝（否则会被解析成一个叫 http 的主机）', 0, () => {
      // 回归保护：这是最常见的粘错方式。若不挡，「http://example.com:443」里的第一个
      // 冒号会让 host 变成 'http' —— 那是个形状合法的主机名，
      // 于是工具会去连一个叫 "http" 的主机，既不报错也连不通。
      const http: PortParseResult = parseTargets('http://example.com:443');
      expect(http.ok).assertFalse();
      expect(http.failure).assertEqual(PortParseFailure.PROTOCOL_PREFIX);

      const https: PortParseResult = parseTargets('https://example.com:443');
      expect(https.ok).assertFalse();
    });

    it('空输入、缺端口、非法端口分别给出对应原因', 0, () => {
      expect(parseTargets('').failure).assertEqual(PortParseFailure.EMPTY);
      expect(parseTargets('   ').failure).assertEqual(PortParseFailure.EMPTY);
      expect(parseTargets('example.com').failure).assertEqual(PortParseFailure.NO_PORT);
      expect(parseTargets('example.com:').failure).assertEqual(PortParseFailure.NO_PORT);
      expect(parseTargets('example.com:0').failure).assertEqual(PortParseFailure.PORT_NOT_INTEGER);
      expect(parseTargets('example.com:65536').failure).assertEqual(PortParseFailure.PORT_NOT_INTEGER);
      expect(parseTargets('example.com:abc').failure).assertEqual(PortParseFailure.PORT_NOT_INTEGER);
      // 十六进制端口也不收（用户可能从配置里拷来）
      expect(parseTargets('example.com:0x1F').failure).assertEqual(PortParseFailure.PORT_NOT_INTEGER);
    });

    it('端口范围起始大于结束时被拒绝', 0, () => {
      const result: PortParseResult = parseTargets('example.com:100-50');
      expect(result.ok).assertFalse();
      expect(result.failure).assertEqual(PortParseFailure.RANGE_REVERSED);
    });

    it('批量上限挡住了「事实上的端口扫描」', 0, () => {
      // 这是产品边界在代码上的落点：一次几十个端口是排查服务，
      // 一次几千个端口客观上就是在扫描。
      const tooMany: PortParseResult = parseTargets('example.com:1-100');
      expect(tooMany.ok).assertFalse();
      expect(tooMany.failure).assertEqual(PortParseFailure.RANGE_TOO_MANY);

      // 恰好到上限是允许的
      const atLimit: PortParseResult = parseTargets('example.com:1-' + String(BATCH_PORT_LIMIT));
      expect(atLimit.ok).assertTrue();
      expect(atLimit.targets.length).assertEqual(BATCH_PORT_LIMIT);

      // 用逗号堆超上限同样被挡
      let many: string = 'example.com:';
      for (let i: number = 0; i <= BATCH_PORT_LIMIT; i++) {
        many += String(1000 + i) + (i === BATCH_PORT_LIMIT ? '' : ',');
      }
            // 逗号堆超上限走的是「总数超限」，与区间超限是两个不同的码
      expect(parseTargets(many).failure).assertEqual(PortParseFailure.TOO_MANY_PORTS);
    });

    it('超长输入被拒绝，而不是硬解析', 0, () => {
      let longInput: string = 'example.com:';
      for (let i: number = 0; i < 600; i++) {
        longInput += '8';
      }
      expect(parseTargets(longInput).failure).assertEqual(PortParseFailure.TOO_LONG);
    });

    it('常用端口会带上用途说明', 0, () => {
      const https = serviceLabelOf(443);
      expect(https === null ? '' : https.forLocale('zh-CN')).assertEqual('HTTPS');
      const mysql = serviceLabelOf(3306);
      expect(mysql === null ? '' : mysql.forLocale('zh-CN')).assertEqual('MySQL');
      // 非预设端口没有说明（而不是硬凑一个）
      expect(serviceLabelOf(12345) === null).assertTrue();
    });

    it('常用端口清单无重复且都在合法范围内', 0, () => {
      const list: Array<PortPreset> = portPresets();
      const seen: Set<number> = new Set<number>();
      for (let i: number = 0; i < list.length; i++) {
        expect(isValidPort(list[i].port)).assertTrue();
        expect(seen.has(list[i].port)).assertFalse();
        // 用途名是双语数据：两侧都要写得出来
      expect(list[i].label.forLocale('zh-CN').length > 0).assertTrue();
      expect(list[i].label.forLocale('en-US').length > 0).assertTrue();
        seen.add(list[i].port);
      }
      expect(seen.size).assertEqual(list.length);
    });

    // ── 联网前自检（最重要的一节） ──────────────────────────

    it('合法目标不会被自检拦下（空数组表示可以联网）', 0, () => {
      const targets: Array<PortTarget> = parseTargets('example.com:443').targets;
      expect(preflightSkip(targets).length).assertEqual(0);
    });

    it('重复目标只测一次，其余给「未重复连接」', 0, () => {
      // 用户写 example.com:80,80 时不必发两个包。
      const targets: Array<PortTarget> = [];
      targets.push(new PortTarget('example.com', 80));
      targets.push(new PortTarget('example.com', 80));
      targets.push(new PortTarget('example.com', 443));
      const skipped: Array<PortResult> = preflightSkip(targets);
      expect(skipped.length).assertEqual(1);
      expect(skipped[0].target.port).assertEqual(80);
      expect(skipped[0].state).assertEqual(PortState.SKIPPED);
      expect(skipped[0].detail).assertEqual(PortDetail.SKIP_DUPLICATE);
      // 跳过的不算连通也不算不通
      expect(skipped[0].isOpen).assertFalse();
    });

    it('非法主机的目标被跳过且标记为「未联网」', 0, () => {
      // 手工构造一个绕过解析的非法目标，验证自检这一层是独立的防线。
      const targets: Array<PortTarget> = [];
      targets.push(new PortTarget('bad host', 80));
      targets.push(new PortTarget('', 80));
      const skipped: Array<PortResult> = preflightSkip(targets);
      expect(skipped.length).assertEqual(2);
      for (let i: number = 0; i < skipped.length; i++) {
        expect(skipped[i].state).assertEqual(PortState.SKIPPED);
        // 跳过类说明分两种：端口不合法 / 主机不合法，两者都表示「一个包都没发」
      expect(skipped[i].detail === PortDetail.SKIP_BAD_PORT
        || skipped[i].detail === PortDetail.SKIP_BAD_HOST).assertTrue();
        // 未联网 ⇒ 耗时无意义，必须是 -1 而不是 0（0 会被显示成「0ms 连通」）
        expect(skipped[i].elapsedMs).assertEqual(-1);
      }
    });

    it('非法端口的目标被跳过', 0, () => {
      const targets: Array<PortTarget> = [];
      targets.push(new PortTarget('example.com', 0));
      targets.push(new PortTarget('example.com', 70000));
      expect(preflightSkip(targets).length).assertEqual(2);
    });

    // ── 错误翻译 ────────────────────────────────────────────

    it('常见 socket 错误码翻译成可行动的人话', 0, () => {
      // 「连接被拒绝」与「超时」的下一步动作完全不同，翻译准就是在替用户省一次排查。
      const refused: SocketDetail = describeSocketError(2300007, '');
      expect(refused.kind).assertEqual(PortDetail.ERR_REFUSED);

      const resolveFailed: SocketDetail = describeSocketError(2300006, '');
      expect(resolveFailed.kind).assertEqual(PortDetail.ERR_DNS);

      const timeout: SocketDetail = describeSocketError(2300028, '');
      expect(timeout.kind).assertEqual(PortDetail.ERR_TIMEOUT);

      const noPermission: SocketDetail = describeSocketError(201, '');
      expect(noPermission.kind).assertEqual(PortDetail.ERR_NO_PERMISSION);
    });

    it('未知错误码保留原始信息，不吞掉线索', 0, () => {
      // 有原始信息时优先显示它（那是最贴近真相的线索）；
      // 连原始信息都没有时才退回错误码 —— 两者至少留一个。
      const known: SocketDetail = describeSocketError(999999, 'some raw message');
      expect(known.kind !== PortDetail.NONE).assertTrue();
      const codeOnly: SocketDetail = describeSocketError(999999, '');
      expect(codeOnly.kind !== PortDetail.NONE).assertTrue();
    });

    // ── 结果汇总 ────────────────────────────────────────────

    it('汇总分别统计连通/不通/跳过，未完成的计入总数但不计入任何一方', 0, () => {
      const target: PortTarget = new PortTarget('example.com', 80);
      const results: Array<PortResult> = [];
      results.push(new PortResult(target, PortState.OPEN, PortDetail.NONE, [], 12));
      results.push(new PortResult(target, PortState.CLOSED, PortDetail.NONE, [], -1));
      results.push(new PortResult(target, PortState.SKIPPED, PortDetail.NONE, [], -1));
      results.push(new PortResult(target, PortState.PENDING, PortDetail.NONE, [], -1));
      results.push(new PortResult(target, PortState.RUNNING, PortDetail.NONE, [], -1));

      const summary: PortSummary = summarize(results);
      expect(summary.total).assertEqual(5);
      expect(summary.open).assertEqual(1);
      expect(summary.closed).assertEqual(1);
      expect(summary.skipped).assertEqual(1);
      // 全部连通才叫 allOpen
      expect(summary.allOpen).assertFalse();
    });

    it('全部连通时 allOpen 为真，空结果时不为真', 0, () => {
      const target: PortTarget = new PortTarget('example.com', 80);
      const all: Array<PortResult> = [];
      all.push(new PortResult(target, PortState.OPEN, PortDetail.OPEN, [], 5));
      expect(summarize(all).allOpen).assertTrue();
      // 空集合不能算「全通」（否则界面上会出现「全部连通」而列表是空的）
      expect(summarize([]).allOpen).assertFalse();
    });

    it('小结文案覆盖各种组合', 0, () => {
      expect(summarize([]).total).assertEqual(0);
      const target: PortTarget = new PortTarget('example.com', 80);
      const allSkipped: Array<PortResult> = [];
      allSkipped.push(new PortResult(target, PortState.SKIPPED, PortDetail.SKIP_BAD_PORT, [], -1));
      // 「尚未开始测试」的判定条件是「连通与不通都是 0」，页面据此显示
      const skippedSummary = summarize(allSkipped);
      expect(skippedSummary.open).assertEqual(0);
      expect(skippedSummary.closed).assertEqual(0);

      const mixed: Array<PortResult> = [];
      mixed.push(new PortResult(target, PortState.OPEN, PortDetail.OPEN, [], 5));
      mixed.push(new PortResult(target, PortState.CLOSED, PortDetail.ERR_REFUSED, [], -1));
      // 小结的**措辞**已下移到 UI 层；这里钉住的是计数这个判断本身：
      // 连通 1、不通 1、总数 2 —— 页面据此拼「1 个连通、1 个不通（共 2 个）」
      const summary = summarize(mixed);
      expect(summary.open).assertEqual(1);
      expect(summary.closed).assertEqual(1);
      expect(summary.total).assertEqual(2);
    });

    it('结果条目带目标、状态与说明种类', 0, () => {
      // 文本拼装（portResultsText）已下移到 UI 层；这里钉住纯逻辑提供的**零件**：
      // 目标的可读写法、状态枚举、说明种类与耗时。
      const results: Array<PortResult> = [];
      results.push(new PortResult(new PortTarget('example.com', 443), PortState.OPEN,
        PortDetail.OPEN, [], 20));
      results.push(new PortResult(new PortTarget('example.com', 80), PortState.CLOSED,
        PortDetail.ERR_REFUSED, [], -1));
      expect(results[0].target.display).assertEqual('example.com:443');
      expect(results[0].state).assertEqual(PortState.OPEN);
      expect(results[0].detail).assertEqual(PortDetail.OPEN);
      expect(results[0].elapsedMs).assertEqual(20);
      expect(results[1].detail).assertEqual(PortDetail.ERR_REFUSED);
      expect(results[1].elapsedMs).assertEqual(-1);
      // 端口用途名是双语数据，页面按端口号取
      expect(serviceLabelOf(443) !== null).assertTrue();
    });

    // ── 本地地址提示 ────────────────────────────────────────

    it('回环与内网地址给出针对性提示', 0, () => {
      // 这些地址测不通不代表服务有问题，提前说明能避免误判成「我的服务挂了」。
      // 断言锚在文案里真正稳定的关键词上：localhost 的提示讲的是
      // 「这台设备自己」，而不是「本设备」——写断言时别凭印象改词。
      // 提示文案已下移到 UI 层；这里断言种类（页面据此选文案）
      expect(localAddressNotice('localhost')).assertEqual(PortNotice.LOCALHOST);
      expect(localAddressNotice('127.0.0.1') === PortNotice.LOOPBACK).assertTrue();
      expect(localAddressNotice('192.168.1.1') === PortNotice.PRIVATE).assertTrue();
      expect(localAddressNotice('10.0.0.5') === PortNotice.PRIVATE).assertTrue();
      expect(localAddressNotice('172.16.0.1') === PortNotice.PRIVATE).assertTrue();
      // 公网地址不提示（那是噪音）
      expect(localAddressNotice('example.com')).assertEqual(PortNotice.NONE);
      expect(localAddressNotice('8.8.8.8')).assertEqual(PortNotice.NONE);
    });

    it('172.16/12 的私有段边界按数值判定，不误判也不漏判', 0, () => {
      // 回归保护：第一版用字符串前缀 '172.2' 判断，既漏了 172.30/172.31，
      // 又会把 172.32 误判成私有。这里把边界逐个钉住。
      expect(localAddressNotice('172.15.0.1')).assertEqual(PortNotice.NONE);       // 略小于 16，不是私有
      expect(localAddressNotice('172.16.0.1') !== PortNotice.NONE).assertTrue(); // 私有段起点
      expect(localAddressNotice('172.31.255.254') !== PortNotice.NONE).assertTrue(); // 私有段终点
      expect(localAddressNotice('172.32.0.1')).assertEqual(PortNotice.NONE);       // 略大于 31，不是私有
      // 10/8 与 192.168/16
      expect(localAddressNotice('10.255.255.254') !== PortNotice.NONE).assertTrue();
      expect(localAddressNotice('11.0.0.1')).assertEqual(PortNotice.NONE);
      expect(localAddressNotice('192.169.0.1')).assertEqual(PortNotice.NONE);
    });

    it('像 IP 的主机名不会被误判成内网地址', 0, () => {
      // 这是「按数值判断」相对「拼前缀」的另一个好处：主机名根本进不了数值比较。
      expect(localAddressNotice('10.example.com')).assertEqual(PortNotice.NONE);
      expect(localAddressNotice('172.16.example.com')).assertEqual(PortNotice.NONE);
      expect(localAddressNotice('192.168.1')).assertEqual(PortNotice.NONE);
      expect(localAddressNotice('192.168.1.1.1')).assertEqual(PortNotice.NONE);
      expect(localAddressNotice('192.168.abc.1')).assertEqual(PortNotice.NONE);
    });
  });
}