/**
 * Privacy policy and terms of use, one page per shop (Google Play needs a public privacy policy URL
 * for every app). Written for what the platform actually collects; keep in sync when that changes.
 * Plain HTML, no scripts, no external assets.
 */
import type { RuntimeConfig } from '@qc/config-schema';

/** The platform operator (the business that runs the apps for the shops). From env; may be missing in dev. */
export interface LegalOperator {
  name?: string;
  email?: string;
  /** City whose courts have jurisdiction, e.g. "Bhavnagar, Gujarat". */
  city?: string;
  /** Date the current text applies from, YYYY-MM-DD. */
  effectiveDate?: string;
}

const escape = (text: string) =>
  text.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]!);

/** Missing operator details are shown marked, so they are noticed before publishing. */
const value = (text: string | undefined, label: string) =>
  text ? escape(text) : `<mark>[${escape(label)} not set]</mark>`;

function formatDate(iso: string | undefined): string {
  if (!iso) return value(undefined, 'effective date');
  const date = new Date(`${iso}T00:00:00Z`);
  return Number.isNaN(date.getTime())
    ? escape(iso)
    : date.toLocaleDateString('en-IN', { day: 'numeric', month: 'long', year: 'numeric', timeZone: 'UTC' });
}

function page(title: string, shopName: string, body: string): string {
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${escape(title)} · ${escape(shopName)}</title>
<style>
  :root { color-scheme: light dark; }
  body { font: 16px/1.6 system-ui, -apple-system, "Segoe UI", Roboto, "Noto Sans", sans-serif; margin: 0; padding: 24px 16px 48px; background: Canvas; color: CanvasText; }
  main { max-width: 760px; margin: 0 auto; }
  h1 { font-size: 1.6rem; line-height: 1.25; margin: 0 0 4px; }
  h2 { font-size: 1.15rem; margin: 28px 0 6px; }
  p, li { margin: 6px 0; }
  ul { padding-left: 22px; }
  .meta { opacity: .75; margin-bottom: 20px; }
  mark { padding: 0 4px; }
  a { color: LinkText; }
</style>
</head>
<body><main>
${body}
</main></body>
</html>`;
}

interface Ctx {
  shop: RuntimeConfig['shop'];
  features: RuntimeConfig['features'];
  payments: RuntimeConfig['payments'];
  returnsWindow: number;
  operator: LegalOperator;
  termsUrl: string;
  privacyUrl: string;
}

function contactBlock({ shop, operator }: Ctx): string {
  const c = shop.contact;
  return `<ul>
  <li><strong>${escape(shop.name)}</strong> (the shop): ${escape(c.address)}. Phone ${escape(c.phone)}${c.whatsapp && c.whatsapp !== c.phone ? `, WhatsApp ${escape(c.whatsapp)}` : ''}.</li>
  <li><strong>${value(operator.name, 'operator name')}</strong> (runs the app for the shop): ${value(operator.email, 'contact email')}.</li>
</ul>`;
}

export function privacyPolicyHtml(ctx: Ctx): string {
  const { shop, features, payments, operator } = ctx;
  const name = escape(shop.name);
  const photos = [
    features.prescriptionUpload && 'prescriptions',
    features.handwrittenListUpload && 'photos of handwritten shopping lists',
    features.returns && 'photos for return requests',
  ].filter(Boolean) as string[];

  return page(
    'Privacy policy',
    shop.name,
    `<h1>Privacy policy</h1>
<p class="meta">${name} app · Effective ${formatDate(operator.effectiveDate)}</p>

<p>This policy explains what information the ${name} app collects, why, who can see it, how long it is
kept and what you can do about it. The app is the online ordering service of ${name} (the shop). It is
built and run for the shop by ${value(operator.name, 'operator name')} (the operator). The shop decides what
happens with your orders; the operator keeps the service running and handles data only to provide it.</p>

<h2>What we collect</h2>
<ul>
  <li><strong>Mobile number</strong>: to log you in with a one-time code and to contact you about orders.</li>
  <li><strong>Name and delivery addresses</strong>, including the map location of an address if you add it: to deliver orders.</li>
  <li><strong>Orders</strong>: items, prices, delivery or pickup, chosen time slot, notes you write, order status and history.</li>
  <li><strong>Payments</strong>: the payment method, amount and status${payments.upi.enabled ? ', and the UPI transaction reference (UTR) you enter' : ''}${payments.razorpay.enabled ? '. Online payments are handled by Razorpay; card, bank and UPI details are entered with Razorpay and are not stored by us' : ''}.</li>
  ${photos.length ? `<li><strong>Photos you add</strong>: ${photos.join(', ')}. Only you and the shop's team can open them.</li>` : ''}
  <li><strong>Device information</strong>: a notification token (to send order updates to your phone), the app language and basic technical logs (time, IP address, errors) used for security and to fix problems.</li>
  <li><strong>Delivery staff location</strong>: if you work as a delivery person for the shop, your phone's location is shared while you are carrying an order (with a visible notification), so the customer can see how far away the order is. It is not collected at other times.</li>
</ul>
<p>We do not collect your contacts, messages, files or location as a customer. The app has no advertising and no tracking for advertising.</p>

<h2>How it is used</h2>
<ul>
  <li>To log you in, take and deliver your orders, collect payment and handle cancellations and returns.</li>
  <li>To send you order updates (notifications, and the login code by WhatsApp or SMS).</li>
  <li>To keep the service secure (for example limiting repeated login attempts) and to fix problems.</li>
  <li>To give the shop sales reports (totals per day and best-selling products).</li>
</ul>
<p>We do not sell your information and do not use it for advertising.</p>

<h2>Who can see it</h2>
<ul>
  <li><strong>The shop's owner and staff</strong> see your orders, name, phone number and delivery address.</li>
  <li><strong>The delivery person</strong> assigned to your order sees your name, phone number, address and the amount to collect.</li>
  <li><strong>Service providers</strong> that the service needs, only for that purpose: the server hosting company; Meta (WhatsApp) or an SMS company to send your login code; Google Firebase to deliver notifications${payments.razorpay.enabled ? '; Razorpay to process online payments' : ''}. Maps open in the Google Maps app or website, under Google's own policy.</li>
  <li>Authorities, when the law requires it.</li>
</ul>
<p>Each shop's data is kept separate. Another shop using the same service cannot see your account or orders, and an account at another shop is a separate account.</p>

<h2>How long it is kept</h2>
<ul>
  <li>Your account and addresses: until you delete your account.</li>
  <li>Orders and payment records: as long as the shop needs them for its accounts and as long as tax and accounting law requires, even after the account is deleted. Your name and phone number are removed from them where the law allows.</li>
  <li>Login codes expire after 5 minutes. Technical logs are kept for a short time. Backups are overwritten within about two weeks.</li>
</ul>

<h2>Security</h2>
<p>All connections use encryption (HTTPS). Login codes are stored only in scrambled (hashed) form. Each person
sees only what their role needs, and private photos are only shown after checking who is asking. No system is
perfectly secure, but we work to protect your information and will inform you as the law requires if it is affected.</p>

<h2>Your choices and rights</h2>
<ul>
  <li><strong>See and correct</strong> your name and addresses in the app (Account).</li>
  <li><strong>Delete your account</strong>: from the app (Account), or by asking the shop or the operator using the contacts below. We confirm the deletion; order records are kept as described above.</li>
  <li><strong>Turn off notifications</strong> in your phone's settings.</li>
  <li>Ask questions or complain about how your information is handled using the contacts below. Under India's Digital Personal Data Protection Act, 2023 you may also approach the Data Protection Board of India.</li>
</ul>

<h2>Children</h2>
<p>The app is meant for people aged 18 and over. We do not knowingly collect information from children.</p>

<h2>Changes</h2>
<p>If this policy changes, the new version is published at this address with a new effective date. Important changes are also shown in the app.</p>

<h2>Contact (grievances)</h2>
${contactBlock(ctx)}
<p>See also the <a href="${escape(ctx.termsUrl)}">terms of use</a>.</p>`,
  );
}

export function termsHtml(ctx: Ctx): string {
  const { shop, features, payments, operator } = ctx;
  const name = escape(shop.name);
  const methods = [payments.cod && 'cash on delivery', payments.upi.enabled && 'UPI to the shop', payments.razorpay.enabled && 'online payment through Razorpay'].filter(Boolean).join(', ');

  return page(
    'Terms of use',
    shop.name,
    `<h1>Terms of use</h1>
<p class="meta">${name} app · Effective ${formatDate(operator.effectiveDate)}</p>

<p>These terms apply when you use the ${name} app to order from ${name} (the shop). The app is run for the
shop by ${value(operator.name, 'operator name')} (the operator). By using the app you agree to these terms and to the
<a href="${escape(ctx.privacyUrl)}">privacy policy</a>.</p>

<h2>Who sells to you</h2>
<p>Every order is a purchase from the shop. The shop sets the products, prices, stock, delivery area, delivery
charges and timings, and is responsible for the goods, their quality, the bill and the delivery. The operator
provides the app and the technology only and is not the seller.</p>

<h2>Your account</h2>
<ul>
  <li>You log in with your mobile number and a one-time code. Keep your phone and codes to yourself; you are responsible for orders placed from your account.</li>
  <li>Give a correct name, phone number and address. You must be 18 or older.</li>
  <li>The shop may block an account that is misused (for example fake orders or abuse of delivery staff).</li>
</ul>

<h2>Orders and prices</h2>
<ul>
  <li>Prices, offers and availability shown in the app can change until you place the order; the app checks them again when you order.</li>
  <li>An order is confirmed when the shop accepts it. The shop may reject an order (for example if an item is no longer available) and will tell you why.</li>
  ${features.handwrittenListUpload || features.prescriptionUpload ? '<li>For orders sent as a photo of a list or prescription, the shop sets the amount when it accepts the order. Medicines are supplied only as the law allows.</li>' : ''}
  <li>Pictures are for illustration; the product delivered may look slightly different.</li>
</ul>

<h2>Payment</h2>
<p>You can pay by ${methods || 'the methods shown in the app'}. Payments go directly to the shop. For UPI, enter the
correct transaction reference so the shop can confirm the payment. Refunds, when due, are made by the shop.</p>

<h2>Delivery and pickup</h2>
<ul>
  <li>Delivery times shown are estimates. Someone should be available at the address to receive the order.</li>
  <li>For delivery, give the 4-digit delivery code shown in the app to the delivery person only when you receive your order.</li>
  <li>For pickup orders, collect the order from the shop when the app says it is ready.</li>
</ul>

<h2>Cancellations and returns</h2>
<ul>
  <li>You can cancel an order in the app until the shop has packed it.</li>
  ${features.returns ? `<li>You can ask for a return or exchange in the app within ${ctx.returnsWindow} days of delivery. The shop decides on each request and handles the refund or replacement at the shop.</li>` : '<li>For problems with an order, contact the shop.</li>'}
</ul>

<h2>Fair use</h2>
<p>Do not misuse the app: no fake orders, no attempts to access other people's accounts or data, no attempts to
disrupt the service, and no abuse of the shop's staff.</p>

<h2>Responsibility</h2>
<p>The shop is responsible for the goods it sells and their delivery. The operator works to keep the app available
and correct but cannot promise it will always be free of interruptions or errors, and is not responsible for the
goods or for losses caused by events outside its control. Nothing in these terms limits rights you have under
Indian consumer protection law.</p>

<h2>Changes</h2>
<p>These terms may change; the new version is published at this address with a new effective date.</p>

<h2>Law and disputes</h2>
<p>These terms are governed by the laws of India. Disputes are subject to the courts at ${value(operator.city, 'city')}, without
affecting your right to approach a consumer commission.</p>

<h2>Contact</h2>
${contactBlock(ctx)}`,
  );
}
