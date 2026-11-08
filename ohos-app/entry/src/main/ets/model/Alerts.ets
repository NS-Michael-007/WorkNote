/**
 * 提醒响铃：鸿蒙的通知本身用系统提示音，自定义音频由 App 自己用 AVPlayer 播，
 * 这样「用户自选一首歌」和「系统默认」可以共存，也不会两套声音一起响。
 *
 * ⚠️ 未经 SDK 编译校验（本机无鸿蒙环境）。
 */
import { common } from '@kit.AbilityKit';
import { media } from '@kit.MediaKit';
import { RingtoneStore } from './RingtoneStore';

export class Alerts {
  private static player: media.AVPlayer | null = null;

  static async fire(ctx: common.UIAbilityContext): Promise<void> {
    const path = await RingtoneStore.current(ctx);
    if (path.length === 0) {
      return;
    }
    await Alerts.stop();
    const player = await media.createAVPlayer();
    Alerts.player = player;
    player.url = 'file://' + path;
    player.on('error', () => {
      Alerts.stop();
    });
    player.on('stateChange', (state: string) => {
      if (state === 'initialized') {
        player.prepare();
      } else if (state === 'prepared') {
        player.play();
      } else if (state === 'completed') {
        Alerts.stop();
      }
    });
  }

  static async stop(): Promise<void> {
    const p = Alerts.player;
    Alerts.player = null;
    if (p === null) {
      return;
    }
    try {
      await p.stop();
      await p.release();
    } catch (e) {
      // 已经释放或还没 prepared 时 stop 会抛错，忽略即可
    }
  }
}
