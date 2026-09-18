import { browserTimeZone, zonedParts, weekStart, addDays, offsetLabel, validTimeZone } from './timezone.js';
import { buildWeek, fetchSchedule } from './schedule.js';
import { ru as t } from './strings.js';

const $ = id => document.getElementById(id);
const browserZone = browserTimeZone();
let zone = browserZone, monday = weekStart(zonedParts(Date.now(), zone).date);
let activeDate = zonedParts(Date.now(), zone).date, data, week, selected = null;
const dateFormat = (date, options) => new Intl.DateTimeFormat('ru-RU', { timeZone: 'UTC', ...options }).format(new Date(`${date}T12:00:00Z`));
const slotsByID = new Map();
const selector = $('timezone');
function option(label, value) { const o = document.createElement('option'); o.value = value; o.textContent = label; selector.append(o); }
option('Автоматически', 'auto');
option('Оренбург', 'Asia/Yekaterinburg');
option('Москва', 'Europe/Moscow');
option(`Часовая зона браузера — ${browserZone}`, browserZone);
const zones = Intl.supportedValuesOf ? Intl.supportedValuesOf('timeZone') : ['Asia/Tbilisi', 'Europe/London', 'Europe/Berlin', 'America/New_York', 'Asia/Kolkata', 'Asia/Tokyo', 'Pacific/Auckland'];
for (const z of [...new Set([...zones, 'UTC'])].sort()) if (![browserZone, 'Asia/Yekaterinburg', 'Europe/Moscow'].includes(z)) option(z, z);
try {
  const saved = localStorage.getItem('availability-timezone');
  if (saved && validTimeZone(saved)) { if (![...selector.options].some(o => o.value === saved)) option(saved, saved); selector.value = saved; zone = saved; }
} catch { /* Storage can be disabled in private browsing. */ }
monday = weekStart(zonedParts(Date.now(), zone).date); activeDate = zonedParts(Date.now(), zone).date;

function zoneMessage() {
  const automatic = selector.value === 'auto';
  const offset = offsetLabel(Date.now(), zone);
  const message = $('timezone-message');
  message.textContent = `${zone} · ${offset}`;
  message.title = `${automatic ? t.localTime : t.chosenTime} ${zone} (${offset}).`;
  message.setAttribute('aria-label', message.title);
}
zoneMessage();

function slotButton(slot, mobile, row, col) {
  const button = document.createElement('button');
  button.type = 'button'; button.className = `slot${slot.busy ? ' busy' : ''}`;
  button.dataset.id = slot.id; button.dataset.date = slot.date;
  if (!mobile) { button.dataset.row = row; button.dataset.col = col; }
  button.setAttribute('aria-pressed', String(slot.id === selected));
  const state = slot.busy ? t.busy : t.free;
  const range = `${slot.time}–${slot.endTime}${slot.endDate !== slot.date ? ` (${dateFormat(slot.endDate, { day: 'numeric', month: 'short' })})` : ''}`;
  const offset = offsetLabel(slot.start, zone);
  const full = `${state}. ${dateFormat(slot.date, { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })}. ${range}. ${zone} (${offset}).`;
  button.setAttribute('aria-label', full); button.title = full;
  if (mobile) { const label = document.createElement('span'); label.className = 'slot-time'; label.textContent = range; button.append(label); }
  const stateLabel = document.createElement('span'); stateLabel.className = 'slot-state';
  stateLabel.textContent = slot.busy ? '−' : '✓';
  stateLabel.setAttribute('aria-hidden', 'true'); button.append(stateLabel);
  // Repeated target wall times during a fall-back retain their distinct instants.
  const repeated = week.byDate.get(slot.date).filter(s => s.time === slot.time).length > 1;
  if (repeated) { const badge = document.createElement('small'); badge.textContent = offset; button.append(badge); }
  return button;
}

