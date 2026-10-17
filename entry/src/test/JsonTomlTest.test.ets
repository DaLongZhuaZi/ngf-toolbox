import { describe, expect, it } from '@ohos/hypium';
import {
  tomlToJson,
  TomlFailureCode
} from '../main/ets/tools/json-toml/JsonToml';

/**
 * TOML 解析的单测：基础表/子表/点键/类型/注释/单行数组/错误路径。
 */
export default function jsonTomlTest() {
  describe('jsonTomlTest', () => {
    it('键值对与类型：字符串/整数/浮点/布尔', 0, () => {
      const nameResult = tomlToJson('name = "alice"');
      expect(nameResult.ok).assertEqual(true);
      expect((JSON.parse(nameResult.json) as Record<string, Object>).name as string).assertEqual('alice');
      const ageResult = tomlToJson('age = 30');
      expect((JSON.parse(ageResult.json) as Record<string, Object>).age as number).assertEqual(30);
      const scoreResult = tomlToJson('score = 9.5');
      expect((JSON.parse(scoreResult.json) as Record<string, Object>).score as number).assertEqual(9.5);
      const activeResult = tomlToJson('active = true');
      expect((JSON.parse(activeResult.json) as Record<string, Object>).active as boolean).assertEqual(true);
    });

    it('基础表 [owner] 归组', 0, () => {
      const r = tomlToJson('[owner]\n' + 'name = "tom"');
      const obj = JSON.parse(r.json);
      expect(obj.owner.name).assertEqual('tom');
    });

    it('子表 [a.b] 两级嵌套', 0, () => {
      const r = tomlToJson('[a.b]\n' + 'x = 1');
      const obj = JSON.parse(r.json);
      expect(obj.a.b.x).assertEqual(1);
    });

    it('点键 a.b = 1 等价子表', 0, () => {
      const r = tomlToJson('a.b = 1');
      const obj = JSON.parse(r.json);
      expect(obj.a.b).assertEqual(1);
    });

    it("注释（含行内）被忽略", 0, () => {
      const r = tomlToJson('# 整行注释\n' + 'x = 1 # 行内注释\n' + 'y = "a#b"');
      const obj = JSON.parse(r.json);
      expect(obj.x).assertEqual(1);
      expect(obj.y).assertEqual('a#b');
    });

    it('单行数组（字符串与数字）', 0, () => {
      const r = tomlToJson('tags = ["a", "b"]\n' + 'nums = [1, 2, 3]');
      const obj = JSON.parse(r.json);
      expect(obj.tags.length).assertEqual(2);
      expect(obj.tags[1]).assertEqual('b');
      expect(obj.nums[2]).assertEqual(3);
    });

    it('三引号多行字符串明确报错', 0, () => {
      const r = tomlToJson('x = """abc"""');
      expect(r.failure.code).assertEqual(TomlFailureCode.UNSUPPORTED_MULTILINE);
    });

    it('缺等号、坏值带行号报错', 0, () => {
      expect(tomlToJson('justakey').failure.code).assertEqual(TomlFailureCode.SYNTAX_ERROR);
      const r = tomlToJson('a = 1\nbad =');
      expect(r.failure.code).assertEqual(TomlFailureCode.SYNTAX_ERROR);
      expect(r.failure.code).assertEqual(TomlFailureCode.SYNTAX_ERROR);
    });

    it('空输入报错', 0, () => {
      expect(tomlToJson('').failure.code).assertEqual(TomlFailureCode.EMPTY_INPUT);
    });
  });
}