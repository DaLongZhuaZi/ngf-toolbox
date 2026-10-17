/**
 * 工具箱的全部工具清单（元数据）。
 *
 * ## 本文件是「清单」，不是「机制」
 *
 * 注册表的机制在 core/ToolRegistry.ets，页面构建器的登记在 ui/ToolPageRegistry.ets；
 * 本文件只回答一个问题：**工具箱目前有哪几件工具、它们各自是什么**。
 * 把清单与机制分开，是为了让「加一件工具」永远只改同一个文件里的同一处，
 * 而不需要去理解注册表的内部实现。
 *
 * ## 为什么用「注入」而不是被 core 直接 import
 *
 * 工具页面要 import core（拿 ToolContext 与 ToolScaffold），若 core 反过来
 * import 本文件就会形成循环依赖。所以本文件在启动时把自己的登记函数注入给 core，
 * 依赖方向始终单向：core ← tools。
 * 注入由 EntryAbility 在 NGF 引导完成后**显式**调用（见 {@link ensureToolCatalogInstalled}），
 * 而不是靠模块加载副作用——「工具箱有哪些工具」这件事应当能在启动流程里被追踪到。
 *
 * ## 新增一件工具
 *
 * 1. 实现 `entry/src/main/ets/tools/<toolId>/`（纯逻辑 + 页面）；
 * 2. 在本文件用 `registry.register(...)` 登记元数据；
 * 3. 在 `ui/ToolPageRegistry.ets` 登记它的页面构建器。
 *
 * 第 2、3 步是唯一的胶水，首页、搜索、收藏、最近使用全部自动生效。
 *
 * ## 三处文案都必须写两种语言
 *
 * `name` / `description` / `limitation` 都是 {@link NGFLocalizedText}，
 * **英文缺失时不会报错**——它会安静地回退成中文。因此漏写英文这件事只有用户会发现。
 * 写英文时守两条与中文相同的纪律：description 里放**用户会搜的词**
 * （英文用户会搜 `hash`、`diff`、`port`，不会搜「摘要」），
 * limitation 要**具体**（说清哪种输入不行，而不是 "some limitations apply"）。
 *
 * ## limitation 字段的写法
 *
 * `limitation` 是产品定义稿 §七 强制的「做不到什么」，会原样显示在工具页帮助区。
 * 写它时守两条：一是**具体**——说清是哪一种输入、哪一种场景不行，
 * 「能力有限」「仅供参考」这类话等于没写；二是**诚实**——宁可暴露短板，
 * 也不能让用户拿着工具去做它做不到的事（例如以为 JWT 解码器验了签）。
 * 另外它是纯文本渲染，**不要写 markdown 星号**（会被原样显示出来），要强调就用「」。
 *
 * @module tools/ToolsCatalog
 */

import { NGFLocalizedText, NGFToolCategory, NGFToolLayer, NGFToolMeta } from '../core/ToolModel';
import { installToolCatalog, toolRegistry, ToolRegistry } from '../core/ToolRegistry';

/** 简写构造器：把「中文 / English」写成一行，避免每处都写完整的类名 */
function l10n(zh: string, en: string): NGFLocalizedText {
  return new NGFLocalizedText(zh, en);
}

/**
 * 已实现工具的元数据。
 *
 * 每件工具一个静态工厂方法而不是一个大数组：元数据字段多（9 个），
 * 数组写法里逗号错位极难发现；工厂方法让每件工具的元数据成为独立、
 * 可单独阅读与修改的一段。
 */
class ImplementedTools {
  static urlCodec(): NGFToolMeta {
    return new NGFToolMeta(
      'url-codec',
      l10n('URL 编解码', 'URL Codec'),
      NGFToolCategory.TEXT,
      l10n('URL 整串编解码与 query 参数逐个拆解（+ 双口径）',
        'Encode/decode URLs and split query parameters one by one (dual plus semantics)'),
      l10n('解码按 JavaScript encodeURIComponent 语义：畸形 % 序列报错并指明第几个参数。'
        + '+ 号给表单与 RFC 3986 两个口径并排展示，不替你猜。不做整 URL 的合法性校验，'
        + '也不解析 userinfo、fragment 以外的协议细节。',
        'Decoding follows JavaScript encodeURIComponent semantics: malformed % sequences error out'
        + 'with the offending parameter index. Both plus semantics (form-style space and RFC 3986 literal)'
        + 'are shown side by side. No full-URL validation, and no userinfo or fragment details beyond that.'),
      [NGFToolLayer.UTILS, NGFToolLayer.CONTENT_WORKFLOW],
      'link',
      15,
      false
    );
  }

  static caseConvert(): NGFToolMeta {
    return new NGFToolMeta(
      'case-convert',
      l10n('命名风格转换', 'Case Converter'),
      NGFToolCategory.TEXT,
      l10n('标识符六种命名风格互转：camel、Pascal、snake、SCREAMING、kebab、dot',
        'Convert identifiers across six styles: camel, Pascal, snake, SCREAMING, kebab, dot'),
      l10n('切词按 ASCII 边界规则：连续大写保持成词（HTTPServer 不拆散），字母与数字交界切开。'
        + '非 ASCII 标识符（中文变量名等）不支持；不做「智能猜测」——切不出词就报错，不猜意图。',
        'Word splitting uses ASCII boundary rules: upper-case runs stay one word (HTTPServer),'
        + 'letter-digit boundaries split. Non-ASCII identifiers are not supported; no guessing,'
        + 'it errors out when no words can be split.'),
      [NGFToolLayer.UTILS],
      'textformat',
      16,
      false
    );
  }

  static textToolkit(): NGFToolMeta {
    return new NGFToolMeta(
      'text-toolkit',
      l10n('文本行工具', 'Text Line Toolkit'),
      NGFToolCategory.TEXT,
      l10n('多行文本去重、排序与统计：行数、字符、词数、CRLF/LF 行尾',
        'Dedupe, sort and count multi-line text: lines, chars, words, CRLF/LF endings'),
      l10n('去重保留首次出现；排序的字典序用本地化比较（A 与 a 相邻，Z 不排在 a 前）。'
        + '统计基于剔除空行后的行；不做正则批量替换，也不处理 CSV/TSV 列。',
        'Dedupe keeps first occurrences; lexical sort uses locale comparison (A and a adjacent,'
        + 'Z never before a). Stats count after empty lines are dropped. No regex batch replace,'
        + 'and no CSV/TSV column handling.'),
      [NGFToolLayer.UTILS, NGFToolLayer.CONTENT_WORKFLOW],
 'list_square',
      17,
      false
    );
  }

  static htmlEntity(): NGFToolMeta {
    return new NGFToolMeta(
      'html-entity',
      l10n('HTML 实体', 'HTML Entities'),
      NGFToolCategory.TEXT,
      l10n('HTML 实体编解码：命名实体、十进制与十六进制数字实体',
        'Encode/decode HTML entities: named, decimal and hex numeric forms'),
      l10n('内置 39 个常用命名实体，大小写不敏感；编码默认只转五个保留字符，扩展模式把非 ASCII 编成十进制实体。'
        + '解码遇到未知命名实体、码点越界或缺分号时报错，不做浏览器式宽容。',
        'Ships 39 common named entities, case-insensitive; encoding covers the five reserved characters,'
        + 'by default, with an extended mode for non-ASCII. Decoding errors out on unknown names,'
        + 'out-of-range code points or missing semicolons instead of forgiving like browsers.'),
      [NGFToolLayer.UTILS],
      'document_code',
      18,
      false
    );
  }

  static loremIpsum(): NGFToolMeta {
    return new NGFToolMeta(
      'lorem-ipsum',
      l10n('占位文本生成', 'Lorem Ipsum'),
      NGFToolCategory.TEXT,
      l10n('生成拉丁/中文占位文本：段落与句数可配，种子可复现',
        'Generate Latin or Chinese placeholder text with reproducible seeds'),
      l10n('种子随机（mulberry32）：同一种子产出完全相同的文本，可复现。'
        + '词表固定 40-50 词，不做领域定制词表，也不输出 Markdown/HTML 格式。',
        'Seeded PRNG (mulberry32): the same seed yields identical output, reproducible.'
        + 'Fixed 40-50 word tables; no domain-specific lists and no Markdown/HTML output.'),
      [NGFToolLayer.UTILS, NGFToolLayer.CONTENT_WORKFLOW],
      'text_alignleft',
      19,
      false
    );
  }

  static csvJson(): NGFToolMeta {
    return new NGFToolMeta(
      'csv-json',
      l10n('CSV 与 JSON 互转', 'CSV to JSON'),
      NGFToolCategory.TEXT,
      l10n('CSV 解析为 JSON 对象数组，或反向导出；RFC 4180 引号规则',
        'Parse CSV into a JSON object array or export back; RFC 4180 quoting'),
      l10n('首行必须是表头；值类型推断只在 CSV 到 JSON 方向发生，15 位以上数字保留为字符串防丢精度。'
        + 'JSON 到 CSV 全部输出字符串。只认逗号分隔，不做分号/制表符方言，也不处理编码。',
        'The first row must be a header; type inference happens only from CSV to JSON and numbers,'
        + 'beyond 15 digits stay strings to keep precision. JSON to CSV outputs strings only,'
        + 'and no semicolon or tab dialects and no encoding detection.'),
      [NGFToolLayer.UTILS, NGFToolLayer.CONTENT_WORKFLOW],
      'table_chart',
      21,
      false
    );
  }

  static mdPreview(): NGFToolMeta {
    return new NGFToolMeta(
      'md-preview',
      l10n('MD 预览', 'Markdown Preview'),
      NGFToolCategory.TEXT,
      l10n('Markdown 实时预览：标题、列表、引用、代码块与行内样式',
        'Live Markdown preview: headings, lists, quotes, code blocks and inline styles'),
      l10n('支持 #/##/### 三级标题、段落聚合、有序与无序列表、引用、代码块、水平线，'
        + '行内支持粗体、斜体与行内代码。不做表格、嵌套列表、图片与链接跳转（链接只显示文本），'
        + '四级以上标题按普通段落处理。',
        'Supports level 1-3 headings, paragraph merging, ordered and unordered lists, quotes,'
        + 'code blocks and horizontal rules, with bold, italic and inline code. No tables,'
        + 'nested lists, images or link navigation (links render as text); heading levels beyond three are paragraphs.'),
      [NGFToolLayer.UTILS, NGFToolLayer.CONTENT_WORKFLOW],
      'doc_plaintext',
      14,
      false
    );
  }

