/**
 * 工具页面构建器登记表 —— 把「工具 id」映射到「怎么渲染它」。
 *
 * ## 为什么要和元数据清单分开
 *
 * 元数据（core/ToolModel + tools/ToolsCatalog）是**纯数据**，必须能在
 * entry/src/test 里被单测直接 import——所以它不能碰 ArkUI。
 * 而页面构建器类型 `WrappedBuilder` 来自 ArkUI，一旦混进元数据层，
 * 注册表的搜索/排序逻辑就再也测不了了。
 *
 * 于是分成两层、用 `toolId` 对齐：
 * - tools/ToolsCatalog.ets  —— 有哪些工具、它们是什么（纯）
 * - ui/ToolPageRegistry.ets —— 每件工具长什么样（UI）
 *
 * 分层代价是多一个文件；收益是「搜索、排序、收藏、分组」这些真正会出 bug
 * 的逻辑可以在单测里覆盖，不必依赖真机。
 *
 * ## 新增一件工具
 *
 * 在 {@link registerToolPages} 里加一行 `pages.set('<toolId>', buildXxxPage)`，
 * 并 import 该工具的 `buildXxxPage`。仅此一处。
 *
 * @module ui/ToolPageRegistry
 */

import { ToolPageParams } from '../core/ToolPageContract';

// 注意：`WrappedBuilder` **不要 import**——它是 ArkTS 在 .ets 里提供的全局类型，
// `@kit.ArkUI` 并不导出它。写成 import 会得到
// 「Module '@kit.ArkUI' has no exported member 'WrappedBuilder'」，而且本机纯逻辑
// 门禁（只剥类型、不查类型）完全看不出来。这条是真编译才报的。

