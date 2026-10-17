"""
真机验证原语（**带守卫版**）。

## 为什么有它

第 44 轮的失败：脚本里 `tap("文本与数据"); tap("时间戳")` 两步**没把工具打开**，
而后面的动作**没有任何检查**，于是一路做在首页上——
`1700000000` 被打进了首页搜索框，输出看起来像"工具没反应"。

**同一类错误第 36 轮已经写进规范了**（`field() == None` 就说明不在这一页），
但**只写进规范不够——得写进代码**。这个模块就是那些守卫。

## 用法

```python
import toolkit as tk
tk.open_tool("时间戳")                       # 打不开会抛异常，不会默默继续
tk.clear_input()                            # 优先用工具的「清空」按钮
tk.type_in_input("1700000000")              # 回读校验
tk.back_if_keyboard()                       # 只收键盘，不弹页
tk.scroll_to("格式化")                       # 滚到控件出现
for y, x, t in tk.read_all(): ...           # 读结果
```
"""
import sys
import time

sys.path.insert(0, "tools/device")
import ui

# ── 基础 ──────────────────────────────────────────────────────────────

def _raw_nodes(retries=3):
    """
    取控件树，**带重试**。

    hdc 偶发 `dumpLayout 没取到文件（设备没连上？）`——瞬时抖动。
    不重试的话一次抖动会把整轮验证打断，而那看起来像"工具坏了"。
    """
    last = None
    for i in range(retries):
        try:
            return ui.walk(ui.dump())
        except RuntimeError as e:
            last = e
            time.sleep(1.5 + i)
    raise AssertionError("控件树取不到（重试 " + str(retries) + " 次仍失败）：" + str(last))


def _texts():
    return [(ui.center((n.get("attributes") or {}).get("bounds", "")),
             ((n.get("attributes") or {}).get("text") or "").strip())
            for n in _raw_nodes()]


def page_title():
    """页面标题：取 y 最小的那个够大够靠上的文本（工具页标题在 y≈216）。"""
    cands = [(c[1], t) for c, t in _texts() if c and 150 < c[1] < 300 and t]
    return min(cands)[1] if cands else None


def assert_tool(name):
    """守卫：当前必须在名为 name 的工具页上，否则抛异常（不静默继续）。"""
    t = page_title()
    if t != name:
        raise AssertionError("不在「" + name + "」页上，实际标题=" + repr(t))
    return True


def field_text_nth(n=0):
    """读第 n 个输入框的文字。

    ⚠️ `field_text()` 只读**第一个**——有两个输入框的工具（文本 Diff / 正则测试）
    校验第 2 个框时会读到第 1 个的内容，**报「回读不一致」而其实是校验错了框**
    （第 58 轮踩过）。
    """
    ins = []
    for node in _raw_nodes():
        a = node.get("attributes") or {}
        if a.get("type") in ("TextInput", "TextArea"):
            ins.append(a.get("text"))
    return ins[n] if n < len(ins) else None


def field_text():
    for n in _raw_nodes():
        a = n.get("attributes") or {}
        if a.get("type") in ("TextInput", "TextArea"):
            return a.get("text")
    return None


def keyboard_is_up():
    """键盘是否弹着：找底部（y>2200）的单字符键。"""
    for c, t in _texts():
        if c and c[1] > 2200 and t in ("Q", "W", "E", "R", "T", "Y", "1", "2", "3"):
            return True
    return False


# ── 动作（每个都带守卫） ────────────────────────────────────────────────

def scroll_down(n=1, pause=1.0):
    for _ in range(n):
        ui.sh("shell", "uinput", "-T", "-m", "612", "2100", "612", "800")
        time.sleep(pause)


def scroll_up(n=1, pause=0.8):
    for _ in range(n):
        ui.sh("shell", "uinput", "-T", "-m", "612", "800", "612", "2100")
        time.sleep(pause)


