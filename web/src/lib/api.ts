import axios from 'axios'
import { getToken, clearToken } from './auth'

const api = axios.create({
  baseURL: '/api',
})

api.interceptors.request.use((config) => {
  const token = getToken()
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

api.interceptors.response.use(
  (res) => res,
  (error) => {
    if (error.response?.status === 401) {
      clearToken()
      window.location.href = '/login'
    }
    return Promise.reject(error)
  }
)

export default api

// ── Types ──────────────────────────────────────────────────────────────────

export interface AuthResponse {
  token: string
  userId: string
  email: string
}

export interface ComboTrickDto {
  position: number
  trickId: string
  trickName: string
  abbreviation: string
  strongFoot: boolean
  noTouch: boolean
  difficulty: number
}

export interface ComboDto {
  id: string
  ownerId: string
  ownerEmail: string
  totalDifficulty: number
  trickCount: number
  isPublic: boolean
  createdAt: string
  displayText: string
  aiDescription: string | null
  tricks: ComboTrickDto[]
  averageRating: number | null
  ratingCount: number
}

export interface GenerateComboOverrides {
  comboLength?: number
  maxDifficulty?: number
  strongFootPercentage?: number
  noTouchPercentage?: number
  maxConsecutiveNoTouch?: number
  includeCrossOver?: boolean
  includeKnee?: boolean
  allowedMotions?: number[]
}

export interface UserPreference {
  id: string
  userId: string
  comboLength: number
  maxDifficulty: number
  strongFootPercentage: number
  noTouchPercentage: number
  maxConsecutiveNoTouch: number
  includeCrossOver: boolean
  includeKnee: boolean
  allowedMotions: number[]
}

export interface RatingDto {
  id: string
  comboId: string
  ratedByUserId: string
  score: number
  createdAt: string
}

// ── Auth ───────────────────────────────────────────────────────────────────

export const authApi = {
  register: (email: string, password: string) =>
    api.post<AuthResponse>('/auth/register', { email, password }),
  login: (email: string, password: string) =>
    api.post<AuthResponse>('/auth/login', { email, password }),
}

// ── Combos ─────────────────────────────────────────────────────────────────

export const combosApi = {
  generate: (usePreferences: boolean, overrides?: GenerateComboOverrides) =>
    api.post<ComboDto>('/combos/generate', { usePreferences, overrides }),
  getPublic: () => api.get<ComboDto[]>('/combos/public'),
  getMine: () => api.get<ComboDto[]>('/combos/mine'),
  getById: (id: string) => api.get<ComboDto>(`/combos/${id}`),
  setPublic: (id: string, isPublic: boolean) =>
    api.patch(`/combos/${id}/visibility`, { isPublic }),
}

// ── Ratings ────────────────────────────────────────────────────────────────

export const ratingsApi = {
  rate: (comboId: string, score: number) =>
    api.post<RatingDto>('/ratings', { comboId, score }),
}

// ── Preferences ───────────────────────────────────────────────────────────

export const preferencesApi = {
  get: () => api.get<UserPreference>('/preferences'),
  upsert: (pref: Omit<UserPreference, 'id' | 'userId'>) =>
    api.put<UserPreference>('/preferences', pref),
}
