import { describe, expect, it } from '@ohos/hypium';
import {
  csvToJson,
  jsonToCsv,
  CsvJsonFailureCode
} from '../main/ets/tools/csv-json/CsvJson';

/**
 * CSV 与 JSON 互转的单测。round-trip 为主。
 *
 * 字符一律 fromCharCode（转义坑）；断言优先用「整段相等」——失败时 hypium 会
 * 打出实际值，便于对账。类型推断防丢精度：15 位以上数字保留为字符串。
 */
const LF: string = String.fromCharCode(10);
const Q: string = String.fromCharCode(34);
const CM: string = String.fromCharCode(44);

export default function csvJsonTest() {
  describe('csvJsonTest', () => {
    it('CSV 转 JSON：类型推断与整段输出', 0, () => {
      const r = csvToJson('id,active,name,note' + LF + '1,true,alice,' + LF + '2,false,bob,x');
      expect(r.ok).assertEqual(true);
      expect(r.rowCount).assertEqual(2);
      expect(r.columnCount).assertEqual(4);
      const expected: string = '[' + LF + '    {' + Q + 'id' + Q + ': 1, ' + Q + 'active' + Q + ': true, '
        + Q + 'name' + Q + ': ' + Q + 'alice' + Q + ', ' + Q + 'note' + Q + ': null},' + LF
        + '    {' + Q + 'id' + Q + ': 2, ' + Q + 'active' + Q + ': false, ' + Q + 'name' + Q + ': '
        + Q + 'bob' + Q + ', ' + Q + 'note' + Q + ': ' + Q + 'x' + Q + '}' + LF + ']';
      expect(r.json).assertEqual(expected);
    });

    it('CSV 转 JSON：15 位以上数字保留为字符串', 0, () => {
      const big: string = '12345678901234567890';
      const r = csvToJson('id' + LF + big);
      expect(r.ok).assertEqual(true);
      const expected: string = '[' + LF + '    {' + Q + 'id' + Q + ': ' + Q + big + Q + '}' + LF + ']';
      expect(r.json).assertEqual(expected);
    });

    it('CSV 转 JSON：引号字段含逗号与双引号转义', 0, () => {
      const r = csvToJson('name' + LF + Q + 'a' + CM + 'b' + Q);
      expect(r.ok).assertEqual(true);
      const expected: string = '[' + LF + '    {' + Q + 'name' + Q + ': ' + Q + 'a' + CM + 'b' + Q + '}' + LF + ']';
      expect(r.json).assertEqual(expected);
      const r2 = csvToJson('note' + LF + Q + 'he said ' + Q + Q + 'hi' + Q + Q + Q);
      expect(r2.ok).assertEqual(true);
      expect(r2.json.indexOf('he said ' + String.fromCharCode(92) + Q + 'hi' + String.fromCharCode(92) + Q) > 0).assertTrue();
    });

    it('CSV 转 JSON：字段数不一致报错并带行号', 0, () => {
      const r = csvToJson('a,b' + LF + '1');
      expect(r.ok).assertEqual(false);
      expect(r.failure.code).assertEqual(CsvJsonFailureCode.COLUMN_MISMATCH);
      expect(r.failure.args[0]).assertEqual('2');
    });

    it('CSV 转 JSON：只有表头报 NO_DATA_ROWS；空输入报 EMPTY_INPUT', 0, () => {
      expect(csvToJson('a,b').failure.code).assertEqual(CsvJsonFailureCode.NO_DATA_ROWS);
      expect(csvToJson('  ').failure.code).assertEqual(CsvJsonFailureCode.EMPTY_INPUT);
    });

    it('JSON 转 CSV：逗号转义与缺键报错', 0, () => {
      const json = '[' + '{' + Q + 'name' + Q + ': ' + Q + 'a' + CM + 'b' + Q + '}' + ']';
      const r = jsonToCsv(json);
      expect(r.ok).assertEqual(true);
      expect(r.csv.indexOf(Q + 'a' + CM + 'b' + Q) > 0).assertTrue();
      const bad = '[' + '{' + Q + 'a' + Q + ':1},' + '{' + Q + 'b' + Q + ':2}' + ']';
      const rb = jsonToCsv(bad);
      expect(rb.ok).assertEqual(false);
      expect(rb.failure.code).assertEqual(CsvJsonFailureCode.INCONSISTENT_KEYS);
    });

    it('JSON 转 CSV：非数组、纯值数组、空数组、坏 JSON', 0, () => {
      expect(jsonToCsv('{}}').failure.code).assertEqual(CsvJsonFailureCode.BAD_JSON);
      expect(jsonToCsv('[1,2]').failure.code).assertEqual(CsvJsonFailureCode.NOT_OBJECT_ARRAY);
      expect(jsonToCsv('[]').failure.code).assertEqual(CsvJsonFailureCode.NO_DATA_ROWS);
    });

    it('round-trip：CSV 到 JSON 再回 CSV，值层面等价', 0, () => {
      const csv = 'id,name' + LF + '1,alice' + LF + '2,bob';
      const mid = csvToJson(csv);
      expect(mid.ok).assertEqual(true);
      const back = jsonToCsv(mid.json);
      expect(back.ok).assertEqual(true);
      expect(back.csv.split(LF).length).assertEqual(3);
      expect(back.csv.indexOf('alice') > 0).assertTrue();
      expect(back.csv.indexOf('bob') > 0).assertTrue();
    });
  });
}