def back_if_keyboard(tool_name=None):
    """
    收键盘，为滑动做准备。**不依赖 `keyboard_is_up()`。**

    ## 为什么弃用 keyboard_is_up()

    它按 `Q/W/E/1/2/3` 找键，而**工具页的键盘不是那种布局**——实测在成功输入时
    也返回 `False`（§3.4.8.6）。于是它：
    - 第 48 轮当"焦点守卫"→ 假阴性，把成功报成失败
    - 第 52 轮据它诊断 → 得出错误结论
    - 第 53 轮据此跳过 BACK → 键盘弹着截走滑动，把输入污染成 `a.+%%%`

    ## 现在的做法：直接按，然后检查

    - 键盘**开着**时按 BACK → 只收键盘，**页面还在** ✓
    - 键盘**没开**时按 BACK → 弹掉页面 ✗ → **重新进入即可**
      （代价很小：草稿会恢复输入，不用重打）

    返回做了什么（`"收键盘"` / `"被弹掉，已重进"`）。
    调用方**必须传 tool_name**，否则弹掉了没法判断。
    """
    ui.sh("shell", "uinput", "-K", "-d", "2", "-u", "2")
    time.sleep(2.4)
    if tool_name is None:
        return "已按 BACK"
    if page_title() == tool_name:
        return "收键盘"
    open_tool(tool_name)
    return "被弹掉，已重进"


def tap_by_text(text, wait=2.5):
    """
    按**文字**找节点并点它的坐标——**不要求该节点自己 clickable**。

    首页的工具卡是 `Column`（**可点但无文字**），文字在**子节点**里：
    ```
    ( 196,1353) Column          clickable=true, text=''
       └─ Text "正则测试"        clickable=false, text='正则测试'
    ```
    所以 `ui.find_clickable("正则测试")` **永远返回 None**。
    **坐标落在卡片范围内，父 `Column` 就会响应**，点文字节点的中心即可。
    （同 §3.4.1「浅色」那个坑。）
    """
    for c, t in _texts():
        if t == text and c:
            tap_xy(c[0], c[1], wait)
            return True
    return False


def tap_text(text, wait=2.0):
    c, _ = ui.find_clickable(text)
    if c is None:
        return False
    ui.sh("shell", "uinput", "-T", "-c", str(c[0]), str(c[1]))
    time.sleep(wait)
    return True


def tap_xy(x, y, wait=2.0):
    ui.sh("shell", "uinput", "-T", "-c", str(x), str(y))
    time.sleep(wait)


def scroll_to(text, max_down=8):
    """向下滚动直到控件出现；找不到返回 None（调用方自己决定怎么办）。"""
    for _ in range(max_down):
        c, _ = ui.find_clickable(text)
        if c:
            return c
        scroll_down(1)
    return None


def _tap_tab(tab):
    """点底部分类页签。**按坐标点**——文字节点本身 clickable=false，按文字找不到。"""
    for c, x in _texts():
        if x == tab and c and c[1] > 2500:
            tap_xy(c[0], c[1], 2.0)
            return True
    return False


CATEGORY_TABS = ["收藏", "文本与数据", "编解码与计算", "网络", "文件与生成"]


def find_text_scroll(text, max_down=6):
    """滚着找**文字节点**（`tap_by_text` 的前提）。找到返回坐标，否则 None。"""
    for _ in range(max_down):
        for c, t in _texts():
            if t == text and c:
                return c
        scroll_down(1)
    return None


def open_tool(tool_name, tab=None, retries=1, max_seconds=75):
    """
    打开工具页并**确认真的打开了**；打不开抛异常。

    ## 为什么是「依次试各分类页签」，而不是搜索框

    搜索框那条路**必须打中文**，而 `uinput -K -t` **打不进非 ASCII**（§3.4.8.11）——
    所以它对中文工具名**永远不可能成功**。第 46–52 轮七轮打不开，一半原因在此。

    现在这条路**完全不打字**：

    ```
    对每个分类页签：
        点页签（按坐标，文字节点本身不可点）
        滚着找工具名的**文字节点**
        找到 → 点它的坐标（父 Column 会响应，见 §3.4.8.8）→ 核对标题
    ```

    `tab` 若给了就**只试那一个**（快）；没给就依次试全部（稳）。
    """
    tabs = [tab] if tab else CATEGORY_TABS
    tried = []
    # 总时限：一个入口函数吃掉几分钟就等于每轮少做几件事（第 66 轮教训）
    deadline = time.time() + max_seconds
    for attempt in range(retries + 1):
        ui.sh("shell", "aa", "force-stop", "com.dlzz.ngftoolbox")
        ui.sh("shell", "aa", "start", "-a", "EntryAbility", "-b", "com.dlzz.ngftoolbox")
        time.sleep(6)
        for tb in tabs:
            if not tap_by_text(tb, 2.2):
                tried.append(tb + ":没找到页签")
                continue
            scroll_up(3)                      # 网格可能停在上次的位置（3 次够归位）
            c = find_text_scroll(tool_name, max_down=4)
            if c is None:
                tried.append(tb + ":没这张卡")
                continue
            tap_xy(c[0], c[1], 2.2)
            title = page_title()
            if title == tool_name or (title and tool_name.startswith(title)):
                return tool_name, tb
            tried.append(tb + ":标题=" + repr(title))
            if time.time() > deadline:
                break
        if time.time() > deadline:
            tried.append("超时")
            break
    raise AssertionError("打不开工具：" + tool_name + "｜" + " / ".join(tried))


