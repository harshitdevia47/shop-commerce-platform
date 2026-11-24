import type { SlotsConfig } from '@qc/config-schema';

/** India has no daylight saving: the shop clock is always UTC+05:30. */
const IST_OFFSET_MS = (5 * 60 + 30) * 60_000;

export interface Slot {
  start: Date;
  end: Date;
}

/** `HH:MM` on the IST calendar day of `dayStartIst` (00:00 IST, as a UTC instant). */
function at(dayStartIst: number, hhmm: string): Date {
  const [h, m] = hhmm.split(':').map(Number) as [number, number];
  return new Date(dayStartIst + (h * 60 + m) * 60_000);
}

/**
 * Delivery windows customers can still choose: today plus `daysAhead - 1` days, each configured
 * window, minus windows closing within `cutoffMinutes`.
 */
export function upcomingSlots(config: SlotsConfig, now: Date): Slot[] {
  const istNow = now.getTime() + IST_OFFSET_MS;
  const todayStartIst = Math.floor(istNow / 86_400_000) * 86_400_000 - IST_OFFSET_MS;
  const closesBefore = now.getTime() + config.cutoffMinutes * 60_000;
  const slots: Slot[] = [];
  for (let day = 0; day < config.daysAhead; day++) {
    const dayStart = todayStartIst + day * 86_400_000;
    for (const window of [...config.windows].sort((a, b) => a.start.localeCompare(b.start))) {
      const start = at(dayStart, window.start);
      if (start.getTime() < closesBefore) continue;
      slots.push({ start, end: at(dayStart, window.end) });
    }
  }
  return slots;
}

/** The offered slot that starts at `start`, if any. */
export function findSlot(config: SlotsConfig, now: Date, start: Date): Slot | undefined {
  return upcomingSlots(config, now).find((s) => s.start.getTime() === start.getTime());
}
