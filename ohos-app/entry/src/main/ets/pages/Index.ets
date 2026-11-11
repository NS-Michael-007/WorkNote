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
import { Speech } from '../model/Speech';

// 两个跨次启动要记住的设置项：收起了哪几个分组（| 分隔）、日程用哪种显示模式
PersistentStorage.persistProp('collapsed_keys', '');
PersistentStorage.persistProp('schedule_mode', 'list');

/** 功能说明页的一小节：标题 + 正文，都走资源，三套语言同键 */
class HelpItem {
  title: Resource;
  body: Resource;

  constructor(title: Resource, body: Resource) {
    this.title = title;
    this.body = body;
  }
}

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

  // 回收站、功能说明页是全屏覆盖的两层，和编辑页一样用状态切换
  @State showBin: boolean = false;
  @State binSelecting: boolean = false;
  @State binSelected: string[] = [];
  @State showHelp: boolean = false;
  @State helpTts: boolean = false;
  @State ttsFailed: boolean = false;
  // 日历模式下当前点中的是哪一天
  @State selectedDay: number = new Date().getDate();
  // 收起的分组（| 分隔），与日程显示模式一起由 PersistentStorage 落盘
  @StorageLink('collapsed_keys') collapsedKeys: string = '';
  @StorageLink('schedule_mode') scheduleMode: string = 'list';

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
      if (this.showHelp) {
        this.helpView();
      } else if (this.showBin) {
        this.binView();
      } else if (this.editing) {
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

          Text($r('app.string.note_delete_into_bin'))
            .fontSize(16)
            .fontColor($r('app.color.badge_red'))
            .width('100%')
            .height(44)
            .textAlign(TextAlign.Center)
            .backgroundColor($r('app.color.card_bg'))
            .borderRadius(12)
            .onClick(() => {
              this.deleteToBin(this.editId);
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
        Text($r('app.string.bin_title')).fontSize(14).fontColor($r('app.color.text_secondary'))
          .margin({ right: 14 })
          .onClick(() => {
            this.openBin();
          })
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
        Row() {
          Text(this.scheduleMode === 'calendar' ? $r('app.string.sched_mode_calendar_short')
            : $r('app.string.sched_mode_list_short'))
            .fontSize(14)
            .fontColor($r('app.color.brand_green'))
          Text(' ▾').fontSize(14).fontColor($r('app.color.brand_green'))
        }
        .margin({ right: 14 })
        .onClick(() => {
          this.showModeDialog();
        })

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

      if (this.scheduleMode === 'calendar') {
        this.calendarPanel();
      } else {
        this.dayListPanel();
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }

  /** 下拉模式：纵向 1 号到月末（原来的做法，未改动） */
  @Builder
  dayListPanel() {
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

  /** 日历模式：整月七列网格，点某天在下面列出当天便签 */
  @Builder
  calendarPanel() {
    Column() {
      Row() {
        ForEach(this.weekdayIndexes(), (i: number) => {
          Text(this.weekdayRes(i))
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
            .width('14.28%')
            .textAlign(TextAlign.Center)
        }, (i: number) => `w${i}`)
      }
      .width('100%')
      .padding({ left: 8, right: 8, bottom: 4 })

      Grid() {
        ForEach(this.calendarCells(), (day: number, index: number) => {
          GridItem() {
            Column() {
              if (day > 0) {
                Text(`${day}`)
                  .fontSize(this.selectedDay === day ? 15 : 14)
                  .fontWeight(this.selectedDay === day ? FontWeight.Medium : FontWeight.Normal)
                  .fontColor(this.selectedDay === day ? Color.White
                    : (this.dateKeyOfDay(day) === todayKey() ? $r('app.color.brand_green')
                      : $r('app.color.text_primary')))
                  .width('100%')
                  .height(34)
                  .textAlign(TextAlign.Center)
                  .backgroundColor(this.selectedDay === day ? $r('app.color.brand_green') : $r('app.color.card_bg'))
                  .borderRadius(8)
                Text(this.countOfDay(day) > 0 ? `${this.countOfDay(day)}` : ' ')
                  .fontSize(10)
                  .fontColor($r('app.color.badge_red'))
              }
            }
            .width('100%')
            .onClick(() => {
              if (day > 0) {
                this.selectedDay = day;
              }
            })
          }
        }, (day: number, index: number) => `c${index}`)
      }
      .columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr')
      .columnsGap(4)
      .rowsGap(4)
      .height(350)
      .padding({ left: 8, right: 8 })

      Column({ space: 8 }) {
        Text(this.dayLabelOf(this.selectedDay))
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
        if (this.notesOfDay(this.selectedDay).length === 0) {
          Text($r('app.string.date_empty_hint'))
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
        } else {
          ForEach(this.notesOfDay(this.selectedDay), (item: Note) => {
            Column() {
              Text(item.title.length === 0 ? '—' : item.title)
                .fontSize(14)
                .fontColor($r('app.color.text_primary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              if (item.remindAt > 0) {
                Text(this.remindLabel(item.remindAt))
                  .fontSize(11)
                  .fontColor($r('app.color.text_secondary'))
                  .margin({ top: 3 })
              }
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
            .padding(10)
            .backgroundColor($r('app.color.card_bg'))
            .borderRadius(10)
          }, (item: Note) => `d_${item.id}`)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 12 })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
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
            this.sectionHeader('appearance', $r('app.string.appearance_section'))
            if (!this.isSectionCollapsed('appearance')) {
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
          }
          .alignItems(HorizontalAlign.Start)
          .padding(16)
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(12)
        }

        ListItem() {
          Column() {
            this.sectionHeader('notify', $r('app.string.notify_section'))
            if (!this.isSectionCollapsed('notify')) {
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
          }
          .alignItems(HorizontalAlign.Start)
          .padding(16)
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(12)
        }

        ListItem() {
          Column() {
            this.sectionHeader('help', $r('app.string.help_section'))
            if (!this.isSectionCollapsed('help')) {
              Column() {
                Text($r('app.string.help_entry_title')).fontSize(16).fontColor($r('app.color.text_primary'))
                Text($r('app.string.help_entry_sub'))
                  .fontSize(12)
                  .fontColor($r('app.color.text_secondary'))
                  .margin({ top: 4 })
              }
              .alignItems(HorizontalAlign.Start)
              .width('100%')
              .padding({ top: 6, bottom: 6 })
              .onClick(() => {
                this.openHelp();
              })
            }
          }
          .alignItems(HorizontalAlign.Start)
          .padding(16)
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(12)
        }

        ListItem() {
          Column() {
            this.sectionHeader('backup', $r('app.string.backup_section'))
            if (!this.isSectionCollapsed('backup')) {
              Text($r('app.string.backup_export')).fontSize(16).padding({ top: 10, bottom: 10 })
              Divider().color($r('app.color.divider'))
              Text($r('app.string.backup_import')).fontSize(16).padding({ top: 10, bottom: 10 })
            }
          }
          .alignItems(HorizontalAlign.Start)
          .padding(16)
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(12)
        }

        ListItem() {
          Column() {
            this.sectionHeader('about', $r('app.string.about_section'))
            if (!this.isSectionCollapsed('about')) {
              Text($r('app.string.about_text')).fontSize(14)
                .fontColor($r('app.color.text_primary'))
            }
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

  /** 分组标题行：点一下收起 / 展开整组，组内内容与行为都不变 */
  @Builder
  sectionHeader(key: string, title: Resource) {
    Row() {
      Text(title)
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .layoutWeight(1)
      Text(this.isSectionCollapsed(key) ? '⌄' : '⌃')
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
    }
    .width('100%')
    .padding({ top: 6, bottom: 6 })
    .onClick(() => {
      this.toggleSection(key);
    })
  }

  /** 回收站：原来没有这一页，本轮新增；逐条恢复 / 彻底删除照旧保留 */
  @Builder
  binView() {
    Column() {
      Row() {
        Text($r('app.string.tab_home'))
          .fontSize(15)
          .fontColor($r('app.color.text_secondary'))
          .onClick(() => {
            this.closeBin();
          })
        Blank()
        Text($r('app.string.bin_title'))
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text(this.binSelecting ? $r('app.string.bin_multi_exit') : $r('app.string.bin_multi_select'))
          .fontSize(15)
          .fontColor($r('app.color.brand_green'))
          .onClick(() => {
            this.toggleBinSelecting();
          })
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })

      if (this.deletedNotes().length === 0) {
        Column() {
          Text($r('app.string.bin_empty_hint'))
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 8 }) {
          ForEach(this.deletedNotes(), (item: Note) => {
            ListItem() {
              Row() {
                if (this.binSelecting) {
                  Text(this.binSelected.indexOf(item.id) >= 0 ? '☑' : '☐')
                    .fontSize(18)
                    .fontColor($r('app.color.brand_green'))
                    .margin({ right: 8 })
                }
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
                .layoutWeight(1)

                if (!this.binSelecting) {
                  Text($r('app.string.bin_restore'))
                    .fontSize(12)
                    .fontColor($r('app.color.brand_green'))
                    .padding(4)
                    .onClick(() => {
                      this.restoreFromBin(item.id);
                    })
                  Text($r('app.string.bin_purge'))
                    .fontSize(12)
                    .fontColor($r('app.color.badge_red'))
                    .padding(4)
                    .margin({ left: 6 })
                    .onClick(() => {
                      this.confirmPurgeOne(item.id);
                    })
                }
              }
              .width('100%')
              .padding(12)
              .backgroundColor($r('app.color.card_bg'))
              .borderRadius(12)
            }
            .onClick(() => {
              if (this.binSelecting) {
                this.toggleBinSelected(item.id);
              }
            })
          }, (item: Note) => `b_${item.id}`)
        }
        .padding({ left: 16, right: 16, top: 4 })
        .layoutWeight(1)
      }

      Row() {
        if (this.binSelecting) {
          Text(this.binAllSelected() ? $r('app.string.bin_select_none') : $r('app.string.bin_select_all'))
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .onClick(() => {
              this.toggleBinSelectAll();
            })
          Blank()
          Text($r('app.string.bin_delete_selected_title'))
            .fontSize(14)
            .fontColor($r('app.color.badge_red'))
            .onClick(() => {
              this.confirmPurgeSelected();
            })
        } else {
          Blank()
          Text($r('app.string.bin_delete_all'))
            .fontSize(14)
            .fontColor($r('app.color.badge_red'))
            .onClick(() => {
              this.confirmPurgeAll();
            })
        }
      }
      .width('100%')
      .height(52)
      .padding({ left: 16, right: 16 })
      .backgroundColor($r('app.color.card_bg'))
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }

  /** 功能说明页：设置页各分组除外，只讲各页怎么用；可开关内容播报 */
  @Builder
  helpView() {
    Column() {
      Row() {
        Text($r('app.string.tab_profile'))
          .fontSize(15)
          .fontColor($r('app.color.text_secondary'))
          .onClick(() => {
            this.closeHelp();
          })
        Blank()
        Text($r('app.string.help_title'))
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text(' ')
          .fontSize(15)
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })

      Scroll() {
        Column() {
          Text($r('app.string.help_intro'))
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')

          Row() {
            Column() {
              Text($r('app.string.help_tts_title'))
                .fontSize(16)
                .fontColor($r('app.color.text_primary'))
              Text($r('app.string.help_tts_sub'))
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
                .margin({ top: 4 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Toggle({ type: ToggleType.Switch, isOn: this.helpTts })
              .onChange((isOn: boolean) => {
                this.helpTts = isOn;
                if (isOn) {
                  this.speakWhole();
                } else {
                  Speech.stop();
                }
              })
          }
          .width('100%')
          .padding({ top: 14, bottom: 6 })

          Text(this.helpTts ? $r('app.string.help_tts_on_hint') : $r('app.string.help_tts_off_hint'))
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')

          if (this.ttsFailed) {
            Text($r('app.string.help_tts_no_engine'))
              .fontSize(12)
              .fontColor($r('app.color.badge_red'))
              .width('100%')
              .margin({ top: 6 })
          }

          if (this.helpTts) {
            Text($r('app.string.help_tts_speak_all'))
              .fontSize(14)
              .fontColor(Color.White)
              .width('100%')
              .height(44)
              .textAlign(TextAlign.Center)
              .backgroundColor($r('app.color.brand_green'))
              .borderRadius(10)
              .margin({ top: 10 })
              .onClick(() => {
                this.speakWhole();
              })
          }

          ForEach(this.helpSections(), (item: HelpItem, index: number) => {
            Column() {
              Text(item.title)
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
                .width('100%')
                .onClick(() => {
                  if (this.helpTts) {
                    this.speakOne(item);
                  }
                })
              Text(item.body)
                .fontSize(13)
                .fontColor($r('app.color.text_secondary'))
                .lineHeight(20)
                .width('100%')
                .margin({ top: 6 })
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
            .margin({ top: 18 })
          }, (item: HelpItem, index: number) => `h${index}`)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 28 })
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }

  private helpSections(): HelpItem[] {
    const out: HelpItem[] = [];
    out.push(new HelpItem($r('app.string.help_1_title'), $r('app.string.help_1_body')));
    out.push(new HelpItem($r('app.string.help_2_title'), $r('app.string.help_2_body')));
    out.push(new HelpItem($r('app.string.help_3_title'), $r('app.string.help_3_body')));
    out.push(new HelpItem($r('app.string.help_4_title'), $r('app.string.help_4_body')));
    out.push(new HelpItem($r('app.string.help_5_title'), $r('app.string.help_5_body')));
    out.push(new HelpItem($r('app.string.help_6_title'), $r('app.string.help_6_body')));
    out.push(new HelpItem($r('app.string.help_7_title'), $r('app.string.help_7_body')));
    out.push(new HelpItem($r('app.string.help_8_title'), $r('app.string.help_8_body')));
    out.push(new HelpItem($r('app.string.help_9_title'), $r('app.string.help_9_body')));
    out.push(new HelpItem($r('app.string.help_10_title'), $r('app.string.help_10_body')));
    out.push(new HelpItem($r('app.string.help_11_title'), $r('app.string.help_11_body')));
    out.push(new HelpItem($r('app.string.help_12_title'), $r('app.string.help_12_body')));
    return out;
  }

  private resText(res: Resource): string {
    try {
      return getContext(this).resourceManager.getStringSync(res.id);
    } catch (e) {
      return '';
    }
  }

  private openHelp(): void {
    this.showHelp = true;
  }

  private closeHelp(): void {
    this.showHelp = false;
    Speech.stop();
  }

  private async prepareSpeech(): Promise<boolean> {
    const ctx = getContext(this) as common.UIAbilityContext;
    const ok = await Speech.prepare(ctx);
    this.ttsFailed = !ok;
    return ok;
  }

  private async speakWhole(): Promise<void> {
    const ok = await this.prepareSpeech();
    if (!ok) {
      return;
    }
    let text = this.resText($r('app.string.help_intro'));
    const items = this.helpSections();
    for (let i = 0; i < items.length; i++) {
      text += `\n${this.resText(items[i].title)}。${this.resText(items[i].body)}`;
    }
    Speech.speak(text);
  }

  private async speakOne(item: HelpItem): Promise<void> {
    const ok = await this.prepareSpeech();
    if (!ok) {
      return;
    }
    Speech.speak(`${this.resText(item.title)}。${this.resText(item.body)}`);
  }

  private openBin(): void {
    this.binSelecting = false;
    this.binSelected = [];
    this.showBin = true;
  }

  private closeBin(): void {
    this.showBin = false;
    this.binSelecting = false;
    this.binSelected = [];
  }

  private toggleBinSelecting(): void {
    this.binSelecting = !this.binSelecting;
    if (!this.binSelecting) {
      this.binSelected = [];
    }
  }

  private deletedNotes(): Note[] {
    const out: Note[] = [];
    for (let i = 0; i < this.store.notes.length; i++) {
      if (this.store.notes[i].status === NoteStatus.DELETED) {
        out.push(this.store.notes[i]);
      }
    }
    return out;
  }

  private toggleBinSelected(id: string): void {
    const list = this.binSelected.slice();
    const idx = list.indexOf(id);
    if (idx >= 0) {
      list.splice(idx, 1);
    } else {
      list.push(id);
    }
    this.binSelected = list;
  }

  private binAllSelected(): boolean {
    const total = this.deletedNotes().length;
    return total > 0 && this.binSelected.length === total;
  }

  private toggleBinSelectAll(): void {
    if (this.binAllSelected()) {
      this.binSelected = [];
      return;
    }
    const list: string[] = [];
    const all = this.deletedNotes();
    for (let i = 0; i < all.length; i++) {
      list.push(all[i].id);
    }
    this.binSelected = list;
  }

  private restoreFromBin(id: string): void {
    const all = this.store.notes;
    for (let i = 0; i < all.length; i++) {
      if (all[i].id !== id) {
        continue;
      }
      all[i].status = NoteStatus.PENDING;
      all[i].updatedAt = Date.now();
      break;
    }
    this.store.save();
    this.reload();
  }

  private removeNotes(ids: string[]): void {
    const keep: Note[] = [];
    for (let i = 0; i < this.store.notes.length; i++) {
      if (ids.indexOf(this.store.notes[i].id) < 0) {
        keep.push(this.store.notes[i]);
      }
    }
    this.store.notes = keep;
    this.store.save();
    this.reload();
  }

  /** 单条彻底删除：走原来那条确认弹窗的文案 */
  private confirmPurgeOne(id: string): void {
    this.getUIContext().showAlertDialog({
      title: $r('app.string.bin_purge_title'),
      message: $r('app.string.bin_purge_msg'),
      buttons: [
        {
          value: $r('app.string.bin_purge'),
          action: () => {
            this.removeNotes([id]);
          }
        }
      ],
      cancel: () => {}
    });
  }

  private confirmPurgeSelected(): void {
    if (this.binSelected.length === 0) {
      this.getUIContext().getPromptAction().showToast({ message: $r('app.string.bin_nothing_selected') });
      return;
    }
    const ids = this.binSelected.slice();
    this.getUIContext().showAlertDialog({
      title: $r('app.string.bin_delete_selected_title'),
      message: $r('app.string.bin_delete_confirm'),
      buttons: [
        {
          value: $r('app.string.bin_delete_selected_title'),
          action: () => {
            this.removeNotes(ids);
            this.binSelected = [];
            this.binSelecting = false;
          }
        }
      ],
      cancel: () => {}
    });
  }

  private confirmPurgeAll(): void {
    const all = this.deletedNotes();
    if (all.length === 0) {
      return;
    }
    const ids: string[] = [];
    for (let i = 0; i < all.length; i++) {
      ids.push(all[i].id);
    }
    this.getUIContext().showAlertDialog({
      title: $r('app.string.bin_delete_all'),
      message: $r('app.string.bin_delete_confirm'),
      buttons: [
        {
          value: $r('app.string.bin_delete_all'),
          action: () => {
            this.removeNotes(ids);
            this.binSelecting = false;
          }
        }
      ],
      cancel: () => {}
    });
  }

  /** 编辑页的「删除（进回收站）」 */
  private deleteToBin(id: string): void {
    const all = this.store.notes;
    for (let i = 0; i < all.length; i++) {
      if (all[i].id !== id) {
        continue;
      }
      all[i].status = NoteStatus.DELETED;
      all[i].updatedAt = Date.now();
      break;
    }
    this.store.save();
    this.reload();
    this.editing = false;
  }

  private isSectionCollapsed(key: string): boolean {
    if (this.collapsedKeys.length === 0) {
      return false;
    }
    return this.collapsedKeys.split('|').indexOf(key) >= 0;
  }

  private toggleSection(key: string): void {
    const list = this.collapsedKeys.length > 0 ? this.collapsedKeys.split('|') : [];
    const idx = list.indexOf(key);
    if (idx >= 0) {
      list.splice(idx, 1);
    } else {
      list.push(key);
    }
    this.collapsedKeys = list.join('|');
  }

  private showModeDialog(): void {
    this.getUIContext().showAlertDialog({
      title: $r('app.string.sched_mode_title'),
      buttons: [
        {
          value: $r('app.string.sched_mode_list'),
          action: () => {
            this.scheduleMode = 'list';
          }
        },
        {
          value: $r('app.string.sched_mode_calendar'),
          action: () => {
            this.selectCalendarMode();
          }
        }
      ],
      cancel: () => {}
    });
  }

  /** 切到日历模式时，如果看的正是本月，就把今天先选中 */
  private selectCalendarMode(): void {
    this.scheduleMode = 'calendar';
    const now = new Date();
    if (this.monthYear === now.getFullYear() && this.monthMonth === now.getMonth() + 1) {
      this.selectedDay = now.getDate();
    } else {
      this.selectedDay = 1;
    }
  }

  private weekdayIndexes(): number[] {
    const out: number[] = [];
    for (let i = 0; i < 7; i++) {
      out.push(i);
    }
    return out;
  }

  private weekdayRes(index: number): Resource {
    if (index === 0) {
      return $r('app.string.weekday_0');
    }
    if (index === 1) {
      return $r('app.string.weekday_1');
    }
    if (index === 2) {
      return $r('app.string.weekday_2');
    }
    if (index === 3) {
      return $r('app.string.weekday_3');
    }
    if (index === 4) {
      return $r('app.string.weekday_4');
    }
    if (index === 5) {
      return $r('app.string.weekday_5');
    }
    return $r('app.string.weekday_6');
  }

  /** 日历格：0 表示空位（月初 / 月末补白），其余是日号 */
  private calendarCells(): number[] {
    const out: number[] = [];
    const lead = new Date(this.monthYear, this.monthMonth - 1, 1).getDay();
    for (let i = 0; i < lead; i++) {
      out.push(0);
    }
    const days = this.daysOfMonth();
    for (let i = 0; i < days.length; i++) {
      out.push(days[i]);
    }
    while (out.length % 7 !== 0) {
      out.push(0);
    }
    return out;
  }

  private notesOfDay(day: number): Note[] {
    const key = this.dateKeyOfDay(day);
    const out: Note[] = [];
    const all = this.store.activeNotes();
    for (let i = 0; i < all.length; i++) {
      if (all[i].dateKey === key) {
        out.push(all[i]);
      }
    }
    return out;
  }

  private dayLabelOf(day: number): string {
    const key = this.dateKeyOfDay(day);
    const d = this.dateFromKey(key);
    const text = `${d.getFullYear()}年${d.getMonth() + 1}月${d.getDate()}日 ${this.resText(this.weekdayRes(d.getDay()))}`;
    return key === todayKey() ? `${text}（${this.resText($r('app.string.day_today'))}）` : text;
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