  static hmacCalc(): NGFToolMeta {
    return new NGFToolMeta(
      'hmac-calc',
      l10n('HMAC 计算', 'HMAC Calculator'),
      NGFToolCategory.COMPUTE,
      l10n('HMAC 签名计算：MD5、SHA-1、SHA-256，RFC 2104',
        'Compute HMAC signatures with MD5, SHA-1 or SHA-256 per RFC 2104'),
      l10n('仅本地计算，密钥与消息不会存储或上报（草稿除外）。不做密钥强度评估，'
        + '也不验证已有签名——那是验证方的工作，本工具只生成。',
        'Local computation only; the key and message are never stored or sent (drafts aside).'
        + 'No key-strength assessment and no signature verification - this tool only generates.'),
      [NGFToolLayer.SECURITY, NGFToolLayer.UTILS],
      'lock_shield',
      55,
      false
    );
  }

  static checksum(): NGFToolMeta {
    return new NGFToolMeta(
      'checksum',
      l10n('校验和', 'Checksum'),
      NGFToolCategory.COMPUTE,
      l10n('CRC-32 与 Adler-32 完整性校验，十六进制与十进制展示',
        'CRC-32 and Adler-32 integrity checks with hex and decimal output'),
      l10n('仅完整性校验（检测传输/存储损坏）：CRC-32 与 Adler-32 都不是加密哈希，'
        + '碰撞在恶意场景下可构造，不能用于防篡改或签名。输入按 UTF-8 字节计算。',
        'Integrity checks only (detect transit or storage corruption): CRC-32 and Adler-32 are,'
        + 'not cryptographic hashes - collisions are constructible, so no tamper protection'
        + 'or signing. Input is processed as UTF-8 bytes.'),
      [NGFToolLayer.UTILS, NGFToolLayer.SECURITY],
      'checkmark_seal',
      56,
      false
    );
  }

  static bitOps(): NGFToolMeta {
    return new NGFToolMeta(
      'bit-ops',
      l10n('位运算器', 'Bit Ops'),
      NGFToolCategory.COMPUTE,
      l10n('32 位位运算可视化：AND/OR/XOR/NOT/移位与位格子翻转',
        'Visual 32-bit operations: AND/OR/XOR/NOT/shifts with a bit-flip panel'),
      l10n('按 32 位无符号整数处理：输入超 2^32 归一、负数按补码归一。移位量限定 0-31。'
        + '不做有符号数语义切换（符号位就是 bit31），也不支持 64 位。',
        'Treated as unsigned 32-bit: values wrap at 2^32 and negatives normalize as two-complement,'
        + 'shift amounts are 0-31 only. No signed-mode switch (bit31 is the sign bit) and no 64-bit.'),
      [NGFToolLayer.UTILS],
      'switch_2',
      57,
      false
    );
  }

  static floatBits(): NGFToolMeta {
    return new NGFToolMeta(
      'float-bits',
      l10n('浮点位分解', 'Float Bits'),
      NGFToolCategory.COMPUTE,
      l10n('IEEE-754 位分解：符号/指数/尾数与五分类（单/双精度）',
        'IEEE-754 decomposition: sign, exponent, mantissa and five classes (single/double)'),
      l10n('支持十进制输入与 NaN、Infinity、-Infinity 字面量（查看特殊值的位型）；'
        + '其它解析不出的输入报错，不静默变成 NaN 位型。不做十六进制到浮点的反向转换。',
        'Accepts decimal input and the NaN, Infinity, -Infinity literals (to inspect their bit patterns),'
        + 'other unparsable input errors out instead of silently becoming a NaN pattern,'
        + 'and there is no hex-to-float reverse conversion.'),
      [NGFToolLayer.UTILS, NGFToolLayer.DATA],
      'percent',
      58,
      false
    );
  }

  static unitConvert(): NGFToolMeta {
    return new NGFToolMeta(
      'unit-convert',
      l10n('单位换算', 'Unit Converter'),
      NGFToolCategory.COMPUTE,
      l10n('数据量/长度/时间/重量比例换算与温度仿射换算',
        'Convert data, length, time and weight ratios plus affine temperature'),
      l10n('数据量按 1024 进制（KiB 口径，不是 KB 1000 进制）；长度/重量含英制常用单位。'
        + '温度拦绝对零度以下。不做复合单位（m/s），不做历史单位与实时汇率类换算。',
        'Data uses the 1024-based KiB convention, not 1000-based KB; length and weight include'
        + 'common imperial units. Temperatures below absolute zero are rejected. No compound units,'
        + 'no historical units and no exchange-rate style conversions.'),
      [NGFToolLayer.UTILS],
      'scale',
      59,
      false
    );
  }

  static percentCalc(): NGFToolMeta {
    return new NGFToolMeta(
      'percent-calc',
      l10n('百分比计算', 'Percent Calculator'),
      NGFToolCategory.COMPUTE,
      l10n('占比/求部分/变化率/求总数/加减百分比，五个方向分步计算',
        'Five percent calculations: of, part, change rate, total and apply'),
      l10n('五个方向独立计算、除零明确报错。特别提示「先加 50% 再减 50% 不回到原值」——'
        + '这是百分比最常被误解的地方。不做连续多步链式计算，不做利息/复利。',
        'Five independent directions with explicit divide-by-zero errors. The page warns that'
        + 'plus-50% then minus-50% does not return to the start. No chained multi-step calculations,'
        + 'no interest and no compound growth.'),
      [NGFToolLayer.UTILS],
      'percent',
      61,
      false
    );
  }

  static contrastCheck(): NGFToolMeta {
    return new NGFToolMeta(
      'contrast-check',
      l10n('对比度检查', 'Contrast Checker'),
      NGFToolCategory.COMPUTE,
      l10n('WCAG 2.1 对比度与等级判定，含大文本口径与可读性建议',
        'WCAG 2.1 contrast ratio and level with large-text mode and readability advice'),
      l10n('按 WCAG 2.1 判级：AA 4.5 / AAA 7.0（大文本 3.0/4.5）。复用主题门禁的同一份'
        + '亮度实现。只判定颜色对，不做整个页面的自动扫描。',
        'Judged per WCAG 2.1: AA 4.5 / AAA 7.0 (3.0 and 4.5 for large text). Reuses the same,'
        + 'luminance implementation as the theme gate. Judges one color pair - no full-page scan.'),
      [NGFToolLayer.UTILS, NGFToolLayer.UI_THEME],
      'eye',
      62,
      false
    );
  }

  static paletteGen(): NGFToolMeta {
    return new NGFToolMeta(
      'palette-gen',
      l10n('色板生成', 'Palette Generator'),
      NGFToolCategory.COMPUTE,
      l10n('从一个基础色生成和谐色板：互补/邻近/三角/四角 + 明暗阶梯',
        'Generate palettes from a base color: harmonies plus a five-step shade scale'),
      l10n('基于 ColorConvert 的和谐与明暗阶梯（主题门禁同源实现）。输出 hex，点击色块复制。'
        + '不做从图片提取色板，也不做无障碍配对建议（那是对比度检查的活）。',
        'Built on ColorConvert harmonies and shade scales (same implementation as the theme gate),'
        + 'outputs hex with tap-to-copy. No palette extraction from images and no accessibility'
        + 'pairing advice - use the contrast checker for that.'),
      [NGFToolLayer.UTILS, NGFToolLayer.UI_THEME],
      'paintpalette',
      63,
      false
    );
  }

  static ipCidr(): NGFToolMeta {
    return new NGFToolMeta(
      'ip-cidr',
      l10n('IP/CIDR 计算器', 'IP CIDR Calculator'),
      NGFToolCategory.NETWORK,
      l10n('CIDR 速查：网络/广播地址、掩码、通配符掩码、地址总数',
        'CIDR lookup: network and broadcast addresses, mask, wildcard mask, address count'),
      l10n('IPv4 only（复用子网计算的解析，IPv6 请用专门的工具）。通配符掩码面向'
        + '网络设备配置（ACL/路由），不是安全边界。',
        'IPv4 only (reuses the subnet calculator parsing - use a dedicated tool for IPv6),'
        + 'the wildcard mask targets network device configs (ACL and routes), not a security boundary.'),
      [NGFToolLayer.UTILS, NGFToolLayer.NETWORK],
      'network',
      65,
      false
    );
  }

  static httpStatus(): NGFToolMeta {
    return new NGFToolMeta(
      'http-status',
      l10n('HTTP 状态码', 'HTTP Status'),
      NGFToolCategory.NETWORK,
      l10n('23 个高频状态码速查：含义与常见原因，支持数字与关键词查询',
        'Quick lookup for 23 common status codes with causes, by code or keyword'),
      l10n('本地表只收录高频 23 条，不是 RFC 全量 60+（工具书要短不是要全）。'
        + '数字查询按前缀匹配（40 匹配 400-409），文本查询模糊匹配名称与中文含义。',
        'The local table covers 23 high-frequency codes, not the full RFC 60+ set - a reference'
        + 'should be short. Numeric queries match by prefix (40 matches 400 to 409) and text'
        + 'queries fuzzily match names and Chinese meanings.'),
      [NGFToolLayer.UTILS, NGFToolLayer.NETWORK],
      'info_square',
      66,
      false
    );
  }

  static httpHeaders(): NGFToolMeta {
    return new NGFToolMeta(
      'http-headers',
      l10n('HTTP 头速查', 'HTTP Headers'),
      NGFToolCategory.NETWORK,
      l10n('24 个高频 HTTP 头：方向标注、含义与示例，支持方向过滤',
        '24 common HTTP headers with direction, meaning and examples, filterable'),
      l10n('本地表只收录高频 24 个，不是 RFC 全量。查询大小写不敏感，匹配头名与中文含义；'
        + '方向过滤含双向头。不做头值语法校验。',
        'The local table covers 24 high-frequency headers, not the full RFC set. Queries are'
        + 'case-insensitive across names and Chinese meanings, with direction filters including'
        + 'both-way headers. No header value syntax validation.'),
      [NGFToolLayer.UTILS, NGFToolLayer.NETWORK],
      'list_paragraph',
      67,
      false
    );
  }

