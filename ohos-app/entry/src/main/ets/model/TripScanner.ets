/**
 * 从行程截图里认出「这是一趟什么行程」。
 *
 * 识别用系统自带的文字识别（Core Vision Kit，离线跑在本机，图片不出设备）；
 * 解析只做规则抽取，抓不到日期或时间就留空，交给用户在编辑页自己补。
 *
 * ⚠️ 未经 SDK 编译校验（本机无 DevEco / hvigorw）。
 */
import { textRecognition } from '@kit.CoreVisionKit';
import { image } from '@kit.ImageKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo } from '@kit.CoreFileKit';

export class TripGuess {
  title: string = '';
  detail: string = '';
  year: number = -1;
  month: number = -1;
  day: number = -1;
  hour: number = -1;
  minute: number = -1;
  kind: string = 'other';
}

export class TripScanner {
  /** 让用户从相册选一张截图，返回图片 uri；取消返回空串 */
  static async pickImage(): Promise<string> {
    const picker = new photoAccessHelper.PhotoViewPicker();
    const options = new photoAccessHelper.PhotoSelectOptions();
    options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
    options.maxSelectNumber = 1;
    const result = await picker.select(options);
    if (result.photoUris.length === 0) {
      return '';
    }
    return result.photoUris[0];
  }

  /** 识别截图里的文字；失败返回空串 */
  static async recognise(uri: string): Promise<string> {
    let file: fileIo.File | null = null;
    try {
      file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      const size = fileIo.statSync(file.fd).size;
      const buffer = new ArrayBuffer(size);
      fileIo.readSync(file.fd, buffer);
      const source = image.createImageSource(buffer);
      const pixelMap = await source.createPixelMap();
      const visionInfo: textRecognition.VisionInfo = { pixelMap: pixelMap };
      textRecognition.init();
      const text = await textRecognition.recognizeText(visionInfo);
      textRecognition.release();
      return text.trim();
    } catch (e) {
      return '';
    } finally {
      if (file !== null) {
        fileIo.closeSync(file);
      }
    }
  }

  static parse(raw: string): TripGuess {
    const guess = new TripGuess();
    const lines = raw.split('\n').map((s: string) => s.trim()).filter((s: string) => s.length > 0);
    const text = lines.join(' ');

    const flight = TripScanner.firstMatch('(?:^|[^A-Za-z0-9])([A-Za-z]{2}\\s?\\d{3,4})(?![0-9])', text);
    const train = flight.length === 0 ? TripScanner.firstMatch('([GDCKTZ]\\s?\\d{1,4})(?![0-9])', text) : '';
    const route = TripScanner.routeOf(text);
    const stations = TripScanner.stationsOf(text);

    const full = TripScanner.matchGroups('(\\d{4})\\s*年\\s*(\\d{1,2})\\s*月\\s*(\\d{1,2})\\s*日', text);
    if (full.length === 3) {
      guess.year = Number(full[0]);
      guess.month = Number(full[1]);
      guess.day = Number(full[2]);
    } else {
      const dash = TripScanner.matchGroups('(\\d{4})[-/](\\d{1,2})[-/](\\d{1,2})', text);
      if (dash.length === 3) {
        guess.year = Number(dash[0]);
        guess.month = Number(dash[1]);
        guess.day = Number(dash[2]);
      } else {
        const md = TripScanner.matchGroups('(\\d{1,2})\\s*月\\s*(\\d{1,2})\\s*日', text);
        if (md.length === 2) {
          guess.month = Number(md[0]);
          guess.day = Number(md[1]);
        }
      }
    }

    const keyword = lines.find((s: string) => /起飞|出发|发车|始发|登机|开车|接机|送机|到达|抵达/.test(s) && /(\d{1,2})[:：](\d{2})/.test(s));
    const timeText = keyword !== undefined ? keyword : text;
    const time = TripScanner.matchGroups('(\\d{1,2})[:：](\\d{2})', timeText);
    if (time.length === 2) {
      const h = Number(time[0]);
      const m = Number(time[1]);
      if (h >= 0 && h <= 23 && m >= 0 && m <= 59) {
        guess.hour = h;
        guess.minute = m;
      }
    }

    if (flight.length > 0) {
      guess.kind = 'flight';
      const code = flight.replace(/\s/g, '').toUpperCase();
      const where = route.length === 2 ? ` ${route[0]}→${route[1]}` : (stations.length >= 2 ? ` ${stations[0]}→${stations[1]}` : '');
      guess.title = `航班 ${code}${where}`;
    } else if (train.length > 0) {
      guess.kind = 'train';
      const code = train.replace(/\s/g, '').toUpperCase();
      const where = stations.length >= 2 ? ` ${stations[0]}→${stations[1]}` : (route.length === 2 ? ` ${route[0]}→${route[1]}` : '');
      guess.title = `车次 ${code}${where}`;
    } else {
      guess.kind = 'other';
      const first = lines.length > 0 ? lines[0] : '';
      guess.title = first.length > 0 ? first.substring(0, 28) : '';
    }

    const parts: string[] = [];
    if (flight.length > 0) {
      parts.push('航班：' + flight.replace(/\s/g, '').toUpperCase());
    }
    if (train.length > 0) {
      parts.push('车次：' + train.replace(/\s/g, '').toUpperCase());
    }
    if (route.length === 2) {
      parts.push(`路线：${route[0]} → ${route[1]}`);
    }
    if (stations.length > 0) {
      parts.push('地点：' + stations.join('、'));
    }
    if (lines.length > 0) {
      parts.push('截图原文：\n' + lines.slice(0, 6).join('\n'));
    }
    guess.detail = parts.join('\n');
    return guess;
  }

  private static firstMatch(pattern: string, text: string): string {
    const groups = TripScanner.matchGroups(pattern, text);
    return groups.length > 0 ? groups[0] : '';
  }

  private static matchGroups(pattern: string, text: string): string[] {
    const regex = new RegExp(pattern);
    const found = regex.exec(text);
    if (found === null) {
      return [];
    }
    const out: string[] = [];
    for (let i = 1; i < found.length; i++) {
      out.push(found[i] === undefined ? '' : found[i]);
    }
    return out;
  }

  private static routeOf(text: string): string[] {
    const groups = TripScanner.matchGroups('([\\u4e00-\\u9fa5]{2,10})\\s*(?:→|->|—|至|到|飞往)\\s*([\\u4e00-\\u9fa5]{2,10})', text);
    return groups.length >= 2 ? [groups[0], groups[1]] : [];
  }

  private static stationsOf(text: string): string[] {
    const regex = new RegExp('([\\u4e00-\\u9fa5]{2,8}(?:站|机场|航站楼))', 'g');
    const out: string[] = [];
    let found = regex.exec(text);
    while (found !== null && out.length < 4) {
      out.push(found[1].replace(/站/g, ''));
      found = regex.exec(text);
    }
    return out;
  }
}
