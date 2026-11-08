/**
 * 主页面：底部三栏 [主界面] [日程] [我]，仿微信结构。
 * 文案全部走 resources 的 $r('app.string.xxx')，简体 / 繁體 / English 三套同键。
 */
import { common } from '@kit.AbilityKit';
import { NoteStore } from '../model/NoteStore';
import { Note, NoteStatus } from '../model/Note';
import { todayKey } from '../model/TimeKey';
import { RingtoneStore } from '../model/RingtoneStore';
import { Alerts } from '../model/Alerts';
import { I18n } from '@kit.LocalizationKit';

@Entry
@Component
struct Index {
  @State tabIndex: number = 0;
  @State notes: Note[] = [];
  @State monthYear: number = new Date().getFullYear();
  @State monthMonth: number = new Date().getMonth() + 1;
  @State ringtoneLabel: string = '';
  // 便签编辑页状态：编辑哪一条、标题、备注、关联日期、提醒时刻（0 表示不提醒）
  @State editing: boolean = false;
  @State editId: string = '';
  @State editTitle: string = '';
  @State editRemark: string = '';
  @State editDateKey: string = '';
  @State editRemindAt: number = 0;

  private store: NoteStore = NoteStore.get();

  async aboutToAppear(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext;
    await this.store.load(ctx);
    this.notes = this.store.overview();
    const label = await RingtoneStore.label(ctx);
    this.ringtoneLabel = label.length > 0 ? label : '';
  }

  private reload(): void {
    this.notes = this.store.overview();
  }

