import fs from 'node:fs';
import { fileURLToPath } from 'node:url';
import { addDays, wallToInstant, zonedParts, validDate } from '../js/timezone.js';
import { validateSchedule, serializeSchedule } from '../js/schedule.js';

// One-time migration of the old undated, Moscow-time HTML. No recurrence is
// introduced: every copied slot gets a concrete date in the requested weeks.
export function migrateLegacy(html, monday, weeks) {
  if (!validDate(monday) || !Number.isInteger(weeks) || weeks < 1 || weeks > 52) throw new Error('Invalid migration range');
  const schedule = { version: 1, sourceTimeZone: 'Asia/Yekaterinburg', slotDurationMinutes: 30,
    dayStart: '09:00', dayEnd: '22:00', updatedAt: new Date().toISOString(), days: {} };
  let rows = 0;
  for (const row of html.matchAll(/<tr\b[^>]*>([\s\S]*?)<\/tr>/gi)) {
    const time = row[1].match(/<th[^>]*>\s*(\d{2}:\d{2})\s*<\/th>/i)?.[1];
    if (!time) continue;
    const cells = [...row[1].matchAll(/<td\b([^>]*)>[\s\S]*?<\/td>/gi)];
    if (cells.length !== 7) throw new Error('Expected seven days'); rows++;
    for (let week = 0; week < weeks; week++) for (let day = 0; day < 7; day++) {
      const classes = cells[day][1].match(/class\s*=\s*["']([^"']*)["']/i)?.[1].split(/\s+/) || [];
      if (!classes.includes('busy')) continue;
      const sourceDate = addDays(monday, week * 7 + day);
      const converted = zonedParts(wallToInstant(sourceDate, time, 'Europe/Moscow'), schedule.sourceTimeZone);
      (schedule.days[converted.date] ||= { busy: [] }).busy.push(converted.time);
    }
  }
  if (!rows) throw new Error('No schedule rows');
  for (const day of Object.values(schedule.days)) day.busy = [...new Set(day.busy)].sort();
  return validateSchedule(schedule);
}
if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const [file, monday, weeks] = process.argv.slice(2);
  process.stdout.write(serializeSchedule(migrateLegacy(fs.readFileSync(file, 'utf8'), monday, Number(weeks))));
}