  static mimeLookup(): NGFToolMeta {
    return new NGFToolMeta(
      'mime-lookup',
      l10n('MIME 速查', 'MIME Lookup'),
      NGFToolCategory.NETWORK,
      l10n('30 个高频扩展名的 MIME 类型查询，支持文件名输入',
        'Look up MIME types for 30 common extensions, accepts filenames'),
      l10n('本地表只收录高频 30 条（一个扩展名取最常用映射，如 js 是 text/javascript）。'
        + '大小写不敏感，接受文件名并自动取最后一段扩展名。',
        'The local table covers 30 common extensions (one mapping each, e.g. js maps to'
        + 'text/javascript). Case-insensitive; filenames are accepted and reduced to the last extension segment.'),
      [NGFToolLayer.UTILS, NGFToolLayer.NETWORK],
      'doc_text',
      68,
      false
    );
  }

  static portLookup(): NGFToolMeta {
    return new NGFToolMeta(
      'port-lookup',
      l10n('端口速查', 'Port Lookup'),
      NGFToolCategory.NETWORK,
      l10n('30 个高频端口的用途查询：服务名与中文说明',
        'Look up the purpose of 30 common ports with service names and Chinese notes'),
      l10n('本地表只收录高频 30 条。数字查询按前缀匹配（80 匹配 80/8080/8443），'
        + '文本匹配服务名与中文用途。与端口测试互补：那是连通测试，这是用途查询。',
        'The local table covers 30 common ports. Numeric queries match by prefix (80 matches'
        + '80, 8080 and 8443) and text matches service names and Chinese notes. Complements the'
        + 'port tester: that checks connectivity, this looks up purposes.'),
      [NGFToolLayer.UTILS, NGFToolLayer.NETWORK],
      'number',
      69,
      false
    );
  }

  static urlParser(): NGFToolMeta {
    return new NGFToolMeta(
      'url-parser',
      l10n('URL 解析器', 'URL Parser'),
      NGFToolCategory.NETWORK,
      l10n('URL 七段拆解：scheme/userinfo/host/port/path/query/fragment',
        'Split a URL into scheme, userinfo, host, port, path, query and fragment'),
      l10n('手写解析：端口默认值按 scheme 补（http=80, https=443），query 里 + 是空格、'
        + '%2B 是字面加号。不做 IDN 转码，不校验 host 合法性（只做结构拆分），相对 URL 报错。',
        'Hand-written parsing: default ports per scheme (http 80, https 443); plus in queries is'
        + 'a space and %2B a literal plus. No IDN conversion, no host validation (structure only),'
        + 'and relative URLs error out.'),
      [NGFToolLayer.UTILS, NGFToolLayer.NETWORK],
      'link',
      64,
      false
    );
  }

  static uaParser(): NGFToolMeta {
    return new NGFToolMeta(
      'ua-parser',
      l10n('UA 解析', 'UA Parser'),
      NGFToolCategory.NETWORK,
      l10n('User-Agent 启发式解析：浏览器/引擎/操作系统三维分类',
        'Heuristic User-Agent parsing: browser, engine and operating system'),
      l10n('启发式匹配不保证完整：UA 可伪造（开发者工具随意切换），识别不出返回 unknown。'
        + '只做三维分类，不解析版本号明细。',
        'Heuristic matching is not exhaustive: UAs can be faked freely in devtools, so unknown'
        + 'results are returned when nothing matches. Three-way classification only - no version number details.'),
      [NGFToolLayer.UTILS],
      'person',
      71,
      false
    );
  }

  static epochTable(): NGFToolMeta {
    return new NGFToolMeta(
      'epoch-table',
      l10n('Epoch 对照表', 'Epoch Table'),
      NGFToolCategory.COMPUTE,
      l10n('Epoch 常用粒度对照：秒/毫秒/微秒/天/小时',
        'Epoch values across common granularities: seconds, milliseconds, days, hours'),
      l10n('确定性设计：毫秒值由调用方传入，不做时钟读取。薄封装时间戳的换算函数。',
        'Deterministic: the millisecond value is passed in by the caller, no clock reading.' +
        'A thin wrapper over the timestamp conversions. Granularity comparison only -' +
        'no timezone conversion (that is the timestamp tool).'),
      [NGFToolLayer.UTILS, NGFToolLayer.DATA],
      'table',
      72,
      false
    );
  }

  static jsonPath(): NGFToolMeta {
    return new NGFToolMeta(
      'json-path',
      l10n('JSON 路径取值', 'JSON Path'),
      NGFToolCategory.TEXT,
      l10n('JSON 点路径取值：a.b.c、数组下标、根数组，输出值与类型',
        'Query JSON by dot paths: a.b.c, array indexes, root arrays - value and type output'),
      l10n('手写解析器不用 eval（路径来自用户输入，eval 是注入面）。支持点段、数组下标与根数组。'
        + '不支持通配符、过滤器、负数下标；连续点与非数字下标报错。',
        'Hand-written parser without eval (paths come from user input and eval is an injection surface),'
        + 'supports dot segments, array indexes and root arrays. No wildcards, filters or negative'
        + 'indexes; double dots and non-numeric indexes error out.'),
      [NGFToolLayer.UTILS, NGFToolLayer.CONTENT_WORKFLOW],
      'route',
      22,
      false
    );
  }

  static formDecode(): NGFToolMeta {
    return new NGFToolMeta(
      'form-decode',
      l10n('表单解析', 'Form Decode'),
      NGFToolCategory.TEXT,
      l10n('表单体解析：逐参数双视图、重复键保留、字段统计',
        'Decode a form body: per-field dual view, duplicate keys kept, field statistics'),
      l10n('表单口径（+ 是空格、%2B 是字面加号），复用 URL 编解码的解码语义。重复键是'
        + '多选框语义，保留多条而不是覆盖。以问号开头视为 query 形态并报错提示。',
        'Form semantics (plus means space, %2B a literal plus), reusing the URL codec decode.'
        + 'Duplicate keys are checkbox semantics and are kept as multiple entries. A leading'
        + 'question mark is treated as query syntax and rejected with a hint.'),
      [NGFToolLayer.UTILS, NGFToolLayer.CONTENT_WORKFLOW],
      'form',
      23,
      false
    );
  }

  static jsonToml(): NGFToolMeta {
    return new NGFToolMeta(
      'json-toml',
      l10n('TOML 解析', 'TOML Parser'),
      NGFToolCategory.TEXT,
      l10n('TOML 转 JSON：表/子表/点键/单行数组/注释，单向解析',
        'TOML to JSON: tables, dotted keys, one-line arrays and comments, one-way'),
      l10n('支持基础表、子表、点键、单行数组与注释。多行字符串明确报错；'
        + '内联表与日期时间不支持。',
        'Supports basic tables, subtables, dotted keys, one-line arrays and comments.'
        + 'Multiline strings error out explicitly; inline tables and datetimes are unsupported.'),
      [NGFToolLayer.UTILS, NGFToolLayer.DATA],
      'list_box',
      24,
      false
    );
  }

  static jsonYaml(): NGFToolMeta {
    return new NGFToolMeta(
      'json-yaml',
      l10n('YAML 解析', 'YAML Parser'),
      NGFToolCategory.TEXT,
      l10n('YAML 转 JSON：标量/一层嵌套/行内数组/注释，单向解析',
        'YAML to JSON: scalars, one nested level, inline arrays and comments, one-way'),
      l10n('支持一层两空格嵌套与行内数组。多行块与多文档明确报错；'
        + '锚点引用与两层以上嵌套不支持。',
        'Supports one two-space nesting level and inline arrays. Block scalars and multi-doc'
        + 'inputs error out explicitly; anchors and deeper nesting are unsupported.'),
      [NGFToolLayer.UTILS, NGFToolLayer.DATA],
      'list_outline',
      25,
      false
    );
  }

  static sqlFormat(): NGFToolMeta {
    return new NGFToolMeta(
      'sql-format',
      l10n('SQL 格式化', 'SQL Formatter'),
      NGFToolCategory.TEXT,
      l10n('SQL 文本级重排：关键字大写、主子句换行、AND/OR 缩进',
        'Text-level SQL reformatting: keyword casing, clause breaks, connector indent'),
      l10n('只是文本级重排，不解析语法树、不校验 SQL 合法性。字符串字面量内容'
        + '原样保护。方言差异（窗口函数、CTE）不特殊处理。',
        'Text-level reformatting only - no syntax tree and no validity check. String literal'
        + 'contents are preserved as-is. Dialect features like window functions and CTEs get'
        + 'no special handling.'),
      [NGFToolLayer.UTILS, NGFToolLayer.CONTENT_WORKFLOW],
      'database',
      26,
      false
    );
  }

  static regexCheatsheet(): NGFToolMeta {
    return new NGFToolMeta(
      'regex-cheatsheet',
      l10n('正则速查', 'Regex Cheatsheet'),
      NGFToolCategory.TEXT,
      l10n('正则语法速查：六大分类 28 条，关键词与分类过滤',
        'Regex syntax reference: 28 entries in six categories with keyword and category filter'),
      l10n('本地表只收录常用 28 条，不是全量语法。每条带示例；查询大小写不敏感。'
        + '不做正则实时测试（那是正则测试工具的事）。',
        'The local table covers 28 common entries, not the full syntax. Each entry has an'
        + 'example and queries are case-insensitive. No live regex testing - use the regex'
        + 'tester for that.'),
      [NGFToolLayer.UTILS, NGFToolLayer.CONTENT_WORKFLOW],
      'text_cursor',
      27,
      false
    );
  }

  static uuidBatch(): NGFToolMeta {
    return new NGFToolMeta(
      'uuid-batch',
      l10n('UUID 批量生成', 'UUID Batch'),
      NGFToolCategory.FILE,
      l10n('UUID v4 批量生成：大小写/连字符开关，逐条或全部复制',
        'Batch-generate UUID v4 with case and hyphen options, copy one or all'),
      l10n('薄封装批量生成的既有逻辑（单测覆盖在 uuid-password 模块）。上限 100 条，'
        + '超出报错而不是静默截断。',
        'A thin wrapper over the existing batch generation (unit tests live in the uuid-password'
        + 'module). The limit is 100 and exceeding it errors out instead of truncating.'),
      [NGFToolLayer.UTILS, NGFToolLayer.SECURITY],
      'copy_plus',
      73,
      false
    );
  }

