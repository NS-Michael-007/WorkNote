/**
 * 便签存储：preferences 落盘，进程内单例。
 * 名称与 iOS/Android 一致（notes.json），方便三端对照调试。
 */
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { LoopType, Note, NoteStatus } from './Note';

const PREF_NAME: string = 'worknote_settings';
const KEY_NOTES: string = 'notes_json';

interface StoredNote {
  id?: string;
  title?: string;
  remark?: string;
  dateKey?: string;
  remindAt?: number;
  loopType?: string;
  repeatEnabled?: boolean;
  repeatMinutes?: number;
  status?: string;
  actions?: Object[];
  createdAt?: number;
  updatedAt?: number;
  remindCount?: number;
}

export class NoteStore {
  private static instance: NoteStore | null = null;
  private store: preferences.Preferences | null = null;
  notes: Note[] = [];

  static get(): NoteStore {
    if (NoteStore.instance === null) {
      NoteStore.instance = new NoteStore();
    }
    return NoteStore.instance;
  }

  async load(context: common.UIAbilityContext): Promise<void> {
    this.store = await preferences.getPreferences(context, PREF_NAME);
    const text = this.store.getSync(KEY_NOTES, '') as string;
    this.notes = [];
    if (text.length === 0) {
      return;
    }
    try {
      const arr = JSON.parse(text) as StoredNote[];
      for (let i = 0; i < arr.length; i++) {
        const raw = arr[i];
        const n = new Note();
        n.id = raw.id === undefined ? `n_${i}` : raw.id;
        n.title = raw.title === undefined ? '' : raw.title;
        n.remark = raw.remark === undefined ? '' : raw.remark;
        n.dateKey = raw.dateKey === undefined ? '' : raw.dateKey;
        n.remindAt = raw.remindAt === undefined ? 0 : raw.remindAt;
        n.loopType = (raw.loopType === undefined ? 'NONE' : raw.loopType) as LoopType;
        n.repeatEnabled = raw.repeatEnabled === true;
        n.repeatMinutes = raw.repeatMinutes === undefined ? 15 : raw.repeatMinutes;
        n.status = (raw.status === undefined ? 'PENDING' : raw.status) as NoteStatus;
        n.createdAt = raw.createdAt === undefined ? 0 : raw.createdAt;
        n.updatedAt = raw.updatedAt === undefined ? 0 : raw.updatedAt;
        n.remindCount = raw.remindCount === undefined ? 0 : raw.remindCount;
        this.notes.push(n);
      }
    } catch (e) {
      this.notes = [];
    }
  }

  async save(): Promise<void> {
    if (this.store === null) {
      return;
    }
    await this.store.put(KEY_NOTES, JSON.stringify(this.notes));
    await this.store.flush();
  }

  activeNotes(): Note[] {
    const out: Note[] = [];
    for (let i = 0; i < this.notes.length; i++) {
      const n = this.notes[i];
      if (n.status !== NoteStatus.DELETED && n.status !== NoteStatus.ARCHIVED) {
        out.push(n);
      }
    }
    return out;
  }

  overview(): Note[] {
    const out: Note[] = [];
    for (let i = 0; i < this.notes.length; i++) {
      const n = this.notes[i];
      if (n.status !== NoteStatus.DELETED) {
        out.push(n);
      }
    }
    return out;
  }
}
