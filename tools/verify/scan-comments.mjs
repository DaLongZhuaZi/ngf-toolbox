import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';

function walk(dir, out) {
  for (const e of readdirSync(dir)) {
    const full = join(dir, e);
    if (statSync(full).isDirectory()) walk(full, out);
    // 同时收 .mjs：tools/ 下的验证脚本也是手写的，同样会踩「星号+斜杠」
    // 提前闭合注释的坑。实测在 check-theme-contrast.mjs 里踩过一次
    // （写 \`resources/*/element/...\` 描述路径），而当时扫描器只看 .ets，没抓到。
    else if (e.endsWith('.ets') || e.endsWith('.mjs')) out.push(full);
  }
  return out;
}

/**
 * 真正的全量扫描：用状态机在**整个文件**上找出所有块注释的起止，
 * 若某个块注释的结束位置之后、同一行内还有非空白且**不是**新注释起点的内容，
 * 就说明它提前闭合了（典型写法是把「星号星号 + 斜杠 + 数字」写在一起，
 * 其中的「星号 + 斜杠」会被当成块注释结束符）。
 */
function scanFile(file) {
  const src = readFileSync(file, 'utf8');
  const problems = [];
  let i = 0;
  const n = src.length;
  let line = 1;
  let state = 'code'; // code | line | block | sq | dq | tpl
  let blockStartLine = 0;
  while (i < n) {
    const c = src[i];
    const c2 = src[i + 1];
    if (c === '\n') line++;
    if (state === 'code') {
      if (c === '/' && c2 === '/') { state = 'line'; i += 2; continue; }
      if (c === '/' && c2 === '*') { state = 'block'; blockStartLine = line; i += 2; continue; }
      if (c === "'") { state = 'sq'; i++; continue; }
      if (c === '"') { state = 'dq'; i++; continue; }
      if (c === '\u0060') { state = 'tpl'; i++; continue; }
      i++; continue;
    }
    if (state === 'line') {
      if (c === '\n') state = 'code';
      i++; continue;
    }
    if (state === 'sq' || state === 'dq') {
      const q = state === 'sq' ? "'" : '"';
      if (c === '\\') { i += 2; continue; }
      if (c === q) state = 'code';
      i++; continue;
    }
    if (state === 'tpl') {
      if (c === '\\') { i += 2; continue; }
      if (c === '\u0060') state = 'code';
      i++; continue;
    }
    // block
    if (c === '*' && c2 === '/') {
      // 结束位置：检查同一行剩余内容
      let j = i + 2;
      while (j < n && src[j] !== '\n' && /[ \t\r]/.test(src[j])) j++;
      const restIsEmpty = j >= n || src[j] === '\n';
      if (!restIsEmpty) {
        // 同一行后面还有东西 —— 可能是提前闭合，也可能是 /* x */ code 这种单行注释
        const prefix = src.slice(src.lastIndexOf('\n', i) + 1, i);
        // 若闭合标记所在行**以 * 开头**（注释续行风格），那几乎一定是提前闭合
        if (/^\s*\*/.test(prefix)) {
          problems.push({ line: line, text: src.slice(src.lastIndexOf('\n', i) + 1, src.indexOf('\n', i)).trim().slice(0, 130) });
        }
      }
      state = 'code';
      i += 2; continue;
    }
    i++;
  }
  return problems;
}

const roots = ['entry/src', 'ngf_framework/src', 'tools'];
let files = [];
for (const r of roots) { try { walk(r, files); } catch (e) {} }
let total = 0;
for (const f of files) {
  const problems = scanFile(f);
  if (problems.length > 0) {
    total += problems.length;
    console.log('[问题] ' + f);
    for (const p of problems) console.log('   第 ' + p.line + ' 行: ' + p.text);
  }
}
console.log('');
console.log('扫描 ' + files.length + ' 个文件（.ets + .mjs），发现疑似提前闭合注释 ' + total + ' 处');

// 退出码：门禁是按退出码判定的，只打印不算数。
//
// ⚠️ 这行原先**不存在**——本脚本报出「发现疑似提前闭合注释 N 处」却始终 exit 0，
// 于是它在十道门禁里**从来没有失败过**。发现途径：把门禁的变异验证固化成脚本后，
// 这条变异「退出码 0（含预期片段）」当场暴露。
process.exit(total === 0 ? 0 : 1);