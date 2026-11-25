/**
 * Sets up a new client shop in one go (run on the platform team's laptop):
 *
 *   cd backend && npm run new-shop                         asks questions step by step
 *   cd backend && npm run new-shop -- --answers shop.json  same answers from a file (see docs/new-shop.md)
 *
 * Options: --yes (no confirmation), --skip-app (do not generate the Android flavor).
 *
 * Live server: with PLATFORM_URL and PLATFORM_TOKEN in backend/.env.platform (never in git), the
 * shop, its owner and its monthly subscription are also created on the live server through the
 * admin site (docs/deploy.md, "Platform admin"), so nobody has to log into the server.
 *
 * Steps: client.json + placeholder logo/icon → validate → (dev stack running) create the shop and its
 * owner in the local database → Android flavor for the app → prints the server commands and what is
 * left (real logo, Firebase file, Play listing).
 */
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { stdin, stdout } from 'node:process';
import { createInterface } from 'node:readline/promises';
import { fileURLToPath } from 'node:url';
import { BUSINESS_TYPES, LOCALES } from '@qc/config-schema';
import { parse as parseEnv } from 'dotenv';
import { answerChecks, buildClientJson, slugify, subscriptionFrom, type BusinessType, type Locale, type ShopAnswers } from './new-shop-lib.js';

const root = fileURLToPath(new URL('../../../../', import.meta.url));
const backendDir = join(root, 'backend');
const clientsDir = process.env.CLIENTS_DIR ?? join(root, 'clients');
const args = process.argv.slice(2);
const flag = (name: string) => args.includes(name);
const option = (name: string) => {
  const i = args.indexOf(name);
  return i >= 0 ? args[i + 1] : undefined;
};

/** Live-server settings for the laptop, kept out of the tenant .env (which would leak into child commands). */
const platformFile = join(backendDir, '.env.platform');
const platform = existsSync(platformFile) ? parseEnv(readFileSync(platformFile)) : {};
const platformUrl = process.env.PLATFORM_URL ?? platform.PLATFORM_URL;
const platformToken = process.env.PLATFORM_TOKEN ?? platform.PLATFORM_TOKEN;
const defaultFee = process.env.PLATFORM_DEFAULT_FEE_RUPEES ?? platform.PLATFORM_DEFAULT_FEE_RUPEES ?? '';

const green = (s: string) => `\x1b[32m${s}\x1b[0m`;
const red = (s: string) => `\x1b[31m${s}\x1b[0m`;
const bold = (s: string) => `\x1b[1m${s}\x1b[0m`;
const dim = (s: string) => `\x1b[2m${s}\x1b[0m`;

/**
 * One line reader for the whole run. Reading lines from the iterator (instead of rl.question) also
 * works when answers are piped in, where rl.question would drop lines that arrive early.
 */
let lineReader: AsyncIterator<string> | undefined;
async function readLine(prompt: string): Promise<string> {
  lineReader ??= createInterface({ input: stdin, terminal: false })[Symbol.asyncIterator]();
  stdout.write(prompt);
  const next = await lineReader.next();
  if (next.done) throw new Error('Input ended before all questions were answered');
  if (!stdin.isTTY) stdout.write(`${next.value}\n`);
  return next.value;
}

