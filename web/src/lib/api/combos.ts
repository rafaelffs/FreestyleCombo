import api, { type PagedResult } from './client'

export interface ComboTrickDto {
  position: number
  trickId: string
  name: string
  abbreviation: string
  strongFoot: boolean
  noTouch: boolean
  difficulty: number
  crossOver: boolean
  isTransition: boolean
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
  isCompleted?: boolean
  completionCount?: number
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
  isTransition: boolean
}

export interface PreviewComboResponse {
  tricks: PreviewTrickItem[]
  warnings: string[]
}

export interface PublicCombosParams {
  page?: number
  pageSize?: number
  sortBy?: string
  maxDifficulty?: number
  search?: string
}

export interface MineCombosParams {
  page?: number
  pageSize?: number
  search?: string
}

export const combosApi = {
  generate: (preferenceId: string | null, overrides?: GenerateComboOverrides, name?: string) =>
    api.post<ComboDto>('/combos/generate', { preferenceId, overrides, name }),
  preview: (preferenceId: string | null, overrides?: GenerateComboOverrides) =>
    api.post<PreviewComboResponse>('/combos/preview', { preferenceId, overrides }),
  build: (tricks: BuildComboTrickItem[], isPublic = false, name?: string) =>
    api.post<ComboDto>('/combos/build', { tricks, isPublic, name }),
  getPublic: (params: PublicCombosParams = {}) =>
    api.get<PagedResult<ComboDto>>('/combos/public', { params }),
  getMine: (params: MineCombosParams = {}) =>
    api.get<PagedResult<ComboDto>>('/combos/mine', { params }),
  getFavourites: () => api.get<ComboDto[]>('/combos/favourites'),
  getById: (id: string) => api.get<ComboDto>(`/combos/${id}`),
  setPublic: (id: string, isPublic: boolean) =>
    api.put(`/combos/${id}/visibility`, { isPublic }),
  delete: (id: string) => api.delete(`/combos/${id}`),
  update: (id: string, data: { name?: string | null; tricks?: BuildComboTrickItem[] }) =>
    api.put<ComboDto>(`/combos/${id}`, data),
  addFavourite: (id: string) => api.post(`/combos/${id}/favourite`),
  removeFavourite: (id: string) => api.delete(`/combos/${id}/favourite`),
  markCompleted: (id: string) => api.post(`/combos/${id}/complete`),
  unmarkCompleted: (id: string) => api.delete(`/combos/${id}/complete`),
  getPendingReview: () => api.get<ComboDto[]>('/combos/pending-review'),
  approveVisibility: (id: string) => api.post(`/combos/${id}/approve-visibility`),
  rejectVisibility: (id: string) => api.post(`/combos/${id}/reject-visibility`),
}

export interface RatingDto {
  id: string
  comboId: string
  ratedByUserId: string
  score: number
  createdAt: string
}

export const ratingsApi = {
  rate: (comboId: string, score: number) =>
    api.post<RatingDto>(`/combos/${comboId}/ratings`, { score }),
}
