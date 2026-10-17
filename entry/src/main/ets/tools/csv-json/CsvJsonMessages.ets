/**
 * CSV 与 JSON 互转的显示文案（UI 层，失败码 → 资源键）。
 *
 * @module tools/csv-json/CsvJsonMessages
 */

import { ToolUiKit } from '../../ui/ToolUiKit';
import { CsvJsonFailure, CsvJsonFailureCode } from './CsvJson';

/** 把失败码翻译成当前语言的句子；NONE 返回空串 */
export function csvJsonFailureText(failure: CsvJsonFailure): string {
  if (failure.code === CsvJsonFailureCode.EMPTY_INPUT) {
    return ToolUiKit.text($r('app.string.cj_err_empty'));
  }
  if (failure.code === CsvJsonFailureCode.NO_DATA_ROWS) {
    return ToolUiKit.text($r('app.string.cj_err_no_rows'));
  }
  if (failure.code === CsvJsonFailureCode.COLUMN_MISMATCH) {
    return ToolUiKit.stringOf($r('app.string.cj_err_columns'), failure.args);
  }
  if (failure.code === CsvJsonFailureCode.NOT_OBJECT_ARRAY) {
    return ToolUiKit.text($r('app.string.cj_err_not_array'));
  }
  if (failure.code === CsvJsonFailureCode.BAD_JSON) {
    return ToolUiKit.text($r('app.string.cj_err_bad_json'));
  }
  if (failure.code === CsvJsonFailureCode.INCONSISTENT_KEYS) {
    return ToolUiKit.stringOf($r('app.string.cj_err_keys'), failure.args);
  }
  return '';
}
