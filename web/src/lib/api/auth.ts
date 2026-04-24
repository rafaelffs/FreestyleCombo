import api from './client'

export interface AuthResponse {
  token: string
  userId: string
  email: string
}

export const authApi = {
  register: (email: string, userName: string, password: string) =>
    api.post<AuthResponse>('/auth/register', { email, userName, password }),
  login: (credential: string, password: string) =>
    api.post<AuthResponse>('/auth/login', { credential, password }),
}
