const TOKEN_KEY = 'fc_token'
const USER_ID_KEY = 'fc_user_id'
const USER_NAME_KEY = 'fc_user_name'

function decodeJwtPayload(token: string): Record<string, unknown> {
  try {
    const payload = token.split('.')[1]
    const decoded = atob(payload.replace(/-/g, '+').replace(/_/g, '/'))
    return JSON.parse(decoded)
  } catch {
    return {}
  }
}

export function getToken(): string | null {
  return localStorage.getItem(TOKEN_KEY)
}

export function setToken(token: string, userId: string): void {
  localStorage.setItem(TOKEN_KEY, token)
  localStorage.setItem(USER_ID_KEY, userId)
  const payload = decodeJwtPayload(token)
  const userName = payload['unique_name'] as string | undefined
  if (userName) localStorage.setItem(USER_NAME_KEY, userName)
}

export function clearToken(): void {
  localStorage.removeItem(TOKEN_KEY)
  localStorage.removeItem(USER_ID_KEY)
  localStorage.removeItem(USER_NAME_KEY)
}

export function getUserId(): string | null {
  return localStorage.getItem(USER_ID_KEY)
}

export function getUserName(): string | null {
  return localStorage.getItem(USER_NAME_KEY)
}

export function setUserName(name: string): void {
  localStorage.setItem(USER_NAME_KEY, name)
}

export function isAuthenticated(): boolean {
  return getToken() !== null
}

export function isAdmin(): boolean {
  const token = getToken()
  if (!token) return false
  const payload = decodeJwtPayload(token)
  const role = payload['http://schemas.microsoft.com/ws/2008/06/identity/claims/role']
  if (Array.isArray(role)) return role.includes('Admin')
  return role === 'Admin'
}
