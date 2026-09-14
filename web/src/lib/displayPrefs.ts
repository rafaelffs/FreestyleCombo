const SHOW_DIFFICULTY_KEY = 'fc_show_difficulty'

export function getShowDifficulty(): boolean {
  return localStorage.getItem(SHOW_DIFFICULTY_KEY) !== 'false'
}

export function setShowDifficulty(show: boolean) {
  localStorage.setItem(SHOW_DIFFICULTY_KEY, show ? 'true' : 'false')
}

export type ComboNameDisplayMode = 'show' | 'hideUnnamed' | 'hideAlways'

const COMBO_NAME_DISPLAY_KEY = 'fc_combo_name_display'

export function getComboNameDisplay(): ComboNameDisplayMode {
  const v = localStorage.getItem(COMBO_NAME_DISPLAY_KEY)
  return v === 'hideUnnamed' || v === 'hideAlways' ? v : 'show'
}

export function setComboNameDisplay(mode: ComboNameDisplayMode) {
  localStorage.setItem(COMBO_NAME_DISPLAY_KEY, mode)
}

/**
 * Whether the title slot should show `combo.name` (true), the
 * displayText/sequence fallback (false), or nothing at all (null) — for
 * a title slot like ComboCard's, which shows exactly one of those. `hasName`
 * is whether the combo has a real name to show.
 */
export function comboTitleUsesName(hasName: boolean, mode: ComboNameDisplayMode): boolean | null {
  if (mode === 'hideAlways') return null
  if (hasName) return true
  if (mode === 'hideUnnamed') return null
  return false
}
