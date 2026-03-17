/**
 * retry.ts — Exponential backoff retry utility
 *
 * Contract:
 *   - Attempts fn() up to maxAttempts times
 *   - On failure: waits baseDelayMs * 2^(attempt-1) before next attempt
 *     Attempt 1 fails → wait 1000ms
 *     Attempt 2 fails → wait 2000ms
 *     Attempt 3 fails → throw last error
 *   - If all attempts fail, rethrows the last error
 */

/**
 * Pause execution for the given number of milliseconds.
 */
export function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Execute fn() with exponential backoff retry.
 *
 * @param fn - Async function to attempt
 * @param maxAttempts - Maximum number of attempts (default: 3)
 * @param baseDelayMs - Base delay in milliseconds (default: 1000)
 * @returns Result of fn() on first success
 * @throws Last error if all attempts fail
 */
export async function withRetry<T>(
  fn: () => Promise<T>,
  maxAttempts: number = 3,
  baseDelayMs: number = 1000
): Promise<T> {
  let lastError: unknown;

  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await fn();
    } catch (err) {
      lastError = err;

      if (attempt < maxAttempts) {
        const delayMs = baseDelayMs * Math.pow(2, attempt - 1);
        await sleep(delayMs);
      }
    }
  }

  throw lastError;
}
