const SHOW_DIFFICULTY_KEY = 'fc_show_difficulty'

export function getShowDifficulty(): boolean {
  return localStorage.getItem(SHOW_DIFFICULTY_KEY) !== 'false'
}

export function setShowDifficulty(show: boolean) {
  localStorage.setItem(SHOW_DIFFICULTY_KEY, show ? 'true' : 'false')
}
