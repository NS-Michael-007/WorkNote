/**
 * 便签数据模型 —— 字段与 docs/三端共享契约（数据模型与备份格式）.md 完全一致。
 * 内存与 JSON 用驼峰，数据库列用下划线；这里只保留契约要求的字段。
 */

export enum NoteStatus {
  PENDING = 'PENDING',
  READY = 'READY',
  POSTPONED = 'POSTPONED',
  DONE = 'DONE',
  ARCHIVED = 'ARCHIVED',
  DELETED = 'DELETED'
}

export enum LoopType {
  NONE = 'NONE',
  DAILY = 'DAILY',
  WEEKLY = 'WEEKLY',
  MONTHLY = 'MONTHLY'
}

export enum ActionKind {
  DONE = 'DONE',
  DELAY = 'DELAY',
  CLOSE = 'CLOSE'
}

/** 强提醒卡片上的自定义按钮，最多 4 个，文字最多 12 字 */
export class NoteAction {
  id: string = '';
  label: string = '';
  kind: ActionKind = ActionKind.DONE;
  delayMinutes: number = 30;

  static create(label: string, kind: ActionKind, delayMinutes: number): NoteAction {
    const a = new NoteAction();
    a.id = `act_${Date.now()}_${Math.floor(Math.random() * 1000)}`;
    a.label = label;
    a.kind = kind;
    a.delayMinutes = delayMinutes;
    return a;
  }
}

export const MAX_ACTIONS: number = 4;
export const MAX_TITLE_LEN: number = 60;
export const MAX_REMARK_LEN: number = 500;
export const MAX_ACTION_LABEL_LEN: number = 12;
export const MIN_TIMESTAMP: number = 946684800000;   // 2000-01-01T00:00:00Z
export const MAX_TIMESTAMP: number = 4102444800000;  // 2100-01-01T00:00:00Z

/** 只有这三种状态会弹强提醒 */
export function shouldRemind(status: NoteStatus): boolean {
  return status === NoteStatus.PENDING || status === NoteStatus.READY || status === NoteStatus.POSTPONED;
}

export class Note {
  id: string = '';
  title: string = '';
  remark: string = '';
  /** 本地日历日 yyyy-MM-dd */
  dateKey: string = '';
  /** 绝对毫秒时间戳；0 表示不设定时提醒 */
  remindAt: number = 0;
  loopType: LoopType = LoopType.NONE;
  repeatEnabled: boolean = false;
  repeatMinutes: number = 15;
  status: NoteStatus = NoteStatus.PENDING;
  actions: NoteAction[] = [];
  createdAt: number = 0;
  updatedAt: number = 0;
  remindCount: number = 0;

  clone(): Note {
    const n = new Note();
    n.id = this.id;
    n.title = this.title;
    n.remark = this.remark;
    n.dateKey = this.dateKey;
    n.remindAt = this.remindAt;
    n.loopType = this.loopType;
    n.repeatEnabled = this.repeatEnabled;
    n.repeatMinutes = this.repeatMinutes;
    n.status = this.status;
    const acts: NoteAction[] = [];
    for (let i = 0; i < this.actions.length; i++) {
      const src = this.actions[i];
      const a = new NoteAction();
      a.id = src.id;
      a.label = src.label;
      a.kind = src.kind;
      a.delayMinutes = src.delayMinutes;
      acts.push(a);
    }
    n.actions = acts;
    n.createdAt = this.createdAt;
    n.updatedAt = this.updatedAt;
    n.remindCount = this.remindCount;
    return n;
  }
}
