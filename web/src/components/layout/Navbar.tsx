import { Link, useNavigate } from 'react-router-dom'
import { isAuthenticated, isAdmin, clearToken } from '@/lib/auth'
import { Button } from '@/components/ui/button'

export function Navbar() {
  const navigate = useNavigate()
  const authed = isAuthenticated()
  const admin = isAdmin()

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
            {authed && (
              <>
                <Link to="/generate" className="text-sm text-gray-600 hover:text-gray-900">
                  Generate
                </Link>
                <Link to="/combos/public" className="text-sm text-gray-600 hover:text-gray-900">
                  Public Combos
                </Link>
                <Link to="/combos/mine" className="text-sm text-gray-600 hover:text-gray-900">
                  My Combos
                </Link>
                <Link to="/preferences" className="text-sm text-gray-600 hover:text-gray-900">
                  Preferences
                </Link>
                <Link to="/tricks/submit" className="text-sm text-gray-600 hover:text-gray-900">
                  Submit Trick
                </Link>
                {admin && (
                  <Link to="/admin/submissions" className="text-sm font-medium text-indigo-600 hover:text-indigo-800">
                    Admin
                  </Link>
                )}
              </>
            )}
            {!authed && (
              <Link to="/combos/public" className="text-sm text-gray-600 hover:text-gray-900">
                Public Combos
              </Link>
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
