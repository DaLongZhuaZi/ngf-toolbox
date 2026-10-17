#!/usr/bin/env python3
"""
工具页冒烟流程：打开工具 → 输入 → 点主按钮 → 打印页面全部文字。

## 为什么固定成脚本

手工跑一件工具要经过「找页签 → 找卡片 → 找输入框 → 输入 → **重新 dump** →
按新坐标找按钮 → 读结果」七步，每步都可能点空，而**点空不报错**。
固定成脚本之后，每件工具只需给三个参数，口径也一致。

## 用法

    python tools/device/flow.py --tab 编解码与计算 --tool 摘要计算 \
        --input abc --action 计算摘要

    # 不输入、只点按钮（如 UUID 生成）
    python tools/device/flow.py --tab 编解码与计算 --tool "UUID 与随机密码" --action 生成

    # 两个输入框
    python tools/device/flow.py --tab 文本与数据 --tool "文本 Diff" \
        --input "a\nb" --input2 "a\nc" --action 对比

## 关键点（都踩过）

- **输入后必须重新 dump**：键盘一弹，按钮位置就变了（实测 y=1261 → 1192）。
- **别用返回键收键盘**：键盘没开着时 BACK 是「返回上一页」，会把工具页弹掉。
- **输入命令要加引号**：`#` 在设备端 shell 是注释符，不加引号文字静默不输入。
"""
import argparse, io, sys, time

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
sys.path.insert(0, __import__("os").path.dirname(__file__))
import ui

SKIP = ("清空", "复制", "示例", "粘贴", "重置", "恢复", "选择", "取消", "返回")

# ⚠️ 下面这类「盲点」坐标（收键盘、滑动）一律避开屏幕下半部。
#
# 实测踩过：一次运行结束后，输入框里莫名多了一个 `%`，而我从没输入过 `%`。
# 查下来是 **盲点落在了软键盘上**——数字行 `~ @ # $ % & * ( )` 里就有 `%`，
# 而那一次键盘还开着（收键盘那一步没生效）。
#
# 后果不只是「多打了一个字符」：这个坏值被**存成草稿**，
# 下一次打开工具会被恢复，于是工具报错，看起来像「工具不认合法输入」。
# **一次误敲，污染了后面所有轮次的判断。**
#
# 规则：只有确认键盘已收起（标题栏可见）才做坐标点击；滑动起点也别用屏幕下部。
#
# ## ⚠️ 更狠的一条：`uinput -T -m` **不能用来滚动**
#
# 逐步回读实测（子网计算页，输入框已聚焦）：
#   3 输入后:      '192.168.1.10/24'   ✓
#   4 收键盘后:    '192.168.1.10/24'   ✓（键盘其实没开）
#   5a 点标题栏后: '192.168.1.10/24'   ✓
#   5b 滑动后:     '192.168.1.10/24%'  ← **滑动敲进了一个字符**
#   6  再滑一次:   '192.168.1.10/24%0' ← 又敲进一个
#
# 点标题栏移开焦点也拦不住。这不是「盲点落在键盘上」，而是
# **系统把对已聚焦输入框的手势当成了滑行输入**，识别出一个字符。
#
# 所以：**页面里有聚焦的输入框时，不要滑动**。要么只读首屏，
# 要么先想办法真正失焦。`--scroll` 默认关闭就是这个原因。
TITLE_TAP = ("612", "218")   # 框架标题栏文字区，非交互，用来收键盘
SAFE_SWIPE = ("612", "1500", "612", "600")


def tap_text(t, wait=1.2):
    c, _ = ui.find(t)
    if c is None:
        return False
    ui.sh("shell", "uinput", "-T", "-c", str(c[0]), str(c[1]))
    time.sleep(wait)
    return True


def text_inputs():
    out = []
    for n in ui.walk(ui.dump()):
        a = n.get("attributes") or {}
        if a.get("type") in ("TextInput", "TextArea"):
            c = ui.center(a.get("bounds", ""))
            if c:
                out.append(c)
    out.sort(key=lambda c: (c[1], c[0]))
    return out


def buttons():
    out = []
    for n in ui.walk(ui.dump()):
        a = n.get("attributes") or {}
        if a.get("type") == "Button":
            t = (a.get("text") or "").strip()
            c = ui.center(a.get("bounds", ""))
            if c and t:
                out.append((c, t))
    out.sort(key=lambda p: (p[0][1], p[0][0]))
    return out


