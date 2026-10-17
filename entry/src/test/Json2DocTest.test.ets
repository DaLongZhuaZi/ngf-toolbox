import { describe, expect, it } from '@ohos/hypium';
import {
  jsonToDoc,
  Json2DocFailureCode
} from '../main/ets/tools/json2doc/Json2DocLogic';

/**
 * JSON 转接口文档的单测：**表格结构断言**（行数/类型列/路径形态）。
 */
export default function json2DocTest() {
  describe('json2DocTest', () => {
    it('扁平对象：每个键一行', 0, () => {
      const r = jsonToDoc('{"id":1,"name":"alice"}');
      expect(r.ok).assertEqual(true);
      // 头 + 分隔 + 2 字段
      const linesArr = r.markdown.split(String.fromCharCode(10));
      expect(linesArr.length).assertEqual(4);
      expect(r.fieldCount).assertEqual(2);
      expect(r.markdown.indexOf('id | number') >= 0).assertEqual(true);
    });

    it('嵌套对象：路径点分', 0, () => {
      const r = jsonToDoc('{"user":{"name":"a","age":1}}');
      expect(r.markdown.indexOf('user | object') >= 0).assertEqual(true);
      expect(r.markdown.indexOf('user.name | string') >= 0).assertEqual(true);
      expect(r.markdown.indexOf('user.age | number') >= 0).assertEqual(true);
      expect(r.fieldCount).assertEqual(3);
    });

    it('数组：取第一个元素下钻', 0, () => {
      const r = jsonToDoc('{"tags":[{"id":1}],"nums":[]}');
      expect(r.markdown.indexOf('tags[0].id | number') >= 0).assertEqual(true);
      // 空数组只标注自身
      expect(r.markdown.indexOf('nums | array') >= 0).assertEqual(true);
    });

    it('深度截断：第 5 层不再下钻', 0, () => {
      const r = jsonToDoc('{"a":{"b":{"c":{"d":{"e":1}}}}}');
      // a/a.b/a.b.c/a.b.c.d 4 层下钻 + 第 5 层 e 不出现
      expect(r.markdown.indexOf('a.b.c.d.e') < 0).assertEqual(true);
      expect(r.markdown.indexOf('a.b.c.d | object') >= 0).assertEqual(true);
    });

    it('null 与布尔类型标注', 0, () => {
      const r = jsonToDoc('{"x":null,"y":true}');
      expect(r.markdown.indexOf('x | null') >= 0).assertEqual(true);
      expect(r.markdown.indexOf('y | boolean') >= 0).assertEqual(true);
    });

    it('bad JSON 与空输入报错', 0, () => {
      expect(jsonToDoc('{bad').failure.code).assertEqual(Json2DocFailureCode.BAD_JSON);
      expect(jsonToDoc('').failure.code).assertEqual(Json2DocFailureCode.EMPTY_INPUT);
    });
  });
}
