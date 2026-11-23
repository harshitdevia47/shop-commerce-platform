#!/usr/bin/env node
/**
 * Dev only: fills a shop with demo categories and products through the gateway, like the admin app would.
 * Needs the dev stack running with OTP_DEV_ECHO=true and an owner account for the shop.
 *
 *   node scripts/seed-demo-catalog.mjs <slug> <owner phone> [gateway url]
 *   node scripts/seed-demo-catalog.mjs sharma_kirana 9876543210
 */
import sharp from 'sharp';

const [slug, phoneArg, base = 'http://localhost:4000'] = process.argv.slice(2);
if (!slug || !phoneArg) {
  console.error('usage: node scripts/seed-demo-catalog.mjs <slug> <owner phone> [gateway url]');
  process.exit(1);
}
const phone = phoneArg.startsWith('+') ? phoneArg : `+91${phoneArg}`;
let token;

async function api(method, path, body, isForm = false) {
  const headers = { 'x-shop-key': slug };
  if (token) headers.authorization = `Bearer ${token}`;
  if (body && !isForm) headers['content-type'] = 'application/json';
  const res = await fetch(`${base}${path}`, { method, headers, body: isForm ? body : body && JSON.stringify(body) });
  const json = res.status === 204 ? {} : await res.json();
  if (!res.ok) throw new Error(`${method} ${path} -> ${res.status} ${JSON.stringify(json.error)}`);
  return json.data;
}

