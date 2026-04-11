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

// ── Error helper ───────────────────────────────────────────────────────────

// The API returns { "error": "..." } for all errors from the middleware.
// Use this helper everywhere instead of inline casting.
export function extractError(err: unknown, fallback: string): string {
  const e = err as { response?: { data?: { error?: string; message?: string } } }
  return e?.response?.data?.error ?? e?.response?.data?.message ?? fallback
}

// ── Types ──────────────────────────────────────────────────────────────────

export interface AuthResponse {
  token: string
  userId: string
  email: string
}

export interface TrickDto {
  id: string
  name: string
  abbreviation: string
  crossOver: boolean
  knee: boolean
  revolution: number
  difficulty: number
  commonLevel: number
}

export interface ComboTrickDto {
  position: number
  trickId: string
  name: string
  abbreviation: string
  strongFoot: boolean
  noTouch: boolean
  difficulty: number
}

export interface PagedResult<T> {
  items: T[]
  totalCount: number
  page: number
  pageSize: number
}

export interface ComboDto {
  id: string
  ownerId: string
  ownerUserName?: string
  name?: string
  averageDifficulty: number
  trickCount: number
  isPublic?: boolean
  visibility?: string
  createdAt: string
  displayText: string
  aiDescription: string | null
  tricks?: ComboTrickDto[]
  averageRating: number | null
  ratingCount?: number
  totalRatings?: number
  isFavourited?: boolean
}

export interface GenerateComboOverrides {
  comboLength?: number
  maxDifficulty?: number
  strongFootPercentage?: number
  noTouchPercentage?: number
  maxConsecutiveNoTouch?: number
  includeCrossOver?: boolean
  includeKnee?: boolean
  allowedRevolutions?: number[]
}

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

export interface RatingDto {
  id: string
  comboId: string
  ratedByUserId: string
  score: number
  createdAt: string
}

export interface TrickSubmissionDto {
  id: string
  name: string
  abbreviation: string
  crossOver: boolean
  knee: boolean
  revolution: number
  difficulty: number
  commonLevel: number
  status: 'Pending' | 'Approved' | 'Rejected'
  submittedAt: string
  submittedByUserName: string
  reviewedAt: string | null
}

export interface SubmitTrickRequest {
  name: string
  abbreviation: string
  crossOver: boolean
  knee: boolean
  revolution: number
  difficulty: number
  commonLevel: number
}

// ── Auth ───────────────────────────────────────────────────────────────────

export const authApi = {
  register: (email: string, userName: string, password: string) =>
    api.post<AuthResponse>('/auth/register', { email, userName, password }),
  login: (credential: string, password: string) =>
    api.post<AuthResponse>('/auth/login', { credential, password }),
}

// ── Combos ─────────────────────────────────────────────────────────────────

export interface BuildComboTrickItem {
  trickId: string
  position: number
  strongFoot: boolean
  noTouch: boolean
}

export interface PreviewTrickItem {
  trickId: string
  trickName: string
  abbreviation: string
  position: number
  strongFoot: boolean
  noTouch: boolean
  difficulty: number
  crossOver: boolean
  revolution: number
}

export interface PreviewComboResponse {
  tricks: PreviewTrickItem[]
  warnings: string[]
}

export const combosApi = {
  generate: (preferenceId: string | null, overrides?: GenerateComboOverrides, name?: string) =>
    api.post<ComboDto>('/combos/generate', { preferenceId, overrides, name }),
  preview: (preferenceId: string | null, overrides?: GenerateComboOverrides) =>
    api.post<PreviewComboResponse>('/combos/preview', { preferenceId, overrides }),
  build: (tricks: BuildComboTrickItem[], isPublic = false, name?: string) =>
    api.post<ComboDto>('/combos/build', { tricks, isPublic, name }),
  getPublic: () => api.get<PagedResult<ComboDto>>('/combos/public'),
  getMine: () => api.get<PagedResult<ComboDto>>('/combos/mine'),
  getFavourites: () => api.get<ComboDto[]>('/combos/favourites'),
  getById: (id: string) => api.get<ComboDto>(`/combos/${id}`),
  setPublic: (id: string, isPublic: boolean) =>
    api.put(`/combos/${id}/visibility`, { isPublic }),
  delete: (id: string) => api.delete(`/combos/${id}`),
  update: (id: string, data: { name?: string | null; tricks?: BuildComboTrickItem[] }) =>
    api.put<ComboDto>(`/combos/${id}`, data),
  addFavourite: (id: string) => api.post(`/combos/${id}/favourite`),
  removeFavourite: (id: string) => api.delete(`/combos/${id}/favourite`),
  getPendingReview: () => api.get<ComboDto[]>('/combos/pending-review'),
  approveVisibility: (id: string) => api.post(`/combos/${id}/approve-visibility`),
  rejectVisibility: (id: string) => api.post(`/combos/${id}/reject-visibility`),
}

// ── Ratings ────────────────────────────────────────────────────────────────

export const ratingsApi = {
  rate: (comboId: string, score: number) =>
    api.post<RatingDto>(`/combos/${comboId}/ratings`, { score }),
}

// ── Trick Submissions ─────────────────────────────────────────────────────

export const trickSubmissionsApi = {
  submit: (data: SubmitTrickRequest) =>
    api.post<{ id: string }>('/trick-submissions', data),
  getMine: () =>
    api.get<TrickSubmissionDto[]>('/trick-submissions/mine'),
  getPending: () =>
    api.get<TrickSubmissionDto[]>('/trick-submissions/pending'),
  approve: (id: string) =>
    api.post(`/trick-submissions/${id}/approve`),
  reject: (id: string) =>
    api.post(`/trick-submissions/${id}/reject`),
}

// ── Tricks ────────────────────────────────────────────────────────────────

export const tricksApi = {
  getAll: (params?: { crossOver?: boolean; knee?: boolean; maxDifficulty?: number }) =>
    api.get<TrickDto[]>('/tricks', { params }),
  update: (id: string, data: Omit<TrickDto, 'id'>) =>
    api.put(`/tricks/${id}`, data),
  delete: (id: string) => api.delete(`/tricks/${id}`),
}

// ── Preferences ───────────────────────────────────────────────────────────

export type PreferencePayload = Omit<UserPreference, 'id' | 'userId'>

export const preferencesApi = {
  getAll: () => api.get<UserPreference[]>('/preferences'),
  create: (pref: PreferencePayload) => api.post<UserPreference>('/preferences', pref),
  update: (id: string, pref: PreferencePayload) => api.put<UserPreference>(`/preferences/${id}`, pref),
  remove: (id: string) => api.delete(`/preferences/${id}`),
}


export const adminApi = {
  getPendingCount: () => api.get<{ total: number }>('/admin/pending-count'),
}
