import { describe, expect, it } from 'vitest';
import { uuidv7 } from '../src/uuid.js';

describe('uuidv7', () => {
  it('is a valid v7 UUID with the timestamp in front', () => {
    const id = uuidv7(0x0190_1234_5678);
    expect(id).toMatch(/^01901234-5678-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
  });

  it('sorts by creation time', () => {
    const ids = [uuidv7(1000), uuidv7(2000), uuidv7(3000)];
    expect([...ids].sort()).toEqual(ids);
  });
});
