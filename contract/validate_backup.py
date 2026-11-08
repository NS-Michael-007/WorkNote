#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""校验 .taskbak 备份文件是否符合「三端共享契约 v1」。

用标准库实现，不依赖 jsonschema，方便 Android / iOS / 鸿蒙三端的 CI 直接跑。
用法：
    python validate_backup.py <文件.taskbak>
    python validate_backup.py --all <目录>
退出码：0 = 通过；1 = 有错误。
"""
import json
import os
import re
import sys
import datetime

APP_IDS = {"工作便签提醒", "WorkNote"}
LOOPS = {"NONE", "DAILY", "WEEKLY", "MONTHLY"}
STATUSES = {"PENDING", "READY", "DONE", "POSTPONED", "ARCHIVED", "DELETED"}
ACTION_TYPES = {"DONE", "DELAY", "CLOSE"}
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")

# 时间戳合理性：2000-01-01 ~ 2100-01-01（毫秒）
MIN_TS = 946684800000
MAX_TS = 4102444800000


class Result:
    def __init__(self, path):
        self.path = path
        self.errors = []
        self.warnings = []

    def err(self, where, msg):
        self.errors.append("%s: %s" % (where, msg))

    def warn(self, where, msg):
        self.warnings.append("%s: %s" % (where, msg))

    @property
    def ok(self):
        return not self.errors


def _is_int(v):
    return isinstance(v, int) and not isinstance(v, bool)


def check_date_key(value, where, r):
    if not isinstance(value, str) or not DATE_RE.match(value):
        r.err(where, "dateKey 必须是 yyyy-MM-dd，实际为 %r" % (value,))
        return None
    try:
        return datetime.date(int(value[0:4]), int(value[5:7]), int(value[8:10]))
    except ValueError:
        r.err(where, "dateKey 不是真实存在的日期：%s" % value)
        return None


def check_note(note, idx, r):
    where = "notes[%d]" % idx
    if not isinstance(note, dict):
        r.err(where, "必须是一个对象")
        return None

    # 必填字段
    for key in ("title", "dateKey", "remindAt", "loopType", "status", "createdAt"):
        if key not in note:
            r.err(where, "缺少必填字段 %s" % key)

    title = note.get("title")
    if not isinstance(title, str) or not title.strip():
        r.err(where, "title 必须是非空字符串")
    elif len(title) > 60:
        r.err(where, "title 超过 60 字符（%d）" % len(title))

    remark = note.get("remark", "")
    if not isinstance(remark, str):
        r.err(where, "remark 必须是字符串")
    elif len(remark) > 500:
        r.err(where, "remark 超过 500 字符（%d）" % len(remark))

    check_date_key(note.get("dateKey"), where, r)

    remind_at = note.get("remindAt")
    if not _is_int(remind_at) or remind_at < 0:
        r.err(where, "remindAt 必须是非负整数（0 表示不设定时）")
    elif remind_at != 0 and not (MIN_TS <= remind_at <= MAX_TS):
        r.err(where, "remindAt 超出合理范围：%d" % remind_at)

    if note.get("loopType") not in LOOPS:
        r.err(where, "loopType 必须是 %s 之一，实际 %r" % ("/".join(sorted(LOOPS)), note.get("loopType")))

    if note.get("status") not in STATUSES:
        r.err(where, "status 必须是 %s 之一，实际 %r" % ("/".join(sorted(STATUSES)), note.get("status")))

    if not _is_int(note.get("createdAt")) or note.get("createdAt") < 1:
        r.err(where, "createdAt 必须是正整数时间戳")
    elif not (MIN_TS <= note.get("createdAt") <= MAX_TS):
        r.err(where, "createdAt 超出合理范围：%r" % (note.get("createdAt"),))

    # 选填字段（缺省时的默认值与 Android 端一致）
    if "repeatEnabled" in note and not isinstance(note["repeatEnabled"], bool):
        r.err(where, "repeatEnabled 必须是布尔值")
    if "repeatMinutes" in note:
        rm = note["repeatMinutes"]
        if not _is_int(rm) or not (1 <= rm <= 1440):
            r.err(where, "repeatMinutes 必须是 1~1440 的整数，实际 %r" % (rm,))
    if "remindCount" in note:
        rc = note["remindCount"]
        if not _is_int(rc) or rc < 0:
            r.err(where, "remindCount 必须是非负整数")

    # 自定义按钮
    actions = note.get("actions", [])
    if not isinstance(actions, list):
        r.err(where, "actions 必须是数组")
        actions = []
    elif len(actions) > 4:
        r.err(where, "actions 最多 4 个，实际 %d" % len(actions))
    for j, act in enumerate(actions):
        aw = "%s.actions[%d]" % (where, j)
        if not isinstance(act, dict):
            r.err(aw, "必须是一个对象")
            continue
        text = act.get("text")
        if not isinstance(text, str) or not text.strip():
            r.err(aw, "text 必须是非空字符串")
        elif len(text) > 12:
            r.err(aw, "text 超过 12 字符（%d）" % len(text))
        if act.get("type") not in ACTION_TYPES:
            r.err(aw, "type 必须是 DONE/DELAY/CLOSE 之一，实际 %r" % (act.get("type"),))

    # 语义提醒（不算错误，但会让人困惑）
    if note.get("status") in ("DONE", "ARCHIVED") and remind_at:
        r.warn(where, "已处理/已归档的便签还带着 remindAt，导入后各端会清掉定时")
    return note


def validate(path):
    r = Result(path)
    try:
        with open(path, "r", encoding="utf-8-sig") as f:
            raw = f.read()
    except OSError as e:
        r.err("file", "读不到文件：%s" % e)
        return r, None

    try:
        doc = json.loads(raw)
    except json.JSONDecodeError as e:
        r.err("file", "不是合法 JSON：%s（行 %d 列 %d）" % (e.msg, e.lineno, e.colno))
        return r, None

    if not isinstance(doc, dict):
        r.err("root", "根节点必须是对象")
        return r, None

    app = doc.get("app")
    if app not in APP_IDS:
        r.err("root.app", "app 必须是「工作便签提醒」或 WorkNote，实际 %r" % (app,))

    if doc.get("version") != 1:
        r.err("root.version", "version 必须为 1（当前格式版本），实际 %r" % (doc.get("version"),))

    exported = doc.get("exportedAt")
    if not _is_int(exported) or exported < 1:
        r.err("root.exportedAt", "exportedAt 必须是正整数毫秒时间戳")
    elif not (MIN_TS <= exported <= MAX_TS):
        r.err("root.exportedAt", "exportedAt 超出合理范围：%r" % (exported,))

    notes = doc.get("notes")
    if not isinstance(notes, list):
        r.err("root.notes", "notes 必须是数组")
        return r, doc
    if not notes:
        r.err("root.notes", "备份里一条便签都没有，导入端会直接报错")

    seen = {}
    for i, n in enumerate(notes):
        check_note(n, i, r)
        if isinstance(n, dict):
            key = (n.get("title"), n.get("dateKey"), n.get("remindAt"))
            if key in seen:
                r.warn("notes[%d]" % i, "与 notes[%d] 完全重复（标题/日期/提醒时刻相同），像是一次导入没清库" % seen[key])
            else:
                seen[key] = i
    return r, doc


def preview_import(doc):
    """按契约的导入规则预演：各端导入后数据应该长这样。"""
    out = []
    for n in doc.get("notes", []):
        status = n.get("status", "PENDING")
        out.append({
            "title": n.get("title", "未命名便签"),
            "dateKey": n.get("dateKey"),
            "status_after_import": "DELETED" if status == "DELETED" else "PENDING",
            "remindAt": n.get("remindAt", 0),
            "loopType": n.get("loopType", "NONE"),
            "actions": len(n.get("actions") or []) or "用默认完成按钮",
            "remindCount_after_import": 0,
        })
    return out


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 1

    if argv[1] == "--all":
        target = argv[2] if len(argv) > 2 else "."
        files = [os.path.join(target, f) for f in os.listdir(target) if f.endswith(".taskbak")]
        files.sort()
        if not files:
            print("目录里没有 .taskbak 文件：%s" % target)
            return 1
    else:
        files = argv[1:]

    bad = 0
    for path in files:
        r, doc = validate(path)
        print("=" * 66)
        print("文件：%s" % path)
        if r.ok:
            n = len(doc.get("notes", []))
            print("结果：通过（%d 条便签）" % n)
            print("导入预演（三端应完全一致）：")
            for item in preview_import(doc):
                print("  - %s | %s | %s | remindAt=%d | %s | 按钮=%s"
                      % (item["title"], item["dateKey"], item["status_after_import"],
                         item["remindAt"], item["loopType"], item["actions"]))
        else:
            bad += 1
            print("结果：不通过（%d 个错误）" % len(r.errors))
        for e in r.errors:
            print("  [错误] %s" % e)
        for w in r.warnings:
            print("  [提醒] %s" % w)

    print("=" * 66)
    print("共 %d 个文件，通过 %d，不通过 %d" % (len(files), len(files) - bad, bad))
    return 0 if bad == 0 else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
