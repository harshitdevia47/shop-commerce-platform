import { randomUUID } from 'node:crypto';
import type { ShopNumbers, ShopSummary } from '../modules/subscriptions/shop-directory.js';
import type { OverviewRow, PaymentView, SubscriptionView } from '../modules/subscriptions/subscriptions.service.js';
import type { Status } from '../modules/subscriptions/status.js';
import { html, type Html } from './layout.js';

export const STATUS_LABEL: Record<Status, string> = {
  overdue: 'Overdue',
  paused: 'Paused',
  due: 'Due',
  due_soon: 'Due soon',
  paid: 'Paid',
  not_set_up: 'Not set up',
};

export const rupees = (paise: number) =>
  `₹${(paise / 100).toLocaleString('en-IN', { minimumFractionDigits: paise % 100 ? 2 : 0, maximumFractionDigits: 2 })}`;

export const niceDate = (day: string | null | undefined) =>
  day ? new Date(`${day.slice(0, 10)}T00:00:00Z`).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric', timeZone: 'UTC' }) : '—';

const badge = (status: Status) => html`<span class="badge s-${status}">${STATUS_LABEL[status]}</span>`;
const formId = () => html`<input type="hidden" name="formId" value="${randomUUID()}">`;
const num = (value: number | null | undefined) => (value === null || value === undefined ? '—' : value.toLocaleString('en-IN'));

export function homeView(rows: (OverviewRow & { numbers: ShopNumbers })[]): Html {
  const count = (status: Status) => rows.filter((r) => r.status === status).length;
  const tiles: Status[] = ['overdue', 'due', 'due_soon', 'paid', ...(count('paused') ? (['paused'] as Status[]) : []), ...(count('not_set_up') ? (['not_set_up'] as Status[]) : [])];
  return html`<h1>Shops</h1>
<div class="tiles">
  ${tiles.map((s) => html`<div class="tile"><span class="s-${s}">${STATUS_LABEL[s]}</span><b>${count(s)}</b></div>`)}
</div>
<div class="card">
  ${rows.length === 0 ? html`<p class="muted">No shops yet. Add one with <code>npm run new-shop</code> on the laptop.</p>` : ''}
  <ul class="list">
    ${rows.map(
      (r) => html`<li><a href="/shops/${r.shop.id}">
        <span><strong>${r.shop.name}</strong><br><span class="muted small">${
          r.subscription ? html`${rupees(r.subscription.feePaise)}/month · due ${niceDate(r.subscription.nextDueDate)}` : 'No subscription yet'
        } · ${num(r.numbers.customers?.total)} customers · ${num(r.numbers.month?.orders)} orders this month</span></span>
        ${badge(r.status)}
      </a></li>`,
    )}
  </ul>
</div>`;
}

export interface ShopPageModel {
  shop: ShopSummary;
  subscription: SubscriptionView | null;
  payments: PaymentView[];
  status: Status;
  numbers: ShopNumbers;
  today: string;
  payTo?: string;
  notice?: string;
  error?: string;
  defaultFeeRupees?: number;
}

const DONE_TEXT: Record<string, string> = {
  setup: 'Subscription set up.',
  edit: 'Saved.',
  paid: 'Payment saved. The next due date moved ahead and orders are on.',
  extend: 'Extended by 7 days.',
  pause: 'Online orders are paused for this shop.',
  resume: 'Online orders are on again.',
  checklist: 'Checklist saved.',
  repeat: 'That form was already sent; nothing changed.',
};
export const doneText = (key: unknown) => (typeof key === 'string' ? DONE_TEXT[key] : undefined);

