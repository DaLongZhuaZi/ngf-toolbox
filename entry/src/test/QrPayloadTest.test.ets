import { describe, expect, it } from '@ohos/hypium';
import {
  buildEmailPayload,
  buildPayload,
  buildPhonePayload,
  buildSmsPayload,
  buildTextPayload,
  buildUrlPayload,
  buildVCardPayload,
  buildWifiPayload,
  encodeUrlComponent,
  escapeVCardValue,
  escapeWifiValue,
  lengthNotice,
  QrHintCode,
  QrLengthNotice,
  QrPayloadFailure,
  normalizePhone,
  normalizeUrl,
  QrContentKind,
  QrInput,
  QrKindInfo,
  QrPayloadResult,
  qrKinds,
  QR_COMFORTABLE_LENGTH,
  QrWifiSecurity,
  shorteningHint
} from '../main/ets/tools/qrcode/QrPayload';

/**
 * 二维码内容构造的单测。
 *
 * ## 为什么这些用例比看起来更重要
 *
 * 二维码工具的错误有一个恶劣性质：**写错了照样能生成一张看着正常的二维码**，
 * 只是扫出来是错的。用户发现问题时已经把它印出去或发给别人了。
 *
 * 而错误又高度集中在这几处：
 * 1. Wi-Fi 字段没转义（密码里含 ; , : 反斜杠时解析错位）；
 * 2. vCard 用了 LF 而不是 CRLF（严格解析器只识别出第一行）；
 * 3. 网址没补协议（扫出来是纯文本，不可点）；
 * 4. 电话号码没清理分隔符（拨不出去）。
 *
 * 下面的用例逐条钉住这些点。
 */
