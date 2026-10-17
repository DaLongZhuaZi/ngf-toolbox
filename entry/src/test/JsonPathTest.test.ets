import { describe, expect, it } from '@ohos/hypium';
import {
  queryJsonPath,
  JsonPathFailureCode
} from '../main/ets/tools/json-path/JsonPath';

/**
 * JSON 点路径的单测。
 *
 * 用**固定 JSON**（两键嵌套对象+数组）测：点段、数组下标、混合、
 * 类型输出、路径不存在、语法错误、bad JSON。
 */
const SAMPLE: string = '{"user":{"name":"alice","tags":["admin","dev"],"age":30},"id":1}';

export default function jsonPathTest() {
  describe('jsonPathTest', () => {
    it('点段：user.name → alice (string)', 0, () => {
      const r = queryJsonPath(SAMPLE, 'user.name');
      expect(r.ok).assertEqual(true);
      expect(r.valueText).assertEqual('alice');
      expect(r.type).assertEqual('string');
    });

    it('数组下标：user.tags[0] → admin', 0, () => {
      const r = queryJsonPath(SAMPLE, 'user.tags[0]');
      expect(r.ok).assertEqual(true);
      expect(r.valueText).assertEqual('admin');
    });

    it('混合：user.tags[1] 与根数组 [0].id', 0, () => {
      expect(queryJsonPath(SAMPLE, 'user.tags[1]').valueText).assertEqual('dev');
      const rootArr: string = '[{"id":10},{"id":20}]';
      const r2 = queryJsonPath(rootArr, '[1].id');
      expect(r2.valueText).assertEqual('20');
    });

    it('数字与布尔类型', 0, () => {
      expect(queryJsonPath(SAMPLE, 'user.age').type).assertEqual('number');
      expect(queryJsonPath(SAMPLE, 'id').type).assertEqual('number');
    });

    it('对象值序列化为 JSON 文本', 0, () => {
      const r = queryJsonPath(SAMPLE, 'user');
      expect(r.type).assertEqual('object');
      expect(r.valueText.indexOf('alice') >= 0).assertEqual(true);
    });

    it('路径不存在报错并带出段名', 0, () => {
      const r = queryJsonPath(SAMPLE, 'user.missing');
      expect(r.ok).assertEqual(false);
      expect(r.failure.code).assertEqual(JsonPathFailureCode.PATH_NOT_FOUND);
      expect(r.failure.args[0]).assertEqual('missing');
    });

    it('数组下标越界报错', 0, () => {
      const r = queryJsonPath(SAMPLE, 'user.tags[5]');
      expect(r.failure.code).assertEqual(JsonPathFailureCode.PATH_NOT_FOUND);
    });

    it('路径语法错误：[abc] 与 a..b', 0, () => {
      expect(queryJsonPath(SAMPLE, 'user[abc]').failure.code)
        .assertEqual(JsonPathFailureCode.BAD_PATH_SYNTAX);
      expect(queryJsonPath(SAMPLE, 'user..name').failure.code)
        .assertEqual(JsonPathFailureCode.BAD_PATH_SYNTAX);
    });

    it('bad JSON 报错；空输入/空路径报错', 0, () => {
      expect(queryJsonPath('{bad', 'a').failure.code).assertEqual(JsonPathFailureCode.BAD_JSON);
      expect(queryJsonPath(SAMPLE, '').failure.code).assertEqual(JsonPathFailureCode.EMPTY_PATH);
      expect(queryJsonPath('', 'a').failure.code).assertEqual(JsonPathFailureCode.EMPTY_INPUT);
    });
  });
}