async function askAll(): Promise<ShopAnswers> {
  const ask = async (question: string, check?: (v: string) => string | null, fallback = ''): Promise<string> => {
    for (;;) {
      const raw = (await readLine(`${bold(question)}${fallback ? dim(` [${fallback}]`) : ''}: `)).trim();
      const value = raw || fallback;
      const problem = check?.(value);
      if (!problem) return value;
      console.log(red(`  ${problem}`));
    }
  };
  const choose = async <T extends string>(question: string, choices: readonly T[], fallback: T): Promise<T> =>
    (await ask(`${question} (${choices.join(' / ')})`, (v) => (choices.includes(v as T) ? null : `Choose one of: ${choices.join(', ')}`), fallback)) as T;

  console.log(`\n${bold('New shop')} ${dim('(press Enter to take the value in [brackets])')}\n`);
  const name = await ask('Shop name in English (also the app name)', answerChecks.name);
  const slug = await ask('Short id for the shop (never changes)', answerChecks.slug, slugify(name));
  const nameGu = await ask('Shop name in Gujarati (optional)');
  const nameHi = await ask('Shop name in Hindi (optional)');
  const businessType = await choose<BusinessType>('Type of shop', BUSINESS_TYPES, 'grocery');
  const ownerName = await ask("Owner's name");
  const ownerPhone = await ask("Owner's mobile (logs in as owner)", answerChecks.phone);
  const shopPhone = await ask('Shop phone for customers', answerChecks.optionalPhone, ownerPhone);
  const whatsapp = await ask('Shop WhatsApp', answerChecks.optionalPhone, shopPhone);
  const address = await ask('Shop address', answerChecks.address);
  console.log(dim('  Location: in Google Maps long-press the shop, copy the numbers shown (like 21.7645, 72.1519).'));
  const location = await ask('Shop location', answerChecks.location);
  const pincodes = await ask('Delivery pincodes, comma separated (empty = any within the delivery distance)', answerChecks.pincodes);
  const upiVpa = await ask('UPI ID for payments (optional, like shop@okaxis)', answerChecks.upi);
  const upiName = upiVpa ? await ask('Name shown when paying', undefined, name) : '';
  const language = await choose<Locale>('App language for customers', LOCALES, 'gu');
  const primaryColor = await ask('Brand colour (optional, like #1B5E20)', answerChecks.color);
  const feeRupees = await ask('Monthly subscription fee in ₹ (what the shop pays you)', answerChecks.fee, defaultFee);
  const dueDay = await ask('Due day of the month (1–28)', answerChecks.dueDay, '5');
  return { name, slug, nameGu, nameHi, businessType, ownerName, ownerPhone, shopPhone, whatsapp, address, location, pincodes, upiVpa, upiName, language, primaryColor, feeRupees, dueDay };
}

