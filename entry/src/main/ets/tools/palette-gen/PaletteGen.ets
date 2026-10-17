/**
 * 色板生成的纯逻辑实现（薄封装 ColorConvert 的 harmony/lightnessScale）。
 *
 * ## 为什么是薄封装
 *
 * harmony/lightnessScale/parseColor 都是 ColorConvert 的既有实现（主题门禁同源）。
 * 本工具的增量只有：输入解析 + 「每色的明暗阶梯」组合——配色方案（互补/三角等）
 * 之外再给每个色一列明暗变体，这是设计稿里最常用的输出形态。
 *
 * @module tools/palette-gen/PaletteGen
 */

import {
  harmony,
  lightnessScale,
  NGFColor,
  parseColor,
  toHex
} from '../color-convert/ColorConvert';

/** 失败原因码 */
export enum PaletteFailureCode {
  NONE = 'none',
  EMPTY_INPUT = 'empty_input',
  BAD_COLOR = 'bad_color'
}

/** 一次失败的原因与文案参数 */
export class PaletteFailure {
  readonly code: PaletteFailureCode;
  readonly args: Array<string>;

  constructor(code: PaletteFailureCode, args: Array<string>) {
    this.code = code;
    this.args = args;
  }
}

/** 一个色板成员：主色或变体 */
export class PaletteSwatch {
  readonly hex: string;
  readonly isBase: boolean;

  constructor(hex: string, isBase: boolean) {
    this.hex = hex;
    this.isBase = isBase;
  }
}

/** 结果：按和谐方案分组的色板 */
export class PaletteResult {
  readonly ok: boolean;
  readonly failure: PaletteFailure;
  /** 每个基础色一组（第一项是主色，其余是明暗阶梯） */
  readonly groups: Array<Array<PaletteSwatch>>;

  constructor(ok: boolean, failure: PaletteFailure, groups: Array<Array<PaletteSwatch>>) {
    this.ok = ok;
    this.failure = failure;
    this.groups = groups;
  }
}

/**
 * 生成色板：基础色 + 和谐色，每个色再展开 5 档明暗阶梯。
 * harmonyKind 是 harmonyOptions() 里的 kind（空串 = 只做明暗阶梯）。
 */
export function generatePalette(colorText: string, harmonyKind: string): PaletteResult {
  if (colorText.trim().length === 0) {
    return new PaletteResult(false, new PaletteFailure(PaletteFailureCode.EMPTY_INPUT, []), []);
  }
  const parsed = parseColor(colorText);
  if (!parsed.ok) {
    return new PaletteResult(false, new PaletteFailure(PaletteFailureCode.BAD_COLOR, [colorText]), []);
  }
  const base: NGFColor = parsed.color as NGFColor;
  const groups: Array<Array<PaletteSwatch>> = [];
  // 第一组：主色的明暗阶梯
  const baseGroup: Array<PaletteSwatch> = [];
  const baseScale: Array<NGFColor> = lightnessScale(base, 5);
  for (let i = 0; i < baseScale.length; i++) {
    baseGroup.push(new PaletteSwatch(toHex(baseScale[i]), i === 2));
  }
  groups.push(baseGroup);
  // 和谐色（各自带阶梯）
  if (harmonyKind.length > 0) {
    const related: Array<NGFColor> = harmony(base, harmonyKind);
    for (let i = 1; i < related.length; i++) {
      const group: Array<PaletteSwatch> = [];
      const scale: Array<NGFColor> = lightnessScale(related[i], 5);
      for (let j = 0; j < scale.length; j++) {
        group.push(new PaletteSwatch(toHex(scale[j]), j === 2));
      }
      groups.push(group);
    }
  }
  return new PaletteResult(true, new PaletteFailure(PaletteFailureCode.NONE, []), groups);
}
