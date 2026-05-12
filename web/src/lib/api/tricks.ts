import api from './client'
import type { TrickSlotDto } from './combos'

export interface TrickItem {
  type: 'trick'
  id: string
  name: string
  abbreviation: string
  crossOver: boolean
  knee: boolean
  revolution: number
  difficulty: number
  isTransition: boolean
}

export interface ComboItem {
  type: 'combo'
  id: string
  name: string
  totalDifficulty: number
  trickCount: number
  tricks: TrickSlotDto[]
}

export type TrickListItem = TrickItem | ComboItem

export interface TrickDto {
  id: string
  name: string
  abbreviation: string
  crossOver: boolean
  knee: boolean
  revolution: number
  difficulty: number
  commonLevel: number
  isTransition: boolean
  createdBy: string | null
  dateCreated: string | null
  notes: string | null
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

export const tricksApi = {
  getAll: (params?: { crossOver?: boolean; knee?: boolean; maxDifficulty?: number }) =>
    api.get<TrickListItem[]>('/tricks', { params }),
  create: (data: Omit<TrickDto, 'id'>) =>
    api.post<{ id: string }>('/tricks', data),
  update: (id: string, data: Omit<TrickDto, 'id'>) =>
    api.put(`/tricks/${id}`, data),
  delete: (id: string) => api.delete(`/tricks/${id}`),
}

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
