#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把 Android 端的 worknote.db 转成 .taskbak，用来做跨端联调。

为什么需要它：iOS / 鸿蒙没有真机时，验证「能不能读懂 Android 备份」最有效的方式，
就是拿真实库生成一份备份喂给各端解析器。这个脚本同时充当字段映射的唯一权威说明。

用法：
    python android_db_to_taskbak.py <worknote.db> <输出.taskbak> [--title-prefix 中文]
不依赖第三方库，只读 sqlite，不改原始库。
"""
import argparse
import datetime
import json
import sqlite3
import sys

# notes 表字段 -> 备份字段（BackupManager 的映射关系，改动任何一端都要两边同步）
FIELD_MAP = {
    "title": "title",
    "remark": "remark",
    "date_key": "dateKey",
    "remind_at": "remindAt",
    "loop_type": "loopType",
    "repeat_enabled": "repeatEnabled",
    "repeat_minutes": "repeatMinutes",
    "status": "status",
    "created_at": "createdAt",
    "remind_count": "remindCount",
}


def parse_actions(raw):
    """actions 列存的是 JSON 数组字符串，形如 [{"text":"已接待","type":"DONE"}]"""
    if not raw:
        return []
    try:
        data = json.loads(raw)
    except (ValueError, TypeError):
        return []
    if not isinstance(data, list):
        return []
    out = []
    for item in data:
        if isinstance(item, dict) and item.get("text"):
            out.append({"text": str(item["text"]), "type": str(item.get("type", "DONE"))})
    return out


def now_ms():
    return int(datetime.datetime.now().timestamp() * 1000)


def convert(db_path):
    conn = sqlite3.connect("file:%s?mode=ro" % db_path, uri=True)
    conn.row_factory = sqlite3.Row
    rows = conn.execute("SELECT * FROM notes ORDER BY _id").fetchall()
    notes = []
    for row in rows:
        note = {}
        for src, dst in FIELD_MAP.items():
            note[dst] = row[src]
        note["repeatEnabled"] = bool(note.get("repeatEnabled", 0))
        note["remindCount"] = int(note.get("remindCount") or 0)
        note["actions"] = parse_actions(row["actions"])
        notes.append(note)
    conn.close()
    return {
        "app": "工作便签提醒",
        "version": 1,
        "exportedAt": now_ms(),
        "notes": notes,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("db")
    ap.add_argument("out")
    args = ap.parse_args()
    doc = convert(args.db)
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(doc, f, ensure_ascii=False, indent=2)
    print("已生成 %s（%d 条便签）" % (args.out, len(doc["notes"])))
    for n in doc["notes"]:
        print("  - %s | %s | %s | actions=%d" % (n["title"], n["dateKey"], n["status"], len(n["actions"])))
    return 0


if __name__ == "__main__":
    sys.exit(main())