function run(label: string, command: string, commandArgs: string[], cwd: string): boolean {
  process.stdout.write(`• ${label}… `);
  const result = spawnSync(command, commandArgs, { cwd, encoding: 'utf8' });
  if (result.status === 0) {
    console.log(green('done'));
    return true;
  }
  console.log(red('failed'));
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`.trim();
  if (output) console.log(dim(output.split('\n').slice(-12).join('\n')));
  return false;
}

async function devStackRunning(): Promise<boolean> {
  try {
    const res = await fetch('http://localhost:4001/health', { signal: AbortSignal.timeout(1500) });
    return res.ok;
  } catch {
    return false;
  }
}

async function main(): Promise<number> {
  const answersFile = option('--answers');
  const answers: ShopAnswers = answersFile ? JSON.parse(readFileSync(answersFile, 'utf8')) : await askAll();

  let built;
  let subscription: { feePaise: number; dueDay: number } | null = null;
  try {
    built = buildClientJson(answers);
    if (answers.feeRupees || answers.dueDay) subscription = subscriptionFrom({ feeRupees: answers.feeRupees ?? '', dueDay: answers.dueDay ?? '' });
  } catch (error) {
    console.error(red('\nPlease fix:\n') + (error as Error).message);
    return 1;
  }
  const { config, json } = built;
  const slug = config.slug;
  const dir = join(clientsDir, slug);
  if (existsSync(join(dir, 'client.json'))) {
    console.error(red(`\nclients/${slug} already exists. Choose another short id, or edit clients/${slug}/client.json and run: npm run client -- sync ${slug}`));
    return 1;
  }

  console.log(`\n${bold('Summary')}`);
  console.log(`  App / shop:  ${config.shop.name}  (${slug}, ${config.shop.businessType})`);
  console.log(`  Package:     ${config.build.androidPackage}  ${dim('(cannot change after publishing)')}`);
  console.log(`  Owner:       ${built.ownerName ?? ''} ${built.ownerPhone}`);
  console.log(`  Contact:     ${config.shop.contact.phone}, ${config.shop.contact.address}`);
  console.log(`  Location:    ${config.shop.contact.lat}, ${config.shop.contact.lng}  https://maps.google.com/?q=${config.shop.contact.lat},${config.shop.contact.lng}`);
  console.log(`  Delivery:    ${config.delivery.enabled ? `${config.delivery.radiusKm} km` : 'off'}${config.delivery.pincodes.length ? `, pincodes ${config.delivery.pincodes.join(', ')}` : ''}`);
  console.log(`  Payments:    cash${config.payments.upi.enabled ? `, UPI ${config.payments.upi.vpa}` : ''}`);
  console.log(`  Language:    ${config.locale.default}`);
  console.log(`  Subscription: ${subscription ? `₹${subscription.feePaise / 100}/month, due on day ${subscription.dueDay}` : 'not set (set it up on the admin site)'}`);
  console.log(`  Live server: ${platformUrl && platformToken ? platformUrl : dim('not configured (backend/.env.platform): only local steps')}`);
  if (!flag('--yes')) {
    const ok = (await readLine(`\n${bold('Create this shop? (y/n)')}: `)).trim().toLowerCase();
    if (!['y', 'yes'].includes(ok)) {
      console.log('Nothing was created.');
      return 1;
    }
  }

  console.log('');
  mkdirSync(dir, { recursive: true });
  writeFileSync(join(dir, 'client.json'), `${JSON.stringify(json, null, 2)}\n`);
  console.log(`• Shop settings file clients/${slug}/client.json… ${green('done')}`);

  const steps: boolean[] = [];
  steps.push(run('Placeholder logo and icon (replace with real ones later)', 'node', ['scripts/placeholder-images.mjs', slug], backendDir));
  steps.push(run('Check settings', 'npm', ['run', '--silent', 'client', '--', 'validate', slug], backendDir));

  const local = await devStackRunning();
  if (local) {
    steps.push(run('Create the shop in the local database', 'npm', ['run', '--silent', 'client', '--', 'sync', slug], backendDir));
    const ownerArgs = ['run', '--silent', 'users', '--', 'create-owner', slug, built.ownerPhone, ...(built.ownerName ? [built.ownerName] : [])];
    steps.push(run('Create the owner login', 'npm', ownerArgs, backendDir));
  } else {
    console.log(dim('• Local services are not running: skipped creating the shop and owner locally (start them and run the commands below).'));
  }

  if (!flag('--skip-app')) {
    steps.push(run('Android app flavor', 'dart', ['run', 'tool/gen_flavors.dart'], join(root, 'app')));
  }

  let live = false;
  if (platformUrl && platformToken && !subscription) {
    console.log(dim('• Live server skipped: answer the monthly fee and due day to create the shop there.'));
  } else if (platformUrl && platformToken && subscription) {
    process.stdout.write('• Create the shop, owner and subscription on the live server… ');
    try {
      const res = await fetch(new URL('/api/shops', platformUrl), {
        method: 'POST',
        headers: { authorization: `Bearer ${platformToken}`, 'content-type': 'application/json' },
        body: JSON.stringify({
          clientJson: json,
          ownerPhone: built.ownerPhone,
          ...(built.ownerName ? { ownerName: built.ownerName } : {}),
          feePaise: subscription.feePaise,
          dueDay: subscription.dueDay,
        }),
        signal: AbortSignal.timeout(20_000),
      });
      const payload = (await res.json().catch(() => ({}))) as { data?: { nextDueDate?: string; created?: boolean; subscription?: string }; error?: { message?: string } };
      if (!res.ok) throw new Error(payload.error?.message ?? `HTTP ${res.status}`);
      live = true;
      console.log(green('done'));
      console.log(dim(`  ${payload.data?.created ? 'New shop' : 'Shop updated'}; subscription ${payload.data?.subscription}, next due ${payload.data?.nextDueDate}`));
    } catch (error) {
      steps.push(false);
      console.log(red('failed'));
      console.log(dim(`  ${(error as Error).message}`));
    }
  }

  const ownerCmd = `create-owner ${slug} ${built.ownerPhone}${built.ownerName ? ` "${built.ownerName}"` : ''}`;
  console.log(`\n${steps.every(Boolean) ? green(bold('Shop is set up.')) : red(bold('Some steps failed: fix them and run that command again.'))}`);
  console.log(`
${bold('Try it on the emulator')}
  cd app && flutter run --flavor ${slug} --dart-define-from-file=config/clients/${slug}.json --dart-define-from-file=config/env.dev.json
  Owner logs in with ${built.ownerPhone}.${local ? '' : `
  (first: cd backend && npm run client -- sync ${slug} && npm run users -- ${ownerCmd})`}

${bold('Still to do')}
  1. Real logo (512x512) and app icon (1024x1024) in clients/${slug}/ (logo.png, icon.png), then: cd app && dart run tool/gen_flavors.dart
  2. Firebase: add Android app ${config.build.androidPackage}, put google-services.json in clients/${slug}/ (docs/deploy.md, section 7)
  3. Commit and push clients/${slug} (git add clients/${slug}; google-services.json stays out of git)
  4. ${live ? 'Live server: already done (shop, owner and subscription are on the admin site).' : `On the server: git pull, then
       docker compose exec tenant node dist/client.js sync ${slug}
       docker compose exec identity node dist/users.js ${ownerCmd}
     and set up the subscription on the admin site.`}
  5. Build for Play: cd app && ./tool/build_release.sh ${slug}   (docs/release.md)
  6. The owner adds products (Quick add or Import from Excel) and checks Shop settings.
`);
  return steps.every(Boolean) ? 0 : 1;
}

main().then(
  (code) => process.exit(code),
  (error) => {
    console.error(error);
    process.exit(1);
  },
);
