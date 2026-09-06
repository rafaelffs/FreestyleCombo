export const REV_MIN = 0.5
export const REV_MAX = 4
export const REV_STEP = 0.5

/**
 * A full-range selection (REV_MIN..REV_MAX) encodes to an empty list, matching
 * the existing "empty AllowedRevolutions = no restriction" backend semantics.
 *
 * Assumes min <= max and both are already snapped to the 0.5 grid within
 * [REV_MIN, REV_MAX] — callers (the range-slider components) guarantee this
 * before invoking it.
 */
export function encodeRevolutionRange(min: number, max: number): number[] {
  if (min <= REV_MIN && max >= REV_MAX) return []
  const steps = Math.round((max - min) / REV_STEP)
  const result: number[] = []
  for (let i = 0; i <= steps; i++) {
    result.push(Math.round((min + i * REV_STEP) * 2) / 2)
  }
  return result
}

export function decodeRevolutionRange(list: number[]): { min: number; max: number } {
  if (list.length === 0) return { min: REV_MIN, max: REV_MAX }
  return { min: Math.min(...list), max: Math.max(...list) }
}
