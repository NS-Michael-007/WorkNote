/**
 * .taskbak v1 读写 —— 与 docs/三端共享契约（数据模型与备份格式）.md 逐条对齐。
 * 导入规则：整体替换；非 DELETED 一律回落 PENDING；remindCount 归零；id / updatedAt 本端重生；
 *          未知字段忽略；deliverable 为空 notes 报错。DELETED 条目原样保留。
 */
import { ActionKind, LoopType, Note, NoteAction, NoteStatus, MAX_ACTIONS, MAX_ACTION_LABEL_LEN,
  MAX_REMARK_LEN, MAX_TITLE_LEN, MAX_TIMESTAMP, MIN_TIMESTAMP } from './Note';
import { isValidDateKey } from './TimeKey';

export const BACKUP_VERSION: number = 1;
export const BACKUP_APP: string = '工作便签提醒';

interface BackupAction {
  id?: string;
  label?: string;
  kind?: string;
  delayMinutes?: number;
}

interface BackupNote {
  id?: string;
  title?: string;
  remark?: string;
  dateKey?: string;
  remindAt?: number;
  loopType?: string;
  repeatEnabled?: boolean;
  repeatMinutes?: number;
  status?: string;
  actions?: BackupAction[];
  createdAt?: number;
  updatedAt?: number;
  remindCount?: number;
}

interface BackupRoot {
  app?: string;
  version?: number;
  exportedAt?: number;
  notes?: BackupNote[];
}

export class BackupReport {
  valid: boolean = true;
  errors: string[] = [];
  notes: Note[] = [];

  addError(msg: string): void {
    this.valid = false;
    this.errors.push(msg);
  }
}

function toNumber(v: number | undefined, def: number): number {
  return typeof v === 'number' && isFinite(v) ? v : def;
}

function toStatus(v: string | undefined): NoteStatus | null {
  const all: string[] = ['PENDING', 'READY', 'POSTPONED', 'DONE', 'ARCHIVED', 'DELETED'];
  if (v === undefined || all.indexOf(v) < 0) {
    return null;
  }
  return v as NoteStatus;
}

function toLoop(v: string | undefined): LoopType {
  const all: string[] = ['NONE', 'DAILY', 'WEEKLY', 'MONTHLY'];
  if (v === undefined || all.indexOf(v) < 0) {
    return LoopType.NONE;
  }
  return v as LoopType;
}

function toKind(v: string | undefined): ActionKind {
  if (v === 'DELAY') {
    return ActionKind.DELAY;
  }
  if (v === 'CLOSE') {
    return ActionKind.CLOSE;
  }
  return ActionKind.DONE;
}

function newId(): string {
  return `n_${Date.now()}_${Math.floor(Math.random() * 100000)}`;
}

/** 读一份备份文本，返回校验报告（含导入预演结果） */
export function decodeBackup(text: string, now: number): BackupReport {
  const report = new BackupReport();
  let root: BackupRoot;
  try {
    root = JSON.parse(text) as BackupRoot;
  } catch (e) {
    report.addError('解析失败');
    return report;
  }
  if (root === null || typeof root !== 'object') {
    report.addError('根节点不是对象');
    return report;
  }
  if (root.version !== BACKUP_VERSION) {
    report.addError('版本号不是 1');
    return report;
  }
  const list = root.notes;
  if (list === undefined || !Array.isArray(list)) {
    report.addError('notes 不是数组');
    return report;
  }
  if (list.length === 0) {
    report.addError('备份里没有便签');
    return report;
  }

  for (let i = 0; i < list.length; i++) {
    const raw = list[i];
    const idx = `第 ${i + 1} 条`;
    const title = raw.title;
    if (title === undefined || title.length === 0) {
      report.addError(`${idx} 缺少 title`);
      continue;
    }
    if (title.length > MAX_TITLE_LEN) {
      report.addError(`${idx} title 超过 ${MAX_TITLE_LEN} 字`);
    }
    const remark = raw.remark === undefined ? '' : raw.remark;
    if (remark.length > MAX_REMARK_LEN) {
      report.addError(`${idx} remark 超过 ${MAX_REMARK_LEN} 字`);
    }
    const dateKey = raw.dateKey;
    if (dateKey === undefined || !isValidDateKey(dateKey)) {
      report.addError(`${idx} dateKey 不是真实日期`);
      continue;
    }
    const status = toStatus(raw.status);
    if (status === null) {
      report.addError(`${idx} status 不在枚举内`);
      continue;
    }
    const remindAt = toNumber(raw.remindAt, 0);
    if (remindAt !== 0 && (remindAt < MIN_TIMESTAMP || remindAt > MAX_TIMESTAMP)) {
      report.addError(`${idx} remindAt 超出 2000–2100`);
    }
    const actionsIn = raw.actions;
    const actions: NoteAction[] = [];
    if (actionsIn !== undefined && Array.isArray(actionsIn)) {
      if (actionsIn.length > MAX_ACTIONS) {
        report.addError(`${idx} 按钮超过 ${MAX_ACTIONS} 个`);
      }
      for (let k = 0; k < actionsIn.length && k < MAX_ACTIONS; k++) {
        const a = actionsIn[k];
        const label = a.label === undefined ? '' : a.label;
        if (label.length === 0 || label.length > MAX_ACTION_LABEL_LEN) {
          report.addError(`${idx} 第 ${k + 1} 个按钮文字长度不合法`);
        }
        const na = new NoteAction();
        na.id = `act_${now}_${i}_${k}`;
        na.label = label;
        na.kind = toKind(a.kind);
        na.delayMinutes = toNumber(a.delayMinutes, 30);
        actions.push(na);
      }
    }

    if (!report.valid) {
      continue;
    }

    const note = new Note();
    // id / updatedAt 本端重生
    note.id = newId();
    note.title = title;
    note.remark = remark;
    note.dateKey = dateKey;
    note.remindAt = remindAt;
    note.loopType = toLoop(raw.loopType);
    note.repeatEnabled = raw.repeatEnabled === true;
    note.repeatMinutes = toNumber(raw.repeatMinutes, 15);
    // 非 DELETED 一律回落 PENDING；DELETED 原样保留
    note.status = status === NoteStatus.DELETED ? NoteStatus.DELETED : NoteStatus.PENDING;
    note.actions = actions;
    note.createdAt = now;
    note.updatedAt = now;
    note.remindCount = 0;
    report.notes.push(note);
  }
  return report;
}

/** 生成一份备份文本 */
export function encodeBackup(notes: Note[], now: number): string {
  const out: Object[] = [];
  for (let i = 0; i < notes.length; i++) {
    const n = notes[i];
    const actions: Object[] = [];
    for (let k = 0; k < n.actions.length; k++) {
      const a = n.actions[k];
      const item: Record<string, Object> = {
        'id': a.id,
        'label': a.label,
        'kind': a.kind,
        'delayMinutes': a.delayMinutes
      };
      actions.push(item);
    }
    const item: Record<string, Object> = {
      'id': n.id,
      'title': n.title,
      'remark': n.remark,
      'dateKey': n.dateKey,
      'remindAt': n.remindAt,
      'loopType': n.loopType,
      'repeatEnabled': n.repeatEnabled,
      'repeatMinutes': n.repeatMinutes,
      'status': n.status,
      'actions': actions,
      'createdAt': n.createdAt,
      'updatedAt': n.updatedAt,
      'remindCount': n.remindCount
    };
    out.push(item);
  }
  const root: Record<string, Object> = {
    'app': BACKUP_APP,
    'version': BACKUP_VERSION,
    'exportedAt': now,
    'notes': out
  };
  return JSON.stringify(root);
}
