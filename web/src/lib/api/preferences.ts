import api from './client'

export interface UserPreference {
  id: string
  userId?: string
  name: string
  comboLength: number
  maxDifficulty: number
  strongFootPercentage: number
  noTouchPercentage: number
  maxConsecutiveNoTouch: number
  includeCrossOver: boolean
  includeKnee: boolean
  allowedRevolutions: number[]
}

export type PreferencePayload = Omit<UserPreference, 'id' | 'userId'>

export const preferencesApi = {
  getAll: () => api.get<UserPreference[]>('/preferences'),
  create: (pref: PreferencePayload) => api.post<UserPreference>('/preferences', pref),
  update: (id: string, pref: PreferencePayload) => api.put<UserPreference>(`/preferences/${id}`, pref),
  remove: (id: string) => api.delete(`/preferences/${id}`),
}
