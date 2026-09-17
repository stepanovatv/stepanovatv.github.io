import { validTimeZone, validDate, addDays, wallToInstant, zonedParts } from './timezone.js';

export const timeMinutes = time => Number(time.slice(0, 2)) * 60 + Number(time.slice(3));
export const timeString = minutes => `${String(Math.floor(minutes / 60)).padStart(2, '0')}:${String(minutes % 60).padStart(2, '0')}`;
const object = x => x !== null && typeof x === 'object' && !Array.isArray(x);
const time = x => typeof x === 'string' && /^(?:[01]\d|2[0-3]):[0-5]\d$/.test(x);
const exactKeys = (o, keys) => Object.keys(o).every(k => keys.includes(k)) && keys.every(k => Object.hasOwn(o, k));

export function slotTimes(schedule) {
  const result = [];
  for (let m = timeMinutes(schedule.dayStart); m < timeMinutes(schedule.dayEnd); m += schedule.slotDurationMinutes) result.push(timeString(m));
  return result;
}

export function validateSchedule(data) {
  const fail = () => { throw new TypeError('Invalid schedule.json'); };
  if (!object(data) || !exactKeys(data, ['version', 'sourceTimeZone', 'slotDurationMinutes', 'dayStart', 'dayEnd', 'updatedAt', 'days'])) fail();
  if (data.version !== 1 || !validTimeZone(data.sourceTimeZone) || !time(data.dayStart) || !time(data.dayEnd)) fail();
  const duration = data.slotDurationMinutes, span = timeMinutes(data.dayEnd) - timeMinutes(data.dayStart);
  if (!Number.isInteger(duration) || duration < 5 || duration > 240 || span <= 0 || span % duration !== 0) fail();
  if (typeof data.updatedAt !== 'string' || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z$/.test(data.updatedAt)
    || !validDate(data.updatedAt.slice(0, 10)) || !Number.isFinite(Date.parse(data.updatedAt))) fail();
  if (!object(data.days) || Object.keys(data.days).length > 10000) fail();
  const allowed = new Set(slotTimes(data));
  for (const [date, value] of Object.entries(data.days)) {
    if (!validDate(date) || !object(value) || !exactKeys(value, ['busy']) || !Array.isArray(value.busy)
      || new Set(value.busy).size !== value.busy.length || value.busy.some(t => !allowed.has(t))) fail();
    for (const t of value.busy) wallToInstant(date, t, data.sourceTimeZone);
  }
  return data;
}

export function parseSchedule(json) { return validateSchedule(JSON.parse(json)); }
export function serializeSchedule(data) { return JSON.stringify(validateSchedule(data), null, 2) + '\n'; }
export function isBusy(schedule, date, time) { return schedule.days[date]?.busy.includes(time) ?? false; }

export function buildWeek(schedule, monday, zone) {
  const dates = Array.from({ length: 7 }, (_, i) => addDays(monday, i));
  const byDate = new Map(dates.map(date => [date, []]));
  // Adjacent source dates are essential: a Monday in the visitor's timezone may
  // contain Sunday's or Tuesday's source slots. Largest IANA offset gap is 26h.
  for (let i = -2; i < 9; i++) {
    const sourceDate = addDays(monday, i);
    for (const time of slotTimes(schedule)) {
      let start;
      try { start = wallToInstant(sourceDate, time, schedule.sourceTimeZone); }
      catch (error) { if (error instanceof RangeError) continue; throw error; }
      const end = start + schedule.slotDurationMinutes * 60000;
      const local = zonedParts(start, zone), localEnd = zonedParts(end, zone);
      if (!byDate.has(local.date)) continue;
      byDate.get(local.date).push({ id: `${sourceDate}/${time}`, sourceDate, sourceTime: time,
        start, end, date: local.date, time: local.time, endDate: localEnd.date, endTime: localEnd.time,
        busy: isBusy(schedule, sourceDate, time) });
    }
  }
  for (const values of byDate.values()) values.sort((a, b) => a.start - b.start);
  const rows = [...new Set([...byDate.values()].flat().map(s => s.time))].sort();
  return { dates, byDate, rows };
}

export async function fetchSchedule(fetcher = fetch) {
  const response = await fetcher(`./schedule.json?v=${Date.now()}`, { cache: 'no-store', signal: AbortSignal.timeout(15000) });
  if (!response.ok) throw new Error('Schedule unavailable');
  return parseSchedule(await response.text());
}
