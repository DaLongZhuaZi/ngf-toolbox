/**
 * 单位换算的纯逻辑实现。
 *
 * ## 换算模型
 *
 * 每类单位一张「到基准单位的系数」表：换算 = 值 × 源系数 ÷ 目标系数。
 * 温度是仿射换算（有偏移），单独走 convertTemperature。
 *
 * ## 类别与单位
 *
 * 数据量（字节系，1024 进制）、长度（米制）、时间（秒系）、重量（千克系）。
 * 开发者视角选高频单位，不做全量单位库。
 *
 * @module tools/unit-convert/UnitConvert
 */

/** 单位类别 */
export enum UnitCategory {
  DATA = 'data',
  LENGTH = 'length',
  TIME = 'time',
  WEIGHT = 'weight'
}

/** 失败原因码 */
export enum UnitFailureCode {
  NONE = 'none',
  EMPTY_VALUE = 'empty_value',
  NOT_A_NUMBER = 'not_a_number',
  /** 负数输入（长度/数据量/时间不允许负值） */
  NEGATIVE = 'negative',
  UNKNOWN_UNIT = 'unknown_unit'
}

/** 一次失败的原因与文案参数 */
export class UnitFailure {
  readonly code: UnitFailureCode;
  readonly args: Array<string>;

  constructor(code: UnitFailureCode, args: Array<string>) {
    this.code = code;
    this.args = args;
  }
}

/** 换算结果 */
export class UnitConvertResult {
  readonly ok: boolean;
  readonly failure: UnitFailure;
  readonly value: number;

  constructor(ok: boolean, failure: UnitFailure, value: number) {
    this.ok = ok;
    this.failure = failure;
    this.value = value;
  }
}

/** 单位定义（键是稳定 ID，页面用资源键显示名称） */
export class UnitDef {
  readonly id: string;
  /** 到该类基准单位的系数 */
  readonly factor: number;

  constructor(id: string, factor: number) {
    this.id = id;
    this.factor = factor;
  }
}

function dataUnits(): Array<UnitDef> {
  return [
    new UnitDef('byte', 1),
    new UnitDef('kb', 1024),
    new UnitDef('mb', 1048576),
    new UnitDef('gb', 1073741824),
    new UnitDef('tb', 1099511627776)
  ];
}

function lengthUnits(): Array<UnitDef> {
  return [
    new UnitDef('mm', 0.001),
    new UnitDef('cm', 0.01),
    new UnitDef('m', 1),
    new UnitDef('km', 1000),
    new UnitDef('inch', 0.0254),
    new UnitDef('foot', 0.3048)
  ];
}

function timeUnits(): Array<UnitDef> {
  return [
    new UnitDef('ms', 0.001),
    new UnitDef('s', 1),
    new UnitDef('min', 60),
    new UnitDef('hour', 3600),
    new UnitDef('day', 86400)
  ];
}

function weightUnits(): Array<UnitDef> {
  return [
    new UnitDef('g', 0.001),
    new UnitDef('kg', 1),
    new UnitDef('ton', 1000),
    new UnitDef('oz', 0.028349523125),
    new UnitDef('lb', 0.45359237)
  ];
}

/** 取某类的单位表 */
export function unitsOf(category: UnitCategory): Array<UnitDef> {
  if (category === UnitCategory.DATA) {
    return dataUnits();
  }
  if (category === UnitCategory.LENGTH) {
    return lengthUnits();
  }
  if (category === UnitCategory.TIME) {
    return timeUnits();
  }
  return weightUnits();
}

function findFactor(category: UnitCategory, unitId: string): number {
  const units: Array<UnitDef> = unitsOf(category);
  for (let i = 0; i < units.length; i++) {
    if (units[i].id === unitId) {
      return units[i].factor;
    }
  }
  return -1;
}

/**
 * 比例换算（数据量/长度/时间/重量通用）。
 */
export function convertUnit(category: UnitCategory, valueText: string,
  fromUnit: string, toUnit: string): UnitConvertResult {
  if (valueText.trim().length === 0) {
    return new UnitConvertResult(false, new UnitFailure(UnitFailureCode.EMPTY_VALUE, []), 0);
  }
  const value: number = parseFloat(valueText);
  if (isNaN(value)) {
    return new UnitConvertResult(false,
      new UnitFailure(UnitFailureCode.NOT_A_NUMBER, [valueText]), 0);
  }
  if (value < 0) {
    return new UnitConvertResult(false,
      new UnitFailure(UnitFailureCode.NEGATIVE, [valueText]), 0);
  }
  const fromFactor: number = findFactor(category, fromUnit);
  const toFactor: number = findFactor(category, toUnit);
  if (fromFactor < 0 || toFactor < 0) {
    return new UnitConvertResult(false,
      new UnitFailure(UnitFailureCode.UNKNOWN_UNIT, [fromUnit + '→' + toUnit]), 0);
  }
  return new UnitConvertResult(true,
    new UnitFailure(UnitFailureCode.NONE, []), value * fromFactor / toFactor);
}

/** 温度换算（仿射）：celsius / fahrenheit / kelvin */
export enum TempUnit {
  CELSIUS = 'celsius',
  FAHRENHEIT = 'fahrenheit',
  KELVIN = 'kelvin'
}

/** 温度结果（含物理下限校验） */
export class TempConvertResult {
  readonly ok: boolean;
  readonly failure: UnitFailure;
  readonly value: number;

  constructor(ok: boolean, failure: UnitFailure, value: number) {
    this.ok = ok;
    this.failure = failure;
    this.value = value;
  }
}

/** 温度换算：统一转摄氏再转目标 */
export function convertTemperature(valueText: string, from: TempUnit, to: TempUnit): TempConvertResult {
  if (valueText.trim().length === 0) {
    return new TempConvertResult(false, new UnitFailure(UnitFailureCode.EMPTY_VALUE, []), 0);
  }
  const value: number = parseFloat(valueText);
  if (isNaN(value)) {
    return new TempConvertResult(false,
      new UnitFailure(UnitFailureCode.NOT_A_NUMBER, [valueText]), 0);
  }
  let celsius: number = 0;
  if (from === TempUnit.CELSIUS) {
    celsius = value;
  } else if (from === TempUnit.FAHRENHEIT) {
    celsius = (value - 32) * 5 / 9;
  } else {
    celsius = value - 273.15;
  }
  if (celsius < -273.15) {
    return new TempConvertResult(false,
      new UnitFailure(UnitFailureCode.NEGATIVE, [valueText]), 0);
  }
  let out: number = celsius;
  if (to === TempUnit.FAHRENHEIT) {
    out = celsius * 9 / 5 + 32;
  } else if (to === TempUnit.KELVIN) {
    out = celsius + 273.15;
  }
  return new TempConvertResult(true, new UnitFailure(UnitFailureCode.NONE, []), out);
}
