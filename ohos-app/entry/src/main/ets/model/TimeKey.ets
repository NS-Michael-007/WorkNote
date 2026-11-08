/**
 * 时间与日期键：dateKey 是「本地日历日」，remindAt 是绝对毫秒。
 * 两者打架时以 remindAt 为准，不自动改 dateKey（契约规定）。
 */

function pad2(n: number): string {
  return n < 10 ? `0${n}` : `${n}`;
}

/** 毫秒时间戳 → 本地日历日 yyyy-MM-dd */
export function dateKeyOf(ts: number): string {
  const d = new Date(ts);
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`;
}

export function todayKey(): string {
  return dateKeyOf(Date.now());
}

/** yyyy-MM-dd 是否为真实存在的日期（挡掉 2026-02-30 这类） */
export function isValidDateKey(key: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(key)) {
    return false;
  }
  const y = Number(key.substring(0, 4));
  const m = Number(key.substring(5, 7));
  const day = Number(key.substring(8, 10));
  if (y < 2000 || y > 2100 || m < 1 || m > 12 || day < 1) {
    return false;
  }
  const daysInMonth = new Date(y, m, 0).getDate();
  return day <= daysInMonth;
}

/** 月份加一天时把小月夹到月末：MONTHLY 循环用 */
export function clampToMonthEnd(year: number, month: number, day: number): number {
  const daysInMonth = new Date(year, month, 0).getDate();
  return day > daysInMonth ? daysInMonth : day;
}

/** 一次性把累计到期的循环提醒推到下一次（不做无限循环，最多 400 次防死循环） */
export function nextOccurrence(ts: number, loopType: string): number {
  const d = new Date(ts);
  if (loopType === 'DAILY') {
    return ts + 24 * 60 * 60 * 1000;
  }
  if (loopType === 'WEEKLY') {
    return ts + 7 * 24 * 60 * 60 * 1000;
  }
  if (loopType === 'MONTHLY') {
    const y = d.getFullYear();
    const m = d.getMonth() + 1;
    const day = d.getDate();
    const nextY = m === 12 ? y + 1 : y;
    const nextM = m === 12 ? 1 : m + 1;
    const clamped = clampToMonthEnd(nextY, nextM, day);
    return new Date(nextY, nextM - 1, clamped, d.getHours(), d.getMinutes(), 0).getTime();
  }
  return 0;
}
