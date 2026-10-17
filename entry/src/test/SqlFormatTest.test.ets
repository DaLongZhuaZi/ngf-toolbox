import { describe, expect, it } from '@ohos/hypium';
import {
  formatSql,
  SqlFormatFailureCode
} from '../main/ets/tools/sql-format/SqlFormat';

/**
 * SQL 格式化的单测：**结果逐行断言**（关键字大写/主子句换行/连接词缩进/字符串保护）
 */
export default function sqlFormatTest() {
  describe('sqlFormatTest', () => {
    it('关键字大写：select/from/where', 0, () => {
      const r = formatSql('select id, name from users where age > 18');
      expect(r.formatted.indexOf('SELECT') === 0).assertEqual(true);
      expect(r.formatted.indexOf('FROM') > 0).assertEqual(true);
      expect(r.formatted.indexOf('WHERE') > 0).assertEqual(true);
    });

    it('主子句换行：每个主子句顶起新行', 0, () => {
      const r = formatSql('select a from t where b = 1 order by a limit 10');
      const linesArr = r.formatted.split(String.fromCharCode(10));
      expect(linesArr.length).assertEqual(5);
      expect(linesArr[0].indexOf('SELECT') === 0).assertEqual(true);
      expect(linesArr[1].indexOf('FROM') === 0).assertEqual(true);
      expect(linesArr[2].indexOf('WHERE') === 0).assertEqual(true);
      expect(linesArr[4].indexOf('LIMIT') === 0).assertEqual(true);
    });

    it('AND/OR 换行加两空格缩进', 0, () => {
      const r = formatSql('select a from t where b = 1 and c = 2 or d = 3');
      const linesArr = r.formatted.split(String.fromCharCode(10));
      // WHERE 行 + AND 行 + OR 行
      expect(linesArr[3]).assertEqual('  AND c = 2');
      expect(linesArr[4]).assertEqual('  OR d = 3');
    });

    it('字符串字面量内不大写', 0, () => {
      const r = formatSql('select ' + "'from where and'" + ' from t');
      expect(r.formatted.indexOf("'from where and'") > 0).assertEqual(true);
      expect(r.formatted.indexOf("'FROM WHERE AND'") < 0).assertEqual(true);
    });

    it('两词主子句 ORDER BY / GROUP BY 识别', 0, () => {
      const r = formatSql('select a, count(*) from t group by a order by a desc');
      const linesArr = r.formatted.split(String.fromCharCode(10));
      let hasGroup = false;
      let hasOrder = false;
      for (let i = 0; i < linesArr.length; i++) {
        if (linesArr[i].indexOf('GROUP BY') === 0) { hasGroup = true; }
        if (linesArr[i].indexOf('ORDER BY') === 0) { hasOrder = true; }
      }
      expect(hasGroup).assertEqual(true);
      expect(hasOrder).assertEqual(true);
    });

    it('大小写混合输入也归一', 0, () => {
      const r = formatSql('SeLeCt a FrOm t');
      expect(r.formatted.indexOf('SELECT') === 0).assertEqual(true);
      expect(r.formatted.indexOf('FROM') > 0).assertEqual(true);
    });

    it('引号未闭合报错；空输入报错', 0, () => {
      expect(formatSql('select ' + "'unclosed").failure.code)
        .assertEqual(SqlFormatFailureCode.UNCLOSED_QUOTE);
      expect(formatSql('').failure.code).assertEqual(SqlFormatFailureCode.EMPTY_INPUT);
    });

    it('逗号列分隔保留在行内', 0, () => {
      const r = formatSql('select id, name, age from t');
      const firstLine = r.formatted.split(String.fromCharCode(10))[0];
      expect(firstLine.indexOf(',') > 0).assertEqual(true);
    });
  });
}