  static passwordStrength(): NGFToolMeta {
    return new NGFToolMeta(
      'password-strength',
      l10n('密码强度评估', 'Password Strength'),
      NGFToolCategory.FILE,
      l10n('密码熵估算与改进建议：三档总结、建议优先级排序',
        'Password entropy estimate with improvement advice, three-level summary'),
      l10n('离线启发式：熵是理论上界，不查泄露库、不做字典攻击模拟。薄封装评估器，'
        + '增量是三档总结与建议优先级排序。',
        'Offline heuristic: entropy is an upper bound, no breach check and no dictionary'
        + 'simulation. A thin wrapper over the evaluator with a three-level summary and prioritized advice.'),
      [NGFToolLayer.UTILS, NGFToolLayer.SECURITY],
      'shield',
      74,
      false
    );
  }

  static mockData(): NGFToolMeta {
    return new NGFToolMeta(
      'mock-data',
      l10n('假数据生成', 'Mock Data'),
      NGFToolCategory.FILE,
      l10n('中文姓名/手机号/邮箱假数据批量生成，本地规则表',
        'Generate fake Chinese names, phone numbers and emails from local rules'),
      l10n('全部是随机生成的假数据：邮箱用 example.com 保留域（不会误发邮件），'
        + '手机号是合法号段但不指向真实用户。上限 200 条。不生成身份证/地址等敏感类型。',
        'Everything is randomly generated fake data: emails use the reserved example.com domain'
        + 'and phone numbers use valid prefixes but belong to nobody. The limit is 200 entries.'
        + 'No ID numbers or addresses.'),
      [NGFToolLayer.UTILS],
      'user_square',
      75,
      false
    );
  }

  static fileHash(): NGFToolMeta {
    return new NGFToolMeta(
      'file-hash',
      l10n('文本哈希校验', 'Text Hash Check'),
      NGFToolCategory.TEXT,
      l10n('一次输出 MD5/SHA-1/SHA-256/SHA-512，并与期望校验值比对',
        'Compute MD5, SHA-1, SHA-256 and SHA-512 at once and compare with an expected value'),
      l10n('范围是文本输入（真实文件的分块读取是后续增强）。比对容错大小写、空格与 0x 前缀。'
        + '薄封装 digest 的 HashCore——与交叉验证门禁同一实现。',
        'Text input only - chunked file reading is a future enhancement. The comparison tolerates'
        + 'case, spaces and a 0x prefix. A thin wrapper over the digest HashCore - the same'
        + 'implementation as the cross-verification gate.'),
      [NGFToolLayer.UTILS, NGFToolLayer.SECURITY],
      'tag',
      28,
      false
    );
  }

  static asciiLine(): NGFToolMeta {
    return new NGFToolMeta(
      'ascii-line',
      l10n('ASCII 分隔线', 'ASCII Lines'),
      NGFToolCategory.TEXT,
      l10n('注释分隔线/横幅/文本框生成：5 种填充、3 种形态、3 种注释前缀',
        'Comment dividers, banners and boxes: five fills, three shapes, three comment prefixes'),
      l10n('中文按 1 字符宽计算（CJK 双宽字符会造成对齐偏差）。纯 ASCII 输出，'
        + '适合粘贴进任意代码注释。',
        'Chinese counts as one column - CJK double-width glyphs will misalign. Output is pure'
        + 'ASCII suitable for pasting into any code comment.'),
      [NGFToolLayer.UTILS],
      'separator',
      29,
      false
    );
  }

  static semverParse(): NGFToolMeta {
    return new NGFToolMeta(
      'semver-parse',
      l10n('版本号解析', 'SemVer Parser'),
      NGFToolCategory.COMPUTE,
      l10n('语义化版本 2.0.0 拆解与优先级比较：先行版本逐标识符比较',
        'SemVer 2.0.0 parsing and precedence comparison with prerelease identifiers'),
      l10n('支持 v 前缀容错、先行版本与构建元数据。比较遵循规范：数字标识符按数值、'
        + '正式版高于先行版。不做版本范围（^ 与波浪线）判断。',
        'Supports a v-prefix, prerelease and build metadata. Comparison follows the spec:'
        + 'numeric identifiers compare by value and releases outrank prereleases. No version'
        + 'range (caret and tilde) support.'),
      [NGFToolLayer.UTILS],
      'tag_outline',
      76,
      false
    );
  }

  static gitCheatsheet(): NGFToolMeta {
    return new NGFToolMeta(
      'git-cheatsheet',
      l10n('Git 速查', 'Git Cheatsheet'),
      NGFToolCategory.TEXT,
      l10n('Git 命令速查：六大场景 30 条，关键词与场景过滤',
        'Git command reference: 30 entries in six scenarios with keyword and filter'),
      l10n('本地表只收录高频 30 条，不是命令全集。查询大小写不敏感。'
        + '不做命令执行——纯速查表。',
        'The local table covers 30 common commands, not the full set. Queries are'
        + 'case-insensitive. No command execution - reference only.'),
      [NGFToolLayer.UTILS, NGFToolLayer.PLATFORM_OHOS],
      'git',
      31,
      false
    );
  }

  static keyseqDoc(): NGFToolMeta {
    return new NGFToolMeta(
      'keyseq-doc',
      l10n('快捷键速查', 'Shortcuts'),
      NGFToolCategory.TEXT,
      l10n('IDE 快捷键速查：五大场景 26 条（Android Studio 键位）',
        'IDE shortcut reference: 26 entries in five categories (Android Studio keymap)'),
      l10n('以 Android Studio/IntelliJ 的 Windows/Linux 键位为准，Mac 键位是后续增强。'
        + '只做速查，不模拟按键。',
        'Based on Android Studio and IntelliJ keymaps for Windows and Linux; Mac keymap is a'
        + 'future enhancement. Reference only - no key simulation.'),
      [NGFToolLayer.UTILS],
      'keyboard',
      32,
      false
    );
  }

  static json2Doc(): NGFToolMeta {
    return new NGFToolMeta(
      'json2doc',
      l10n('JSON 转接口文档', 'JSON to Doc'),
      NGFToolCategory.TEXT,
      l10n('JSON 示例转 Markdown 字段表：点分路径、类型标注、四层深度',
        'Turn a JSON sample into a Markdown field table with dotted paths and types'),
      l10n('数组取第一个元素作为样例下钻（路径带 [0] 标注）；对象根从字段开始不产生根行。'
        + '说明列留空由用户补充——工具不猜测字段含义。深度上限 4 层。',
        'Arrays drill into the first element (paths carry a [0] marker) and an object root'
        + 'starts at its fields. The description column is left blank - the tool does not guess'
        + 'meanings. Depth is capped at four levels.'),
      [NGFToolLayer.UTILS, NGFToolLayer.CONTENT_WORKFLOW],
      'doc_richtext',
      33,
      false
    );
  }

  static changelogGen(): NGFToolMeta {
    return new NGFToolMeta(
      'changelog-gen',
      l10n('更新日志生成', 'Changelog Builder'),
      NGFToolCategory.TEXT,
      l10n('提交清单按约定式提交归类：十一种类型分节，非规范行兜底',
        'Classify commits by Conventional Commits into eleven sections with an Other bucket'),
      l10n('识别约定式提交的十一种类型（feat 到 revert），scope 自动拆除，'
        + 'subject 首字母大写，非规范行归入 Other。不读取 git 历史——用户粘贴清单。',
        'Recognizes eleven Conventional Commits types from feat to revert, strips scopes,'
        + 'capitalizes subjects and puts non-conforming lines into Other. No git history reading -'
        + 'the user pastes the list.'),
      [NGFToolLayer.UTILS, NGFToolLayer.CONTENT_WORKFLOW],
      'list_bullet',
      34,
      false
    );
  }

  static sprintCalc(): NGFToolMeta {
    return new NGFToolMeta(
      'sprint-calc',
      l10n('迭代计算', 'Sprint Calculator'),
      NGFToolCategory.COMPUTE,
      l10n('工作日加减：周末跳过，输出结果日期与自然日数',
        'Add or subtract workdays skipping weekends, with the resulting date and day count'),
      l10n('只跳过周末，不含法定节假日（那是地区数据）。使用 UTC 日期算术避免时区偏移。'
        + '上限 3650 天。',
        'Only weekends are skipped - public holidays are regional data. Uses UTC date math to'
        + 'avoid timezone offsets. The limit is 3650 days.'),
      [NGFToolLayer.UTILS],
      'calendar',
      77,
      false
    );
  }

  static curlBuilder(): NGFToolMeta {
    return new NGFToolMeta(
      'curl-builder',
      l10n('HTTP 命令生成', 'HTTP Command Builder'),
      NGFToolCategory.NETWORK,
      l10n('表单生成 cURL 与 HTTPie 双命令：方法/URL/请求头/请求体',
        'Build cURL and HTTPie commands from method, URL, headers and body'),
      l10n('只生成文本命令，不执行（隐私红线：工具不发起网络请求）。URL 缺 scheme'
        + '补 https://，Shell 单引号转义，GET 请求不带 body。',
        'Generates text commands only - nothing is executed (privacy rule: no network requests).'
        + 'A missing scheme becomes https, shell quotes are escaped and GET omits the body.'),
      [NGFToolLayer.UTILS, NGFToolLayer.NETWORK],
      'terminal',
      78,
      false
    );
  }

  static shellCheatsheet(): NGFToolMeta {
    return new NGFToolMeta(
      'shell-cheatsheet',
      l10n('Shell 速查', 'Shell Cheatsheet'),
      NGFToolCategory.TEXT,
      l10n('bash 与 PowerShell 双栏对照：五大场景 19 条只读操作',
        'bash and PowerShell side by side: 19 read-only operations in five scenarios'),
      l10n('只收录只读与低风险操作——不收录删除、格式化、提权类命令。双栏对照，'
        + '只做速查不执行。',
        'Only read-only and low-risk operations - no delete, format or privilege-escalation'
        + 'commands. Side-by-side reference, nothing is executed.'),
      [NGFToolLayer.UTILS, NGFToolLayer.PLATFORM_OHOS],
      'terminal_square',
      79,
      false
    );
  }

