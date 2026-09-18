// All wall-clock conversions use the runtime's IANA timezone database.
const formatters = new Map();
const pad = n => String(n).padStart(2, '0');

export function validTimeZone(zone) {
  if (typeof zone !== 'string' || (!zone.includes('/') && zone !== 'UTC')) return false;
  try { new Intl.DateTimeFormat('en', { timeZone: zone }).format(); return true; }
  catch { return false; }
}

export function zonedParts(instant, zone) {
  if (!formatters.has(zone)) formatters.set(zone, new Intl.DateTimeFormat('en-GB', {
    timeZone: zone, calendar: 'gregory', numberingSystem: 'latn',
    year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit', second: '2-digit', hourCycle: 'h23'
  }));
  const parts = Object.fromEntries(formatters.get(zone).formatToParts(instant)
    .filter(p => p.type !== 'literal').map(p => [p.type, Number(p.value)]));
  return { ...parts, date: `${parts.year}-${pad(parts.month)}-${pad(parts.day)}`,
    time: `${pad(parts.hour)}:${pad(parts.minute)}` };
}

export function offsetMinutes(instant, zone) {
  const p = zonedParts(instant, zone);
  return (Date.UTC(p.year, p.month - 1, p.day, p.hour, p.minute, p.second)
    - Math.floor(Number(instant) / 1000) * 1000) / 60000;
}

export function offsetLabel(instant, zone) {
  const offset = offsetMinutes(instant, zone);
  return `UTC${offset < 0 ? '−' : '+'}${Math.floor(Math.abs(offset) / 60)}${offset % 60 ? ':' + pad(Math.abs(offset) % 60) : ''}`;
}

export function validDate(date) {
  if (typeof date !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(date)) return false;
  const value = new Date(`${date}T12:00:00Z`);
  return Number.isFinite(+value) && value.toISOString().slice(0, 10) === date && date >= '1900-01-01' && date <= '2100-12-31';
}

export function addDays(date, count) {
  const d = new Date(`${date}T12:00:00Z`);
  d.setUTCDate(d.getUTCDate() + count);
  return d.toISOString().slice(0, 10);
}

export function weekStart(date) {
  const day = new Date(`${date}T12:00:00Z`).getUTCDay();
  return addDays(date, -((day + 6) % 7));
}

export function currentWeek(zone, now = Date.now()) {
  return weekStart(zonedParts(now, zone).date);
}

export function clampToCurrentWeek(candidate, zone, now = Date.now()) {
  const earliest = currentWeek(zone, now);
  return candidate < earliest ? earliest : candidate;
}

// Resolve wall time by trying real IANA offsets around that date. Unlike a fixed
// numeric offset, this accounts for both sides of DST and fractional timezones.
// Model v1 has no "fold" field: ambiguous source wall times use the first occurrence.
export function wallToInstant(date, time, zone) {
  const [year, month, day] = date.split('-').map(Number);
  const [hour, minute] = time.split(':').map(Number);
  const wall = Date.UTC(year, month - 1, day, hour, minute);
  const offsets = new Set([-36, -12, 0, 12, 36].map(h => offsetMinutes(wall + h * 3600000, zone)));
  const candidates = [...offsets].map(o => wall - o * 60000).filter(t => {
    const p = zonedParts(t, zone);
    return p.date === date && p.time === time;
  });
  if (!candidates.length) throw new RangeError(`Nonexistent local time: ${date} ${time} ${zone}`);
  return Math.min(...candidates);
}

export function browserTimeZone() {
  try { return Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC'; }
  catch { return 'UTC'; }
}
