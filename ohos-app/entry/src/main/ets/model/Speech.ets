/**
 * 内容播报：用系统 CoreSpeechKit 的文本转语音能力读说明页文字。
 * 引擎创建失败（设备上没有语音引擎、系统版本不支持）时返回 false，
 * 页面据此把提示换成「这台手机没有可用的语音播报引擎」，与安卓端同一套降级做法。
 */
import { textToSpeech } from '@kit.CoreSpeechKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

export class Speech {
  private static engine: textToSpeech.TextToSpeechEngine | null = null;
  private static seq: number = 0;

  static async prepare(ctx: common.UIAbilityContext): Promise<boolean> {
    if (Speech.engine !== null) {
      return true;
    }
    const params: textToSpeech.CreateEngineParams = {
      language: 'zh-CN',
      person: 0,
      online: 1
    };
    const ok = await new Promise<boolean>((resolve: (value: boolean) => void) => {
      try {
        textToSpeech.createEngine(params, (err: BusinessError, eng: textToSpeech.TextToSpeechEngine) => {
          if (err) {
            resolve(false);
            return;
          }
          Speech.engine = eng;
          resolve(true);
        });
      } catch (e) {
        resolve(false);
      }
    });
    return ok;
  }

  static speak(text: string): void {
    const engine = Speech.engine;
    if (engine === null || text.length === 0) {
      return;
    }
    Speech.seq++;
    const extra: Record<string, Object> = {
      'speed': 1,
      'volume': 1,
      'pitch': 1,
      'languageContext': 'zh-CN',
      'audioType': 'pcm'
    };
    try {
      engine.speak(text, {
        requestId: `speak_${Speech.seq}_${Date.now()}`,
        extraParams: extra
      });
    } catch (e) {
      // 单次播报失败不影响页面，静默跳过
    }
  }

  static stop(): void {
    const engine = Speech.engine;
    if (engine === null) {
      return;
    }
    try {
      engine.stop();
    } catch (e) {
      // 没有在播时报错也无需处理
    }
  }
}