function showDetails(slot) {
  const panel = $('slot-detail'); panel.replaceChildren();
  panel.classList.toggle('has-selection', Boolean(slot));
  if (!slot) { panel.textContent = t.selectHint; return; }
  const top = document.createElement('div'); top.className = 'detail-top';
  const state = document.createElement('strong'); state.textContent = `${slot.busy ? '−' : '✓'} ${slot.busy ? t.busy : t.free}`;
  const date = document.createElement('span'); date.textContent = `${dateFormat(slot.date, { weekday: 'long', day: 'numeric', month: 'long' })} · ${slot.time}–${slot.endTime}${slot.endDate !== slot.date ? ' (' + dateFormat(slot.endDate, { day: 'numeric', month: 'long' }) + ')' : ''}`;
  top.append(state, date);
  const meta = document.createElement('div'); meta.className = 'detail-meta';
  meta.textContent = `${zone} (${offsetLabel(slot.start, zone)}${offsetLabel(slot.end, zone) !== offsetLabel(slot.start, zone) ? ' → ' + offsetLabel(slot.end, zone) : ''}) · ${data.slotDurationMinutes} ${t.duration}.`;
  panel.append(top, meta);
  const close = document.createElement('button'); close.className = 'close-detail'; close.textContent = 'Снять выделение';
  close.onclick = () => { selected = null; document.querySelectorAll('.slot').forEach(b => b.setAttribute('aria-pressed', 'false')); showDetails(null); };
  panel.append(close);
}

function renderDay() {
  $('mobile-date').textContent = dateFormat(activeDate, { weekday: 'long', day: 'numeric', month: 'long' });
  const slots = week.byDate.get(activeDate) || [];
  $('day-slots').replaceChildren(...slots.map(s => slotButton(s, true)));
  if (!slots.length) $('day-slots').textContent = t.noSlots;
  for (const button of $('day-tabs').children) button.setAttribute('aria-pressed', String(button.dataset.date === activeDate));
}

function render() {
  if (!data) return;
  week = buildWeek(data, monday, zone); slotsByID.clear(); selected = null;
  for (const slots of week.byDate.values()) for (const slot of slots) slotsByID.set(slot.id, slot);
  const today = zonedParts(Date.now(), zone).date;
  if (!week.dates.includes(activeDate)) activeDate = week.dates.includes(today) ? today : monday;
  $('week-label').textContent = `${dateFormat(monday, { day: 'numeric', month: 'short' })} — ${dateFormat(addDays(monday, 6), { day: 'numeric', month: 'short' })}`;
  $('month-label').textContent = dateFormat(monday, { month: 'long', year: 'numeric' });
  $('slot-duration').textContent = `Окна по ${data.slotDurationMinutes} ${t.duration}`;
  $('updated').textContent = `${t.updated}: ${new Intl.DateTimeFormat('ru-RU', { timeZone: zone, day: 'numeric', month: 'long', hour: '2-digit', minute: '2-digit' }).format(new Date(data.updatedAt))}`;
  $('day-tabs').replaceChildren(...week.dates.map(date => {
    const button = document.createElement('button'); button.dataset.date = date;
    button.className = date === today ? 'is-today' : '';
    button.setAttribute('aria-label', dateFormat(date, { weekday: 'long', day: 'numeric', month: 'long' }));
    button.textContent = dateFormat(date, { weekday: 'short' });
    const day = document.createElement('b'); day.textContent = dateFormat(date, { day: 'numeric' }); button.append(day); return button;
  }));
  const table = $('week-table'); table.querySelector('thead')?.remove(); table.querySelector('tbody')?.remove();
  const thead = document.createElement('thead'), header = document.createElement('tr');
  const corner = document.createElement('th'); corner.scope = 'col'; corner.textContent = 'Время'; header.append(corner);
  week.dates.forEach((date, col) => {
    const th = document.createElement('th'); th.scope = 'col'; th.dataset.col = col; th.className = date === today ? 'today' : '';
    th.textContent = dateFormat(date, { weekday: 'short' });
    const number = document.createElement('b'); number.textContent = dateFormat(date, { day: '2-digit', month: '2-digit' }); th.append(number); header.append(th);
  }); thead.append(header);
  const tbody = document.createElement('tbody');
  week.rows.forEach((time, row) => {
    const tr = document.createElement('tr'); tr.dataset.row = row;
    const th = document.createElement('th'); th.scope = 'row'; th.textContent = time; tr.append(th);
    week.dates.forEach((date, col) => {
      const td = document.createElement('td'); td.dataset.col = col;
      const slots = week.byDate.get(date).filter(s => s.time === time);
      if (slots.length) td.append(...slots.map(s => slotButton(s, false, row, col)));
      else { const blank = document.createElement('span'); blank.className = 'outside'; blank.textContent = '·'; blank.setAttribute('aria-label', t.outside); td.append(blank); }
      tr.append(td);
    }); tbody.append(tr);
  }); table.append(thead, tbody);
  // Roving focus avoids hundreds of Tab stops; arrows move inside the week.
  const buttons = table.querySelectorAll('button'); buttons.forEach((b, i) => b.tabIndex = i === 0 ? 0 : -1);
  renderDay(); showDetails(null); zoneMessage();
}