def keyboard_is_up():
    """
    判断软键盘是否弹起。

    判据：控件树里出现了键盘的按键文字（`Q`/`W`/`E` 这类单个大写字母）。
    比「点一下空白看会不会掉」可靠——**盲点可能落在键盘上敲出字符**（实测踩过）。
    """
    letters = {"Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "A", "S", "D"}
    for n in ui.walk(ui.dump()):
        a = n.get("attributes") or {}
        if (a.get("text") or "").strip() in letters:
            return True
    return False


def dismiss_keyboard():
    """
    收起软键盘。

    ⚠️ **不能用「点标题栏」**：实测那样键盘不收（点完再滑动，滑动会落在键盘上，
    数字行的 `%` 被敲进输入框，还被存成草稿，污染后面每一轮）。
    键盘**开着**时按 BACK 才是安全且确定的收法——
    键盘没开时 BACK 是「返回上一页」，会把工具页弹掉，所以必须先判断。
    """
    for i in range(4):
        if not keyboard_is_up():
            return True
        if i % 2 == 0:
            # 先点键盘自带的「收起」箭头（∨，在键盘工具条最右）。
            # 这比按 BACK 安全：BACK 在键盘没开时是「返回上一页」，会把工具页弹掉。
            ui.sh("shell", "uinput", "-T", "-c", "1103", "1790")
        else:
            ui.sh("shell", "uinput", "-K", "-d", "2", "-u", "2")
        time.sleep(1.3)
    return not keyboard_is_up()


def field_text():
    """读当前输入框的内容（第一个 TextInput）。"""
    for n in ui.walk(ui.dump()):
        a = n.get("attributes") or {}
        if a.get("type") in ("TextInput", "TextArea"):
            return a.get("text") or ""
    return None


def dump_text(ymin=0):
    items = []
    for n in ui.walk(ui.dump()):
        a = n.get("attributes") or {}
        t = (a.get("text") or "").strip()
        c = ui.center(a.get("bounds", ""))
        if t and c and c[1] >= ymin:
            items.append((c[1], c[0], t))
    items.sort()
    return items


def report_scrolled(args):
    """
    往下滚 n 屏，把**首屏之外**的内容也打出来。

    为什么需要：`dumpLayout` 只给**可见区域**。子网计算的结果里，
    网络地址/掩码/可用范围都在首屏以下，不滚就一条都看不到——
    实测第一次跑只读到「最常见的局域网规格：254 个可用地址」就没了，
    看起来像「结果不全」，其实是没滚。
    """
    if args.scroll <= 0:
        return
    # ⚠️ 滑动前必须先**真正失焦**：输入框聚焦时滑动手势会被系统当成滑行输入，
    # 把识别出的字符敲进输入框（实测 '192.168.1.10/24' → '192.168.1.10/24%'）。
    # 点标题栏**不管用**（实测点完照样敲进去）。
    # 点一个不改变取值的按钮（如「复制秒」）**也不管用**——实测照样敲进去一个字符
    # （'1700000000' → '1700000000%'）。所以 `--scroll` 实际不可用。
    if args.blur_tap:
        for c, bt in buttons():
            if args.blur_tap in bt:
                ui.sh("shell", "uinput", "-T", "-c", str(c[0]), str(c[1]))
                time.sleep(1.0)
                print("   （点了「%s」以移开焦点）" % bt)
                break
    seen = set()
    for i in range(args.scroll):
        ui.sh("shell", "uinput", "-T", "-m", "612", "2100", "612", "800")
        time.sleep(1.2)
        # ⚠️ 滚动后内容**上移**，y 会变小 —— 这里不能再套 --ymin 过滤，
        # 否则一屏都打不出来（实测踩过：--ymin 2400 时滚动屏全空）。
        print("   --- 第 %d 屏 ---" % (i + 2))
        for y, x, tt in dump_text(0):
            k = (x, tt)
            if k in seen:
                continue
            seen.add(k)
            print("   (%4d,%4d) %s" % (x, y, tt[:64]))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tab", required=True)
    ap.add_argument("--tool", required=True)
    ap.add_argument("--input", default=None)
    ap.add_argument("--input2", default=None)
    ap.add_argument("--action", default=None,
                    help="主按钮文字。**建议显式给**：不给就挑第一个非辅助按钮，"
                         "实测在「时间戳」页挑中了『用当前时间填入』，把输入的值覆盖了。"
                         "传空串表示**不点任何按钮**（输入即算的工具）")
    ap.add_argument("--ymin", type=int, default=0)
    ap.add_argument("--blur-tap", dest="blur_tap", default=None,
                    help="滚动前点这个按钮以移开焦点（如「复制秒」）。不点的话滑动会污染输入框")
    ap.add_argument("--scroll", type=int, default=0,
                    help="往下滚几屏（⚠️ 默认 0：输入框聚焦时滑动会被当成滑行输入，"
                         "把识别出的字符敲进输入框。见文件头说明）")
    ap.add_argument("--dismiss", dest="dismiss", action="store_true", default=True,
                    help="输入后点标题栏收键盘（默认开）")
    ap.add_argument("--clear", dest="clear", action="store_true", default=True,
                    help="输入前先点『清空』（默认开）")
    args = ap.parse_args()

    ui.sh("shell", "aa", "force-stop", "com.dlzz.ngftoolbox")
    ui.sh("shell", "aa", "start", "-a", "EntryAbility", "-b", "com.dlzz.ngftoolbox")
    time.sleep(6)
    if not tap_text(args.tab):
        print("FAIL: 页签没找到 " + args.tab); sys.exit(2)
    if not tap_text(args.tool, 2.0):
        print("FAIL: 工具没找到 " + args.tool); sys.exit(2)

    values = [v for v in (args.input, args.input2) if v is not None]
    if values:
        # ⚠️ 先清空。工具会恢复上次的草稿，不清空的话这次输入是**追加**在旧值后面——
        # 实测：上次输了 255，这次再输 255 得到 "255255"，十六进制 0x3e517。
        # 那个结果**是对的**（255255 的十六进制确实是 0x3e517），
        # 但会让人误以为工具算错。测试脚本必须先把自己造成的状态清干净。
        ui.sh("shell", "uinput", "-T", "-c", "1", "1"); time.sleep(0.3)
        if args.clear is not False:
            for c, bt in buttons():
                if bt == "清空":
                    ui.sh("shell", "uinput", "-T", "-c", str(c[0]), str(c[1])); time.sleep(0.8)
                    break
        boxes = text_inputs()
        if not boxes:
            print("FAIL: 页面没有输入框"); sys.exit(2)
        for i, v in enumerate(values):
            if i >= len(boxes):
                break
            c = boxes[i]
            ui.sh("shell", "uinput", "-T", "-c", str(c[0]), str(c[1])); time.sleep(1)
            ui.sh("shell", "uinput -K -t '" + v.replace("'", "'\\''") + "'"); time.sleep(1.2)
            # ⚠️ **必须回读确认**。不确认的话，「盲点落在键盘上多敲了一个字符」
            # 这种事会一路带到结果里，而人会先怀疑工具算错（实测踩过：多了个 %，
            # 工具报「前缀长度必须是 0~32 的整数」，看起来像工具不认合法输入）。
            got = field_text()
            if got != v:
                print("   ⚠️ 输入回读不一致：期望 %r，实际 %r —— 重试一次" % (v, got))
                got2 = field_text()
                if got2 is not None and got != v:
                    # 重试：清空再打一遍
                    for c, bt in buttons():
                        if bt == "清空":
                            ui.sh("shell", "uinput", "-T", "-c", str(c[0]), str(c[1])); time.sleep(0.8)
                            break
                    ui.sh("shell", "uinput", "-T", "-c", str(c[0]), str(c[1])); time.sleep(1)
                    ui.sh("shell", "uinput -K -t '" + v.replace("'", "'\\''") + "'"); time.sleep(1.2)
                    got = field_text()
                    print("   → 重试后：%r" % got)

    # 键盘弹起后重新 dump —— 按钮坐标已经变了
    if values and args.dismiss:
        # 不收键盘，下半屏的结果根本读不到（实测只读到 y=1625）。
        if not dismiss_keyboard():
            print("   ⚠️ 键盘没收起来，结果可能读不全")
    btns = buttons()
    pick = None
    if args.action == "":
        # 显式要求「不点按钮」：输入即算的工具用这个
        print("=== %s（输入即算，未点任何按钮）===" % args.tool)
        for y, x, tt in dump_text(args.ymin):
            print("   (%4d,%4d) %s" % (x, y, tt[:64]))
        report_scrolled(args)
        return
    if args.action:
        for c, t in btns:
            if args.action in t:
                pick = (c, t); break
    if pick is None:
        for c, t in btns:
            if t not in SKIP:
                pick = (c, t); break
    if pick is None:
        # 有些工具是「输入即算」，没有主按钮（实测：子网计算、颜色转换只有『清空』）。
        # 这不是缺陷，直接读结果即可。
        print("=== %s（输入即算，无主按钮）===" % args.tool)
        for y, x, tt in dump_text(args.ymin):
            print("   (%4d,%4d) %s" % (x, y, tt[:64]))
        report_scrolled(args)
        return

    ui.sh("shell", "uinput", "-T", "-c", str(pick[0][0]), str(pick[0][1])); time.sleep(2.5)
    print("=== %s（点了「%s」）===" % (args.tool, pick[1]))
    for y, x, t in dump_text(args.ymin):
        print("   (%4d,%4d) %s" % (x, y, t[:64]))
    report_scrolled(args)


if __name__ == "__main__":
    main()
