#!/usr/bin/env python3
"""
真机 UI 助手：按**控件文字**定位并点击，不靠估坐标。

## 为什么需要它

`AGENTS.md` §3.4 记着一条教训：看着缩放后的截图估坐标，实测点空三次，
其中一次差了 420px（以为输入框在 y=1230，实际 1650）。
**点空不报错**，只会让人误判成「功能坏了」，然后去改本来正确的代码。

鸿蒙自带的 `uitest dumpLayout` 会导出**控件树**（JSON，含每个节点的
`text` 与 `bounds`）。按文字找控件，坐标就是设备自己报的，不用猜。

## 用法

    python tools/device/ui.py dump                      # 列出所有可点控件的文字与坐标
    python tools/device/ui.py find "转换"                # 只打印坐标
    python tools/device/ui.py tap "转换"                 # 找到并点击
    python tools/device/ui.py tap "转换" --wait 1        # 点完等 1 秒
    python tools/device/ui.py input "HelloNGF"           # 往当前焦点输入文字
    python tools/device/ui.py key back                   # 返回键

环境变量 `HDC` 可覆盖 hdc 路径，`TARGET` 覆盖设备序列号。

## ⚠️ 已知限制：特殊字符

| 输入 | 实际落进输入框 |
|---|---|
| `#FF0000` | **什么都没进**（`#` 被设备 shell 当注释） |
| `{` | `{}` ← **输入法自动补了右花括号** |
| `{a}` / `abc` | 正常 ✓ |
| `{"b":2,"a":1}` | `{"b":2,"a":1}}` ← 自动补的与手打的收尾 `}` 撞在一起 |

**绕法**：打 `{` 后不要再打收尾的 `}`。
**改完输入一律 `field_text()` 回读**——这条救过一次误判（非法 JSON 让工具报错，
差点被当成工具的解析缺陷）。

"""
import json, os, re, subprocess, sys, tempfile, time

HDC = os.environ.get("HDC", r"G:\DevEco Studio 26\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe")
TARGET = os.environ.get("TARGET", "192.168.5.124:44879")


def sh(*args: str) -> str:
    return subprocess.run([HDC, "-t", TARGET, *args], capture_output=True, text=True, errors="replace").stdout


def dump() -> dict:
    """导出控件树。优先用 uitest；失败时抛异常而不是返回空树——静默返回空会被误当成「没有这个控件」。"""
    remote = "/data/local/tmp/_ui_layout.json"
    sh("shell", "uitest", "dumpLayout", "-p", remote)
    local = os.path.join(tempfile.gettempdir(), "_ui_layout.json")
    if os.path.exists(local):
        os.remove(local)
    sh("file", "recv", remote, local)
    if not os.path.exists(local):
        raise RuntimeError("dumpLayout 没取回文件（设备没连上？）")
    with open(local, encoding="utf-8") as f:
        return json.load(f)


def walk(node: dict):
    yield node
    for c in node.get("children") or []:
        yield from walk(c)


