import { describe, expect, it } from '@ohos/hypium';
import {
  detectBrowser,
  detectEngine,
  detectOS,
  parseUserAgent
} from '../main/ets/tools/ua-parser/UaParser';

/**
 * UA 解析的单测：**真实 UA 样本**（Chrome/Edge/Firefox/Safari 各平台）。
 * 浏览器识别的顺序敏感（Edg/ 在 Chrome/ 之前的 UA 里）是重点。
 */
export default function uaParserTest() {
  describe('uaParserTest', () => {
    it('Chrome on Windows', 0, () => {
      const ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
      expect(detectBrowser(ua)).assertEqual('Chrome');
      expect(detectEngine(ua)).assertEqual('Blink');
      expect(detectOS(ua)).assertEqual('Windows');
    });

    it('Edge on Windows：Edg/ 优先于 Chrome/', 0, () => {
      const ua = 'Mozilla/5.0 (Windows NT 10.0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0';
      expect(detectBrowser(ua)).assertEqual('Edge');
      expect(detectEngine(ua)).assertEqual('Blink');
      expect(detectOS(ua)).assertEqual('Windows');
    });

    it('Firefox on Linux', 0, () => {
      const ua = 'Mozilla/5.0 (X11; Linux x86_64; rv:120.0) Gecko/20100101 Firefox/120.0';
      expect(detectBrowser(ua)).assertEqual('Firefox');
      expect(detectEngine(ua)).assertEqual('Gecko');
      expect(detectOS(ua)).assertEqual('Linux');
    });

    it('Safari on macOS：无 Chrome 时才识别 Safari', 0, () => {
      const ua = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15';
      expect(detectBrowser(ua)).assertEqual('Safari');
      expect(detectEngine(ua)).assertEqual('WebKit');
      expect(detectOS(ua)).assertEqual('macOS');
    });

    it('Opera：OPR/ 优先于 Chrome/', 0, () => {
      const ua = 'Mozilla/5.0 (Windows NT 10.0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 OPR/105.0.0.0';
      expect(detectBrowser(ua)).assertEqual('Opera');
    });

    it('Android Chrome', 0, () => {
      const ua = 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';
      expect(detectOS(ua)).assertEqual('Android');
      expect(detectBrowser(ua)).assertEqual('Chrome');
    });

    it('iOS Safari', 0, () => {
      const ua = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1';
      expect(detectOS(ua)).assertEqual('iOS');
      expect(detectBrowser(ua)).assertEqual('Safari');
    });

    it('空串与未知 UA → unknown + partial', 0, () => {
      const r = parseUserAgent('');
      expect(r.browser).assertEqual('unknown');
      expect(r.partial).assertEqual(true);
      const r2 = parseUserAgent('SomeRandomBot/1.0');
      expect(r2.partial).assertEqual(true);
    });

    it('parseUserAgent 聚合三维', 0, () => {
      const r = parseUserAgent('Mozilla/5.0 (Windows NT 10.0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
      expect(r.browser).assertEqual('Chrome');
      expect(r.engine).assertEqual('Blink');
      expect(r.os).assertEqual('Windows');
      expect(r.partial).assertEqual(false);
    });
  });
}
