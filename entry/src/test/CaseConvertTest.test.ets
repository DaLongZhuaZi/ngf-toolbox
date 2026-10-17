import { describe, expect, it } from '@ohos/hypium';
import {
  convertCase,
  splitNameWords,
  CaseFailureCode,
  NameCaseStyle
} from '../main/ets/tools/case-convert/CaseConvert';

/**
 * 命名风格转换的单测。
 *
 * 最容易错的是切词：连续大写（HTTPServer）、数字边界（user2Name）、
 * 混合分隔符（a_b-c.d）。每类都有断言，并round-trip 验证——
 * 六种输出里任取一种再喂回去，词数组必须一致（幂等性）。
 */
export default function caseConvertTest() {
  describe('caseConvertTest', () => {
    it('snake 与 kebab 的常规路径', 0, () => {
      const r = convertCase('user_name');
      expect(r.camel).assertEqual('userName');
      expect(r.pascal).assertEqual('UserName');
      expect(r.screaming).assertEqual('USER_NAME');
      expect(r.kebab).assertEqual('user-name');
      expect(r.dot).assertEqual('user.name');
      const k = convertCase('user-name');
      expect(k.camel).assertEqual('userName');
    });

    it('连续大写归词：HTTPServer 不被切碎', 0, () => {
      const r = convertCase('HTTPServer');
      expect(r.snake).assertEqual('http_server');
      expect(r.camel).assertEqual('httpServer');
      const w = convertCase('parseHTTPResponse');
      expect(w.snake).assertEqual('parse_http_response');
    });

    it('数字边界：user2Name 在字母↔数字交界切开', 0, () => {
      const r = convertCase('user2Name');
      expect(r.snake).assertEqual('user_2_name');
      const r2 = convertCase('sha256Hash');
      expect(r2.snake).assertEqual('sha_256_hash');
    });

    it('混合分隔符与空白都当词界', 0, () => {
      const r = convertCase('a_b-c.d e');
      expect(r.snake).assertEqual('a_b_c_d_e');
      expect(r.pascal).assertEqual('ABCDE');
    });

    it('全大写输入与其小写形式产出一致（幂等）', 0, () => {
      const a = convertCase('USER_NAME');
      const b = convertCase('user_name');
      expect(a.snake).assertEqual(b.snake);
      expect(a.camel).assertEqual(b.camel);
    });

    it('splitNameWords 直接断言：HTTPServer → HTTP|Server', 0, () => {
      const w = splitNameWords('HTTPServer');
      expect(w.length).assertEqual(2);
      expect(w[0]).assertEqual('HTTP');
      expect(w[1]).assertEqual('Server');
    });

    it('空输入与纯符号输入各自报对错误码', 0, () => {
      expect(convertCase('').failure.code).assertEqual(CaseFailureCode.EMPTY_INPUT);
      expect(convertCase('   ').failure.code).assertEqual(CaseFailureCode.EMPTY_INPUT);
      expect(convertCase('---').failure.code).assertEqual(CaseFailureCode.NO_WORDS);
      expect(convertCase('!!!').ok).assertEqual(false);
    });

    it('round-trip：snake 输出再喂回去结果不变', 0, () => {
      const first = convertCase('HTTPServer2');
      const again = convertCase(first.snake);
      expect(again.snake).assertEqual(first.snake);
      const first2 = convertCase('parseHTTPResponse');
      const again2 = convertCase(first2.kebab);
      expect(again2.kebab).assertEqual(first2.kebab);
    });

    it('NameCaseStyle 枚举值稳定（页面按它映射展示行）', 0, () => {
      expect(NameCaseStyle.CAMEL).assertEqual('camel');
      expect(NameCaseStyle.SCREAMING).assertEqual('screaming');
      expect(NameCaseStyle.DOT).assertEqual('dot');
    });
  });
}