function remindLink(m: ShopPageModel): string | null {
  const phone = (m.numbers.owner?.phone ?? m.shop.contact.whatsapp ?? m.shop.contact.phone).replace(/\D/g, '');
  if (!m.subscription || !phone) return null;
  const lines = [
    `Hello from the ${m.shop.name} app team.`,
    `Your monthly app subscription of ${rupees(m.subscription.feePaise)} was due on ${niceDate(m.subscription.nextDueDate)}.`,
    m.payTo ? `Please pay by UPI to ${m.payTo} and send the screenshot here.` : 'Please pay and send the screenshot here.',
    'Thank you!',
  ];
  return `https://wa.me/${phone}?text=${encodeURIComponent(lines.join('\n'))}`;
}

function setupForm(m: ShopPageModel): Html {
  return html`<h2>Set up the subscription</h2>
<div class="card">
  <form class="stack" method="post" action="/shops/${m.shop.id}/setup">
    ${formId()}
    <label>Monthly fee (₹)<input name="fee" inputmode="decimal" required value="${m.defaultFeeRupees ?? ''}"></label>
    <label>Due day of the month (1–28)<input name="dueDay" inputmode="numeric" required value="5"></label>
    <button class="primary" type="submit">Set up</button>
  </form>
  <p class="small muted">The first due date is the next due day from today.</p>
</div>`;
}

function subscriptionCard(m: ShopPageModel, sub: SubscriptionView): Html {
  const remind = remindLink(m);
  return html`<h2>Subscription</h2>
<div class="card">
  <dl>
    <dt>Status</dt><dd>${badge(m.status)}</dd>
    <dt>Monthly fee</dt><dd>${rupees(sub.feePaise)}</dd>
    <dt>Due day</dt><dd>${sub.dueDay} of every month</dd>
    <dt>Next due</dt><dd>${niceDate(sub.nextDueDate)}</dd>
    ${sub.extendedUntil ? html`<dt>Extended until</dt><dd>${niceDate(sub.extendedUntil)}</dd>` : ''}
    ${sub.pausedAt ? html`<dt>Paused since</dt><dd>${niceDate(sub.pausedAt.toISOString())}</dd>` : ''}
  </dl>
</div>

<h2>Mark paid</h2>
<div class="card">
  <form class="stack" method="post" action="/shops/${m.shop.id}/paid">
    ${formId()}
    <label>Amount (₹)<input name="amount" inputmode="decimal" required value="${(sub.feePaise / 100).toString()}"></label>
    <label>Months covered<input name="months" inputmode="numeric" required value="1"></label>
    <label>UPI reference (optional)<input name="upiRef" maxlength="40"></label>
    <label>Paid on<input type="date" name="paidOn" required value="${m.today}"></label>
    <label>Note (optional)<input name="note" maxlength="200"></label>
    <button class="primary" type="submit">Save payment</button>
  </form>
</div>

<h2>Actions</h2>
<div class="card row">
  ${remind ? html`<a class="button" href="${remind}" target="_blank" rel="noopener noreferrer">Remind on WhatsApp</a>` : ''}
  <form method="post" action="/shops/${m.shop.id}/extend">${formId()}<button type="submit">Extend 7 days</button></form>
  ${
    sub.pausedAt
      ? html`<form method="post" action="/shops/${m.shop.id}/resume">${formId()}<button class="primary" type="submit">Resume orders</button></form>`
      : html`<a class="button danger" href="/shops/${m.shop.id}/pause">Pause orders…</a>`
  }
</div>

<details class="card"><summary>Change fee or due day</summary>
  <form class="stack" method="post" action="/shops/${m.shop.id}/edit">
    ${formId()}
    <label>Monthly fee (₹)<input name="fee" inputmode="decimal" required value="${(sub.feePaise / 100).toString()}"></label>
    <label>Due day of the month (1–28)<input name="dueDay" inputmode="numeric" required value="${sub.dueDay}"></label>
    <button type="submit">Save</button>
  </form>
</details>

<h2>Payments</h2>
<div class="card">
  ${
    m.payments.length === 0
      ? html`<p class="muted">No payments recorded yet.</p>`
      : html`<table><thead><tr><th>Paid on</th><th>Amount</th><th>Months</th><th>UPI ref</th><th>Note</th></tr></thead><tbody>
        ${m.payments.map((p) => html`<tr><td>${niceDate(p.paidOn)}</td><td>${rupees(p.amountPaise)}</td><td>${p.months}</td><td>${p.upiRef ?? ''}</td><td>${p.note ?? ''}</td></tr>`)}
      </tbody></table>`
  }
</div>`;
}

