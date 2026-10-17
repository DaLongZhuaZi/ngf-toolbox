/**
 * MIME 类型速查的纯逻辑实现（本地数据表）。
 *
 * ## 数据口径
 *
 * 收录开发高频的扩展名 → MIME 映射（约 30 个），不是 IANA 全量。
 * 一个扩展名可能对应多个 MIME（如 js）——表取最常用的那个。
 *
 * ## 查询
 *
 * 输入扩展名（可带点）或文件名（自动取最后一段扩展名），大小写不敏感。
 *
 * @module tools/mime-lookup/MimeLookup
 */

import { NGFLocalizedText } from '../../core/ToolModel';

/** 一条 MIME 映射 */
export class MimeEntry {
  readonly extension: string;
  readonly mime: string;
  readonly meaning: NGFLocalizedText;

  constructor(extension: string, mime: string, meaning: NGFLocalizedText) {
    this.extension = extension;
    this.mime = mime;
    this.meaning = meaning;
  }
}

/** 查询结果 */
export class MimeLookupResult {
  readonly found: boolean;
  readonly entry: MimeEntry | null;

  constructor(found: boolean, entry: MimeEntry | null) {
    this.found = found;
    this.entry = entry;
  }
}

function buildTable(): Array<MimeEntry> {
  const list: Array<MimeEntry> = [];
  const add = (ext: string, mime: string, meaning: NGFLocalizedText): void => {
  list.push(new MimeEntry(ext, mime, meaning));
  };
  add('html', 'text/html', new NGFLocalizedText('网页', 'Web page'));
  add('css', 'text/css', new NGFLocalizedText('样式表', 'Stylesheet'));
  add('js', 'text/javascript', new NGFLocalizedText('JavaScript 脚本', 'JavaScript source'));
  add('mjs', 'text/javascript', new NGFLocalizedText('ES Module 脚本', 'ES module source'));
  add('json', 'application/json', new NGFLocalizedText('JSON 数据', 'JSON data'));
  add('jsonl', 'application/jsonl', new NGFLocalizedText('逐行 JSON', 'Line-delimited JSON'));
  add('xml', 'application/xml', new NGFLocalizedText('XML 数据', 'XML data'));
  add('txt', 'text/plain', new NGFLocalizedText('纯文本', 'Plain text'));
  add('md', 'text/markdown', new NGFLocalizedText('Markdown 文档', 'Markdown document'));
  add('csv', 'text/csv', new NGFLocalizedText('逗号分隔数据', 'Comma-separated data'));
  add('pdf', 'application/pdf', new NGFLocalizedText('PDF 文档', 'PDF document'));
  add('zip', 'application/zip', new NGFLocalizedText('ZIP 压缩包', 'ZIP archive'));
  add('gz', 'application/gzip', new NGFLocalizedText('GZIP 压缩包', 'GZIP archive'));
  add('png', 'image/png', new NGFLocalizedText('PNG 图片', 'PNG image'));
  add('jpg', 'image/jpeg', new NGFLocalizedText('JPEG 图片', 'JPEG image'));
  add('jpeg', 'image/jpeg', new NGFLocalizedText('JPEG 图片', 'JPEG image'));
  add('gif', 'image/gif', new NGFLocalizedText('GIF 图片', 'GIF image'));
  add('webp', 'image/webp', new NGFLocalizedText('WebP 图片', 'WebP image'));
  add('svg', 'image/svg+xml', new NGFLocalizedText('SVG 矢量图', 'SVG vector image'));
  add('ico', 'image/x-icon', new NGFLocalizedText('图标', 'Icon'));
  add('mp3', 'audio/mpeg', new NGFLocalizedText('MP3 音频', 'MP3 audio'));
  add('mp4', 'video/mp4', new NGFLocalizedText('MP4 视频', 'MP4 video'));
  add('wav', 'audio/wav', new NGFLocalizedText('WAV 音频', 'WAV audio'));
  add('woff', 'font/woff', new NGFLocalizedText('WOFF 字体', 'WOFF font'));
  add('woff2', 'font/woff2', new NGFLocalizedText('WOFF2 字体', 'WOFF2 font'));
  add('wasm', 'application/wasm', new NGFLocalizedText('WebAssembly 模块', 'WebAssembly module'));
  add('ts', 'text/typescript', new NGFLocalizedText('TypeScript 源码', 'TypeScript source'));
  add('yaml', 'text/yaml', new NGFLocalizedText('YAML 配置', 'YAML config'));
  add('yml', 'text/yaml', new NGFLocalizedText('YAML 配置', 'YAML config'));
  add('toml', 'text/plain', new NGFLocalizedText('TOML 配置', 'TOML config'));
  return list;
}

const TABLE: Array<MimeEntry> = buildTable();

/** 全表 */
export function allMimeEntries(): Array<MimeEntry> {
  return TABLE;
}

/** 从输入里取扩展名（去点、小写；取最后一段点之后） */
export function normalizeExtension(input: string): string {
  let text: string = input.trim().toLowerCase();
  const lastDot: number = text.lastIndexOf(String.fromCharCode(46));
  if (lastDot >= 0) {
    text = text.substring(lastDot + 1);
  }
  return text;
}

/** 查询：文件名或扩展名 → MIME 条目；未命中 found=false */
export function lookupMime(input: string): MimeLookupResult {
  const ext: string = normalizeExtension(input);
  if (ext.length === 0) {
    return new MimeLookupResult(false, null);
  }
  for (let i = 0; i < TABLE.length; i++) {
    if (TABLE[i].extension === ext) {
      return new MimeLookupResult(true, TABLE[i]);
    }
  }
  return new MimeLookupResult(false, null);
}