def clear_input():
    """
    清空输入框。**优先用工具自己的「清空」按钮**（滚动能找到）——
    实测连发退格丢键率高（61 次只落 19 次，见手册 §3.4.4.1）。
    """
    c = scroll_to("清空", max_down=6)
    if c:
        tap_xy(c[0], c[1], 2.0)
    if field_text() == "":
        return "清空按钮"
    # 兜底：退格（需要焦点）
    _focus_input()
    v = field_text() or ""
    for _ in range(len(v) + 4):
        ui.sh("shell", "uinput", "-K", "-d", "2055", "-u", "2055")
        time.sleep(0.32)
    time.sleep(1.2)
    return "退格" if field_text() == "" else "未清空"


def _focus_input():
    for n in _raw_nodes():
        a = n.get("attributes") or {}
        if a.get("type") in ("TextInput", "TextArea"):
            c = ui.center(a.get("bounds", ""))
            ui.sh("shell", "uinput", "-T", "-c", str(c[0]), str(c[1]))
            time.sleep(1.3)
            return True
    return False


def focus_input_nth(n=0):
    """点第 n 个（0 起）输入框拿焦点。返回是否成功。

    有些工具有两个输入框（如正则测试：正则 + 测试文本），
    `_focus_input()` 只会点第一个——**必须能指定第几个**。
    """
    ins = []
    for node in _raw_nodes():
        a = node.get("attributes") or {}
        if a.get("type") in ("TextInput", "TextArea"):
            c = ui.center(a.get("bounds", ""))
            if c:
                ins.append(c)
    if n >= len(ins):
        return False
    ui.sh("shell", "uinput", "-T", "-c", str(ins[n][0]), str(ins[n][1]))
    time.sleep(1.3)
    return True


def clear_input_nth(n=0):
    """
    清空第 n 个输入框。**`clear_input()` 只清第一个**——
    多输入框工具（文本 Diff / 正则测试）里，第二个框的残留会让输入变成
    `'abcXefabcXef'`（第 58 轮踩过，看起来像"打了两遍"）。
    """
    if not focus_input_nth(n):
        return "找不到第 " + str(n) + " 个输入框"
    v = field_text_nth(n) or ""
    if v == "":
        return "本来就是空的"
    for _ in range(len(v) + 4):
        ui.sh("shell", "uinput", "-K", "-d", "2055", "-u", "2055")
        time.sleep(0.32)
    time.sleep(1.2)
    return "退格" if field_text_nth(n) == "" else "未清空：" + repr(field_text_nth(n))


def type_in_input_nth(text, n=0, verify=True):
    """往第 n 个输入框输入。**必须先滚动到它可见**（dump 只报屏上的节点）。"""
    if not focus_input_nth(n):
        raise AssertionError("找不到第 " + str(n) + " 个输入框")
    ui.type_text(text)
    time.sleep(1.5)
    got = field_text_nth(n)
    if verify and got != text:
        raise AssertionError("第" + str(n) + "框回读不一致：期望 " + repr(text) + " 实际 " + repr(got))
    return got


def type_in_input(text, verify=True):
    """点输入框 → 输入 → **回读校验**（不校验就等于不知道打进去没有）。"""
    if not _focus_input():
        raise AssertionError("页面上找不到输入框")
    ui.type_text(text)
    time.sleep(2.0)
    got = field_text()
    if verify and got != text:
        raise AssertionError("回读不一致：期望 " + repr(text) + " 实际 " + repr(got))
    return got


def type_json_braced(inner):
    """
    打一个以 { 开头、以 } 结尾的 JSON。
    §3.4 的花括号法：打 "{" 输入法自动补 "}" 且光标落在中间 → 直接接着打内容。
    """
    _focus_input()
    ui.type_text("{")
    time.sleep(1.3)
    ui.type_text(inner)
    time.sleep(1.8)
    return field_text()


def read_all(ymin=150):
    out = [(c[1], c[0], t) for c, t in _texts() if c and c[1] > ymin and t]
    out.sort()
    return out
