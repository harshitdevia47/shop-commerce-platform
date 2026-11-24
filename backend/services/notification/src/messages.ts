import type { Locale } from '@qc/config-schema';

/**
 * Push texts in every app language. `{n}` order number, `{shop}` shop name, `{amount}` ₹ amount,
 * `{items}` item count, `{reason}` shop's reason. Keep them short: phones cut long lines.
 */

type Text = { title: string; body: string };
type Catalog = {
  newOrder: Text;
  delivery: string;
  pickup: string;
  online: string;
  items: string;
  cancelledByCustomer: Text;
  utrSubmitted: Text;
  markedPaid: Text;
  status: Record<CustomerStatus, Text>;
  newListOrder: Text;
  returnRequested: Text;
  exchangeRequested: Text;
  returnStatus: Record<'APPROVED' | 'REJECTED' | 'COMPLETED', Text>;
  riderAssigned: Text;
  riderReassigned: Text;
  riderCancelled: Text;
};

export type CustomerStatus = 'CONFIRMED' | 'PACKED' | 'OUT_FOR_DELIVERY' | 'READY_FOR_PICKUP' | 'DELIVERED' | 'PICKED_UP' | 'REJECTED';

const MESSAGES: Record<Locale, Catalog> = {
  en: {
    newOrder: { title: 'New order #{n}', body: '{amount} · {items} · {fulfillment} · {payment}' },
    delivery: 'Delivery',
    pickup: 'Pickup',
    online: 'Online',
    items: '{count} items',
    cancelledByCustomer: { title: 'Order #{n} cancelled', body: 'The customer cancelled this order.' },
    utrSubmitted: { title: 'UPI payment for #{n}', body: 'Customer sent {amount}. Check your UPI app, then mark it paid.' },
    markedPaid: { title: 'Payment received for #{n}', body: '{shop} confirmed your payment of {amount}.' },
    status: {
      CONFIRMED: { title: 'Order #{n} accepted', body: '{shop} is preparing your order.' },
      PACKED: { title: 'Order #{n} packed', body: '{shop} has packed your order.' },
      OUT_FOR_DELIVERY: { title: 'Order #{n} is on the way', body: '{shop} is delivering your order.' },
      READY_FOR_PICKUP: { title: 'Order #{n} is ready for pickup', body: 'Collect it from {shop}.' },
      DELIVERED: { title: 'Order #{n} delivered', body: 'Thank you for shopping with {shop}.' },
      PICKED_UP: { title: 'Order #{n} picked up', body: 'Thank you for shopping with {shop}.' },
      REJECTED: { title: 'Order #{n} could not be accepted', body: '{shop}: {reason}' },
    },
    newListOrder: { title: 'New list order #{n}', body: 'Photo of a list · {fulfillment} · {payment}. Open it to set the amount.' },
    returnRequested: { title: 'Return request for #{n}', body: 'The customer wants to return items. Open the order to decide.' },
    exchangeRequested: { title: 'Exchange request for #{n}', body: 'The customer wants to exchange items. Open the order to decide.' },
    returnStatus: {
      APPROVED: { title: 'Request for #{n} approved', body: '{shop}: {note}' },
      REJECTED: { title: 'Request for #{n} declined', body: '{shop}: {note}' },
      COMPLETED: { title: 'Request for #{n} completed', body: 'Thank you for shopping with {shop}.' },
    },
    riderAssigned: { title: 'New delivery #{n}', body: 'Open the app for the address and the customer.' },
    riderReassigned: { title: 'Delivery #{n} reassigned', body: 'The shop gave this delivery to another rider.' },
    riderCancelled: { title: 'Delivery #{n} cancelled', body: 'The order was cancelled. Do not deliver it; bring it back to the shop.' },
  },
  gu: {
    newOrder: { title: 'નવો ઓર્ડર #{n}', body: '{amount} · {items} · {fulfillment} · {payment}' },
    delivery: 'ડિલિવરી',
    pickup: 'પિકઅપ',
    online: 'ઓનલાઇન',
    items: '{count} વસ્તુ',
    cancelledByCustomer: { title: 'ઓર્ડર #{n} રદ', body: 'ગ્રાહકે આ ઓર્ડર રદ કર્યો.' },
    utrSubmitted: { title: '#{n} માટે UPI ચુકવણી', body: 'ગ્રાહકે {amount} મોકલ્યા. UPI એપમાં તપાસીને ચૂકવેલ કરો.' },
    markedPaid: { title: '#{n} ની ચુકવણી મળી', body: '{shop} એ {amount} મળ્યાની પુષ્ટિ કરી.' },
    status: {
      CONFIRMED: { title: 'ઓર્ડર #{n} સ્વીકારાયો', body: '{shop} તમારો ઓર્ડર તૈયાર કરી રહ્યું છે.' },
      PACKED: { title: 'ઓર્ડર #{n} પેક થઈ ગયો', body: '{shop} એ તમારો ઓર્ડર પેક કર્યો છે.' },
      OUT_FOR_DELIVERY: { title: 'ઓર્ડર #{n} રસ્તામાં છે', body: '{shop} તમારો ઓર્ડર પહોંચાડી રહ્યું છે.' },
      READY_FOR_PICKUP: { title: 'ઓર્ડર #{n} પિકઅપ માટે તૈયાર', body: '{shop} પરથી લઈ જાઓ.' },
      DELIVERED: { title: 'ઓર્ડર #{n} પહોંચી ગયો', body: '{shop} પાસેથી ખરીદી કરવા બદલ આભાર.' },
      PICKED_UP: { title: 'ઓર્ડર #{n} લઈ લીધો', body: '{shop} પાસેથી ખરીદી કરવા બદલ આભાર.' },
      REJECTED: { title: 'ઓર્ડર #{n} સ્વીકારી શકાયો નથી', body: '{shop}: {reason}' },
    },
    newListOrder: { title: 'નવો યાદી ઓર્ડર #{n}', body: 'યાદીનો ફોટો · {fulfillment} · {payment}. રકમ નક્કી કરવા ખોલો.' },
    returnRequested: { title: '#{n} માટે પરત વિનંતી', body: 'ગ્રાહક વસ્તુઓ પરત કરવા માગે છે. નિર્ણય માટે ઓર્ડર ખોલો.' },
    exchangeRequested: { title: '#{n} માટે બદલવાની વિનંતી', body: 'ગ્રાહક વસ્તુઓ બદલવા માગે છે. નિર્ણય માટે ઓર્ડર ખોલો.' },
    returnStatus: {
      APPROVED: { title: '#{n} ની વિનંતી મંજૂર', body: '{shop}: {note}' },
      REJECTED: { title: '#{n} ની વિનંતી નામંજૂર', body: '{shop}: {note}' },
      COMPLETED: { title: '#{n} ની વિનંતી પૂર્ણ', body: '{shop} પાસેથી ખરીદી કરવા બદલ આભાર.' },
    },
    riderAssigned: { title: 'નવી ડિલિવરી #{n}', body: 'સરનામું અને ગ્રાહકની વિગત માટે એપ ખોલો.' },
    riderReassigned: { title: 'ડિલિવરી #{n} બીજાને સોંપાઈ', body: 'દુકાને આ ડિલિવરી બીજા રાઇડરને આપી છે.' },
    riderCancelled: { title: 'ડિલિવરી #{n} રદ', body: 'ઓર્ડર રદ થયો છે. ડિલિવર ન કરો; દુકાને પાછો લાવો.' },
  },
  hi: {
    newOrder: { title: 'नया ऑर्डर #{n}', body: '{amount} · {items} · {fulfillment} · {payment}' },
    delivery: 'डिलीवरी',
    pickup: 'पिकअप',
    online: 'ऑनलाइन',
    items: '{count} आइटम',
    cancelledByCustomer: { title: 'ऑर्डर #{n} रद्द', body: 'ग्राहक ने यह ऑर्डर रद्द कर दिया।' },
    utrSubmitted: { title: '#{n} के लिए UPI भुगतान', body: 'ग्राहक ने {amount} भेजे। UPI ऐप में जाँचकर भुगतान हुआ करें।' },
    markedPaid: { title: '#{n} का भुगतान मिला', body: '{shop} ने {amount} मिलने की पुष्टि की।' },
    status: {
      CONFIRMED: { title: 'ऑर्डर #{n} स्वीकार हुआ', body: '{shop} आपका ऑर्डर तैयार कर रहा है।' },
      PACKED: { title: 'ऑर्डर #{n} पैक हो गया', body: '{shop} ने आपका ऑर्डर पैक कर दिया है।' },
      OUT_FOR_DELIVERY: { title: 'ऑर्डर #{n} रास्ते में है', body: '{shop} आपका ऑर्डर पहुँचा रहा है।' },
      READY_FOR_PICKUP: { title: 'ऑर्डर #{n} पिकअप के लिए तैयार', body: '{shop} से ले जाएँ।' },
      DELIVERED: { title: 'ऑर्डर #{n} पहुँच गया', body: '{shop} से खरीदारी के लिए धन्यवाद।' },
      PICKED_UP: { title: 'ऑर्डर #{n} ले लिया गया', body: '{shop} से खरीदारी के लिए धन्यवाद।' },
      REJECTED: { title: 'ऑर्डर #{n} स्वीकार नहीं हो सका', body: '{shop}: {reason}' },
    },
    newListOrder: { title: 'नया लिस्ट ऑर्डर #{n}', body: 'लिस्ट की फोटो · {fulfillment} · {payment}। राशि तय करने के लिए खोलें।' },
    returnRequested: { title: '#{n} के लिए वापसी अनुरोध', body: 'ग्राहक सामान वापस करना चाहते हैं। फैसले के लिए ऑर्डर खोलें।' },
    exchangeRequested: { title: '#{n} के लिए बदलने का अनुरोध', body: 'ग्राहक सामान बदलना चाहते हैं। फैसले के लिए ऑर्डर खोलें।' },
    returnStatus: {
      APPROVED: { title: '#{n} का अनुरोध स्वीकार', body: '{shop}: {note}' },
      REJECTED: { title: '#{n} का अनुरोध अस्वीकार', body: '{shop}: {note}' },
      COMPLETED: { title: '#{n} का अनुरोध पूरा', body: '{shop} से खरीदारी के लिए धन्यवाद।' },
    },
    riderAssigned: { title: 'नई डिलीवरी #{n}', body: 'पता और ग्राहक की जानकारी के लिए ऐप खोलें।' },
    riderReassigned: { title: 'डिलीवरी #{n} किसी और को दी गई', body: 'दुकान ने यह डिलीवरी दूसरे राइडर को दे दी है।' },
    riderCancelled: { title: 'डिलीवरी #{n} रद्द', body: 'ऑर्डर रद्द हो गया है। डिलीवर न करें; दुकान पर वापस लाएँ।' },
  },
};