function checklist(m: ShopPageModel, sub: SubscriptionView | null): Html {
  const item = (done: boolean, text: string) => html`<div class="check">${done ? '✅' : '⬜'} ${text}</div>`;
  return html`<h2>Launch checklist</h2>
<div class="card">
  ${item(true, 'Shop created')}
  ${item(!!m.numbers.owner?.hasLoggedIn, 'Owner logged in')}
  ${item((m.numbers.products ?? 0) > 0, 'First product added')}
  ${item(!!m.numbers.month?.lastOrderAt, 'First order')}
  ${
    sub
      ? html`<form method="post" action="/shops/${m.shop.id}/checklist">
          <label class="check"><input type="checkbox" name="logoDone" value="1" ${sub.logoDone ? 'checked' : ''}> Real logo added</label>
          <label class="check"><input type="checkbox" name="playDone" value="1" ${sub.playDone ? 'checked' : ''}> App on Play Store</label>
          <input type="hidden" name="sent" value="1">
          <button type="submit">Save checklist</button>
        </form>`
      : html`<p class="small muted">Set up the subscription to tick the logo and Play Store steps.</p>`
  }
</div>`;
}

export function shopView(m: ShopPageModel): Html {
  const sub = m.subscription;
  const n = m.numbers;
  return html`<p class="small"><a href="/">← All shops</a></p>
<h1>${m.shop.name}</h1>
<p class="muted">${m.shop.slug} · ${m.shop.businessType}${m.shop.isActive ? '' : ' · inactive'}</p>
${m.notice ? html`<p class="card notice">${m.notice}</p>` : ''}
${m.error ? html`<p class="card notice error">${m.error}</p>` : ''}

<div class="card"><dl>
  <dt>Owner</dt><dd>${n.owner?.name ?? '—'} ${n.owner?.phone ?? ''}</dd>
  <dt>Shop phone</dt><dd>${m.shop.contact.phone}</dd>
  <dt>Address</dt><dd>${m.shop.contact.address}</dd>
</dl></div>

${sub ? subscriptionCard(m, sub) : setupForm(m)}

<h2>App numbers</h2>
<div class="tiles">
  <div class="tile">Customers<b>${num(n.customers?.total)}</b><span class="small muted">${num(n.customers?.newSince)} new this month</span></div>
  <div class="tile">Active this month<b>${num(n.customers?.activeSince)}</b></div>
  <div class="tile">Orders this month<b>${num(n.month?.orders)}</b></div>
  <div class="tile">Sales this month<b>${n.month ? rupees(n.month.salesPaise) : '—'}</b></div>
  <div class="tile">Products<b>${num(n.products)}</b></div>
</div>
<p class="small muted">Last order: ${n.month?.lastOrderAt ? niceDate(n.month.lastOrderAt) : 'none yet'}</p>

${checklist(m, sub)}`;
}

export function pauseConfirmView(shop: ShopSummary): Html {
  return html`<p class="small"><a href="/shops/${shop.id}">← ${shop.name}</a></p>
<h1>Pause online orders?</h1>
<div class="card">
  <p>Customers of <strong>${shop.name}</strong> will not be able to place new orders in the app. They will see
  "This shop is not taking online orders right now. Please call the shop."</p>
  <p>The owner can still log in, finish open orders and see that the subscription is unpaid. When you save a
  payment, orders turn on again automatically.</p>
  <div class="row">
    <form method="post" action="/shops/${shop.id}/pause">${formId()}<button class="danger" type="submit">Pause orders</button></form>
    <a class="button" href="/shops/${shop.id}">Cancel</a>
  </div>
</div>`;
}
