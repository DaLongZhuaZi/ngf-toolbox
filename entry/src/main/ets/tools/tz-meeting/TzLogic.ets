/**
 * 时区会议时间的纯逻辑实现（薄封装时间戳的 partsOf/formatWithOffset）。
 *
 * ## 城市表
 *
 * 八个常用协作城市（固定偏移，不含夏令时——limitation 写明）：
 * 北京/东京/新加坡/伦敦/巴黎/纽约/旧金山/悉尼。
 *
 * @module tools/tz-meeting/TzLogic
 */

import { NGFLocalizedText } from '../../core/ToolModel';

import { formatWithOffset } from '../timestamp/TimestampLogic';

/** 失败原因码 */
export enum TzFailureCode {
  NONE = 'none',
  EMPTY_INPUT = 'empty_input',
  BAD_TIME = 'bad_time'
}

/** 一次失败的原因与文案参数 */
export class TzFailure {
  readonly code: TzFailureCode;
  readonly args: Array<string>;

  constructor(code: TzFailureCode, args: Array<string>) {
    this.code = code;
    this.args = args;
  }
}

/** 一个城市行 */
export class TzCityRow {
  readonly city: NGFLocalizedText;
  readonly timeText: string;
  /** 是否在工作时段（8:00-22:00 当地） */
  readonly reasonable: boolean;

  constructor(city: NGFLocalizedText, timeText: string, reasonable: boolean) {
    this.city = city;
    this.timeText = timeText;
    this.reasonable = reasonable;
  }
}

/** 结果 */
export class TzResult {
  readonly ok: boolean;
  readonly failure: TzFailure;
  readonly rows: Array<TzCityRow>;

  constructor(ok: boolean, failure: TzFailure, rows: Array<TzCityRow>) {
    this.ok = ok;
    this.failure = failure;
    this.rows = rows;
  }
}

class TzCity {
  readonly name: NGFLocalizedText;
  readonly offsetMinutes: number;

  constructor(name: NGFLocalizedText, offsetMinutes: number) {
    this.name = name;
    this.offsetMinutes = offsetMinutes;
  }
}

function buildCities(): Array<TzCity> {
  const out: Array<TzCity> = [];
  out.push(new TzCity(new NGFLocalizedText('北京', 'Beijing'), 480));
  out.push(new TzCity(new NGFLocalizedText('东京', 'Tokyo'), 540));
  out.push(new TzCity(new NGFLocalizedText('新加坡', 'Singapore'), 480));
  out.push(new TzCity(new NGFLocalizedText('伦敦', 'London'), 0));
  out.push(new TzCity(new NGFLocalizedText('巴黎', 'Paris'), 60));
  out.push(new TzCity(new NGFLocalizedText('纽约', 'New York'), -300));
  out.push(new TzCity(new NGFLocalizedText('旧金山', 'San Francisco'), -480));
  out.push(new TzCity(new NGFLocalizedText('悉尼', 'Sydney'), 600));
  return out;
}

/** 城市名列表（测试断言用；页面直接用 row.city.forLocale） */
export function tzCityNames(): Array<string> {
  const out: Array<string> = [];
  for (let i = 0; i < CITIES.length; i++) {
    out.push(CITIES[i].name.zh);
  }
  return out;
}

const CITIES: Array<TzCity> = buildCities();


/**
 * 输入基准时区的时刻（HH:mm），输出各城市对照。
 * baseOffsetMinutes 是基准时区偏移（默认北京 480）。
 */
export function meetingTimes(timeText: string, baseOffsetMinutes: number): TzResult {
  if (timeText.trim().length === 0) {
    return new TzResult(false, new TzFailure(TzFailureCode.EMPTY_INPUT, []), []);
  }
  const t: string = timeText.trim();
  const colon: number = t.indexOf(':');
  if (colon <= 0) {
    return new TzResult(false, new TzFailure(TzFailureCode.BAD_TIME, []), []);
  }
  const hh: number = parseInt(t.substring(0, colon), 10);
  const mm: number = parseInt(t.substring(colon + 1), 10);
  if (isNaN(hh) || isNaN(mm) || hh < 0 || hh > 23 || mm < 0 || mm > 59) {
    return new TzResult(false, new TzFailure(TzFailureCode.BAD_TIME, []), []);
  }
  const baseMs: number = Date.UTC(2000, 0, 3, hh, mm) - baseOffsetMinutes * 60000;
  const rows: Array<TzCityRow> = [];
  for (let i = 0; i < CITIES.length; i++) {
    const city: TzCity = CITIES[i];
    const timeText2: string = formatWithOffset(baseMs, city.offsetMinutes, 'HH:mm');
    const localMs: number = baseMs + city.offsetMinutes * 60000;
    const localH: number = new Date(localMs).getUTCHours();
    rows.push(new TzCityRow(city.name, timeText2, localH >= 8 && localH < 22));

  }
  return new TzResult(true, new TzFailure(TzFailureCode.NONE, []), rows);
}