const DEFAULT_NOTE: Record<Locale, string> = {
  en: 'Please contact the shop.',
  gu: 'કૃપા કરીને દુકાનનો સંપર્ક કરો.',
  hi: 'कृपया दुकान से संपर्क करें।',
};

export function defaultNote(locale: string): string {
  return DEFAULT_NOTE[(locale in DEFAULT_NOTE ? locale : 'en') as Locale];
}

const DEFAULT_REASON: Record<Locale, string> = {
  en: 'The shop could not take this order.',
  gu: 'દુકાન આ ઓર્ડર લઈ શકતી નથી.',
  hi: 'दुकान यह ऑर्डर नहीं ले सकती।',
};

export function messagesFor(locale: string): Catalog {
  return MESSAGES[(locale in MESSAGES ? locale : 'en') as Locale];
}

export function defaultReason(locale: string): string {
  return DEFAULT_REASON[(locale in DEFAULT_REASON ? locale : 'en') as Locale];
}

/** ₹1,234 or ₹1,234.50 (Indian digit grouping). */
export function formatRupees(paise: number): string {
  const rupees = paise / 100;
  return `₹${rupees.toLocaleString('en-IN', { minimumFractionDigits: paise % 100 === 0 ? 0 : 2, maximumFractionDigits: 2 })}`;
}

export function fill(text: Text, values: Record<string, string | number>): Text {
  const apply = (s: string) => s.replace(/\{(\w+)\}/g, (match, key: string) => (key in values ? String(values[key]) : match));
  return { title: apply(text.title), body: apply(text.body) };
}
