import { Navigate, Outlet } from 'react-router-dom'
import { isAdmin } from '@/lib/auth'

export function AdminRoute() {
  if (!isAdmin()) {
    return <Navigate to="/generate" replace />
  }
  return <Outlet />
}