  static tzMeeting(): NGFToolMeta {
    return new NGFToolMeta(
      'tz-meeting',
      l10n('时区会议时间', 'Meeting Timezones'),
      NGFToolCategory.COMPUTE,
      l10n('八城市会议时刻对照：当地时间与工作时段标记',
        'Compare a meeting time across eight cities with working-hours markers'),
      l10n('固定时区偏移，不含夏令时（跨 DST 的会议需自行核对）。八城市覆盖'
        + '常见协作时区，基准时区可切换。',
        'Fixed offsets without daylight saving - check DST manually for meetings that cross it.'
        + 'Eight cities cover the common collaboration zones and the base zone is switchable.'),
      [NGFToolLayer.UTILS, NGFToolLayer.PLATFORM_OHOS],
      'globe',
      81,
      false
    );
  }

  static regexReplace(): NGFToolMeta {
    return new NGFToolMeta(
      'regex-replace',
      l10n('正则替换预览', 'Regex Replace'),
      NGFToolCategory.TEXT,
      l10n('正则替换预览：替换后全文 + 匹配清单，支持 $1-$9 与 g/i/m',
        'Preview regex replacement with the full result and a match list, $1 to $9 groups'),
      l10n('预览态不落盘。标志只允许 g/i/m（其余剥掉）。空匹配防死循环。'
        + '捕获组引用支持 $1 到 $9 简单形态，不做命名组。',
        'Preview only - nothing is persisted. Flags are limited to g, i and m (others stripped).'
        + 'Empty matches cannot loop forever. Group references support the simple $1 to $9'
        + 'form, no named groups.'),
      [NGFToolLayer.UTILS, NGFToolLayer.CONTENT_WORKFLOW],
      'replace',
      35,
      false
    );
  }

  static imgBase64(): NGFToolMeta {
    return new NGFToolMeta(
      'img-base64',
      l10n('Base64 图片预览', 'Base64 Image'),
      NGFToolCategory.TEXT,
      l10n('data URI 或 Base64 解析：MIME 识别、体积估算、图片预览',
        'Parse a data URI or Base64: MIME detection, size estimate and image preview'),
      l10n('文本级解析：MIME 来自 data URI 头或魔数猜测（PNG/JPEG/GIF/WebP），'
        + '体积按 Base64 4 比 3 估算。不做缩放或转码。',
        'Text-level parsing: the MIME comes from the data URI header or magic-number guessing'
        + '(PNG, JPEG, GIF and WebP), and the size is estimated at four Base64 chars per three'
        + 'bytes. No scaling or transcoding.'),
      [NGFToolLayer.UTILS],
      'image',
      36,
      false
    );
  }

  static jwtBuilder(): NGFToolMeta {
    return new NGFToolMeta(
      'jwt-builder',
      l10n('JWT 构建', 'JWT Builder'),
      NGFToolCategory.COMPUTE,
      l10n('JWT HS256 本地签名构建：payload 加密钥生成三段 token',
        'Build an HS256-signed JWT from a payload and a secret'),
      l10n('仅演示：本地 HS256 签名，不校验密钥强度、不加密钥管理。'
        + '组装链复用编解码与 HMAC 的既有实现，与 jwt-decoder 配对。',
        'Demo only: local HS256 signing with no key strength checks and no secret management.'
        + 'The assembly reuses the codec and HMAC implementations and pairs with the'
        + 'JWT decoder.'),
      [NGFToolLayer.UTILS, NGFToolLayer.SECURITY],
      'key',
      82,
      false
    );
  }

  static codeMinify(): NGFToolMeta {
    return new NGFToolMeta(
      'code-minify',
      l10n('代码压缩预览', 'Code Minifier'),
      NGFToolCategory.TEXT,
      l10n('文本级压缩：剥离注释与压空白，字符串字面量保护',
        'Text-level minifying: strip comments and squeeze whitespace, strings preserved'),
      l10n('文本级预览：不改标识符与语义，不做 AST 级压缩。未闭合块注释报错。'
        + '字符串字面量内的注释符号原样保留。',
        'Text-level preview: identifiers and semantics are unchanged, no AST minifying.'
        + 'Unclosed block comments error out. Comment markers inside string literals stay.'),
      [NGFToolLayer.UTILS, NGFToolLayer.CONTENT_WORKFLOW],
      'compress',
      83,
      false
    );
  }

  static markdownToc(): NGFToolMeta {
    return new NGFToolMeta(
      'markdown-toc',
      l10n('文档目录生成', 'Markdown TOC'),
      NGFToolCategory.TEXT,
      l10n('标题生成文档目录：锚点规则与代码块跳过',
        'Build a TOC from Markdown headings with GitHub-style anchors, skipping code fences'),
      l10n('一至三级标题、GitHub 锚点规则（小写、空格转横线、去标点、保留中文）。'
        + '代码块围栏内的井号行跳过。四级及更深标题忽略。',
        'Level 1 to 3 headings with GitHub anchor rules (lowercase, spaces to hyphens,'
        + 'punctuation dropped, CJK kept). Hash lines inside code fences are skipped.'
        + 'Level 4 and deeper headings are ignored.'),
      [NGFToolLayer.UTILS, NGFToolLayer.CONTENT_WORKFLOW],
      'list_outline',
      84,
      false
    );
  }

  static cronCheatsheet(): NGFToolMeta {
    return new NGFToolMeta(
      'cron-cheatsheet',
      l10n('Cron 速查', 'Cron Cheatsheet'),
      NGFToolCategory.TEXT,
      l10n('Cron 表达式速查：七分类 21 条，与解析器配对',
        'Cron expression reference: 21 entries in seven categories, pairs with the parser'),
      l10n('本地表只收录高频 21 条。查询大小写不敏感，含 @reboot 等特殊形态。'
        + '只做速查，语义解析用 cron-parser。',
        'The local table covers 21 common expressions. Queries are case-insensitive and include'
        + 'the special forms like @reboot. Reference only - use the cron parser for semantics.'),
      [NGFToolLayer.UTILS],
      'clock_circle',
      85,
      false
    );
  }

  static hueShift(): NGFToolMeta {
    return new NGFToolMeta(
      'hue-shift',
      l10n('色相微调', 'Hue Shift'),
      NGFToolCategory.COMPUTE,
      l10n('色相与明度偏移：同色系变体生成，hex 与 HSL 报告',
        'Shift hue and lightness of a color, with hex and HSL readout'),
      l10n('设计场景是品牌色定稿后的同色系变体。薄封装 rotateHue 与 adjustLightness'
        + '（主题门禁同源）。色相按角度环回，明度按百分比偏移。',
        'The design case is same-family variants of a settled brand color. A thin wrapper over'
        + 'rotateHue and adjustLightness (same source as the theme gate). Hue wraps by degrees'
        + 'and lightness shifts by percentage.'),
      [NGFToolLayer.UTILS, NGFToolLayer.UI_THEME],
      'palette_circle',
      86,
      false
    );
  }

  static httpMethod(): NGFToolMeta {
    return new NGFToolMeta(
      'http-method',
      l10n('HTTP 方法速查', 'HTTP Methods'),
      NGFToolCategory.NETWORK,
      l10n('九个标准 HTTP 方法：语义、幂等性、常见状态码',
        'Nine standard HTTP methods with semantics, idempotency and common statuses'),
      l10n('幂等性是重点标注：GET/PUT/DELETE 等幂等，POST/PATCH 不幂等——'
        + '这是重试策略的依据。与 http-status 配对。',
        'Idempotency is the key annotation: GET, PUT and DELETE are idempotent while POST and'
        + 'PATCH are not - that drives retry strategies. Pairs with the status code lookup.'),
      [NGFToolLayer.UTILS, NGFToolLayer.NETWORK],
      'swap',
      87,
      false
    );
  }

  static dateDiff(): NGFToolMeta {
    return new NGFToolMeta(
      'date-diff',
      l10n('日期差计算', 'Date Difference'),
      NGFToolCategory.COMPUTE,
      l10n('两日期之间：自然日差、工作日数、周数，支持反向',
        'Days between two dates: natural, workdays and weeks, signed'),
      l10n('自然日与工作日分开统计，start 晚于 end 结果为负。不做节假日表。',
        'Natural and workday counts are separate; a later start gives negative results.'
        + 'No holiday tables.'),
      [NGFToolLayer.UTILS],
      'date_range',
      89,
      false
    );
  }

  static unitTable(): NGFToolMeta {
    return new NGFToolMeta(
      'unit-table',
      l10n('存储单位速查', 'Storage Units'),
      NGFToolCategory.COMPUTE,
      l10n('KB 与 KiB 双体系对照：字节数换算两套数值',
        'Compare KB and KiB systems: convert bytes into both scales'),
      l10n('磁盘标称用十进制（1000 进制），操作系统常用二进制（1024 进制）——'
        + '两者相差约 7%。输入字节数看两套体系的数值。',
        'Disk labels use decimal (1000-based) while operating systems use binary (1024-based),'
        + 'about 7% apart. Enter a byte count to see both scales.'),
      [NGFToolLayer.UTILS],
      'storage',
      91,
      false
    );
  }

  static mdLinkCheck(): NGFToolMeta {
    return new NGFToolMeta(
      'md-link-check',
      l10n('链接检查', 'Link Check'),
      NGFToolCategory.TEXT,
      l10n('链接提取与分类：锚点/相对/绝对/其它协议，重复检测',
        'Extract and classify links with duplicate and empty target checks'),
      l10n('纯文本检查：四类分类、重复 target、空 target、行号定位。'
        + '不校验链接可达性——不发网络请求。',
        'Text-level checks: four kinds, duplicate targets, empty targets and line numbers.'
        + 'No reachability checks and no network requests.'),
      [NGFToolLayer.UTILS, NGFToolLayer.CONTENT_WORKFLOW],
      'link_square',
      37,
      false
    );
  }

  static entityTable(): NGFToolMeta {
    return new NGFToolMeta(
      'entity-table',
      l10n('实体速查', 'HTML Entities'),
      NGFToolCategory.TEXT,
      l10n('常用命名实体速查：四分类 24 条，字符与说明',
        'Common named entities in four categories with characters and meanings'),
      l10n('本地表只收录常用 24 条，不是 HTML 全量表。查询大小写不敏感。'
        + '与 html-entity 解码工具配对。',
        'The local table covers 24 common entries, not the full HTML set. Pairs with the'
        + 'decoder tool.'),
      [NGFToolLayer.UTILS, NGFToolLayer.CONTENT_WORKFLOW],
      'quote_left',
      38,
      false
    );
  }