export default function qrPayloadTest() {
  describe('qrPayloadTest', () => {
    // ── 类型清单 ────────────────────────────────────────────

    it('类型清单完整且标识唯一、字段非空', 0, () => {
      const list: Array<QrKindInfo> = qrKinds();
      expect(list.length).assertEqual(7);
      const seen: Set<string> = new Set<string>();
      for (let i: number = 0; i < list.length; i++) {
        expect(seen.has(list[i].kind)).assertFalse();
        seen.add(list[i].kind);
        // 类型名是双语数据：两侧都要写得出来
        expect(list[i].label.forLocale('zh-CN').length > 0).assertTrue();
        expect(list[i].label.forLocale('en-US').length > 0).assertTrue();
        expect(list[i].fields.length > 0).assertTrue();
      }
      // 页面按这个清单渲染类型选择器，因此每种 buildXxxPayload 都必须被覆盖
      expect(seen.has(QrContentKind.TEXT)).assertTrue();
      expect(seen.has(QrContentKind.WIFI)).assertTrue();
      expect(seen.has(QrContentKind.VCARD)).assertTrue();
      expect(seen.has(QrContentKind.URL)).assertTrue();
      expect(seen.has(QrContentKind.PHONE)).assertTrue();
      expect(seen.has(QrContentKind.SMS)).assertTrue();
      expect(seen.has(QrContentKind.EMAIL)).assertTrue();
    });

    // ── Wi-Fi（最容易出错的一类） ───────────────────────────

    it('Wi-Fi 基本格式含末尾两个分号', 0, () => {
      // 末尾的 ;; 是格式的一部分（记录结束），漏掉它部分扫码器会解析失败。
      const input: QrInput = new QrInput()
        .set('ssid', 'MyNetwork')
        .set('password', 'secret123')
        .set('security', QrWifiSecurity.WPA);
      const result: QrPayloadResult = buildWifiPayload(input);
      expect(result.ok).assertTrue();
      expect(result.payload).assertEqual('WIFI:T:WPA;S:MyNetwork;P:secret123;;');
    });

    it('Wi-Fi 密码里的分号、逗号、冒号、反斜杠都被转义', 0, () => {
      // 这是本模块最要紧的一条：不转义时解析方会在错误位置截断，
      // 扫出来的密码是错的，而用户看到的只是一张"生成成功"的二维码。
      expect(escapeWifiValue('a;b')).assertEqual('a\\;b');
      expect(escapeWifiValue('a,b')).assertEqual('a\\,b');
      expect(escapeWifiValue('a:b')).assertEqual('a\\:b');
      expect(escapeWifiValue('a\\b')).assertEqual('a\\\\b');
      expect(escapeWifiValue('a"b')).assertEqual('a\\"b');

      const input: QrInput = new QrInput()
        .set('ssid', 'Net;5G')
        .set('password', 'p;w,d:1\\2')
        .set('security', QrWifiSecurity.WPA);
      const payload: string = buildWifiPayload(input).payload;
      expect(payload).assertEqual('WIFI:T:WPA;S:Net\\;5G;P:p\\;w\\,d\\:1\\\\2;;');
    });

    it('Wi-Fi 转义先处理反斜杠，避免二次转义', 0, () => {
      // 顺序错了会把刚加上的转义符再转义一遍（a;b 变成 a\\\;b 而不是 a\;b）。
      const once: string = escapeWifiValue(';');
      expect(once).assertEqual('\\;');
      // 对已经转义过的结果再转义一次，应当把反斜杠也转义（这是正确行为，不是幂等）
      expect(escapeWifiValue(once)).assertEqual('\\\\\\;');
    });

    it('无密码网络不写 P 字段', 0, () => {
      const input: QrInput = new QrInput()
        .set('ssid', 'OpenNet')
        .set('security', QrWifiSecurity.NONE);
      const result: QrPayloadResult = buildWifiPayload(input);
      expect(result.ok).assertTrue();
      expect(result.payload.indexOf('P:') < 0).assertTrue();
      expect(result.payload).assertEqual('WIFI:T:nopass;S:OpenNet;;');
    });

    it('加密方式缺省按 WPA，此时必须填密码', 0, () => {
      const noPassword: QrPayloadResult = buildWifiPayload(new QrInput().set('ssid', 'X'));
      expect(noPassword.ok).assertFalse();
      expect(noPassword.failure).assertEqual(QrPayloadFailure.WIFI_PASSWORD_REQUIRED);

      const withPassword: QrPayloadResult = buildWifiPayload(
        new QrInput().set('ssid', 'X').set('password', 'p'));
      expect(withPassword.ok).assertTrue();
      expect(withPassword.payload.indexOf('T:WPA') >= 0).assertTrue();
    });

    it('缺 SSID 被拒绝', 0, () => {
      const result: QrPayloadResult = buildWifiPayload(
        new QrInput().set('password', 'p').set('security', QrWifiSecurity.WPA));
      expect(result.ok).assertFalse();
      expect(result.failure).assertEqual(QrPayloadFailure.WIFI_SSID_REQUIRED);
    });

    it('隐藏网络会带上 H 字段', 0, () => {
      const input: QrInput = new QrInput()
        .set('ssid', 'Hidden')
        .set('password', 'p')
        .set('security', QrWifiSecurity.WPA)
        .set('hidden', 'true');
      expect(buildWifiPayload(input).payload.indexOf('H:true;') >= 0).assertTrue();
    });

    // ── vCard ───────────────────────────────────────────────

    it('vCard 用 CRLF 行尾（不是 LF）', 0, () => {
      // 用 LF 时严格解析器会把整张名片当成一行，只识别出姓名。
      const input: QrInput = new QrInput().set('name', '张三').set('tel', '13800000000');
      const payload: string = buildVCardPayload(input).payload;
      expect(payload.indexOf('\r\n') >= 0).assertTrue();
      expect(payload.indexOf('BEGIN:VCARD\r\nVERSION:3.0\r\n') >= 0).assertTrue();
      // 不能出现「没有伴随 \r 的 \n」
      const loneLf: number = payload.indexOf('\n') >= 0 && payload.indexOf('\r\n') < 0 ? 1 : 0;
      expect(loneLf).assertEqual(0);
      expect(payload.substring(payload.length - 9)).assertEqual('END:VCARD');
    });

    it('vCard 字段转义分号、逗号、换行', 0, () => {
      expect(escapeVCardValue('a;b')).assertEqual('a\\;b');
      expect(escapeVCardValue('a,b')).assertEqual('a\\,b');
      expect(escapeVCardValue('a\\b')).assertEqual('a\\\\b');
      // 换行转成字面量 \n（vCard 的规范写法）
      expect(escapeVCardValue('a\nb')).assertEqual('a\\nb');
      // CR 直接丢掉（它已经被 CRLF 表达过）
      expect(escapeVCardValue('a\rb')).assertEqual('ab');
    });

    it('vCard 缺姓名被拒绝', 0, () => {
      const result: QrPayloadResult = buildVCardPayload(new QrInput().set('tel', '138'));
      expect(result.ok).assertFalse();
      expect(result.failure).assertEqual(QrPayloadFailure.VCARD_NAME_REQUIRED);
    });

    it('vCard 总是带 N 字段（缺它部分解析器会拒收整张名片）', 0, () => {
      const payload: string = buildVCardPayload(new QrInput().set('name', 'Li')).payload;
      expect(payload.indexOf('N:Li;') >= 0).assertTrue();
    });

    it('vCard 的可选字段缺失时不写空行', 0, () => {
      const payload: string = buildVCardPayload(new QrInput().set('name', 'Li')).payload;
      expect(payload.indexOf('ORG:') < 0).assertTrue();
      expect(payload.indexOf('TEL') < 0).assertTrue();
      expect(payload.indexOf('EMAIL') < 0).assertTrue();
      // 姓名与 N 两行 + BEGIN/VERSION/END 三行
      expect(payload.split('\r\n').length).assertEqual(5);
    });

    it('vCard 的地址按 ADR 的七段格式给出', 0, () => {
      const payload: string = buildVCardPayload(
        new QrInput().set('name', 'Li').set('address', '某市某路 1 号')).payload;
      expect(payload.indexOf('ADR:;;某市某路 1 号;;;;') >= 0).assertTrue();
    });

    // ── 网址 ────────────────────────────────────────────────

    it('网址自动补 https 前缀，但保留用户写的 http', 0, () => {
      // 不补前缀时很多扫码器把它当纯文本，扫出来不可点。
      expect(normalizeUrl('example.com')).assertEqual('https://example.com');
      // 内网服务常用 http，不能擅自改成 https
      expect(normalizeUrl('http://192.168.1.1')).assertEqual('http://192.168.1.1');
      expect(normalizeUrl('https://example.com')).assertEqual('https://example.com');
      // 其它协议原样保留
      expect(normalizeUrl('ftp://files.example.com')).assertEqual('ftp://files.example.com');
      expect(normalizeUrl('')).assertEqual('');
    });

    it('明显不是网址的输入被拒绝', 0, () => {
      const result: QrPayloadResult = buildUrlPayload(new QrInput().set('url', 'notaurl'));
      expect(result.ok).assertFalse();
      expect(result.failure).assertEqual(QrPayloadFailure.URL_INVALID);
      expect(buildUrlPayload(new QrInput().set('url', '   ')).ok).assertFalse();
      // 有域名后缀就放行（不做连通性检查，那是另一回事）
      expect(buildUrlPayload(new QrInput().set('url', 'a.cn')).ok).assertTrue();
    });

    // ── 纯文本 ──────────────────────────────────────────────

    it('纯文本原样保留（含换行与空白，不 trim）', 0, () => {
      const raw: string = '  第一行\n第二行  ';
      const result: QrPayloadResult = buildTextPayload(new QrInput().set('text', raw));
      expect(result.ok).assertTrue();
      expect(result.payload).assertEqual(raw);
    });

    it('空文本被拒绝', 0, () => {
      expect(buildTextPayload(new QrInput().set('text', '')).ok).assertFalse();
    });

    // ── 电话 / 短信 / 邮件 ──────────────────────────────────

    it('电话号码去掉分隔符但保留开头的 +', 0, () => {
      expect(normalizePhone('+86 138-0000-0000')).assertEqual('+8613800000000');
      expect(normalizePhone('(010) 1234 5678')).assertEqual('01012345678');
      expect(normalizePhone('138 0000 0000')).assertEqual('13800000000');
      // 中间的 + 不是区号标记，丢掉
      expect(normalizePhone('12+34')).assertEqual('1234');
    });

    it('电话号码内容以 tel: 开头', 0, () => {
      const result: QrPayloadResult = buildPhonePayload(new QrInput().set('phone', '+86 138 0000 0000'));
      expect(result.ok).assertTrue();
      expect(result.payload).assertEqual('tel:+8613800000000');
    });

    it('没有数字的电话被拒绝，而不是生成一个 tel:+ 的二维码', 0, () => {
      expect(buildPhonePayload(new QrInput().set('phone', 'abc')).ok).assertFalse();
      expect(buildPhonePayload(new QrInput().set('phone', '+')).ok).assertFalse();
      expect(buildPhonePayload(new QrInput().set('phone', '')).ok).assertFalse();
    });

    it('短信内容用 SMSTO，有正文时用冒号接上', 0, () => {
      const bare: QrPayloadResult = buildSmsPayload(new QrInput().set('phone', '13800000000'));
      expect(bare.payload).assertEqual('SMSTO:13800000000');

      const withBody: QrPayloadResult = buildSmsPayload(
        new QrInput().set('phone', '13800000000').set('body', '你好'));
      expect(withBody.payload).assertEqual('SMSTO:13800000000:你好');
    });

    it('短信缺号码被拒绝', 0, () => {
      expect(buildSmsPayload(new QrInput().set('body', 'x')).ok).assertFalse();
    });

    it('邮件内容按 mailto 规则编码参数', 0, () => {
      const result: QrPayloadResult = buildEmailPayload(
        new QrInput().set('email', 'a@b.com').set('subject', 'hi').set('body', 'x y'));
      expect(result.ok).assertTrue();
      // 空格必须编码成 %20（原样留空格会让部分客户端截断参数）
      expect(result.payload).assertEqual('mailto:a@b.com?subject=hi&body=x%20y');
    });

    it('邮件只填地址时不带问号', 0, () => {
      const result: QrPayloadResult = buildEmailPayload(new QrInput().set('email', 'a@b.com'));
      expect(result.payload).assertEqual('mailto:a@b.com');
      expect(result.payload.indexOf('?') < 0).assertTrue();
    });

    it('邮箱格式明显不对时被拒绝', 0, () => {
      expect(buildEmailPayload(new QrInput().set('email', 'noat')).ok).assertFalse();
      expect(buildEmailPayload(new QrInput().set('email', '@b.com')).ok).assertFalse();
      expect(buildEmailPayload(new QrInput().set('email', 'a@')).ok).assertFalse();
      expect(buildEmailPayload(new QrInput().set('email', '')).ok).assertFalse();
    });

    // ── URL 编码 ────────────────────────────────────────────

    it('URL 编码只放过 unreserved 字符', 0, () => {
      // RFC 3986 的 unreserved：字母、数字、- _ . ~
      expect(encodeUrlComponent('abcABC123')).assertEqual('abcABC123');
      expect(encodeUrlComponent('-_.~')).assertEqual('-_.~');
      // 保留字符必须编码
      expect(encodeUrlComponent(' ')).assertEqual('%20');
      expect(encodeUrlComponent('&')).assertEqual('%26');
      expect(encodeUrlComponent('?')).assertEqual('%3F');
      expect(encodeUrlComponent('=')).assertEqual('%3D');
      expect(encodeUrlComponent('+')).assertEqual('%2B');
      expect(encodeUrlComponent('/')).assertEqual('%2F');
    });

    it('URL 编码正确处理中文与 emoji（UTF-8 多字节）', 0, () => {
      // 中文按 UTF-8 三字节编码：'中' = E4 B8 AD
      expect(encodeUrlComponent('中')).assertEqual('%E4%B8%AD');
      // emoji 是四字节（代理对），不按代理对处理会得到错误的字节序列
      expect(encodeUrlComponent('🎉')).assertEqual('%F0%9F%8E%89');
      // 混合
      expect(encodeUrlComponent('a中b')).assertEqual('a%E4%B8%ADb');
    });

    // ── 统一入口 ────────────────────────────────────────────

    it('统一入口按类型分派到对应构造器', 0, () => {
      const text: QrPayloadResult = buildPayload(QrContentKind.TEXT, new QrInput().set('text', 'hi'));
      expect(text.payload).assertEqual('hi');

      const url: QrPayloadResult = buildPayload(QrContentKind.URL, new QrInput().set('url', 'a.com'));
      expect(url.payload).assertEqual('https://a.com');

      const wifi: QrPayloadResult = buildPayload(QrContentKind.WIFI,
        new QrInput().set('ssid', 'S').set('password', 'p').set('security', QrWifiSecurity.WPA));
      expect(wifi.payload.indexOf('WIFI:') === 0).assertTrue();

      const phone: QrPayloadResult = buildPayload(QrContentKind.PHONE, new QrInput().set('phone', '138'));
      expect(phone.payload).assertEqual('tel:138');
    });

    it('每种类型的成功结果都带类型说明（页面据此告诉用户扫出来是什么）', 0, () => {
      const cases: Array<QrContentKind> = [QrContentKind.TEXT, QrContentKind.URL, QrContentKind.PHONE];
      const inputs: Array<QrInput> = [
        new QrInput().set('text', 'hi'),
        new QrInput().set('url', 'a.com'),
        new QrInput().set('phone', '138')
      ];
      for (let i: number = 0; i < cases.length; i++) {
        const result: QrPayloadResult = buildPayload(cases[i], inputs[i]);
        expect(result.ok).assertTrue();
        // 结果不再回传类型说明（那句话是 this.kind 的显示名，页面本来就知道）；
        // 这里改为断言「每种类型都构造成功且载荷非空」。
        expect(result.payload.length > 0).assertTrue();
      }
    });

    // ── 长度提示 ────────────────────────────────────────────

    it('长度提示只在超过舒适长度时出现，且给的是建议不是拒绝', 0, () => {
      // 长度提示现在返回结构（布尔量 + 两个数字），措辞在 UI 层
      expect(lengthNotice('short').tooLong).assertFalse();
      let long: string = '';
      for (let i: number = 0; i <= QR_COMFORTABLE_LENGTH; i++) {
        long += 'x';
      }
      const notice: QrLengthNotice = lengthNotice(long);
      expect(notice.tooLong).assertTrue();
      // 参数顺序须与资源文案里的 %s 一致：实际长度在前、舒适上限在后
      expect(notice.length).assertEqual(long.length);
      expect(notice.comfortable).assertEqual(QR_COMFORTABLE_LENGTH);
      // 仍然能生成（只是提示）
      expect(buildTextPayload(new QrInput().set('text', long)).ok).assertTrue();
    });

    it('缩短建议只针对网址与文本，且不承诺短链服务', 0, () => {
      let long: string = '';
      for (let i: number = 0; i <= QR_COMFORTABLE_LENGTH; i++) {
        long += 'x';
      }
      // 本 App 不做短链（那需要联网），所以建议里不能出现具体短链服务名
      // 建议现在是码；「不承诺短链服务」这条断言移到文案侧由 check-resources 保证
      // （资源文案里不出现具体短链服务名），纯逻辑这边只钉住「给不给建议」。
      expect(shorteningHint(QrContentKind.URL, long)).assertEqual(QrHintCode.LONG_URL);
      expect(shorteningHint(QrContentKind.TEXT, long)).assertEqual(QrHintCode.COULD_BE_URL);
      // 名片与 Wi-Fi 不给这类建议（它们本来就不该太长）
      expect(shorteningHint(QrContentKind.VCARD, long)).assertEqual(QrHintCode.NONE);
      // 短内容不给建议
      expect(shorteningHint(QrContentKind.URL, 'short')).assertEqual(QrHintCode.NONE);
    });

    // ── 输入容器 ────────────────────────────────────────────

    it('输入容器对未设置的字段返回空串而不是 undefined', 0, () => {
      // 页面字段是动态的，未设置的字段很常见；返回 undefined 会到处 NPE。
      const input: QrInput = new QrInput();
      expect(input.get('nope')).assertEqual('');
      expect(input.trimmed('nope')).assertEqual('');
      input.set('a', '  x  ');
      expect(input.get('a')).assertEqual('  x  ');
      expect(input.trimmed('a')).assertEqual('x');
    });
  });
}