import { describe, expect, it } from '@ohos/hypium';
import {
  yamlToJson,
  YamlFailureCode
} from '../main/ets/tools/json-yaml/JsonYaml';

/** 行分隔与 Tab 的字面常量 */
const NL2 = '\n';
const TABCH = '\t';

/**
 * YAML 子集解析的单测：标量类型 / 一层嵌套 / 行内数组 / 注释 / 缩进与多文档错误。
 */
export default function jsonYamlTest() {
  describe('jsonYamlTest', () => {
    it('顶层标量：字符串/整数/浮点/布尔/null', 0, () => {
      const input = 'name: alice' + NL2 + 'age: 30' + NL2 + 'score: 9.5' + NL2 + 'active: true' + NL2 + 'note: null';
      const r = yamlToJson(input);
      expect(r.ok).assertEqual(true);
      const obj = JSON.parse(r.json);
      expect(obj.name).assertEqual('alice');
      expect(obj.age).assertEqual(30);
      expect(obj.score).assertEqual(9.5);
      expect(obj.active).assertEqual(true);
    });

    it('一层嵌套对象（两空格缩进）', 0, () => {
      const input = 'server:' + NL2 + '  host: localhost' + NL2 + '  port: 8080';
      const r = yamlToJson(input);
      const obj = JSON.parse(r.json);
      expect(obj.server.host).assertEqual('localhost');
      expect(obj.server.port).assertEqual(8080);
    });

    it('行内数组', 0, () => {
      const r = yamlToJson('tags: [alpha, beta]');
      const obj = JSON.parse(r.json);
      expect(obj.tags.length).assertEqual(2);
      expect(obj.tags[1]).assertEqual('beta');
    });

    it('整行注释被忽略', 0, () => {
      const input = '# 配置' + NL2 + 'x: 1';
      const r = yamlToJson(input);
      const obj = JSON.parse(r.json);
      expect(obj.x).assertEqual(1);
    });

    it('Tab 缩进报错', 0, () => {
      const input = 'server:' + NL2 + TABCH + 'host: x';
      expect(yamlToJson(input).failure.code).assertEqual(YamlFailureCode.BAD_INDENT);
    });

    it('三层缩进（超过一层嵌套）报错', 0, () => {
      const input = 'a:' + NL2 + '  b:' + NL2 + '    c: 1';
      expect(yamlToJson(input).failure.code).assertEqual(YamlFailureCode.BAD_INDENT);
    });

    it('多文档分隔符报错', 0, () => {
      const input = 'a: 1' + NL2 + '---' + NL2 + 'b: 2';
      expect(yamlToJson(input).failure.code).assertEqual(YamlFailureCode.MULTI_DOCUMENT);
    });

    it('多行块标量（竖线）报错', 0, () => {
      const r = yamlToJson('text: |');
      expect(r.failure.code).assertEqual(YamlFailureCode.UNSUPPORTED_BLOCK);
    });

    it('缺冒号报错；空输入报错', 0, () => {
      expect(yamlToJson('justakey').failure.code).assertEqual(YamlFailureCode.SYNTAX_ERROR);
      expect(yamlToJson('').failure.code).assertEqual(YamlFailureCode.EMPTY_INPUT);
    });
  });
}