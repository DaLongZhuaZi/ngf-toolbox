import { describe, expect, it } from '@ohos/hypium';
import {
  appendHistory,
  HISTORY_MAX_ENTRIES,
  HISTORY_MIN_LENGTH,
  HISTORY_SETTLE_MS,
  isHistoryWorthy,
  parseHistory,
  shouldCommitPrevious
} from '../main/ets/core/ToolStateStore';

/**
 * 输入历史三个纯函数的测试。
 *
 * ## 为什么这些用例值得存在
 *
 * 「每个工具的输入历史」是产品定义稿 §三 要求随首发上线的 data 层能力。
 * 它的判据全部藏在纯函数里，而出错方式**都不报错**：
 *
 * - 判据放宽 → 历史里塞满「{」「{"」这种逐字符的半成品，功能看着有、实际没法用；
 * - 去重写成「跳过」而不是「提前」 → 同一个值用第二次时沉在下面找不回来；
 * - 截断写错 → 历史无限增长，Preferences 单条 value 越来越大；
 * - 解析不设防 → 存坏一条就抛异常，工具页直接打不开。
 *
 * 这四条都只能靠断言发现，跑一遍界面看不出来。
 */
export default function toolStateStoreHistoryTest() {
  describe('ToolStateStoreHistoryTest', () => {

    it('isHistoryWorthy：空串、纯空白、单字符都不算', 0, () => {
      expect(isHistoryWorthy('')).assertFalse();
      expect(isHistoryWorthy('   ')).assertFalse();
      expect(isHistoryWorthy('\n\t ')).assertFalse();
      expect(isHistoryWorthy('{')).assertFalse();
    });

    it('isHistoryWorthy：达到最小长度才算（边界取等号）', 0, () => {
      // 恰好等于下限：必须算数，否则「ab」这种两字符输入永远进不了历史
      expect(HISTORY_MIN_LENGTH).assertEqual(2);
      expect(isHistoryWorthy('ab')).assertTrue();
      expect(isHistoryWorthy('abc')).assertTrue();
    });

    it('isHistoryWorthy：两端空白不影响判定', 0, () => {
      expect(isHistoryWorthy('  a  ')).assertFalse();
      expect(isHistoryWorthy('  ab  ')).assertTrue();
    });

    it('parseHistory：空串与非法 JSON 都返回空数组而不是抛异常', 0, () => {
      expect(parseHistory('').length).assertEqual(0);
      expect(parseHistory('not json').length).assertEqual(0);
      expect(parseHistory('{"a":1}').length).assertEqual(0);
      expect(parseHistory('[').length).assertEqual(0);
    });

    it('parseHistory：正常数组逐项还原', 0, () => {
      const raw: string = JSON.stringify(['first', 'second']);
      const parsed: Array<string> = parseHistory(raw);
      expect(parsed.length).assertEqual(2);
      expect(parsed[0]).assertEqual('first');
      expect(parsed[1]).assertEqual('second');
    });

    it('parseHistory：丢掉空串项，但不丢内容里有空格的项', 0, () => {
      const raw: string = JSON.stringify(['keep me', '', 'x']);
      const parsed: Array<string> = parseHistory(raw);
      expect(parsed.length).assertEqual(2);
      expect(parsed[0]).assertEqual('keep me');
      expect(parsed[1]).assertEqual('x');
    });

    it('appendHistory：新值排在最前', 0, () => {
      const next: Array<string> = appendHistory(['old'], 'new', HISTORY_MAX_ENTRIES);
      expect(next.length).assertEqual(2);
      expect(next[0]).assertEqual('new');
      expect(next[1]).assertEqual('old');
    });

    it('appendHistory：重复值**提到最前**而不是被跳过', 0, () => {
      // 「跳过」会让同一个值用第二次时沉在下面——那是用户最想找回来的那次。
      // 注意这里必须用**多字符**值：单字符过不了 isHistoryWorthy（见下一条用例），
      // 用 'a'/'b'/'c' 写这条会误以为去重逻辑坏了。
      const next: Array<string> = appendHistory(['aa', 'bb', 'cc'], 'cc', HISTORY_MAX_ENTRIES);
      expect(next.length).assertEqual(3);
      expect(next[0]).assertEqual('cc');
      expect(next[1]).assertEqual('aa');
      expect(next[2]).assertEqual('bb');
    });

    it('appendHistory：单字符输入不进历史（本仓的取舍，非缺陷）', 0, () => {
      // 记录这个**有意的**行为：进制转换之类的工具里输入 '5' 是合法操作，
      // 但单字符作为历史条目的回填价值很低，且会挤掉真正有用的长输入。
      // 若将来要改这个取舍，改 HISTORY_MIN_LENGTH 并把这条用例一起改。
      const next: Array<string> = appendHistory(['aa'], 'z', HISTORY_MAX_ENTRIES);
      expect(next.length).assertEqual(1);
      expect(next[0]).assertEqual('aa');
    });

    it('appendHistory：不值得记的值原样返回（不改动入参）', 0, () => {
      const before: Array<string> = ['a'];
      const next: Array<string> = appendHistory(before, '', HISTORY_MAX_ENTRIES);
      expect(next.length).assertEqual(1);
      expect(next[0]).assertEqual('a');
      const short: Array<string> = appendHistory(before, 'x', HISTORY_MAX_ENTRIES);
      expect(short.length).assertEqual(1);
    });

    it('appendHistory：超过上限时截断，且保留最新的那些', 0, () => {
      let entries: Array<string> = [];
      for (let i: number = 0; i < HISTORY_MAX_ENTRIES + 5; i++) {
        entries = appendHistory(entries, 'value-' + i, HISTORY_MAX_ENTRIES);
      }
      expect(entries.length).assertEqual(HISTORY_MAX_ENTRIES);
      // 最后写入的在最前，最老的已经被挤掉
      expect(entries[0]).assertEqual('value-' + (HISTORY_MAX_ENTRIES + 4));
      expect(entries[HISTORY_MAX_ENTRIES - 1]).assertEqual('value-5');
    });

    it('appendHistory：正好等于上限时不截断', 0, () => {
      let entries: Array<string> = [];
      for (let i: number = 0; i < HISTORY_MAX_ENTRIES; i++) {
        entries = appendHistory(entries, 'v' + i, HISTORY_MAX_ENTRIES);
      }
      expect(entries.length).assertEqual(HISTORY_MAX_ENTRIES);
    });

    it('shouldCommitPrevious：没有上一个值时不结算', 0, () => {
      // 首次输入：漏了这个判断会把空串当成一条历史记进去
      expect(shouldCommitPrevious(undefined, undefined, 'abc', 10000)).assertFalse();
      expect(shouldCommitPrevious(1000, undefined, 'abc', 10000)).assertFalse();
      expect(shouldCommitPrevious(undefined, 'abc', 'def', 10000)).assertFalse();
    });

    it('shouldCommitPrevious：上一个值还没定型时不结算', 0, () => {
      // 逐字符输入时每两次按键间隔很短，漏了这条会刷出一堆半成品
      const justNow: number = 10000;
      expect(shouldCommitPrevious(justNow, 'ab', 'abc', justNow + 1)).assertFalse();
      expect(shouldCommitPrevious(justNow, 'ab', 'abc', justNow + HISTORY_SETTLE_MS - 1)).assertFalse();
    });

    it('shouldCommitPrevious：恰好到定型时长就结算（边界取等号）', 0, () => {
      const t0: number = 10000;
      expect(shouldCommitPrevious(t0, 'ab', 'abc', t0 + HISTORY_SETTLE_MS)).assertTrue();
      expect(shouldCommitPrevious(t0, 'ab', 'abc', t0 + HISTORY_SETTLE_MS + 5000)).assertTrue();
    });

    it('shouldCommitPrevious：新值与上一个值相同则不结算', 0, () => {
      // 光标移动、重复触发 onChange 都会走到这里；不判重会刷出一堆同样的条目
      const t0: number = 10000;
      expect(shouldCommitPrevious(t0, 'same', 'same', t0 + HISTORY_SETTLE_MS)).assertFalse();
    });

    it('序列化后解析回来是同一个列表（往返一致）', 0, () => {
      const entries: Array<string> = ['{"json":"inside"}', '含 空格 与\n换行', 'plain'];
      const roundTrip: Array<string> = parseHistory(JSON.stringify(entries));
      expect(roundTrip.length).assertEqual(3);
      for (let i: number = 0; i < entries.length; i++) {
        expect(roundTrip[i]).assertEqual(entries[i]);
      }
    });
  });
}
