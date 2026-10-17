import { describe, expect, it } from '@ohos/hypium';
import {
  decodeForm,
  FormDecodeFailureCode
} from '../main/ets/tools/form-decode/FormDecode';

/**
 * 表单编码解析的单测：**表单语义**（+ 是空格、%2B 是字面加号、重复键保留多条）。
 */
export default function formDecodeTest() {
  describe('formDecodeTest', () => {
    it('基本解析：name=alice&age=30', 0, () => {
      const r = decodeForm('name=alice&age=30');
      expect(r.ok).assertEqual(true);
      expect(r.fields.length).assertEqual(2);
      expect(r.fields[0].key).assertEqual('name');
      expect(r.fields[0].value).assertEqual('alice');
      expect(r.fields[1].key).assertEqual('age');
      expect(r.fields[1].value).assertEqual('30');
    });

    it('表单口径：+ 是空格、%2B 是字面加号', 0, () => {
      const r = decodeForm('q=a+b&lit=%2B');
      expect(r.fields[0].value).assertEqual('a b');
      expect(r.fields[1].value).assertEqual('+');
    });

    it('URL 编码的键与值都解码', 0, () => {
      const r = decodeForm('%E7%94%A8%E6%88%B7=%E6%B5%8B%E8%AF%95');
      expect(r.fields[0].key).assertEqual('用户');
      expect(r.fields[0].value).assertEqual('测试');
    });

    it('重复键保留多条（多选框语义）', 0, () => {
      const r = decodeForm('tag=a&tag=b&tag=c');
      expect(r.fields.length).assertEqual(3);
      expect(r.uniqueKeys).assertEqual(1);
      expect(r.fields[0].value).assertEqual('a');
      expect(r.fields[2].value).assertEqual('c');
    });

    it('无值字段：flag= 与 flag（等价空值）', 0, () => {
      const r = decodeForm('a=&b');
      expect(r.fields[0].key).assertEqual('a');
      expect(r.fields[0].value).assertEqual('');
      expect(r.fields[1].key).assertEqual('b');
      expect(r.fields[1].value).assertEqual('');
    });

    it('? 开头报错（那是 query 的形态）', 0, () => {
      const r = decodeForm('?name=alice');
      expect(r.ok).assertEqual(false);
      expect(r.failure.code).assertEqual(FormDecodeFailureCode.LEADING_QUESTION_MARK);
    });

    it('空输入报错', 0, () => {
      expect(decodeForm('').failure.code).assertEqual(FormDecodeFailureCode.EMPTY_INPUT);
    });

    it('唯一键数与字段数的差 = 重复', 0, () => {
      const r = decodeForm('a=1&b=2&a=3&b=4&c=5');
      expect(r.fields.length).assertEqual(5);
      expect(r.uniqueKeys).assertEqual(3);
    });
  });
}