// 各工具页面的构建器。这里是全仓唯一 import 具体工具页面的地方——
// 首页、宿主页都只认 toolId，不认识任何一件具体工具。
import { buildCodecSuitePage } from '../tools/codec-suite/CodecSuitePage';
import { buildCronParserPage } from '../tools/cron-parser/CronParserPage';
import { buildDateCalcPage } from '../tools/date-calc/DateCalcPage';
import { buildDigestPage } from '../tools/digest/DigestPage';
import { buildJsonToolkitPage } from '../tools/json-toolkit/JsonToolkitPage';
import { buildJwtDecoderPage } from '../tools/jwt-decoder/JwtDecoderPage';
import { buildRadixConvertPage } from '../tools/radix-convert/RadixConvertPage';
import { buildRegexTesterPage } from '../tools/regex-tester/RegexTesterPage';
import { buildSubnetCalcPage } from '../tools/subnet-calc/SubnetCalcPage';
import { buildTextDiffPage } from '../tools/text-diff/TextDiffPage';
import { buildColorConvertPage } from '../tools/color-convert/ColorConvertPage';
import { buildPortTesterPage } from '../tools/port-tester/PortTesterPage';
import { buildQrCodePage } from '../tools/qrcode/QrCodePage';
import { buildCodeViewerPage } from '../tools/code-viewer/CodeViewerPage';
import { buildTimestampPage } from '../tools/timestamp/TimestampPage';
import { buildCaseConvertPage } from '../tools/case-convert/CaseConvertPage';
import { buildHtmlEntityPage } from '../tools/html-entity/HtmlEntityPage';
import { buildCsvJsonPage } from '../tools/csv-json/CsvJsonPage';
import { buildMdPreviewPage } from '../tools/md-preview/MdPreviewPage';
import { buildBitOpsPage } from '../tools/bit-ops/BitOpsPage';
import { buildFloatBitsPage } from '../tools/float-bits/FloatBitsPage';
import { buildUnitConvertPage } from '../tools/unit-convert/UnitConvertPage';
import { buildChecksumPage } from '../tools/checksum/ChecksumPage';
import { buildContrastCheckPage } from '../tools/contrast-check/ContrastCheckPage';
import { buildPaletteGenPage } from '../tools/palette-gen/PaletteGenPage';
import { buildHttpStatusPage } from '../tools/http-status/HttpStatusPage';
import { buildMimeLookupPage } from '../tools/mime-lookup/MimeLookupPage';
import { buildUrlParserPage } from '../tools/url-parser/UrlParserPage';
import { buildUaParserPage } from '../tools/ua-parser/UaParserPage';
import { buildEpochTablePage } from '../tools/epoch-table/EpochTablePage';
import { buildUuidBatchPage } from '../tools/uuid-batch/UuidBatchPage';
import { buildPasswordStrengthPage } from '../tools/password-strength/PasswordStrengthPage';
import { buildMockDataPage } from '../tools/mock-data/MockDataPage';
import { buildFileHashPage } from '../tools/file-hash/FileHashPage';
import { buildAsciiLinePage } from '../tools/ascii-line/AsciiLinePage';
import { buildJwtBuilderPage } from '../tools/jwt-builder/JwtBuilderPage';
import { buildCodeMinifyPage } from '../tools/code-minify/CodeMinifyPage';
import { buildMarkdownTocPage } from '../tools/markdown-toc/MarkdownTocPage';
import { buildCronCheatsheetPage } from '../tools/cron-cheatsheet/CronCheatsheetPage';
import { buildMdLinkCheckPage } from '../tools/md-link-check/MdLinkCheckPage';
import { buildEntityTablePage } from '../tools/entity-table/EntityTablePage';
import { buildKeyboardSymbolsPage } from '../tools/keyboard-symbols/KeyboardSymbolsPage';
import { buildAsciiTablePage } from '../tools/ascii-table/AsciiTablePage';
import { buildHueShiftPage } from '../tools/hue-shift/HueShiftPage';
import { buildHttpMethodPage } from '../tools/http-method/HttpMethodPage';
import { buildDateDiffPage } from '../tools/date-diff/DateDiffPage';
import { buildByteSplitPage } from '../tools/byte-split/ByteSplitPage';
import { buildColorBlendPage } from '../tools/color-blend/ColorBlendPage';
import { buildCookieHeaderPage } from '../tools/cookie-header/CookieHeaderPage';
import { buildMdTableGenPage } from '../tools/md-table-gen/MdTableGenPage';
import { buildCharFreqPage } from '../tools/char-frequency/CharFreqPage';
import { buildWordWrapPage } from '../tools/word-wrap/WordWrapPage';
import { buildLineNumbersPage } from '../tools/line-numbers/LineNumbersPage';
import { buildHexDumpPage } from '../tools/hex-dump/HexDumpPage';
import { buildUnitTablePage } from '../tools/unit-table/UnitTablePage';
import { buildSemverPage } from '../tools/semver-parse/SemverPage';
import { buildGitCheatsheetPage } from '../tools/git-cheatsheet/GitCheatsheetPage';
import { buildKeyseqDocPage } from '../tools/keyseq-doc/KeyseqDocPage';
import { buildJson2DocPage } from '../tools/json2doc/Json2DocPage';
import { buildChangelogGenPage } from '../tools/changelog-gen/ChangelogPage';
import { buildSprintPage } from '../tools/sprint-calc/SprintPage';
import { buildCurlBuilderPage } from '../tools/curl-builder/CurlBuilderPage';
import { buildShellCheatsheetPage } from '../tools/shell-cheatsheet/ShellCheatsheetPage';
import { buildTzPage } from '../tools/tz-meeting/TzPage';
import { buildRegexReplacePage } from '../tools/regex-replace/RegexReplacePage';
import { buildImgBase64Page } from '../tools/img-base64/ImgBase64Page';
import { buildPortLookupPage } from '../tools/port-lookup/PortLookupPage';
import { buildHttpHeadersPage } from '../tools/http-headers/HttpHeadersPage';
import { buildIpCidrPage } from '../tools/ip-cidr/IpCidrPage';
import { buildPercentCalcPage } from '../tools/percent-calc/PercentCalcPage';
import { buildHmacCalcPage } from '../tools/hmac-calc/HmacCalcPage';
import { buildLoremIpsumPage } from '../tools/lorem-ipsum/LoremIpsumPage';
import { buildTextToolkitPage } from '../tools/text-toolkit/TextToolkitPage';
import { buildFormDecodePage } from '../tools/form-decode/FormDecodePage';
import { buildJsonTomlPage } from '../tools/json-toml/JsonTomlPage';
import { buildJsonYamlPage } from '../tools/json-yaml/JsonYamlPage';
import { buildSqlFormatPage } from '../tools/sql-format/SqlFormatPage';
import { buildRegexCheatsheetPage } from '../tools/regex-cheatsheet/RegexCheatsheetPage';
import { buildJsonPathPage } from '../tools/json-path/JsonPathPage';
import { buildUrlCodecPage } from '../tools/url-codec/UrlCodecPage';
import { buildUuidPasswordPage } from '../tools/uuid-password/UuidPasswordPage';