def center(bounds: str):
    m = re.match(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", bounds or "")
    if not m:
        return None
    x1, y1, x2, y2 = (int(v) for v in m.groups())
    return (x1 + x2) // 2, (y1 + y2) // 2


def find(text: str):
    """找**文字完全等于** text 的控件，返回 (中心坐标, 节点)。找不到返回 (None, None)。"""
    for n in walk(dump()):
        a = n.get("attributes") or {}
        if a.get("text") == text:
            c = center(a.get("bounds", ""))
            if c:
                return c, n
    return None, None


def find_clickable(text: str):
    """
    找 **可点击** 且文字匹配的节点，返回 (中心坐标, 节点)。

    ## 为什么要区分「可点」与「不可点」

    实测踩过：`显示和亮度` 页里「浅色」出现两次——
    一次是可点的卡片 `Column`（clickable=true，y=1110），
    一次是卡片里的**文字标签** `Text`（clickable=false，y=1512）。
    按文字找到的第一个是那个文字标签，**点上去什么都不会发生，而且不报错**，
    看起来就像「系统不响应」。
    """
    fallback = (None, None)
    for n in walk(dump()):
        a = n.get("attributes") or {}
        if a.get("text") == text:
            c = center(a.get("bounds", ""))
            if not c:
                continue
            if a.get("clickable") == "true":
                return c, n
            if fallback[0] is None:
                fallback = (c, n)
    return fallback


def cmd_dump():
    for n in walk(dump()):
        a = n.get("attributes") or {}
        t = a.get("text") or ""
        c = center(a.get("bounds", ""))
        if t and c:
            print("%-28s (%4d,%4d)  %s" % (t[:28], c[0], c[1], a.get("type", "")))


def cmd_find(text: str):
    c, _ = find(text)
    if c is None:
        print("NOT FOUND: " + text)
        sys.exit(2)
    print("%d %d" % c)


def cmd_tap(text: str):
    c, _ = find_clickable(text)
    if c is None:
        print("NOT FOUND: " + text)
        sys.exit(2)
    sh("shell", "uinput", "-T", "-c", str(c[0]), str(c[1]))
    print("TAPPED %s at (%d,%d)" % (text, c[0], c[1]))


def type_text(text: str):
    """
    往当前焦点输入文本。**文本作为独立 argv 传给 hdc**。

    ## 为什么不能把引号写进同一个 argv

    第 48 轮查明：写成 `ui.sh("shell", "uinput", "-K", "-t 'json'")` 时，
    设备会把引号**当成要输入的字符**，还会"智能"替换成弯引号——
    回读变成 `‘json'’`，于是"回读不一致"一路报下去，而错误信息完全指错方向。

    `sh(*args)` 本来就是**按 argv 分开**执行的（`subprocess.run([HDC, "-t", TARGET, *args])`），
    所以文本直接作为**独立参数**给即可，**不要自己加引号**。
    `#` 和空格也不会被设备 shell 误解（它们不是 shell 语法的一部分）。
    """
    sh("shell", "uinput", "-K", "-t", text)
    time.sleep(0.8)


def cmd_input(text: str):
    """
    输入文字。**走 type_text()——文本作为独立 argv，不要自己加引号。**

    ## 这里曾经写错，值得留档

    旧实现是 `sh("shell", "uinput -K -t '" + text + "'")`，注释写着
    「必须在设备侧 shell 里加单引号，不然 `#` 会被当成注释」。

    **但 `sh(*args)` 本来就是 `subprocess.run([HDC, "-t", TARGET, *args])`——
    每个 arg 是独立的 argv，设备 shell 不会把内容当语法解析。**
    那句注释描述的是一个**不存在的问题**，而它引入的引号带来了**真实的问题**：
    第 48 轮查明，设备会把引号**当字符输入**并替换成弯引号，
    回读变成 `‘json'’`——"回读不一致"一路报下去，错误信息完全指错方向。

    > 教训：**注释里的因果链，如果前提是错的，会长期误导**（同 §3.4 里那条
    > 「草稿是坏值」的误判）。改动调用约定时，把旧注释一起审一遍。
    """
    type_text(text)
    print("INPUT " + text)


def cmd_key(name: str):
    keys = {"back": 2, "home": 1, "power": 18}
    sh("shell", "uinput", "-K", "-d", str(keys[name]), "-u", str(keys[name]))
    print("KEY " + name)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    op = sys.argv[1]
    arg = sys.argv[2] if len(sys.argv) > 2 else ""
    if op == "dump":
        cmd_dump()
    elif op == "find":
        cmd_find(arg)
    elif op == "tap":
        cmd_tap(arg)
    elif op == "input":
        cmd_input(arg)
    elif op == "key":
        cmd_key(arg)
    else:
        print("未知命令: " + op)
        sys.exit(1)
