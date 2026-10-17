import { describe, expect, it } from '@ohos/hypium';
import {
  analyzeCidr,
  IpCidrFailureCode
} from '../main/ets/tools/ip-cidr/IpCidr';

/**
 * CIDR 计算的单测：**手算基准**。
 * 192.168.1.130/25 → 网络 192.168.1.128、广播 192.168.1.255、掩码 255.255.255.128、
 * 通配符 0.0.0.127、128 个地址。
 */
export default function ipCidrTest() {
  describe('ipCidrTest', () => {
    it('/25 经典例：网络/广播/掩码/通配符', 0, () => {
      const r = analyzeCidr('192.168.1.130/25');
      expect(r.ok).assertEqual(true);
      expect(r.cidr).assertEqual('192.168.1.128/25');
      expect(r.network).assertEqual('192.168.1.128');
      expect(r.broadcast).assertEqual('192.168.1.255');
      expect(r.mask).assertEqual('255.255.255.128');
      expect(r.wildcard).assertEqual('0.0.0.127');
      expect(r.totalAddresses).assertEqual('128');
    });

    it('/24 对齐：IP 落在网段内自动归网络地址', 0, () => {
      const r = analyzeCidr('10.0.5.77/24');
      expect(r.network).assertEqual('10.0.5.0');
      expect(r.broadcast).assertEqual('10.0.5.255');
      expect(r.mask).assertEqual('255.255.255.0');
      expect(r.wildcard).assertEqual('0.0.0.255');
      expect(r.totalAddresses).assertEqual('256');
    });

    it('/32 单机：掩码 255.255.255.255，1 个地址', 0, () => {
      const r = analyzeCidr('192.168.1.1/32');
      expect(r.network).assertEqual('192.168.1.1');
      expect(r.broadcast).assertEqual('192.168.1.1');
      expect(r.mask).assertEqual('255.255.255.255');
      expect(r.wildcard).assertEqual('0.0.0.0');
      expect(r.totalAddresses).assertEqual('1');
    });

    it('/0 全网段：4294967296 个地址（十进制字符串防丢精度）', 0, () => {
      const r = analyzeCidr('1.2.3.4/0');
      expect(r.totalAddresses).assertEqual('4294967296');
      expect(r.network).assertEqual('0.0.0.0');
      expect(r.broadcast).assertEqual('255.255.255.255');
    });

    it('缺前缀、前缀越界、坏 IP 各自报错', 0, () => {
      expect(analyzeCidr('192.168.1.1').failure.code).assertEqual(IpCidrFailureCode.MISSING_PREFIX);
      expect(analyzeCidr('192.168.1.1/33').failure.code).assertEqual(IpCidrFailureCode.PREFIX_OUT_OF_RANGE);
      expect(analyzeCidr('192.168.1.1/-1').failure.code).assertEqual(IpCidrFailureCode.PREFIX_OUT_OF_RANGE);
      expect(analyzeCidr('999.1.1.1/24').failure.code).assertEqual(IpCidrFailureCode.BAD_FORMAT);
      expect(analyzeCidr('').failure.code).assertEqual(IpCidrFailureCode.EMPTY_INPUT);
    });
  });
}
