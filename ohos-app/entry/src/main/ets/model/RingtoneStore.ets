/**
 * 提醒铃声：用户从系统文件选择器挑一首音频，复制进应用私有目录里的副本。
 * 只存副本，外部文件删了也照样响；换歌时删掉旧副本。
 *
 * ⚠️ 本文件未经 DevEco / SDK 编译校验（本机无鸿蒙环境），API 名称按 API 12 文档书写。
 */
import { common } from '@kit.AbilityKit';
import { picker, fileIo as fs } from '@kit.CoreFileKit';
import { preferences } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';

export class RingtoneStore {
  private static readonly PREF_NAME: string = 'worknote_settings';
  private static readonly KEY_PATH: string = 'ringtone_path';
  private static readonly KEY_LABEL: string = 'ringtone_label';
  private static readonly DIR: string = 'ringtone';

  private static async pref(ctx: common.UIAbilityContext): Promise<preferences.Preferences> {
    return await preferences.getPreferences(ctx, RingtoneStore.PREF_NAME);
  }

  private static dir(ctx: common.UIAbilityContext): string {
    const dir = ctx.filesDir + '/' + RingtoneStore.DIR;
    if (!fs.accessSync(dir)) {
      fs.mkdirSync(dir);
    }
    return dir;
  }

  /** 当前自定义铃声的绝对路径；没设置或文件丢了返回空串 */
  static async current(ctx: common.UIAbilityContext): Promise<string> {
    const p = await RingtoneStore.pref(ctx);
    const path = p.getSync(RingtoneStore.KEY_PATH, '') as string;
    if (path.length === 0) {
      return '';
    }
    if (!fs.accessSync(path)) {
      return '';
    }
    return path;
  }

  static async label(ctx: common.UIAbilityContext): Promise<string> {
    const p = await RingtoneStore.pref(ctx);
    return p.getSync(RingtoneStore.KEY_LABEL, '') as string;
  }

  /** 弹出系统文件选择器，复制选中的音频进来；返回落盘路径，取消返回空串 */
  static async pickAndImport(ctx: common.UIAbilityContext): Promise<string> {
    const options = new picker.DocumentSelectOptions();
    options.maxSelectNumber = 1;
    options.fileSuffixFilters = ['音频文件|.mp3,.m4a,.aac,.wav,.ogg,.flac,.amr'];
    const viewPicker = new picker.DocumentViewPicker(ctx);
    const uris: string[] = await viewPicker.select(options);
    if (uris === undefined || uris.length === 0) {
      return '';
    }
    return await RingtoneStore.importUri(ctx, uris[0]);
  }

  private static async importUri(ctx: common.UIAbilityContext, uri: string): Promise<string> {
    const dir = RingtoneStore.dir(ctx);
    // 清掉上一次的副本，避免扩展名不同留两份
    const existing = fs.listFileSync(dir);
    for (const name of existing) {
      fs.unlinkSync(dir + '/' + name);
    }

    const ext = RingtoneStore.pickExtension(uri);
    const target = dir + '/alarm.' + ext;
    const src = fs.openSync(uri, fs.OpenMode.READ_ONLY);
    try {
      fs.copyFileSync(src.fd, target);
    } finally {
      fs.closeSync(src);
    }

    const stat = fs.statSync(target);
    if (stat.size <= 0) {
      fs.unlinkSync(target);
      throw new Error('音频读不出来');
    }

    const p = await RingtoneStore.pref(ctx);
    p.putSync(RingtoneStore.KEY_PATH, target);
    p.putSync(RingtoneStore.KEY_LABEL, RingtoneStore.displayName(uri));
    await p.flush();
    return target;
  }

  static async reset(ctx: common.UIAbilityContext): Promise<void> {
    const dir = RingtoneStore.dir(ctx);
    const existing = fs.listFileSync(dir);
    for (const name of existing) {
      fs.unlinkSync(dir + '/' + name);
    }
    const p = await RingtoneStore.pref(ctx);
    p.deleteSync(RingtoneStore.KEY_PATH);
    p.deleteSync(RingtoneStore.KEY_LABEL);
    await p.flush();
  }

  private static displayName(uri: string): string {
    const raw = uri.substring(uri.lastIndexOf('/') + 1);
    return decodeURIComponent(raw);
  }

  private static pickExtension(uri: string): string {
    const name = RingtoneStore.displayName(uri).toLowerCase();
    const dot = name.lastIndexOf('.');
    if (dot < 0) {
      return 'mp3';
    }
    const ext = name.substring(dot + 1);
    const allowed: string[] = ['mp3', 'm4a', 'aac', 'wav', 'ogg', 'flac', 'amr'];
    return allowed.includes(ext) ? ext : 'mp3';
  }
}
