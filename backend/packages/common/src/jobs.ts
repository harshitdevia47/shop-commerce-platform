import type { Logger } from 'pino';

export interface IntervalJob {
  /** Runs the job once now (tests, manual triggers). Waits for a run already in progress. */
  runOnce(): Promise<void>;
  stop(): Promise<void>;
}

/**
 * Runs `fn` every `intervalMs`, never overlapping itself. Errors are logged, not thrown.
 * Meant for small housekeeping jobs (sweepers); one instance per service.
 */
export function startIntervalJob(name: string, intervalMs: number, fn: () => Promise<unknown>, logger: Logger): IntervalJob {
  let current: Promise<void> | null = null;
  let stopped = false;

  const run = (): Promise<void> => {
    current ??= fn()
      .then(() => undefined)
      .catch((err: unknown) => logger.error({ err, job: name }, 'job failed'))
      .finally(() => {
        current = null;
      });
    return current;
  };

  const timer = setInterval(() => {
    if (!stopped) void run();
  }, intervalMs);
  timer.unref();

  return {
    runOnce: run,
    async stop() {
      stopped = true;
      clearInterval(timer);
      await current;
    },
  };
}