  static keyboardSymbols(): NGFToolMeta {
    return new NGFToolMeta(
      'keyboard-symbols',
      l10n('键盘符号速查', 'Keyboard Symbols'),
      NGFToolCategory.TEXT,
      l10n('Mac 键盘符号与 Windows/Linux 等价键对照',
        'Mac keyboard symbols with their Windows and Linux equivalents'),
      l10n('读国外文档或快捷键表时的符号翻译器：符号、名称、中文与等价键四列。'
        + '只做对照表，不模拟按键。',
        'A symbol translator for foreign docs and shortcut tables: symbol, name, Chinese and'
        + 'the equivalent key. Reference only - no key simulation.'),
      [NGFToolLayer.UTILS],
      'keyboard_fill',
      92,
      false
    );
  }

  static asciiTable(): NGFToolMeta {
    return new NGFToolMeta(
      'ascii-table',
      l10n('ASCII 对照表', 'ASCII Table'),
      NGFToolCategory.TEXT,
      l10n('ASCII 对照：十进制/十六进制/字符/说明，四种查询方式',
        'ASCII table with decimal, hex, char and names, four query styles'),
      l10n('控制字符 8 条代表与可打印 95 条全量。查询支持十进制前缀、十六进制、'
        + '字符精确与名称模糊。',
        'Eight representative control chars and all 95 printable ones. Queries support'
        + 'decimal prefix, hex, exact char and name fuzzy match.'),
      [NGFToolLayer.UTILS],
      'table_lamp',
      93,
      false
    );
  }

  static byteSplit(): NGFToolMeta {
    return new NGFToolMeta(
      'byte-split',
      l10n('字节序演示', 'Byte Order'),
      NGFToolCategory.COMPUTE,
      l10n('32 位整数的字节序对照：大端与小端排列与十六进制',
        'Byte order of a 32-bit int: big vs little endian layouts in hex'),
      l10n('教学件：网络字节序是大端，x86 内存序是小端。经典例 0x12345678。',
        'Teaching tool: network order is big-endian, x86 memory is little-endian.'
        + 'Classic example 0x12345678.'),
      [NGFToolLayer.UTILS],
      'swap_horiz',
      95,
      false
    );
  }

  static mdTableGen(): NGFToolMeta {
    return new NGFToolMeta(
      'md-table-gen',
      l10n('表格生成', 'Table Builder'),
      NGFToolCategory.TEXT,
      l10n('分隔文本转 Markdown 表格：自定义分隔符、竖线转义、列补齐',
        'Convert delimited text to a Markdown table with custom delimiter and escaping'),
      l10n('首行是表头。单元格内的竖线自动转义。列数不足的数据行补空单元格。',
        'The first line is the header. Pipes inside cells are escaped and short rows are'
        + 'padded with empty cells.'),
      [NGFToolLayer.UTILS, NGFToolLayer.CONTENT_WORKFLOW],
      'grid',
      96,
      false
    );
  }

  static charFrequency(): NGFToolMeta {
    return new NGFToolMeta(
      'char-frequency',
      l10n('字符频率', 'Char Frequency'),
      NGFToolCategory.TEXT,
      l10n('字符出现次数与占比：降序排列，可忽略大小写与空白',
        'Character counts and percentages in descending order with case and space options'),
      l10n('排序确定性：次数相同按字符码升序。只统计单字符，不做词频。',
        'Deterministic ordering: equal counts sort by char code. Single characters only,'
        + 'no word frequency.'),
      [NGFToolLayer.UTILS],
      'pie_chart',
      97,
      false
    );
  }

  static wordWrap(): NGFToolMeta {
    return new NGFToolMeta(
      'word-wrap',
      l10n('文本换行', 'Word Wrap'),
      NGFToolCategory.TEXT,
      l10n('按列宽贪心装行：词边界优先、超长词强制断',
        'Greedy word wrap by column width, breaking long words when needed'),
      l10n('词边界优先装行，单个超长词强制断到行宽。显式换行保留。'
        + '宽度 10-200。',
        'Word boundaries are preferred and a single long word is hard-broken to the width.'
        + 'Explicit newlines are kept. Width is 10 to 200.'),
      [NGFToolLayer.UTILS],
      'text_snippet',
      98,
      false
    );
  }

  static lineNumbers(): NGFToolMeta {
    return new NGFToolMeta(
      'line-numbers',
      l10n('行号添加器', 'Line Numbers'),
      NGFToolCategory.TEXT,
      l10n('给文本每行加行号：三种样式、起始号、右对齐',
        'Add line numbers in three styles with a configurable start and right alignment'),
      l10n('行号右对齐补空格（与最大行号对齐）。空行也加行号保持对齐。',
        'Numbers are right-aligned to the widest line. Empty lines get numbers too.'),
      [NGFToolLayer.UTILS],
      'format_list_numbered',
      99,
      false
    );
  }

  static hexDump(): NGFToolMeta {
    return new NGFToolMeta(
      'hex-dump',
      l10n('十六进制转储', 'Hex Dump'),
      NGFToolCategory.TEXT,
      l10n('经典三列转储：偏移量、十六进制字节、ASCII 预览',
        'Classic three-column dump: offset, hex bytes and ASCII preview'),
      l10n('每行 16 字节，不可打印字符显示点。教学/调试件——看 UTF-8 的实际字节。',
        'Sixteen bytes per line with dots for non-printables. See the actual UTF-8 bytes.'),
      [NGFToolLayer.UTILS],
      'code_blocks',
      101,
      false
    );
  }

  static colorBlend(): NGFToolMeta {
    return new NGFToolMeta(
      'color-blend',
      l10n('两色混合', 'Color Blend'),
      NGFToolCategory.COMPUTE,
      l10n('两色的 RGB 线性插值：2-12 步渐变色带',
        'RGB linear interpolation of two colors as a 2 to 12 step gradient'),
      l10n('RGB 通道线性插值（不是感知均匀的插值）。解析复用 ColorConvert。',
        'Channels interpolate linearly in RGB (not perceptually). Parsing reuses ColorConvert.'),
      [NGFToolLayer.UTILS, NGFToolLayer.UI_THEME],
      'gradient',
      102,
      false
    );
  }

  static cookieHeader(): NGFToolMeta {
    return new NGFToolMeta(
      'cookie-header',
      l10n('Cookie 头解析', 'Cookie Header'),
      NGFToolCategory.NETWORK,
      l10n('Cookie 请求头拆键值对，Set-Cookie 属性表解析',
        'Split the Cookie request header and parse Set-Cookie attributes'),
      l10n('值不 URL 解码（原样展示）。含等号的值只切第一个等号。'
        + '只解析文本，不发请求。',
        'Values are shown as-is without URL decoding, and only the first equals sign splits.'
        + 'Text parsing only - no requests.'),
      [NGFToolLayer.UTILS, NGFToolLayer.NETWORK],
      'cookie',
      103,
      false
    );
  }

  static regexTester(): NGFToolMeta {
    return new NGFToolMeta(
      'regex-tester',
      l10n('正则测试', 'Regex Tester'),
      NGFToolCategory.TEXT,
      l10n('正则表达式测试、匹配高亮、分组捕获与常用预设',
        'Test regular expressions with match highlighting, capture groups and presets'),
      l10n('按 JavaScript（ECMAScript）正则语义执行：PCRE 专有写法（递归 (?R)、条件断言、固化分组）在这里会报错或语义不同。'
        + '只做匹配与分组展示，不做替换、不做正则代码生成，也不统计回溯次数——写得糟的表达式照样能把页面卡住。',
      'Runs JavaScript (ECMAScript) regex semantics: PCRE-only constructs (recursion, conditional assertions, '
        + 'atomic groups) either error out or behave differently here. Matching and group display only — no '
        + 'replacement, no code generation, and no backtracking counter, so a pathological pattern can still freeze the page.'),
      [NGFToolLayer.UTILS],
      'magnifyingglass',
      10,
      false
    );
  }

  static jsonToolkit(): NGFToolMeta {
    return new NGFToolMeta(
      'json-toolkit',
      l10n('JSON 工具', 'JSON Toolkit'),
      NGFToolCategory.TEXT,
      l10n('JSON 格式化、压缩、校验并定位错误行列、转义与反转义',
        'Format, minify and validate JSON with error line/column, plus escape and unescape'),
      l10n('严格按 JSON 标准解析：注释、尾随逗号、单引号字符串这些 JSON5/JavaScript 写法一律判为非法。'
        + '超出双精度安全范围的数字按原文保留、不参与数值运算，也不做树形编辑与 JSON 转 CSV。',
      'Parses strict JSON only: comments, trailing commas and single-quoted strings (JSON5/JavaScript style) '
        + 'are reported as invalid. Numbers beyond the double-precision safe range are kept verbatim and never '
        + 'used in arithmetic. No tree editor and no JSON-to-CSV conversion.'),
      [NGFToolLayer.UTILS, NGFToolLayer.CONTENT_WORKFLOW],
      'list_square',
      20,
      false
    );
  }

  static timestamp(): NGFToolMeta {
    return new NGFToolMeta(
      'timestamp',
      l10n('时间戳', 'Timestamp'),
      NGFToolCategory.COMPUTE,
      l10n('时间戳与日期互转、秒毫秒自动识别、多时区对照、相对时间',
        'Convert between timestamps and dates, auto-detect seconds vs milliseconds, compare time zones'),
      l10n('按设备本地时区与系统时区库换算：设备的时区数据过期时，历史或远期时刻的夏令时结果可能差一小时。'
        + '超出 Date 可表示范围（约公元 ±27 万年）的输入会被拒绝；不联网校时，也不做农历换算。',
      'Converts using the device time zone and its system time-zone database: if that data is stale, daylight '
        + 'saving for historical or far-future moments can be off by an hour. Inputs outside the range Date can '
        + 'represent (roughly ±270,000 years) are rejected. No network time sync and no lunar calendar.'),
      [NGFToolLayer.UTILS],
      'clock',
      30,
      false
    );
  }

