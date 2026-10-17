import { describe, expect, it } from '@ohos/hypium';
import {
  convertTemperature,
  convertUnit,
  unitsOf,
  TempUnit,
  UnitCategory,
  UnitFailureCode
} from '../main/ets/tools/unit-convert/UnitConvert';

/**
 * 单位换算的单测：**手算基准值**。
 * 数据量 1024 进制（不是 1000）；温度的物理下限（绝对零度）要拦。
 */
export default function unitConvertTest() {
  describe('unitConvertTest', () => {
    it('数据量：1 GB = 1024 MB = 1048576 KB', 0, () => {
      expect(convertUnit(UnitCategory.DATA, '1', 'gb', 'mb').value).assertEqual(1024);
      expect(convertUnit(UnitCategory.DATA, '1', 'gb', 'kb').value).assertEqual(1048576);
      expect(convertUnit(UnitCategory.DATA, '2048', 'kb', 'mb').value).assertEqual(2);
    });

    it('长度：米 ↔ 英寸/英尺（国际换算系数）', 0, () => {
      // 1 inch = 0.0254 m；1 m ≈ 39.3700787 inch
      const r = convertUnit(UnitCategory.LENGTH, '1', 'm', 'inch');
      expect(Math.abs(r.value - 39.37007874015748) < 1e-9).assertTrue();
      const r2 = convertUnit(UnitCategory.LENGTH, '1', 'foot', 'm');
      expect(Math.abs(r2.value - 0.3048) < 1e-12).assertTrue();
    });

    it('时间：1 day = 86400 s = 1440 min', 0, () => {
      expect(convertUnit(UnitCategory.TIME, '1', 'day', 's').value).assertEqual(86400);
      expect(convertUnit(UnitCategory.TIME, '1', 'day', 'min').value).assertEqual(1440);
      expect(convertUnit(UnitCategory.TIME, '90', 'min', 'hour').value).assertEqual(1.5);
    });

    it('重量：1 kg = 1000 g = 2.20462... lb', 0, () => {
      expect(convertUnit(UnitCategory.WEIGHT, '1', 'kg', 'g').value).assertEqual(1000);
      const r = convertUnit(UnitCategory.WEIGHT, '1', 'kg', 'lb');
      expect(Math.abs(r.value - 2.2046226218) < 1e-6).assertTrue();
    });

    it('unitsOf：每类单位表非空且 id 唯一', 0, () => {
      for (const cat of [UnitCategory.DATA, UnitCategory.LENGTH, UnitCategory.TIME, UnitCategory.WEIGHT]) {
        const units = unitsOf(cat);
        expect(units.length > 0).assertEqual(true);
        const seen = new Set<string>();
        for (let i = 0; i < units.length; i++) {
          expect(seen.has(units[i].id)).assertEqual(false);
          seen.add(units[i].id);
        }
      }
    });

    it('温度：0°C = 32°F = 273.15 K；100°C = 212°F', 0, () => {
      expect(convertTemperature('0', TempUnit.CELSIUS, TempUnit.FAHRENHEIT).value).assertEqual(32);
      expect(convertTemperature('0', TempUnit.CELSIUS, TempUnit.KELVIN).value).assertEqual(273.15);
      expect(convertTemperature('100', TempUnit.CELSIUS, TempUnit.FAHRENHEIT).value).assertEqual(212);
    });

    it('温度：低于绝对零度报错', 0, () => {
      const r = convertTemperature('-300', TempUnit.CELSIUS, TempUnit.KELVIN);
      expect(r.ok).assertEqual(false);
      expect(r.failure.code).assertEqual(UnitFailureCode.NEGATIVE);
    });

    it('负值与非数字报错；未知单位报错', 0, () => {
      expect(convertUnit(UnitCategory.LENGTH, '-1', 'm', 'cm').failure.code)
        .assertEqual(UnitFailureCode.NEGATIVE);
      expect(convertUnit(UnitCategory.LENGTH, 'abc', 'm', 'cm').failure.code)
        .assertEqual(UnitFailureCode.NOT_A_NUMBER);
      expect(convertUnit(UnitCategory.LENGTH, '1', 'm', 'parsec').failure.code)
        .assertEqual(UnitFailureCode.UNKNOWN_UNIT);
    });

    it('round-trip：GB→MB→GB 回到原值', 0, () => {
      const mid = convertUnit(UnitCategory.DATA, '3', 'gb', 'mb');
      const back = convertUnit(UnitCategory.DATA, String(mid.value), 'mb', 'gb');
      expect(back.value).assertEqual(3);
    });
  });
}
