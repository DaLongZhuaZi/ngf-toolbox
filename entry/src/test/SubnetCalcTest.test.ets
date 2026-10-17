import { describe, expect, it } from '@ohos/hypium';
import {
  addressInSubnet,
  computeSubnet,
  describeAddressKind,
  ipToValue,
  isValidPrefix,
  maskIsContiguous,
  maskToPrefix,
  parseSubnetInput,
  prefixForHosts,
  PrefixRemarkCode,
  prefixRemark,
  prefixToMaskValue,
  SubnetInfo,
  SubnetParseFailure,
  SubnetParseResult,
  subnetsOverlap,
  usableHostCount,
  valueToIp
} from '../main/ets/tools/subnet-calc/SubnetCalc';
import { NGFLocalizedText } from '../main/ets/core/ToolModel';

/**
 * 子网计算的单测。
 *
 * ## 为什么这些用例值得逐条写
 *
 * 子网计算器的错误**不会以异常的形式出现**，而是给出一组看起来像模像样的数字。
 * 用户拿着它去配网络，配不通才会回头怀疑工具——那时已经浪费了时间。
 * 而它的错法高度集中在三处，下面的用例正是逐条钉这三处：
 *
 * 1. **无符号 vs 有符号**：255.255.255.255、掩码全 1、地址总数 2^32
 *    全部落在符号位上，一旦混入有符号算术就会变成负数；
 * 2. **前缀 31 与 32 的 RFC 口径**：教科书公式「2^n − 2」在这里给出 0 或 −1；
 * 3. **掩码合法性**：255.0.255.0 每段都合法却不是掩码。
 */