  static codecSuite(): NGFToolMeta {
    return new NGFToolMeta(
      'codec-suite',
      l10n('编解码套件', 'Codec Suite'),
      NGFToolCategory.COMPUTE,
      l10n('Base64、URL 编码、Unicode 转义、Hex 的编解码',
        'Encode and decode Base64, URL encoding, Unicode escapes and Hex'),
      l10n('只处理 UTF-8 文本：把图片、压缩包这类二进制内容粘进来，非 UTF-8 字节会在解码时丢失。'
        + '不做 Base64 URL 安全变体（- 与 _ 需自行替换），不做 gzip/deflate 解压，也不做 MIME 类型识别。',
      'UTF-8 text only: pasting binary content such as an image or archive loses non-UTF-8 bytes during decode. '
        + 'No Base64 URL-safe variant (replace - and _ yourself), no gzip/deflate decompression, and no MIME sniffing.'),
      [NGFToolLayer.UTILS],
      'arrow_left_arrow_right',
      40,
      false
    );
  }

  static digest(): NGFToolMeta {
    return new NGFToolMeta(
      'digest',
      l10n('摘要计算', 'Hash / Digest'),
      NGFToolCategory.COMPUTE,
      l10n('文本 MD5、SHA-1、SHA-256、SHA-512 摘要计算与指纹比对',
        'Compute MD5, SHA-1, SHA-256 and SHA-512 hashes of text and compare fingerprints'),
      l10n('只处理文本输入，不能直接选文件算摘要（大文件请先自行转文本）。'
        + '摘要一致只说明这段内容没变，「不构成对来源的担保」：摘要可被伪造，也无法证明文件安全；'
        + 'MD5 与 SHA-1 已被证实可构造碰撞，不要用于签名或校验对抗场景。',
      'Text input only — you cannot pick a file to hash (convert large files to text first). A matching digest '
        + 'only means the content did not change; it is NOT a guarantee about its origin, since digests can be '
        + 'forged and prove nothing about safety. MD5 and SHA-1 are known to be collision-prone — do not use them '
        + 'for signatures or adversarial verification.'),
      [NGFToolLayer.UTILS, NGFToolLayer.SECURITY],
      'lock_shield',
      50,
      false
    );
  }

  static jwtDecoder(): NGFToolMeta {
    return new NGFToolMeta(
      'jwt-decoder',
      l10n('JWT 解码', 'JWT Decoder'),
      NGFToolCategory.COMPUTE,
      l10n('JWT 三段解码、Header 与 Payload 解析、过期时间人话化',
        'Decode JWT segments, parse Header and Payload, and spell out expiry in plain language'),
      l10n('「只解码、不验签」：任何字符串都能被解出来，看到内容不代表令牌有效或未被篡改，'
        + '签名段只做原样展示与长度提示。也不校验 iss/aud 等声明是否合规，不做密钥管理，不联网。',
      'Decode only — NO signature verification. Any string will decode, and seeing the contents does not mean the '
        + 'token is valid or untampered; the signature segment is displayed as-is with a length note. Claim checks '
        + '(iss/aud) are not performed, there is no key management, and nothing is sent over the network.'),
      [NGFToolLayer.UTILS],
      'doc_text_badge_magnifyingglass',
      60,
      false
    );
  }

  static cronParser(): NGFToolMeta {
    return new NGFToolMeta(
      'cron-parser',
      l10n('Cron 解析', 'Cron Parser'),
      NGFToolCategory.TEXT,
      l10n('Cron 表达式解析、接下来执行时间、人话描述',
        'Parse cron expressions, list upcoming run times and describe them in plain language'),
      l10n('只支持标准 5 段（分 时 日 月 周）：秒级 6 段、@yearly 这类别名、Quartz 的 ? / L / W 写法都不支持。'
        + '执行时间按设备本地时区推算、不处理夏令时跳变，也不读取系统或远程的任何 crontab。',
      'Standard 5-field expressions only (minute hour day month weekday): 6-field seconds syntax, aliases such as '
        + '@yearly, and Quartz ? / L / W are unsupported. Run times are computed in the device time zone without '
        + 'daylight-saving transitions, and no system or remote crontab is read.'),
      [NGFToolLayer.UTILS],
      'calendar',
      70,
      false
    );
  }

  static radixConvert(): NGFToolMeta {
    return new NGFToolMeta(
      'radix-convert',
      l10n('进制转换', 'Base Converter'),
      NGFToolCategory.COMPUTE,
      l10n('二、八、十、十六进制与 2-36 任意进制互转，按位运算',
        'Convert between binary, octal, decimal, hex and any base from 2 to 36, with bitwise ops'),
      l10n('进制转换用字符串算法、不丢精度；但位运算按 64 位有符号语义处理，超出该范围的数只保证低 64 位结果正确。'
        + '输入里出现目标进制之外的字符会整串判错，不给部分结果。',
      'Base conversion uses string arithmetic and loses no precision, but bitwise operations follow 64-bit signed '
        + 'semantics — for larger values only the low 64 bits are guaranteed correct. A character outside the '
        + 'target base invalidates the whole input instead of returning a partial result.'),
      [NGFToolLayer.UTILS],
      'list_number',
      80,
      false
    );
  }

  static dateCalc(): NGFToolMeta {
    return new NGFToolMeta(
      'date-calc',
      l10n('日期计算', 'Date Calculator'),
      NGFToolCategory.COMPUTE,
      l10n('日期相差天数与工作日数、日期加减、闰年与某月天数',
        'Days between dates, business-day counts, date arithmetic, leap years and days in a month'),
      l10n('只按公历计算：不内置中国法定节假日与调休日历，「工作日」仅指排除周六周日。'
        + '忽略输入里的时间部分（一律按当天 0 点算），也不做农历换算与时区换算。',
      'Gregorian calendar only: public holidays and make-up workdays are not built in, so "business day" just '
        + 'means "not Saturday or Sunday". Any time-of-day part in the input is ignored (dates are treated as '
        + 'midnight), and there is no lunar-calendar or time-zone conversion.'),
      [NGFToolLayer.UTILS],
      'calendar_badge_checkmark',
      90,
      false
    );
  }

  static uuidPassword(): NGFToolMeta {
    return new NGFToolMeta(
      'uuid-password',
      l10n('UUID 与随机密码', 'UUID & Password'),
      NGFToolCategory.COMPUTE,
      l10n('UUID v4 批量生成、随机密码生成与强度评估',
        'Generate UUID v4 in bulk and create random passwords with a strength estimate'),
      l10n('随机数取自系统安全随机源，但本工具不是密码管理器：结果只显示在页面上，不落盘、不上传，关掉页面就找不回。'
        + 'UUID 只生成 v4 纯随机版（不含 v1/v7），也无法反查或保证全局唯一。',
      'Randomness comes from the system secure source, but this is not a password manager: results live only on '
        + 'screen, are never written to disk or uploaded, and are gone once you leave the page. UUIDs are v4 '
        + '(random) only — no v1/v7 — and cannot be reversed or guaranteed globally unique.'),
      [NGFToolLayer.UTILS, NGFToolLayer.SECURITY],
      'lock',
      100,
      false
    );
  }

  static subnetCalc(): NGFToolMeta {
    return new NGFToolMeta(
      'subnet-calc',
      l10n('子网计算', 'Subnet Calculator'),
      NGFToolCategory.NETWORK,
      l10n('CIDR 与子网掩码互算、可用主机数、地址范围、按主机数反推前缀',
        'CIDR and netmask conversion, usable hosts, address ranges and prefix from host count'),
      l10n('只做 IPv4：不解析 IPv6（IPv6 的规划方式完全不同，用 /64 起步是常态）。'
        + '不做路由聚合（把多个网段合并成一条 CIDR），也不做地址归属查询——那需要联网，本 App 不做。'
        + '掩码必须是连续 1 后接连续 0，像 255.0.255.0 这种会被判为非法。',
      'IPv4 only — no IPv6 (its addressing model is entirely different and starts at /64 in practice). No route '
        + 'aggregation (merging several networks into one CIDR) and no IP ownership lookup, which would require '
        + 'network access this app does not use. Masks must be contiguous ones followed by contiguous zeros, so '
        + '255.0.255.0 is rejected.'),
      [NGFToolLayer.UTILS],
      'externaldrive',
      140,
      false
    );
  }

  static textDiff(): NGFToolMeta {
    return new NGFToolMeta(
      'text-diff',
      l10n('文本 Diff', 'Text Diff'),
      NGFToolCategory.TEXT,
      l10n('两段文本行级对比、差异高亮与行号对齐，含行尾风格提示',
        'Line-level comparison of two texts with highlighted differences, aligned line numbers and line-ending notes'),
      l10n('只做行级差异：不做到字符级或词级高亮（所以同一行里改了两个字，会显示为整行被替换）。'
        + '不做三方合并，也不导出可直接 patch 的补丁文件——那需要精确的字节范围与文件头，超出本工具范围。'
        + '两侧各限 2000 行且行数乘积受限，整份大日志请先裁再对比。',
      'Line-level differences only — no character- or word-level highlighting, so changing two characters in a '
        + 'line shows the whole line as replaced. No three-way merge, and no patch files (those need exact byte '
        + 'offsets and headers, which is out of scope). Each side is capped at 2000 lines with a limit on the '
        + 'line-count product, so trim large logs before comparing.'),
      [NGFToolLayer.CONTENT_WORKFLOW],
      'doc_text_on_doc_text',
      160,
      false
    );
  }

  static colorConvert(): NGFToolMeta {
    return new NGFToolMeta(
      'color-convert',
      l10n('颜色转换', 'Color Converter'),
      NGFToolCategory.COMPUTE,
      l10n('HEX、RGB、HSL、HSV、CMYK 互转，明暗阶梯与配色方案，含 WCAG 对比度校验',
        'Convert HEX, RGB, HSL, HSV and CMYK, build lightness scales and harmonies, check WCAG contrast'),
      l10n('一切换算都在 sRGB 空间内做：不做色彩管理（ICC、P3 广色域），所以这里给的数值'
        + '不等于印刷或广色域屏上的实际观感。不做屏幕取色（那需要平台能力），也不导出 .ase 等色板文件。'
        + '对比度按 WCAG 公式给出，但它只回答「黑白底色上够不够看清」，'
        + '不覆盖色盲友好性与动态内容上的对比度。',
      'Everything stays inside sRGB — no colour management (ICC, P3 wide gamut) — so these numbers do not equal '
        + 'what you see in print or on a wide-gamut display. No on-screen colour picking (that needs platform '
        + 'support) and no .ase palette export. Contrast uses the WCAG formula, which only answers "is it legible '
        + 'on a solid background" and does not cover colour-blindness friendliness or contrast over dynamic content.'),
      [NGFToolLayer.UI_THEME],
      'highlight_block',
      150,
      false
    );
  }

