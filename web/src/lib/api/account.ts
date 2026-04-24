import api from './client'

export interface ProfileDto {
  id: string
  userName: string
  email: string
  isAdmin: boolean
}

export interface PublicProfileDto {
  id: string
  userName: string
  email: string
}

export interface AdminUserDto {
  id: string
  userName: string
  email: string
  isAdmin: boolean
  comboCount: number
}

export const accountApi = {
  getProfile: () => api.get<ProfileDto>('/account/me'),
  updateProfile: (data: { userName?: string; email?: string }) =>
    api.put<ProfileDto>('/account/me', data),
  changePassword: (data: { currentPassword: string; newPassword: string }) =>
    api.put('/account/me/password', data),
  getPublicProfile: (id: string) => api.get<PublicProfileDto>(`/account/${id}`),
}

export const adminApi = {
  getPendingCount: () => api.get<{ total: number }>('/admin/pending-count'),
  getUsers: () => api.get<AdminUserDto[]>('/admin/users'),
  updateUser: (id: string, data: { userName?: string; email?: string }) =>
    api.put<AdminUserDto>(`/admin/users/${id}`, data),
  resetUserPassword: (id: string, newPassword: string) =>
    api.put(`/admin/users/${id}/password`, { newPassword }),
  updateUserRole: (id: string, isAdmin: boolean) =>
    api.put(`/admin/users/${id}/role`, { isAdmin }),
  deleteUser: (id: string) => api.delete(`/admin/users/${id}`),
}
