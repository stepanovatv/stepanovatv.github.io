import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { validateSchedule, parseSchedule, serializeSchedule, slotTimes, isBusy, buildWeek, fetchSchedule } from '../js/schedule.js';
import { wallToInstant, zonedParts, addDays, weekStart, offsetLabel } from '../js/timezone.js';
import { migrateLegacy } from '../scripts/migrate-legacy.mjs';
const fixture = () => ({ version: 1, sourceTimeZone: 'Asia/Yekaterinburg', slotDurationMinutes: 30, dayStart:'09:00', dayEnd:'22:00', updatedAt:'2026-09-17T10:30:00Z', days: { '2026-09-21': {busy:['09:00','13:00']} } });

test('shared JSON round trip and production schema', () => {
  const value = fixture(); assert.deepEqual(parseSchedule(serializeSchedule(value)), value);
  validateSchedule(JSON.parse(fs.readFileSync(new URL('../schedule.json', import.meta.url))));
});
test('26 configured slots, end is exclusive', () => {
  const times = slotTimes(fixture()); assert.equal(times.length, 26); assert.equal(times[0], '09:00'); assert.equal(times.at(-1),'21:30');
  assert.deepEqual(slotTimes({...fixture(), dayStart:'10:15', dayEnd:'11:15', slotDurationMinutes:15}), ['10:15','10:30','10:45','11:00']);
});
test('busy and implicit free are date specific', () => {
  assert.equal(isBusy(fixture(),'2026-09-21','09:00'), true);
  assert.equal(isBusy(fixture(),'2026-09-21','09:30'), false);
  assert.equal(isBusy(fixture(),'2026-09-28','09:00'), false);
});
test('Orenburg to Moscow uses IANA', () => {
  const instant = wallToInstant('2026-09-23','15:00','Asia/Yekaterinburg');
  assert.equal(new Date(instant).toISOString(), '2026-09-23T10:00:00.000Z');
  assert.equal(zonedParts(instant,'Europe/Moscow').time, '13:00');
});
test('previous day / previous month / previous year', () => {
  for (const [date, expected] of [['2026-09-23','2026-09-22'],['2026-10-01','2026-09-30'],['2027-01-01','2026-12-31']]) {
    const p = zonedParts(wallToInstant(date,'09:00','Asia/Yekaterinburg'),'America/Los_Angeles');
    assert.equal(p.date,expected); assert.ok(['20:00','21:00'].includes(p.time));
  }
});
test('next day / next month / next year', () => {
  for (const [date, expected] of [['2026-09-23','2026-09-24'],['2026-09-30','2026-10-01'],['2026-12-31','2027-01-01']]) {
    const p = zonedParts(wallToInstant(date,'21:30','Asia/Yekaterinburg'),'Pacific/Auckland'); assert.equal(p.date,expected);
  }
});
test('fractional offsets are preserved', () => {
  const instant = wallToInstant('2026-09-23','09:00','Asia/Yekaterinburg');
  assert.equal(zonedParts(instant,'Asia/Kathmandu').time, '09:45'); assert.equal(offsetLabel(instant,'Asia/Kathmandu'),'UTC+5:45');
});
test('Berlin DST changes with the date', () => {
  const winter = zonedParts(wallToInstant('2026-03-28','15:00','Asia/Yekaterinburg'),'Europe/Berlin');
  const summer = zonedParts(wallToInstant('2026-03-29','15:00','Asia/Yekaterinburg'),'Europe/Berlin');
  assert.equal(winter.time,'11:00'); assert.equal(summer.time,'12:00');
});
test('source DST gap rejects nonexistent time; fold picks first', () => {
  assert.throws(() => wallToInstant('2026-03-29','02:30','Europe/Berlin'), RangeError);
  assert.equal(new Date(wallToInstant('2026-10-25','02:30','Europe/Berlin')).toISOString(), '2026-10-25T00:30:00.000Z');
});
test('local week includes neighboring source dates and all 182 instants', () => {
  const value = fixture(); value.days['2026-09-22'] = {busy:['09:00']};
  const week = buildWeek(value,'2026-09-21','America/Los_Angeles');
  const slots = [...week.byDate.values()].flat(); assert.equal(slots.length,182); assert.equal(new Set(slots.map(s=>s.id)).size,182);
  const monday = week.byDate.get('2026-09-21'); assert.ok(monday.some(s=>s.sourceDate === '2026-09-22' && s.busy && s.time==='21:00'));
});
test('DST fold retains repeated wall times as distinct slots', () => {
  const week = buildWeek(fixture(),'2026-10-26','America/New_York');
  const repeated = week.byDate.get('2026-11-01').filter(s=>s.time==='01:00');
  assert.equal(repeated.length,2); assert.notEqual(repeated[0].id,repeated[1].id); assert.equal(repeated[1].start-repeated[0].start,3600000);
});
test('month, year, leap day and Monday arithmetic', () => {
  assert.equal(addDays('2026-12-31',1),'2027-01-01'); assert.equal(addDays('2024-02-28',1),'2024-02-29');
  assert.equal(weekStart('2027-01-01'),'2026-12-28'); assert.equal(weekStart('2026-09-20'),'2026-09-14');
});
test('invalid JSON, extra private fields, version, timezone, dates, slots, duplicates', () => {
  assert.throws(()=>parseSchedule('{'));
  for (const change of [ {version:2}, {sourceTimeZone:'UTC+5'}, {dayStart:'22:00'}, {slotDurationMinutes:0}, {slotDurationMinutes:17},
    {updatedAt:'2026-02-30T10:30:00Z'}, {days:{'2026-02-30':{busy:[]}}}, {days:{'2026-09-21':{busy:['22:00']}}},
    {days:{'2026-09-21':{busy:['09:00','09:00']}}}, {days:{'2026-09-21':{busy:[],name:'Private'}}}, {email:'private@example.com'} ]) {
    assert.throws(()=>validateSchedule({...fixture(),...change}), undefined, JSON.stringify(change));
  }
});
test('fetch cache busting and failed network / invalid data', async () => {
  let request;
  await fetchSchedule(async (url, opts) => { request={url,opts}; return {ok:true,text:async()=>JSON.stringify(fixture())}; });
  assert.match(request.url,/schedule\.json\?v=\d+/); assert.equal(request.opts.cache,'no-store');
  await assert.rejects(fetchSchedule(async()=>({ok:false})));
  await assert.rejects(fetchSchedule(async()=>({ok:true,text:async()=>'{'})));
  await assert.rejects(fetchSchedule(async()=>{throw new Error('Offline');}));
});
test('legacy migration preserves busy state for exactly two dated weeks', () => {
  const html = '<tr><th>13:30</th><td class="busy"></td>' + '<td></td>'.repeat(6) + '</tr>';
  const migrated = migrateLegacy(html, '2026-09-14', 2);
  assert.deepEqual(Object.keys(migrated.days), ['2026-09-14', '2026-09-21']);
  assert.deepEqual(migrated.days['2026-09-14'].busy, ['15:30']);
  assert.equal(isBusy(migrated, '2026-09-28', '15:30'), false);
});