/** 工具页面构建器类型。工具模块导出它，本表持有它。 */
export type NGFToolPageBuilder = WrappedBuilder<[ToolPageParams]>;

/** 工具 id → 页面构建器 */
const pages: Map<string, NGFToolPageBuilder> = new Map<string, NGFToolPageBuilder>();

let registered: boolean = false;

/**
 * 取某件工具的页面构建器；未实现（规划中）返回 null。
 *
 * 调用方（ToolHostPage）遇到 null **必须**显示「建设中」而不是崩溃：
 * 用户可能通过收藏/最近使用/搜索点进一件尚未实现的工具，
 * 那时白屏或崩溃都是不可接受的，明确告知「还没做好」才是正确行为。
 */
export function toolPageBuilderOf(id: string): NGFToolPageBuilder | null {
  ensureToolPagesRegistered();
  const builder: NGFToolPageBuilder | undefined = pages.get(id.trim());
  return builder === undefined ? null : builder;
}

/** 已实现的工具 id 清单（调试与「建设中」判定用） */
export function implementedToolIds(): Array<string> {
  ensureToolPagesRegistered();
  const ids: Array<string> = [];
  pages.forEach((builder: NGFToolPageBuilder, id: string): void => {
    ids.push(id);
  });
  return ids;
}

/** 幂等注册入口 */
export function ensureToolPagesRegistered(): void {
  if (registered) {
    return;
  }
  registered = true;
  registerToolPages();
}

/**
 * 登记全部工具页面。
 *
 * 本函数是工具箱里**唯一** import 具体工具页面的地方。
 * 每件工具完成时在此加一行即可；首页与宿主页都不需要改动。
 */