  static portTester(): NGFToolMeta {
    // usesNetwork=true 是全仓唯一一处（PR-002/PR-003）：只有这件工具联网，且页内明示。
    return new NGFToolMeta(
      'port-tester',
      l10n('端口测试', 'Port Tester'),
      NGFToolCategory.NETWORK,
      l10n('主机端口的 TCP 连通性测试、常用端口预设、批量测试（会连接你输入的主机）',
        'Test TCP reachability of host ports with presets and batching (connects to the host you enter)'),
      l10n('只判断 TCP 端口能不能连上：不做端口扫描、不做服务指纹识别、也不探测漏洞。'
        + '只连接你自己输入的主机，没有内置任何目标列表，也不联网做域名以外的任何查询。'
        + '一次最多 64 个端口，且能离线判定为无效的输入一个包都不会发出去。'
        + '不发任何应用层数据——「连上了」就是结论，不抓 banner、不发 HTTP 请求。'
        + '因此它不能告诉你「那个端口上跑的是什么服务」。',
      'Answers one question only: can this TCP port be reached. It is not a port scanner, does no service '
        + 'fingerprinting and does not probe for vulnerabilities. It connects only to the host you type, ships no '
        + 'built-in target list, and performs no lookup beyond the host name you gave. At most 64 ports per run, '
        + 'and anything that can be ruled out offline sends zero packets. No application-layer data is sent — '
        + '"connected" is the whole answer, so it never grabs banners or issues HTTP requests. It therefore cannot '
        + 'tell you what service is listening on that port.'),
      [NGFToolLayer.NETWORK],
      'network_acceleration',
      130,
      true
    );
  }

  static qrCode(): NGFToolMeta {
    return new NGFToolMeta(
      'qrcode',
      l10n('二维码生成', 'QR Code Generator'),
      NGFToolCategory.FILE,
      l10n('文本、网址、Wi-Fi、名片 vCard、电话、短信、邮件生成二维码',
        'Generate QR codes for text, URLs, Wi-Fi, vCards, phone numbers, SMS and email'),
      l10n('只生成二维码，不扫别人的码（那需要相机权限，本 App 不申请任何额外权限）。'
        + '不能把二维码存成图片：存图需要组件截图并写入文件或相册，'
        + '本工具只提供「复制内容」与「系统分享文本」，需要图片请自行截屏。'
        + '固定黑码白底、不提供调色——对比度是能不能扫出来的决定性因素。'
        + '内容超过约 300 字符后会变密，部分扫码器可能识别失败。',
      'Generates codes only — it does not scan other codes (that would need camera permission, and this app '
        + 'requests no extra permissions). It cannot save a QR code as an image: that needs a component snapshot '
        + 'written to files or the gallery, so the tool offers only "copy contents" and "share as text" — take a '
        + 'screenshot yourself if you need a picture. Fixed black-on-white with no theming, because contrast is '
        + 'what decides whether a code scans at all. Beyond roughly 300 characters the code becomes dense and '
        + 'some scanners will fail to read it.'),
      [NGFToolLayer.PLATFORM_OHOS],
      'qrcode',
      110,
      false
    );
  }

  static codeViewer(): NGFToolMeta {
    return new NGFToolMeta(
      'code-viewer',
      l10n('代码查看', 'Code Viewer'),
      NGFToolCategory.FILE,
      l10n('打开本地文本与代码文件，按语言高亮，只读浏览大文件',
        'Open local text and code files with language-aware highlighting and smooth read-only scrolling'),
      l10n('只读：不能编辑、不能保存，也不显示二进制文件（图片、压缩包会读成乱码或读不出来）。'
        + '文件经系统选择器打开，不申请存储权限，也不扫描目录。'
        + '语法高亮是单行分词：不做跨行状态，所以跨行的块注释中间几行会按普通代码着色。'
        + '超过 3000 行只显示前 3000 行、超过 2 MB 直接拒绝打开——这是为了避免几千个组件把首帧卡住。',
      'Read-only: no editing, no saving, and no binary files (images and archives either read as garbage or fail '
        + 'to open). Files are opened through the system picker, so no storage permission is requested and no '
        + 'directory is scanned. Highlighting tokenises one line at a time with no cross-line state, so the middle '
        + 'rows of a multi-line block comment are coloured as ordinary code. Files over 3000 lines show only the '
        + 'first 3000, and files over 2 MB are refused outright, to keep thousands of components from stalling the '
        + 'first frame.'),
      [NGFToolLayer.CONTENT_SOURCE, NGFToolLayer.CONTENT_WORKFLOW],
      'doc_text',
      120,
      false
    );
  }
}
/**
 * 登记全部工具。注册表的机制不管清单内容，清单在这里一次性交代清楚。
 *
 * 顺序读起来就是首页的顺序（order 10→160），但真正的排序由 order 决定，
 * 这里保持同序只是为了让人核对「16 件都在」时不用来回跳。
 *
 * 首发 16 件已全部实现，因此这里没有「规划中」的占位登记了。
 * 若将来要加一件尚未实现的工具：仍用 `registry.registerPlaceholder(meta)` 登记元数据，
 * 首页会显示「建设中」；实现完成后再改成 `registry.register(meta)`
 * 并在 `ui/ToolPageRegistry.ets` 加一行 `pages.set(...)`。
 * 两条路径的差别只有一个「有没有页面」，元数据本身完全一样。
 */
export function builtinTools(): Array<NGFToolMeta> {
  return [
    ImplementedTools.mdPreview(),
  ImplementedTools.csvJson(),
  ImplementedTools.unitConvert(),
  ImplementedTools.floatBits(),
  ImplementedTools.bitOps(),
  ImplementedTools.paletteGen(),
  ImplementedTools.contrastCheck(),
  ImplementedTools.imgBase64(),
  ImplementedTools.regexReplace(),
  ImplementedTools.tzMeeting(),
  ImplementedTools.shellCheatsheet(),
  ImplementedTools.curlBuilder(),
  ImplementedTools.sprintCalc(),
  ImplementedTools.changelogGen(),
  ImplementedTools.json2Doc(),
  ImplementedTools.keyseqDoc(),
  ImplementedTools.gitCheatsheet(),
  ImplementedTools.semverParse(),
  ImplementedTools.unitTable(),
  ImplementedTools.hexDump(),
  ImplementedTools.lineNumbers(),
  ImplementedTools.wordWrap(),
  ImplementedTools.charFrequency(),
  ImplementedTools.mdTableGen(),
  ImplementedTools.cookieHeader(),
  ImplementedTools.colorBlend(),
  ImplementedTools.byteSplit(),
  ImplementedTools.dateDiff(),
  ImplementedTools.httpMethod(),
  ImplementedTools.hueShift(),
  ImplementedTools.asciiTable(),
  ImplementedTools.keyboardSymbols(),
  ImplementedTools.entityTable(),
  ImplementedTools.mdLinkCheck(),
  ImplementedTools.cronCheatsheet(),
  ImplementedTools.markdownToc(),
  ImplementedTools.codeMinify(),
  ImplementedTools.jwtBuilder(),
  ImplementedTools.asciiLine(),
  ImplementedTools.fileHash(),
  ImplementedTools.mockData(),
  ImplementedTools.passwordStrength(),
  ImplementedTools.uuidBatch(),
  ImplementedTools.epochTable(),
  ImplementedTools.uaParser(),
  ImplementedTools.urlParser(),
  ImplementedTools.mimeLookup(),
  ImplementedTools.portLookup(),
  ImplementedTools.httpHeaders(),
  ImplementedTools.httpStatus(),
  ImplementedTools.ipCidr(),
  ImplementedTools.percentCalc(),
  ImplementedTools.checksum(),
  ImplementedTools.hmacCalc(),
  ImplementedTools.loremIpsum(),
  ImplementedTools.htmlEntity(),
  ImplementedTools.textToolkit(),
  ImplementedTools.caseConvert(),
  ImplementedTools.regexCheatsheet(),
  ImplementedTools.sqlFormat(),
  ImplementedTools.jsonYaml(),
  ImplementedTools.jsonToml(),
  ImplementedTools.formDecode(),
  ImplementedTools.jsonPath(),
  ImplementedTools.urlCodec(),
  ImplementedTools.regexTester(),
    ImplementedTools.jsonToolkit(),
    ImplementedTools.timestamp(),
    ImplementedTools.codecSuite(),
    ImplementedTools.digest(),
    ImplementedTools.jwtDecoder(),
    ImplementedTools.cronParser(),
    ImplementedTools.radixConvert(),
    ImplementedTools.dateCalc(),
    ImplementedTools.uuidPassword(),
    ImplementedTools.subnetCalc(),
    ImplementedTools.textDiff(),
    ImplementedTools.colorConvert(),
    ImplementedTools.portTester(),
    ImplementedTools.qrCode(),
    ImplementedTools.codeViewer()
  ];
}

/**
 * 登记全部工具。
 *
 * 清单本身由 {@link builtinTools} 提供：**一份**清单同时供启动登记与单测使用。
 * 早先这里是 16 行 `registry.register(ImplementedTools.xxx())`，
 * 单测想核对「16 件都在、英文都写全了」就只能去戳全局单例（会被同进程其它用例污染）；
 * 抽成导出函数后，单测直接读清单，与运行期用的是同一份数据。
 */
function registerAllTools(registry: ToolRegistry): void {
  const metas: Array<NGFToolMeta> = builtinTools();
  for (let i: number = 0; i < metas.length; i++) {
    registry.register(metas[i]);
  }
}

/** 是否已注入（幂等保护：EntryAbility 可能因多实例/重启被调用多次） */
let catalogInstalled: boolean = false;

/**
 * 把工具清单注入注册表。由 EntryAbility 在 NGF 引导完成后调用。
 *
 * 内部顺序刻意固定为「先注入清单、再让注册表消费它」：
 * 反过来的话 ensureBuiltinsRegistered 会在清单为空时把幂等标志置位，
 * 之后无论怎样都不会再注册——首页将永远显示「没有工具」。
 */
export function ensureToolCatalogInstalled(): void {
  if (catalogInstalled) {
    return;
  }
  catalogInstalled = true;
  installToolCatalog(registerAllTools);
  toolRegistry.ensureBuiltinsRegistered();
}