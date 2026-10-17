/**
 * UUID 批量的去重校验（薄封装 uuid-password 的批量生成）。
 *
 * ## 为什么这个文件存在
 *
 * 本工具是 uuid-password 批量生成的薄封装，但「生成结果去重校验」是
 * 本工具的独立功能（批量场景的完整性检查）：重复 UUID 出现即报错——
 * 在测试 fixture 或数据库 seed 场景，重复键会直接失败。
 *
 * @module tools/uuid-batch/UuidBatchLogic
 */

import { generateUuidBatch, NGFRandomByteSource, NGFUuidBatchResult } from '../uuid-password/UuidPasswordLogic';

/** 校验结果 */
export class UuidBatchCheckResult {
  readonly ok: boolean;
  readonly duplicates: Array<string>;
  readonly result: NGFUuidBatchResult;

  constructor(ok: boolean, duplicates: Array<string>, result: NGFUuidBatchResult) {
    this.ok = ok;
    this.duplicates = duplicates;
    this.result = result;
  }
}

/** 生成并去重校验 */
export function generateUuidBatchChecked(source: NGFRandomByteSource, count: number,
  uppercase: boolean, hyphens: boolean): UuidBatchCheckResult {
  const r: NGFUuidBatchResult = generateUuidBatch(source, count, uppercase, hyphens);
  if (!r.ok) {
    return new UuidBatchCheckResult(false, [], r);
  }
  const seen: Set<string> = new Set<string>();
  const duplicates: Array<string> = [];
  for (let i = 0; i < r.uuids.length; i++) {
    if (seen.has(r.uuids[i])) {
      duplicates.push(r.uuids[i]);
    }
    seen.add(r.uuids[i]);
  }
  return new UuidBatchCheckResult(duplicates.length === 0, duplicates, r);
}