function highlight(button) {
  document.querySelectorAll('.cross,.hovered').forEach(e => e.classList.remove('cross', 'hovered'));
  if (!button || button.dataset.col === undefined) return;
  button.classList.add('hovered');
  $('week-table').querySelectorAll(`[data-col="${button.dataset.col}"]`).forEach(e => { if (e.tagName !== 'BUTTON') e.classList.add('cross'); });
  button.closest('tr').querySelectorAll('th,td').forEach(e => e.classList.add('cross'));
}
$('schedule-content').addEventListener('click', event => {
  const button = event.target.closest('.slot'); if (!button) return;
  selected = selected === button.dataset.id ? null : button.dataset.id;
  document.querySelectorAll('.slot').forEach(b => b.setAttribute('aria-pressed', String(b.dataset.id === selected)));
  showDetails(slotsByID.get(selected));
});
$('day-tabs').addEventListener('click', event => {
  const b = event.target.closest('button'); if (!b) return; activeDate = b.dataset.date; selected = null;
  document.querySelectorAll('.slot').forEach(s => s.setAttribute('aria-pressed', 'false')); renderDay(); showDetails(null);
});
$('week-table').addEventListener('pointerover', event => { if (event.pointerType !== 'touch') highlight(event.target.closest('.slot')); });
$('week-table').addEventListener('pointerleave', () => highlight(null));
$('week-table').addEventListener('focusin', event => { if (event.target.matches('.slot')) { highlight(event.target); showDetails(slotsByID.get(event.target.dataset.id)); } });
$('week-table').addEventListener('focusout', () => highlight(null));
$('week-table').addEventListener('keydown', event => {
  const b = event.target.closest('.slot'); if (!b) return;
  const all = [...$('week-table').querySelectorAll('button')];
  let row = Number(b.dataset.row), col = Number(b.dataset.col), target;
  if (event.key === 'Escape') { selected = null; document.querySelectorAll('.slot').forEach(s => s.setAttribute('aria-pressed', 'false')); showDetails(null); return; }
  if (event.key === 'Home') target = all[0];
  else if (event.key === 'End') target = all.at(-1);
  else if (['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'].includes(event.key)) {
    const dr = event.key === 'ArrowUp' ? -1 : event.key === 'ArrowDown' ? 1 : 0;
    const dc = event.key === 'ArrowLeft' ? -1 : event.key === 'ArrowRight' ? 1 : 0;
    const sameCell = all.filter(s => s.dataset.row === b.dataset.row && s.dataset.col === b.dataset.col);
    // Reach both occurrences of a repeated DST wall time using vertical arrows.
    if (dr) target = sameCell[sameCell.indexOf(b) + dr];
    while (!target) { row += dr; col += dc; if (row < 0 || row >= week.rows.length || col < 0 || col > 6) break;
      target = all.find(s => Number(s.dataset.row) === row && Number(s.dataset.col) === col); }
  } else return;
  event.preventDefault(); if (target) { all.forEach(s => s.tabIndex = -1); target.tabIndex = 0; target.focus(); }
});
selector.addEventListener('change', () => {
  zone = selector.value === 'auto' ? browserZone : selector.value;
  try { if (selector.value === 'auto') localStorage.removeItem('availability-timezone'); else localStorage.setItem('availability-timezone', zone); } catch {}
  render(); zoneMessage();
});
function navigate(days) { const next = addDays(monday, days); if (next < '1901-01-01' || next > '2099-12-20') return; monday = next; render(); }
$('previous-week').onclick = () => navigate(-7); $('next-week').onclick = () => navigate(7);
$('current-week').onclick = () => { activeDate = zonedParts(Date.now(), zone).date; monday = weekStart(activeDate); render(); };
async function load() {
  $('schedule').setAttribute('aria-busy', 'true'); $('load-status').hidden = false; $('load-status').textContent = t.loading;
  $('schedule-content').hidden = true; $('retry').hidden = true;
  try { data = await fetchSchedule(); render(); $('schedule-content').hidden = false; $('load-status').hidden = true; }
  catch { $('load-status').textContent = t.error; $('retry').hidden = false; }
  finally { $('schedule').setAttribute('aria-busy', 'false'); }
}
$('retry').onclick = load; load();