async function image(label, color) {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="800" height="800">
    <rect width="100%" height="100%" fill="${color}"/>
    <text x="50%" y="52%" font-size="72" font-family="sans-serif" fill="white" text-anchor="middle">${label}</text></svg>`;
  const png = await sharp(Buffer.from(svg)).png().toBuffer();
  const form = new FormData();
  form.append('kind', 'PRODUCT_IMAGE');
  form.append('file', new Blob([png], { type: 'image/png' }), `${label}.png`);
  return (await api('POST', '/api/v1/admin/media', form, true)).id;
}

const CATALOGS = {
  grocery: [
    {
      category: { name: 'Fruits & Vegetables', nameI18n: { gu: 'ફળ અને શાકભાજી', hi: 'फल और सब्ज़ियाँ' } },
      color: '#43a047',
      products: [
        { name: 'Onion', nameI18n: { gu: 'ડુંગળી', hi: 'प्याज़' }, tags: ['kanda', 'pyaz'], variants: [['500 g', 2500, 3000], ['1 kg', 4800, 6000]] },
        { name: 'Tomato', nameI18n: { gu: 'ટામેટાં', hi: 'टमाटर' }, tags: ['tamatar'], variants: [['500 g', 2000], ['1 kg', 3800]] },
        { name: 'Banana', nameI18n: { gu: 'કેળાં', hi: 'केला' }, tags: ['kela'], variants: [['6 pcs', 3600, 4200], ['12 pcs', 7000, 8400]] },
      ],
    },
    {
      category: { name: 'Dairy & Bread', nameI18n: { gu: 'ડેરી અને બ્રેડ', hi: 'डेयरी और ब्रेड' } },
      color: '#1e88e5',
      products: [
        { name: 'Amul Taaza Milk', nameI18n: { gu: 'અમૂલ તાઝા દૂધ', hi: 'अमूल ताज़ा दूध' }, brand: 'Amul', tags: ['doodh'], variants: [['500 ml', 2800], ['1 l', 5400]] },
        { name: 'Paneer', nameI18n: { gu: 'પનીર', hi: 'पनीर' }, brand: 'Amul', variants: [['200 g', 9000, 9500]] },
        { name: 'Brown Bread', nameI18n: { gu: 'બ્રાઉન બ્રેડ', hi: 'ब्राउन ब्रेड' }, variants: [['400 g', 5000, 5500]] },
      ],
    },
    {
      category: { name: 'Atta, Rice & Dal', nameI18n: { gu: 'લોટ, ચોખા અને દાળ', hi: 'आटा, चावल और दाल' } },
      color: '#f9a825',
      products: [
        { name: 'Basmati Rice', nameI18n: { gu: 'બાસમતી ચોખા', hi: 'बासमती चावल' }, brand: 'India Gate', tags: ['chawal'], variants: [['1 kg', 12000, 14000], ['5 kg', 55000, 65000]] },
        { name: 'Toor Dal', nameI18n: { gu: 'તુવેર દાળ', hi: 'तूर दाल' }, tags: ['arhar'], variants: [['500 g', 8500], ['1 kg', 16500, 18000]] },
        { name: 'Whole Wheat Atta', nameI18n: { gu: 'ઘઉંનો લોટ', hi: 'गेहूं का आटा' }, brand: 'Aashirvaad', tags: ['gehu'], variants: [['5 kg', 26000, 29000], ['10 kg', 50000, 57000]], stock0: true },
      ],
    },
  ],
  clothing: [
    {
      category: { name: 'Men', nameI18n: { gu: 'પુરુષો', hi: 'पुरुष' } },
      color: '#3949ab',
      products: [
        { name: 'Cotton Shirt', custom: { fabric: 'Cotton', gender: 'men' }, options: [['M', 'Blue', 79900], ['L', 'Blue', 79900], ['XL', 'White', 84900]] },
        { name: 'Slim Fit Jeans', custom: { fabric: 'Denim', gender: 'men' }, options: [['30', 'Blue', 129900], ['32', 'Blue', 129900], ['34', 'Black', 139900]] },
      ],
    },
    {
      category: { name: 'Women', nameI18n: { gu: 'સ્ત્રીઓ', hi: 'महिलाएँ' } },
      color: '#d81b60',
      products: [
        { name: 'Printed Kurti', custom: { fabric: 'Rayon', gender: 'women' }, options: [['S', 'Red', 59900], ['M', 'Red', 59900], ['L', 'Green', 64900]] },
        { name: 'Silk Saree', custom: { fabric: 'Silk', gender: 'women' }, options: [['Free', 'Maroon', 249900]] },
      ],
    },
  ],
};

const otp = await api('POST', '/api/v1/auth/otp/request', { phone });
if (!otp.debugCode) throw new Error('OTP_DEV_ECHO must be on to seed');
const session = await api('POST', '/api/v1/auth/otp/verify', { phone, code: otp.debugCode });
if (!['OWNER', 'STAFF'].includes(session.user.role)) throw new Error(`${phone} is not an owner of ${slug}`);
token = session.accessToken;

const config = await api('GET', '/api/v1/shop/config');
const existing = await api('GET', '/api/v1/admin/catalog/products?limit=1');
if (existing.length > 0) {
  console.log(`${slug} already has products; nothing to do`);
  process.exit(0);
}
const groups = config.catalog.variantStyle === 'options' ? CATALOGS.clothing : CATALOGS.grocery;

let count = 0;
for (const [index, group] of groups.entries()) {
  const categoryImage = await image(group.category.name.split(' ')[0], group.color);
  const category = await api('POST', '/api/v1/admin/catalog/categories', { ...group.category, sortOrder: index, imageMediaId: categoryImage });
  for (const [i, p] of group.products.entries()) {
    const variants = p.options
      ? p.options.map(([size, color, price]) => ({ options: { size, color }, pricePaise: price, mrpPaise: Math.round(price * 1.25) }))
      : p.variants.map(([label, price, mrp]) => ({ label, pricePaise: price, mrpPaise: mrp ?? null, stockQty: p.stock0 ? 0 : null }));
    await api('POST', '/api/v1/admin/catalog/products', {
      name: p.name,
      nameI18n: p.nameI18n,
      categoryId: category.id,
      tags: p.tags ?? [],
      customFields: p.custom ?? (p.brand ? { brand: p.brand } : {}),
      sortOrder: i,
      imageMediaIds: [await image(p.name.split(' ')[0], group.color)],
      variants,
    });
    count++;
  }
}
console.log(`Seeded ${groups.length} categories and ${count} products into ${slug}`);