export default function subnetCalcTest() {
  describe('subnetCalcTest', () => {
    // ── 地址与掩码的基本换算 ────────────────────────────────

    it('点分十进制与数值的来回换算保持一致', 0, () => {
      const cases: Array<string> = ['0.0.0.0', '255.255.255.255', '192.168.1.10', '10.0.0.1', '1.2.3.4'];
      for (let i: number = 0; i < cases.length; i++) {
        const text: string = cases[i];
        const value: number = ipToValue(text);
        expect(value >= 0).assertTrue();
        expect(valueToIp(value)).assertEqual(text);
      }
    });

    it('全 1 地址是无符号的 4294967295，不是 -1', 0, () => {
      // 这是整个模块最关键的算术性质：混入有符号就会在这里变成负数。
      expect(ipToValue('255.255.255.255')).assertEqual(4294967295);
      expect(valueToIp(4294967295)).assertEqual('255.255.255.255');
    });

    it('非法地址一律返回 -1，而不是抛异常或猜一个值', 0, () => {
      // -1 不是合法地址，可以安全当哨兵；抛异常会让页面的输入过程被打断。
      const bad: Array<string> = ['', '  ', '1.2.3', '1.2.3.4.5', '256.1.1.1', '1.2.3.-1', 'a.b.c.d',
        '1..3.4', '192.168.1.256', '.1.2.3', '1.2.3.4.'];
      for (let i: number = 0; i < bad.length; i++) {
        expect(ipToValue(bad[i])).assertEqual(-1);
      }
      // 首尾空白是**允许**的：用户从日志/文档里复制地址几乎总会带上空格，
      // 为此报「格式错误」只会让人以为是自己地址写错了。
      expect(ipToValue('  192.168.1.1  ')).assertEqual(ipToValue('192.168.1.1'));
      expect(ipToValue('192.168.1.1 ')).assertEqual(ipToValue('192.168.1.1'));
      expect(ipToValue('\t10.0.0.1\n')).assertEqual(ipToValue('10.0.0.1'));
    });

    it('拒绝前导零写法（01 在部分系统里会被当八进制）', 0, () => {
      // 这是刻意的严格：01 与 1 是同一个地址，但写法差异会让用户在别处踩坑。
      expect(ipToValue('192.168.01.1')).assertEqual(-1);
      expect(ipToValue('192.168.1.01')).assertEqual(-1);
      // 单独的 0 是合法的
      expect(ipToValue('0.0.0.0')).assertEqual(0);
      expect(ipToValue('192.168.0.1')).assertEqual(ipToValue('192.168.0.1'));
    });

    it('位移构造的掩码在 0 与 32 两端都正确', 0, () => {
      // 边界：1 << 32 在 JS 里会回绕成 1 << 0，必须特判。
      expect(prefixToMaskValue(0)).assertEqual(0);
      expect(prefixToMaskValue(1)).assertEqual(2147483648);
      expect(prefixToMaskValue(24)).assertEqual(4294967040);
      expect(prefixToMaskValue(31)).assertEqual(4294967294);
      expect(prefixToMaskValue(32)).assertEqual(4294967295);
    });

    it('前缀与原始终为整数且在 0..32 内', 0, () => {
      expect(isValidPrefix(0)).assertTrue();
      expect(isValidPrefix(32)).assertTrue();
      expect(isValidPrefix(-1)).assertFalse();
      expect(isValidPrefix(33)).assertFalse();
      expect(isValidPrefix(24.5)).assertFalse();
      expect(isValidPrefix(NaN)).assertFalse();
    });

    it('掩码必须是连续的 1 后接连续的 0', 0, () => {
      // 255.0.255.0 每段都在 0..255 内，却不是掩码。
      expect(maskIsContiguous(ipToValue('255.255.255.0'))).assertTrue();
      expect(maskIsContiguous(ipToValue('255.0.255.0'))).assertFalse();
      expect(maskIsContiguous(ipToValue('255.255.255.1'))).assertFalse();
      expect(maskIsContiguous(0)).assertTrue();
      expect(maskIsContiguous(4294967295)).assertTrue();
    });

    it('掩码与前缀长度互为反函数', 0, () => {
      for (let prefix: number = 0; prefix <= 32; prefix++) {
        expect(maskToPrefix(prefixToMaskValue(prefix))).assertEqual(prefix);
      }
      expect(maskToPrefix(ipToValue('255.0.255.0'))).assertEqual(-1);
    });

    // ── 可用主机数的 RFC 口径 ───────────────────────────────

    it('常规网段（1~30）可用主机数是 2^n − 2', 0, () => {
      expect(usableHostCount(24)).assertEqual(254);
      expect(usableHostCount(25)).assertEqual(126);
      expect(usableHostCount(30)).assertEqual(2);
      expect(usableHostCount(1)).assertEqual(2147483646);
    });

    it('/31 是 RFC 3021 点对点链路：2 个可用地址，不是 0', 0, () => {
      // 回归保护：套用 2^n − 2 会得到 0，那是错的。
      expect(usableHostCount(31)).assertEqual(2);
    });

    it('/32 是单主机：1 个可用地址，不是 -1', 0, () => {
      // 回归保护：套用 2^n − 2 会得到 -1。
      expect(usableHostCount(32)).assertEqual(1);
    });

    it('/0 给出 2^32 − 2，且不溢出成负数', 0, () => {
      expect(usableHostCount(0)).assertEqual(4294967294);
    });

    // ── 完整计算 ────────────────────────────────────────────

    it('典型 /24 网段的每一项都对', 0, () => {
      const info: SubnetInfo = computeSubnet(ipToValue('192.168.1.10'), 24);
      expect(info.cidr).assertEqual('192.168.1.0/24');
      expect(info.mask).assertEqual('255.255.255.0');
      expect(info.wildcardMask).assertEqual('0.0.0.255');
      expect(info.network).assertEqual('192.168.1.0');
      expect(info.broadcast).assertEqual('192.168.1.255');
      expect(info.firstUsable).assertEqual('192.168.1.1');
      expect(info.lastUsable).assertEqual('192.168.1.254');
      expect(info.totalAddresses).assertEqual(256);
      expect(info.usableHosts).assertEqual(254);
      expect(info.isNetworkAddress).assertFalse();
      expect(info.isBroadcastAddress).assertFalse();
    });

    it('输入本身就是网络地址或广播地址时能被识别出来', 0, () => {
      // 用户常把网络地址当成一台机器填进去，工具要主动指出。
      const network: SubnetInfo = computeSubnet(ipToValue('192.168.1.0'), 24);
      expect(network.isNetworkAddress).assertTrue();
      expect(network.isBroadcastAddress).assertFalse();

      const broadcast: SubnetInfo = computeSubnet(ipToValue('192.168.1.255'), 24);
      expect(broadcast.isBroadcastAddress).assertTrue();
      expect(broadcast.isNetworkAddress).assertFalse();
    });

    it('/31 的可用范围覆盖两个地址且没有网络号/广播号之分', 0, () => {
      const info: SubnetInfo = computeSubnet(ipToValue('192.168.1.1'), 31);
      expect(info.cidr).assertEqual('192.168.1.0/31');
      expect(info.totalAddresses).assertEqual(2);
      expect(info.usableHosts).assertEqual(2);
      expect(info.firstUsable).assertEqual('192.168.1.0');
      expect(info.lastUsable).assertEqual('192.168.1.1');
      // /31 不该把网络地址判成「不可用」
      expect(info.isBroadcastAddress).assertFalse();
    });

    it('/32 的可用范围就是它自己', 0, () => {
      const info: SubnetInfo = computeSubnet(ipToValue('10.1.2.3'), 32);
      expect(info.cidr).assertEqual('10.1.2.3/32');
      expect(info.totalAddresses).assertEqual(1);
      expect(info.usableHosts).assertEqual(1);
      expect(info.firstUsable).assertEqual('10.1.2.3');
      expect(info.lastUsable).assertEqual('10.1.2.3');
    });

    it('/0 的全网广播是 255.255.255.255，且总数不溢出', 0, () => {
      const info: SubnetInfo = computeSubnet(ipToValue('8.8.8.8'), 0);
      expect(info.network).assertEqual('0.0.0.0');
      expect(info.broadcast).assertEqual('255.255.255.255');
      expect(info.mask).assertEqual('0.0.0.0');
      expect(info.totalAddresses).assertEqual(4294967296);
      expect(info.usableHosts).assertEqual(4294967294);
    });

    it('/8 的大网段数量不因符号位出错', 0, () => {
      const info: SubnetInfo = computeSubnet(ipToValue('10.1.2.3'), 8);
      expect(info.totalAddresses).assertEqual(16777216);
      expect(info.usableHosts).assertEqual(16777214);
      expect(info.broadcast).assertEqual('10.255.255.255');
    });

    it('255.255.255.255/32 能算而不产生负数', 0, () => {
      const info: SubnetInfo = computeSubnet(ipToValue('255.255.255.255'), 32);
      expect(info.network).assertEqual('255.255.255.255');
      expect(info.totalAddresses).assertEqual(1);
      expect(info.usableHosts).assertEqual(1);
    });

    it('反掩码是掩码取反且始终无符号', 0, () => {
      expect(computeSubnet(ipToValue('10.0.0.1'), 8).wildcardMask).assertEqual('0.255.255.255');
      expect(computeSubnet(ipToValue('10.0.0.1'), 30).wildcardMask).assertEqual('0.0.0.3');
      // /32 的反掩码是 0.0.0.0，不能是 255.255.255.255
      expect(computeSubnet(ipToValue('10.0.0.1'), 32).wildcardMask).assertEqual('0.0.0.0');
    });

    // ── 输入解析 ────────────────────────────────────────────

    it('接受 CIDR 与点分十进制掩码两种写法，结果一致', 0, () => {
      const byPrefix: SubnetParseResult = parseSubnetInput('192.168.1.10/24');
      const byMask: SubnetParseResult = parseSubnetInput('192.168.1.10/255.255.255.0');
      expect(byPrefix.ok).assertTrue();
      expect(byMask.ok).assertTrue();
      expect(byPrefix.prefix).assertEqual(24);
      expect(byMask.prefix).assertEqual(24);
      expect(byPrefix.addressValue).assertEqual(byMask.addressValue);
    });

    it('省略前缀时按 /32 处理', 0, () => {
      // 这是最容易让人意外的默认值，所以页面上必须提示。
      const result: SubnetParseResult = parseSubnetInput('192.168.1.10');
      expect(result.ok).assertTrue();
      expect(result.prefix).assertEqual(32);
    });

    it('IPv6 输入给出针对性提示，而不是笼统的「格式错误」', 0, () => {
      const result: SubnetParseResult = parseSubnetInput('2001:db8::1/64');
      expect(result.ok).assertFalse();
      expect(result.failure).assertEqual(SubnetParseFailure.IPV6);
      // 文案已下移到 UI 层；纯逻辑只保证给了 IPv6 这个专用码
      // （而不是笼统的 BAD_ADDRESS），页面据此给出针对性提示。
      expect(result.args.length).assertEqual(0);
    });

    it('非法掩码与非法前缀长度分别给出对应的失败原因', 0, () => {
      const badMask: SubnetParseResult = parseSubnetInput('192.168.1.1/255.0.255.0');
      expect(badMask.ok).assertFalse();
      // 「每段都合法但中间断开」现在有**独立**的码，页面能给出更准的提示
      // （原先与「掩码写法不合法」共用一个码，两种情况的话术是一样的）
      expect(badMask.failure).assertEqual(SubnetParseFailure.BAD_MASK_CONTIGUOUS);

      const badPrefix: SubnetParseResult = parseSubnetInput('192.168.1.1/33');
      expect(badPrefix.ok).assertFalse();
      expect(badPrefix.failure).assertEqual(SubnetParseFailure.BAD_PREFIX);

      // 非数字前缀
      expect(parseSubnetInput('192.168.1.1/abc').ok).assertFalse();
      // 小数前缀
      expect(parseSubnetInput('192.168.1.1/24.5').ok).assertFalse();
    });

    it('空输入与纯空白给出「请输入」提示而不是报格式错', 0, () => {
      expect(parseSubnetInput('').failure).assertEqual(SubnetParseFailure.EMPTY);
      expect(parseSubnetInput('   ').failure).assertEqual(SubnetParseFailure.EMPTY);
    });

    it('三段简写被拒绝（不同工具里含义不一致，宁可要求写全）', 0, () => {
      const result: SubnetParseResult = parseSubnetInput('192.168.1/24');
      expect(result.ok).assertFalse();
      expect(result.failure).assertEqual(SubnetParseFailure.BAD_ADDRESS);
    });

    // ── 归属与重叠 ──────────────────────────────────────────

    it('地址归属判断包含网络地址与广播地址两端', 0, () => {
      const network: number = ipToValue('192.168.1.0');
      expect(addressInSubnet(ipToValue('192.168.1.0'), network, 24)).assertTrue();
      expect(addressInSubnet(ipToValue('192.168.1.255'), network, 24)).assertTrue();
      expect(addressInSubnet(ipToValue('192.168.1.254'), network, 24)).assertTrue();
      expect(addressInSubnet(ipToValue('192.168.2.1'), network, 24)).assertFalse();
      expect(addressInSubnet(ipToValue('192.168.0.255'), network, 24)).assertFalse();
    });

    it('重叠判断不是「网络地址相等」：包含关系也算重叠', 0, () => {
      // 10.1.0.0/16 完全落在 10.0.0.0/8 之内，网络地址不同但确实重叠。
      const a: number = ipToValue('10.0.0.0');
      const b: number = ipToValue('10.1.0.0');
      expect(subnetsOverlap(a, 8, b, 16)).assertTrue();
      expect(subnetsOverlap(b, 16, a, 8)).assertTrue();
      // 相邻但不重叠
      expect(subnetsOverlap(ipToValue('10.0.0.0'), 24, ipToValue('10.0.1.0'), 24)).assertFalse();
    });

    it('私有/保留网段能被识别，且更具体的排前面', 0, () => {
      // 返回的是双语数据（NGFLocalizedText），按语言取值后再断言
      const home: Array<NGFLocalizedText> = describeAddressKind(ipToValue('192.168.1.1'));
      expect(home.length >= 1).assertTrue();
      expect(home[0].forLocale('zh-CN').indexOf('192.168') >= 0).assertTrue();
      // 英文侧也必须写得出来（缺英文会安静回退中文）
      expect(home[0].forLocale('en-US').indexOf('192.168') >= 0).assertTrue();

      const loopback: Array<NGFLocalizedText> = describeAddressKind(ipToValue('127.0.0.1'));
      expect(loopback[0].forLocale('zh-CN').indexOf('回环') >= 0).assertTrue();
      expect(loopback[0].forLocale('en-US').length > 0).assertTrue();

      // 100.64/10 是运营商级 NAT，既不是 10/8 也不是回环
      const cgn: Array<NGFLocalizedText> = describeAddressKind(ipToValue('100.64.1.1'));
      expect(cgn.length >= 1).assertTrue();
      expect(cgn[0].forLocale('zh-CN').indexOf('100.64') >= 0).assertTrue();

      // 公网地址不命中任何保留段
      expect(describeAddressKind(ipToValue('8.8.8.8')).length).assertEqual(0);
    });

    // ── 反向规划 ────────────────────────────────────────────

    it('按主机数反推前缀长度，且优先给常规网段', 0, () => {
      // 2 台机器给 /30 而不是 /31：/31 是 RFC 3021 点对点特例，
      // 很多设备的接口配置不接受它，做规划时应给业界惯例的 /30。
      expect(prefixForHosts(2)).assertEqual(30);
      // 3 台就得上 /29
      expect(prefixForHosts(3)).assertEqual(29);
      expect(prefixForHosts(254)).assertEqual(24);
      expect(prefixForHosts(255)).assertEqual(23);
      // 1 台用 /32（单主机路由，这是它的正确用途）
      expect(prefixForHosts(1)).assertEqual(32);
    });

    it('反推的边界：非法主机数返回 -1，而不是给一个看似合理的前缀', 0, () => {
      expect(prefixForHosts(0)).assertEqual(-1);
      expect(prefixForHosts(-1)).assertEqual(-1);
      expect(prefixForHosts(NaN)).assertEqual(-1);
      expect(prefixForHosts(4294967295)).assertEqual(-1);
    });

    it('反推结果与可用主机数自洽（对每个前缀双向验证）', 0, () => {
      // 这是逻辑自洽性检查：对每个**常规**前缀求可用数，再反推，应当回到同一个前缀。
      // 上界取 30 而不是 32：/31 与 /32 是特例，反推时按设计会被映射回常规网段
      // （见 prefixForHosts 的说明），所以它们不在自洽范围内。
      for (let prefix: number = 30; prefix >= 1; prefix--) {
        const hosts: number = usableHostCount(prefix);
        if (hosts < 1) {
          continue;
        }
        expect(prefixForHosts(hosts)).assertEqual(prefix);
      }
    });

    // ── 提示文案 ────────────────────────────────────────────

    it('特殊前缀给出常识提示，普通前缀不啰嗦', 0, () => {
      // 现在返回的是**码**（措辞在 UI 层）。断言码而不是文案：
      // 文案改措辞不该让测试变红，而「哪个前缀该提示」是稳定契约。
      expect(prefixRemark(32)).assertEqual(PrefixRemarkCode.SINGLE_HOST);
      expect(prefixRemark(31)).assertEqual(PrefixRemarkCode.POINT_TO_POINT_RFC3021);
      expect(prefixRemark(30)).assertEqual(PrefixRemarkCode.POINT_TO_POINT_COMMON);
      expect(prefixRemark(24)).assertEqual(PrefixRemarkCode.COMMON_LAN);
      expect(prefixRemark(0)).assertEqual(PrefixRemarkCode.ALL_IPV4);
      expect(prefixRemark(8)).assertEqual(PrefixRemarkCode.VERY_LARGE);
      // /25 这类没有特别要提醒的，返回 NONE（页面据此不显示这句）
      expect(prefixRemark(25)).assertEqual(PrefixRemarkCode.NONE);
      expect(prefixRemark(26)).assertEqual(PrefixRemarkCode.NONE);
    });
  });
}