function registerToolPages(): void {
  // ── 已实现的 10 件 ────────────────────────────────────────
  // 顺序与 tools/ToolsCatalog.ets 的 order 一致（10 → 100）。
  // 注意：首页的**排序不依赖这里**（排序由元数据的 order 决定），
  // 保持同序只是为了核对「10 件都在」时不用来回跳。
  pages.set('md-preview', wrapBuilder(buildMdPreviewPage));     // order 14   文本与数据
  pages.set('csv-json', wrapBuilder(buildCsvJsonPage));         // order 21   文本与数据
  pages.set('unit-convert', wrapBuilder(buildUnitConvertPage)); // order 59   编解码与计算
  pages.set('float-bits', wrapBuilder(buildFloatBitsPage));     // order 58   编解码与计算
  pages.set('bit-ops', wrapBuilder(buildBitOpsPage));         // order 57   编解码与计算
  pages.set('palette-gen', wrapBuilder(buildPaletteGenPage));   // order 63   编解码与计算
  pages.set('contrast-check', wrapBuilder(buildContrastCheckPage)); // order 62   编解码与计算
  pages.set('http-headers', wrapBuilder(buildHttpHeadersPage));   // order 67   网络
  pages.set('git-cheatsheet', wrapBuilder(buildGitCheatsheetPage)); // order 30   文本与数据
  pages.set('tz-meeting', wrapBuilder(buildTzPage));          // order 80   编解码与计算
  pages.set('shell-cheatsheet', wrapBuilder(buildShellCheatsheetPage)); // order 79   文本与数据
  pages.set('curl-builder', wrapBuilder(buildCurlBuilderPage)); // order 78   网络
  pages.set('sprint-calc', wrapBuilder(buildSprintPage));     // order 77   编解码与计算
  pages.set('changelog-gen', wrapBuilder(buildChangelogGenPage)); // order 34   文本与数据
  pages.set('json2doc', wrapBuilder(buildJson2DocPage));      // order 33   文本与数据
  pages.set('img-base64', wrapBuilder(buildImgBase64Page));   // order 36   文本与数据
  pages.set('regex-replace', wrapBuilder(buildRegexReplacePage)); // order 35   文本与数据
  pages.set('keyseq-doc', wrapBuilder(buildKeyseqDocPage));   // order 32   文本与数据
  pages.set('semver-parse', wrapBuilder(buildSemverPage));    // order 76   编解码与计算
  pages.set('unit-table', wrapBuilder(buildUnitTablePage));   // order 90   编解码与计算
  pages.set('hex-dump', wrapBuilder(buildHexDumpPage));       // order 100   文本与数据
  pages.set('line-numbers', wrapBuilder(buildLineNumbersPage)); // order 99   文本与数据
  pages.set('word-wrap', wrapBuilder(buildWordWrapPage));     // order 98   文本与数据
  pages.set('char-frequency', wrapBuilder(buildCharFreqPage)); // order 97   文本与数据
  pages.set('md-table-gen', wrapBuilder(buildMdTableGenPage)); // order 96   文本与数据
  pages.set('cookie-header', wrapBuilder(buildCookieHeaderPage)); // order 103   网络
  pages.set('color-blend', wrapBuilder(buildColorBlendPage)); // order 102   编解码与计算
  pages.set('byte-split', wrapBuilder(buildByteSplitPage));   // order 95   编解码与计算
  pages.set('date-diff', wrapBuilder(buildDateDiffPage));     // order 89   编解码与计算
  pages.set('http-method', wrapBuilder(buildHttpMethodPage)); // order 87   网络
  pages.set('hue-shift', wrapBuilder(buildHueShiftPage));     // order 86   编解码与计算
  pages.set('keyboard-symbols', wrapBuilder(buildKeyboardSymbolsPage)); // order 91   文本与数据
  pages.set('ascii-table', wrapBuilder(buildAsciiTablePage)); // order 93   文本与数据
  pages.set('entity-table', wrapBuilder(buildEntityTablePage)); // order 38   文本与数据
  pages.set('md-link-check', wrapBuilder(buildMdLinkCheckPage)); // order 37   文本与数据
  pages.set('cron-cheatsheet', wrapBuilder(buildCronCheatsheetPage)); // order 85   文本与数据
  pages.set('markdown-toc', wrapBuilder(buildMarkdownTocPage)); // order 84   文本与数据
  pages.set('code-minify', wrapBuilder(buildCodeMinifyPage)); // order 83   文本与数据
  pages.set('jwt-builder', wrapBuilder(buildJwtBuilderPage)); // order 82   编解码与计算
  pages.set('ascii-line', wrapBuilder(buildAsciiLinePage));   // order 29   文本与数据
  pages.set('file-hash', wrapBuilder(buildFileHashPage));     // order 28   文本与数据
  pages.set('mock-data', wrapBuilder(buildMockDataPage)); // order 75   文件与生成
  pages.set('password-strength', wrapBuilder(buildPasswordStrengthPage)); // order 74   文件与生成
  pages.set('uuid-batch', wrapBuilder(buildUuidBatchPage));   // order 73   文件与生成
  pages.set('epoch-table', wrapBuilder(buildEpochTablePage));   // order 72   编解码与计算
  pages.set('ua-parser', wrapBuilder(buildUaParserPage));     // order 70   网络
  pages.set('url-parser', wrapBuilder(buildUrlParserPage));     // order 68   网络
  pages.set('mime-lookup', wrapBuilder(buildMimeLookupPage));   // order 68   网络
  pages.set('port-lookup', wrapBuilder(buildPortLookupPage));   // order 69   网络
  pages.set('http-status', wrapBuilder(buildHttpStatusPage));   // order 66   网络
  pages.set('ip-cidr', wrapBuilder(buildIpCidrPage));         // order 65   网络
  pages.set('percent-calc', wrapBuilder(buildPercentCalcPage)); // order 60   编解码与计算
  pages.set('checksum', wrapBuilder(buildChecksumPage));       // order 56   编解码与计算
  pages.set('hmac-calc', wrapBuilder(buildHmacCalcPage));       // order 55   编解码与计算
  pages.set('lorem-ipsum', wrapBuilder(buildLoremIpsumPage));     // order 19   文本与数据
  pages.set('html-entity', wrapBuilder(buildHtmlEntityPage));     // order 18   文本与数据
  pages.set('text-toolkit', wrapBuilder(buildTextToolkitPage));    // order 17   文本与数据
  pages.set('case-convert', wrapBuilder(buildCaseConvertPage));     // order 16   文本与数据
  pages.set('regex-cheatsheet', wrapBuilder(buildRegexCheatsheetPage)); // order 27   文本与数据
  pages.set('sql-format', wrapBuilder(buildSqlFormatPage));   // order 26   文本与数据
  pages.set('json-yaml', wrapBuilder(buildJsonYamlPage));     // order 25   文本与数据
  pages.set('json-toml', wrapBuilder(buildJsonTomlPage));     // order 24   文本与数据
  pages.set('form-decode', wrapBuilder(buildFormDecodePage));     // order 23   文本与数据
  pages.set('json-path', wrapBuilder(buildJsonPathPage));       // order 22   文本与数据
  pages.set('url-codec', wrapBuilder(buildUrlCodecPage));         // order 30   文本与数据
  pages.set('regex-tester', wrapBuilder(buildRegexTesterPage));    // order 10   文本与数据
  pages.set('json-toolkit', wrapBuilder(buildJsonToolkitPage));    // order 20   文本与数据
  pages.set('timestamp', wrapBuilder(buildTimestampPage));         // order 30   编解码与计算
  pages.set('codec-suite', wrapBuilder(buildCodecSuitePage));      // order 40   编解码与计算
  pages.set('digest', wrapBuilder(buildDigestPage));               // order 50   编解码与计算
  pages.set('jwt-decoder', wrapBuilder(buildJwtDecoderPage));      // order 60   编解码与计算
  pages.set('cron-parser', wrapBuilder(buildCronParserPage));      // order 70   文本与数据
  pages.set('radix-convert', wrapBuilder(buildRadixConvertPage));  // order 80   编解码与计算
  pages.set('date-calc', wrapBuilder(buildDateCalcPage));          // order 90   编解码与计算
  pages.set('uuid-password', wrapBuilder(buildUuidPasswordPage));
  pages.set('subnet-calc', wrapBuilder(buildSubnetCalcPage));
  pages.set('text-diff', wrapBuilder(buildTextDiffPage));
  pages.set('color-convert', wrapBuilder(buildColorConvertPage));
  pages.set('port-tester', wrapBuilder(buildPortTesterPage));
  pages.set('qrcode', wrapBuilder(buildQrCodePage));
  pages.set('code-viewer', wrapBuilder(buildCodeViewerPage));  // order 120  文件与生成

  // 首版 16 件工具**全部**已登记，没有占位页了。
  //
  // 曾经的坑：工具做完了但忘了在上面加一行，ToolsCatalog 里还走
  // registerPlaceholder，用户点进去看到「建设中」——不报错、不崩溃，
  // 只有真机上点一下才发现。check-wiring.mjs 现在会挡住这种不同步。
}