  build() {
    Column() {
      if (this.editing) {
        this.editorView();
      } else {
        Tabs({ barPosition: BarPosition.End, index: this.tabIndex }) {
          TabContent() {
            this.homeView();
          }.tabBar($r('app.string.tab_home'))

          TabContent() {
            this.scheduleView();
          }.tabBar($r('app.string.tab_schedule'))

          TabContent() {
            this.profileView();
          }.tabBar($r('app.string.tab_profile'))
        }
        .barMode(BarMode.Fixed)
        .onChange((index: number) => {
          this.tabIndex = index;
        })
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }

  /**
   * 便签编辑页。关联日期用系统年月日选择框（年、月、日三段都能直接选），
   * 右侧「今天」一键回到当天；提醒时间同样是年月日 + 时分。
   */
  @Builder
  editorView() {
    Column() {
      Row() {
        Text($r('app.string.cancel'))
          .fontSize(16)
          .fontColor($r('app.color.text_secondary'))
          .onClick(() => {
            this.closeEditor();
          })
        Blank()
        Text($r('app.string.edit_note'))
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text($r('app.string.save'))
          .fontSize(16)
          .fontColor($r('app.color.brand_green'))
          .onClick(() => {
            this.saveEditor();
          })
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })

      Scroll() {
        Column({ space: 12 }) {
          Column() {
            Text($r('app.string.note_title_label'))
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
            TextInput({ text: this.editTitle })
              .margin({ top: 6 })
              .onChange((value: string) => {
                this.editTitle = value;
              })
            Text($r('app.string.note_remark_label'))
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .margin({ top: 10 })
            TextArea({ text: this.editRemark })
              .height(80)
              .margin({ top: 6 })
              .onChange((value: string) => {
                this.editRemark = value;
              })
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(16)
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(12)

          Column() {
            Row() {
              Text($r('app.string.note_date_label'))
                .fontSize(16)
                .fontColor($r('app.color.text_primary'))
              Blank()
              Text($r('app.string.day_today'))
                .fontSize(14)
                .fontColor($r('app.color.brand_green'))
                .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                .onClick(() => {
                  this.editDateKey = todayKey();
                })
            }
            .width('100%')

            Text(this.dateLabel(this.editDateKey))
              .fontSize(18)
              .fontColor($r('app.color.text_primary'))
              .margin({ top: 8 })
              .onClick(() => {
                this.pickEditDate();
              })
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(16)
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(12)

          Column() {
            Text($r('app.string.reminder_section'))
              .fontSize(16)
              .fontColor($r('app.color.text_primary'))
            Row() {
              Text($r('app.string.rmd_timed'))
                .fontSize(14)
                .fontColor($r('app.color.text_primary'))
              Blank()
              Toggle({ type: ToggleType.Switch, isOn: this.editRemindAt > 0 })
                .onChange((isOn: boolean) => {
                  this.editRemindAt = isOn ? this.defaultRemindTs() : 0;
                })
            }
            .width('100%')
            .height(44)

            if (this.editRemindAt > 0) {
              Row() {
                Text($r('app.string.remind_time_label'))
                  .fontSize(14)
                  .fontColor($r('app.color.text_primary'))
                Blank()
                Text($r('app.string.move_to_today'))
                  .fontSize(14)
                  .fontColor($r('app.color.brand_green'))
                  .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                  .onClick(() => {
                    this.remindToToday();
                  })
              }
              .width('100%')

              Text(this.remindLabel(this.editRemindAt))
                .fontSize(18)
                .fontColor($r('app.color.text_primary'))
                .margin({ top: 8 })
                .onClick(() => {
                  this.pickRemindDate();
                })
            } else {
              Text($r('app.string.remind_none'))
                .fontSize(14)
                .fontColor($r('app.color.text_secondary'))
                .margin({ top: 4 })
            }
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(16)
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(12)

          Text($r('app.string.mark_done'))
            .fontSize(16)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
            .height(44)
            .textAlign(TextAlign.Center)
            .backgroundColor($r('app.color.card_bg'))
            .borderRadius(12)
            .onClick(() => {
              this.markDoneById(this.editId);
              this.editing = false;
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 4, bottom: 16 })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }

  @Builder
  homeView() {
    Column() {
      Row() {
        Text($r('app.string.home_title')).fontSize(20).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text('＋').fontSize(24).fontColor($r('app.color.text_primary'))
          .onClick(() => {
            this.addNote();
          })
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })

      if (this.store.activeNotes().length === 0) {
        Column() {
          Text($r('app.string.home_empty'))
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 8 }) {
          ForEach(this.store.activeNotes(), (item: Note) => {
            ListItem() {
              Column() {
                Text(item.title.length === 0 ? '—' : item.title)
                  .fontSize(16)
                  .fontColor($r('app.color.text_primary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                if (item.remark.length > 0) {
                  Text(item.remark)
                    .fontSize(12)
                    .fontColor($r('app.color.text_secondary'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .margin({ top: 4 })
                }
              }
              .alignItems(HorizontalAlign.Start)
              .width('100%')
              .padding(12)
              .backgroundColor($r('app.color.card_bg'))
              .borderRadius(12)
            }
            .onClick(() => {
              this.openEditor(item);
            })
          }, (item: Note) => item.id)
        }
        .padding({ left: 16, right: 16, top: 4 })
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }

  @Builder
  scheduleView() {
    Column() {
      Row() {
        Text($r('app.string.schedule_title')).fontSize(20).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text(`${this.monthYear}年${this.monthMonth}月 ▾`)
          .fontSize(14)
          .fontColor($r('app.color.brand_green'))
          .onClick(() => {
            this.pickMonth();
          })
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })

      // 纵向 1 号到月末，不做前后翻月
      List() {
        ForEach(this.daysOfMonth(), (day: number) => {
          ListItem() {
            Row() {
              Text(`${day}`).fontSize(16).fontColor($r('app.color.text_primary')).width(40)
              Text(this.dateKeyOfDay(day))
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
                .layoutWeight(1)
              Text(this.countOfDay(day).toString())
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
            }
            .width('100%')
            .height(52)
            .padding({ left: 16, right: 16 })
            .border({ width: { bottom: 0.5 }, color: $r('app.color.divider') })
          }
        }, (day: number) => `${this.monthYear}-${this.monthMonth}-${day}`)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }

  @Builder
  profileView() {
    Column() {
      Row() {
        Text($r('app.string.profile_title')).fontSize(20).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })

      List() {
        ListItem() {
          Column() {
            Text($r('app.string.appearance_section'))
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .margin({ bottom: 8 })
            Row() {
              Text($r('app.string.lang_title')).fontSize(16)
              Blank()
              Text($r('app.string.lang_zh')).fontSize(14).fontColor($r('app.color.text_secondary'))
            }
            .width('100%')
            .height(44)
            .onClick(() => {
              this.chooseLanguage();
            })
            Text($r('app.string.lang_restart_hint'))
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start)
          .padding(16)
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(12)
        }

        ListItem() {
          Column() {
            Text($r('app.string.notify_section'))
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .margin({ bottom: 8 })
            Row() {
              Text($r('app.string.ringtone_title')).fontSize(16)
              Blank()
              if (this.ringtoneLabel.length > 0) {
                Text(this.ringtoneLabel).fontSize(14).fontColor($r('app.color.text_secondary'))
              } else {
                Text($r('app.string.ringtone_default')).fontSize(14).fontColor($r('app.color.text_secondary'))
              }
            }
            .width('100%')
            .height(44)
            .onClick(() => {
              this.chooseRingtone();
            })
            if (this.ringtoneLabel.length > 0) {
              Divider().color($r('app.color.divider'))
              Text($r('app.string.ringtone_reset')).fontSize(16).padding({ top: 10, bottom: 10 })
                .onClick(() => {
                  this.resetRingtone();
                })
            }
            Text($r('app.string.ringtone_hint'))
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start)
          .padding(16)
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(12)
        }

        ListItem() {
          Column() {
            Text($r('app.string.backup_section'))
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .margin({ bottom: 8 })
            Text($r('app.string.backup_export')).fontSize(16).padding({ top: 10, bottom: 10 })
            Divider().color($r('app.color.divider'))
            Text($r('app.string.backup_import')).fontSize(16).padding({ top: 10, bottom: 10 })
          }
          .alignItems(HorizontalAlign.Start)
          .padding(16)
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(12)
        }

        ListItem() {
          Column() {
            Text($r('app.string.about_section'))
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .margin({ bottom: 8 })
            Text($r('app.string.about_text')).fontSize(14)
              .fontColor($r('app.color.text_primary'))
          }
          .alignItems(HorizontalAlign.Start)
          .padding(16)
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(12)
        }
      }
      .space(12)
      .padding({ left: 16, right: 16 })
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }

  private daysOfMonth(): number[] {
    const days = new Date(this.monthYear, this.monthMonth, 0).getDate();
    const out: number[] = [];
    for (let i = 1; i <= days; i++) {
      out.push(i);
    }
    return out;
  }

  private dateKeyOfDay(day: number): string {
    const m = this.monthMonth < 10 ? `0${this.monthMonth}` : `${this.monthMonth}`;
    const d = day < 10 ? `0${day}` : `${day}`;
    return `${this.monthYear}-${m}-${d}`;
  }

  private countOfDay(day: number): number {
    const key = this.dateKeyOfDay(day);
    let n = 0;
    const all = this.store.activeNotes();
    for (let i = 0; i < all.length; i++) {
      if (all[i].dateKey === key) {
        n++;
      }
    }
    return n;
  }

  private addNote(): void {
    const n = new Note();
    n.id = `n_${Date.now()}`;
    n.title = '';
    n.remark = '';
    n.dateKey = todayKey();
    n.createdAt = Date.now();
    n.updatedAt = Date.now();
    n.status = NoteStatus.PENDING;
    this.store.notes.push(n);
    this.store.save();
    this.reload();
    this.openEditor(n);
  }

  private openEditor(note: Note): void {
    this.editId = note.id;
    this.editTitle = note.title;
    this.editRemark = note.remark;
    this.editDateKey = note.dateKey.length > 0 ? note.dateKey : todayKey();
    this.editRemindAt = note.remindAt;
    this.editing = true;
  }

  private closeEditor(): void {
    this.editing = false;
  }

  private saveEditor(): void {
    const all = this.store.notes;
    for (let i = 0; i < all.length; i++) {
      if (all[i].id !== this.editId) {
        continue;
      }
      const note = all[i];
      note.title = this.editTitle;
      note.remark = this.editRemark;
      note.dateKey = this.editDateKey;
      note.remindAt = this.editRemindAt;
      note.updatedAt = Date.now();
      break;
    }
    this.store.save();
    this.reload();
    this.editing = false;
  }

  private markDoneById(id: string): void {
    const all = this.store.notes;
    for (let i = 0; i < all.length; i++) {
      if (all[i].id !== id) {
        continue;
      }
      all[i].status = NoteStatus.DONE;
      all[i].updatedAt = Date.now();
      break;
    }
    this.store.save();
    this.reload();
  }

  private dateFromKey(key: string): Date {
    if (/^\d{4}-\d{2}-\d{2}$/.test(key)) {
      const y = Number(key.substring(0, 4));
      const m = Number(key.substring(5, 7));
      const day = Number(key.substring(8, 10));
      return new Date(y, m - 1, day, 0, 0, 0, 0);
    }
    return new Date();
  }

  /** 关联日期那一行：2026年11月8日，当天再加「（今天）」 */
  private dateLabel(key: string): string {
    const d = this.dateFromKey(key);
    const text = `${d.getFullYear()}年${d.getMonth() + 1}月${d.getDate()}日`;
    return key === todayKey() ? `${text}（今天）` : text;
  }

  /** 提醒时间那一行：2026年11月8日 09:00 */
  private remindLabel(ts: number): string {
    const d = new Date(ts);
    const h = d.getHours() < 10 ? `0${d.getHours()}` : `${d.getHours()}`;
    const m = d.getMinutes() < 10 ? `0${d.getMinutes()}` : `${d.getMinutes()}`;
    return `${d.getFullYear()}年${d.getMonth() + 1}月${d.getDate()}日 ${h}:${m}`;
  }

  /** 打开定时提醒时给的默认值：关联日期那天的 09:00 */
  private defaultRemindTs(): number {
    const d = this.dateFromKey(this.editDateKey);
    return new Date(d.getFullYear(), d.getMonth(), d.getDate(), 9, 0, 0, 0).getTime();
  }

  /** 关联日期：年月日选择框，点一下直接改日期 */
  private pickEditDate(): void {
    const d = this.dateFromKey(this.editDateKey);
    this.getUIContext().showDatePickerDialog({
      start: new Date(2000, 0, 1),
      end: new Date(2100, 11, 31),
      selected: new Date(d),
      onAccept: (value: DatePickerResult) => {
        if (value.year !== undefined && value.month !== undefined && value.day !== undefined) {
          this.editDateKey = `${value.year}-${this.two(value.month + 1)}-${this.two(value.day)}`;
        }
      }
    });
  }

  /** 提醒时间：先选年月日，再选时分，两步走完就是一个完整时间点 */
  private pickRemindDate(): void {
    const ts = this.editRemindAt > 0 ? this.editRemindAt : this.defaultRemindTs();
    const d = new Date(ts);
    this.getUIContext().showDatePickerDialog({
      start: new Date(2000, 0, 1),
      end: new Date(2100, 11, 31),
      selected: new Date(d),
      onAccept: (value: DatePickerResult) => {
        if (value.year !== undefined && value.month !== undefined && value.day !== undefined) {
          this.editRemindAt = new Date(value.year, value.month, value.day, d.getHours(), d.getMinutes(), 0, 0).getTime();
          this.pickRemindTime();
        }
      }
    });
  }

  private pickRemindTime(): void {
    const ts = this.editRemindAt > 0 ? this.editRemindAt : this.defaultRemindTs();
    const d = new Date(ts);
    this.getUIContext().showTimePickerDialog({
      selected: new Date(d),
      useMilitaryTime: true,
      onAccept: (value: TimePickerResult) => {
        if (value.hour !== undefined && value.minute !== undefined) {
          this.editRemindAt = new Date(d.getFullYear(), d.getMonth(), d.getDate(), value.hour, value.minute, 0, 0).getTime();
        }
      }
    });
  }

  /** 「改到今天」：日期落到今天，时分保持不变 */
  private remindToToday(): void {
    const base = this.editRemindAt > 0 ? new Date(this.editRemindAt) : new Date(this.defaultRemindTs());
    const now = new Date();
    this.editRemindAt = new Date(now.getFullYear(), now.getMonth(), now.getDate(), base.getHours(), base.getMinutes(), 0, 0).getTime();
  }

  private two(n: number): string {
    return n < 10 ? `0${n}` : `${n}`;
  }

  private pickMonth(): void {
    this.getUIContext().showDatePickerDialog({
      start: new Date(2000, 0, 1),
      end: new Date(2100, 11, 31),
      selected: new Date(this.monthYear, this.monthMonth - 1, 1),
      onAccept: (value: DatePickerResult) => {
        if (value.year !== undefined && value.month !== undefined) {
          this.monthYear = value.year;
          this.monthMonth = value.month + 1;
        }
      }
    });
  }

  private chooseLanguage(): void {
    const names: string[] = ['简体中文', '繁體中文', 'English'];
    const codes: string[] = ['zh-Hans', 'zh-Hant', 'en'];
    this.getUIContext().showAlertDialog({
      title: '语言 / Language',
      buttons: [
        { value: '简体中文', action: () => this.applyLanguage(codes[0]) },
        { value: '繁體中文', action: () => this.applyLanguage(codes[1]) },
        { value: 'English', action: () => this.applyLanguage(codes[2]) }
      ],
      cancel: () => {}
    });
  }

  private applyLanguage(code: string): void {
    try {
      // HarmonyOS 的应用级语言：切换后需要重启应用才生效
      I18n.System.setAppPreferredLanguage(code);
    } catch (e) {
      // 旧版本系统可能没有这个接口，忽略即可，界面仍按系统语言显示
    }
  }

  /** 选本地音频当提醒铃声：复制进私有目录，并立刻试听一次 */
  private async chooseRingtone(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext;
    try {
      const path = await RingtoneStore.pickAndImport(ctx);
      if (path.length === 0) {
        return;
      }
      const label = await RingtoneStore.label(ctx);
      this.ringtoneLabel = label;
      await Alerts.fire(ctx);
    } catch (e) {
      const msg = e instanceof Error ? e.message : `${e}`;
      this.getUIContext().showAlertDialog({
        title: $r('app.string.ringtone_title'),
        message: msg,
        confirm: { value: $r('app.string.ok'), action: () => {} }
      });
    }
  }

  private async resetRingtone(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext;
    await RingtoneStore.reset(ctx);
    this.ringtoneLabel = '';
  }
}
