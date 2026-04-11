import { Link, useNavigate } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { isAuthenticated, isAdmin, clearToken } from '@/lib/auth'
import { Button } from '@/components/ui/button'
import { adminApi } from '@/lib/api'

export function Navbar() {
  const navigate = useNavigate()
  const authed = isAuthenticated()
  const admin = isAdmin()

  const { data: pendingData } = useQuery({
    queryKey: ['pending-count'],
    queryFn: () => adminApi.getPendingCount().then((r) => r.data),
    enabled: admin,
    refetchInterval: 60_000,
  })
  const pendingCount = pendingData?.total ?? 0

  function handleLogout() {
    clearToken()
    navigate('/login')
  }

  return (
    <nav className="border-b border-gray-200 bg-white">
      <div className="mx-auto max-w-6xl px-4 sm:px-6 lg:px-8">
        <div className="flex h-16 items-center justify-between">
          <div className="flex items-center gap-6">
            <Link to="/" className="text-xl font-bold text-indigo-600">
              FreestyleCombo
            </Link>
            <Link to="/combos" className="text-sm text-gray-600 hover:text-gray-900">
              Combos
            </Link>
            <Link to="/tricks" className="text-sm text-gray-600 hover:text-gray-900">
              Tricks
            </Link>
            {authed && (
              <>
                <Link to="/preferences" className="text-sm text-gray-600 hover:text-gray-900">
                  Preferences
                </Link>
                {admin && (
                  <Link to="/admin/approvals" className="flex items-center gap-1.5 text-sm font-medium text-indigo-600 hover:text-indigo-800">
                    Approvals
                    {pendingCount > 0 && (
                      <span className="inline-flex h-5 min-w-5 items-center justify-center rounded-full bg-indigo-600 px-1.5 text-xs font-semibold text-white">
                        {pendingCount}
                      </span>
                    )}
                  </Link>
                )}
              </>
            )}
          </div>
          <div className="flex items-center gap-3">
            {authed ? (
              <Button variant="ghost" size="sm" onClick={handleLogout}>
                Logout
              </Button>
            ) : (
              <>
                <Button variant="ghost" size="sm" asChild>
                  <Link to="/login">Login</Link>
                </Button>
                <Button size="sm" asChild>
                  <Link to="/register">Register</Link>
                </Button>
              </>
            )}
          </div>
        </div>
      </div>
    </nav>
  )
}
