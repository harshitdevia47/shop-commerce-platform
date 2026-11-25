import { describe, expect, it } from 'vitest';
import { buildClientJson, normalizePhone, parseLocation, parsePincodes, slugify, type ShopAnswers } from '../scripts/new-shop-lib.js';

const answers: ShopAnswers = {
  name: 'Patel Provision Store',
  nameGu: 'પટેલ પ્રોવિઝન સ્ટોર',
  businessType: 'grocery',
  ownerName: 'Mahesh Patel',
  ownerPhone: '098250 12345',
  address: 'Waghawadi Road, Bhavnagar 364002',
  location: 'https://www.google.com/maps/place/Shop/@21.7559,72.1426,17z/data=!3m1',
  pincodes: '364002, 364001',
  upiVpa: 'patelstore@oksbi',
  upiName: '',
  language: 'gu',
};

describe('new shop helpers', () => {
  it('makes slugs, phones, locations and pincodes from what people type', () => {
    expect(slugify('Patel Provision Store')).toBe('patel_provision_store');
    expect(slugify("Raju's 24x7 Mart!")).toBe('raju_s_24x7_mart');
    expect(slugify('7 Star Kirana')).toBe('star_kirana');
    expect(normalizePhone('+91 98250-12345')).toBe('+919825012345');
    expect(normalizePhone('09825012345')).toBe('+919825012345');
    expect(normalizePhone('12345')).toBeNull();
    expect(parseLocation('21.7645, 72.1519')).toEqual({ lat: 21.7645, lng: 72.1519 });
    expect(parseLocation('https://maps.google.com/?q=21.7645,72.1519')).toEqual({ lat: 21.7645, lng: 72.1519 });
    expect(parseLocation('https://www.google.com/maps/place/X/data=!3d21.7645!4d72.1519')).toEqual({ lat: 21.7645, lng: 72.1519 });
    expect(parseLocation('https://maps.app.goo.gl/AbCdEf')).toBeNull();
    expect(parsePincodes('364001, 364002 364001')).toEqual(['364001', '364002']);
    expect(parsePincodes('')).toEqual([]);
    expect(parsePincodes('36400')).toBeNull();
  });

  it('builds a valid client.json with the business-type defaults', () => {
    const { config, json, ownerPhone, ownerName } = buildClientJson(answers);
    expect(config.slug).toBe('patel_provision_store');
    expect(config.build).toEqual({ appName: 'Patel Provision Store', androidPackage: 'in.qcommerce.patelprovisionstore', version: '1.0.0+1' });
    expect(config.shop.contact).toEqual({
      phone: '+919825012345',
      whatsapp: '+919825012345',
      address: 'Waghawadi Road, Bhavnagar 364002',
      lat: 21.7559,
      lng: 72.1426,
    });
    expect(config.shop.nameI18n).toEqual({ gu: 'પટેલ પ્રોવિઝન સ્ટોર' });
    expect(config.delivery.pincodes).toEqual(['364002', '364001']);
    expect(config.payments.upi).toEqual({ enabled: true, vpa: 'patelstore@oksbi', payeeName: 'Patel Provision Store' });
    expect(config.branding.colors.primary).toBe('#1B5E20');
    expect(config.locale.default).toBe('gu');
    expect(ownerPhone).toBe('+919825012345');
    expect(ownerName).toBe('Mahesh Patel');
    expect(json).not.toHaveProperty('features'); // preset defaults stay in the preset
  });

  it('lists every wrong answer at once', () => {
    expect(() =>
      buildClientJson({ ...answers, ownerPhone: '123', location: 'near bus stand', upiVpa: 'patel', slug: 'Bad Slug' }),
    ).toThrow(/Short id[\s\S]*Owner mobile[\s\S]*Location[\s\S]*UPI ID/);
  });
});
