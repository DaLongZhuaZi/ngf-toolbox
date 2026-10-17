import { describe, expect, it } from '@ohos/hypium';
import { generateTable } from '../main/ets/tools/md-table-gen/MdTableLogic';

/**
 * Markdown 表格生成的单测：结构、竖线转义、列补齐。
 */
export default function mdTableGenTest() {
  describe('mdTableGenTest', () => {
    it('基本生成：表头 + 分隔 + 数据行', 0, () => {
      const r = generateTable('name,age' + LF + 'alice,30', ',');
      const linesArr = r.markdown.split(LF);
      expect(linesArr.length).assertEqual(3);
      expect(linesArr[0]).assertEqual('| name | age |');
      expect(linesArr[1]).assertEqual('| --- | --- |');
      expect(linesArr[2]).assertEqual('| alice | 30 |');
      expect(r.rowCount).assertEqual(2);
      expect(r.columnCount).assertEqual(2);
    });

    it('竖线转义', 0, () => {
      const r = generateTable('a|b,c', ',');
      expect(r.markdown.indexOf('&#124;') >= 0).assertEqual(true);
      expect(r.columnCount).assertEqual(2);
    });

    it('列数不足补空单元格', 0, () => {
      const r = generateTable('h1,h2,h3' + LF + 'only-two', ',');
      const linesArr = r.markdown.split(LF);
      expect(linesArr[2]).assertEqual('| only-two |  |  |');
    });

    it('自定义分隔符：制表符', 0, () => {
      const r = generateTable('a' + TAB + 'b', TAB);
      expect(r.markdown).assertEqual('| a | b |' + LF + '| --- | --- |');
    });

    it('空行跳过；空输入报错', 0, () => {
      const r = generateTable('a,b' + LF + LF + 'c,d', ',');
      expect(r.rowCount).assertEqual(2);
      expect(generateTable('', ',').failure.code).assertEqual('empty_input');
    });
  });
}
const LF = String.fromCharCode(10);
const TAB = String.fromCharCode(9);
