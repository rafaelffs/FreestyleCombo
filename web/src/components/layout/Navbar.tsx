import { useState, useRef, useEffect } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { useTranslation } from 'react-i18next'
import { isAuthenticated, isAdmin, clearToken, getUserName } from '@/lib/auth'
import { Button } from '@/components/ui/button'
import { adminApi } from '@/lib/api'
import { Logo } from '@/components/Logo'

export function Navbar() {
  const navigate = useNavigate()
  const authed = isAuthenticated()
  const admin = isAdmin()
  const userName = getUserName()
  const { t, i18n } = useTranslation()

  const [menuOpen, setMenuOpen] = useState(false)
  const [mobileOpen, setMobileOpen] = useState(false)
  const menuRef = useRef<HTMLDivElement>(null)

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

  function toggleLanguage() {
    const next = i18n.language === 'en' ? 'pt-BR' : 'en'
    void i18n.changeLanguage(next)
  }

  const langFlag = i18n.language === 'en' ? '🇺🇸' : '🇧🇷'

  // Close desktop dropdown when clicking outside
  useEffect(() => {
    function handleClickOutside(e: MouseEvent) {
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) {
        setMenuOpen(false)
      }
    }
    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [])

  return (
    <nav className="border-b border-gray-200 bg-white">
      <div className="mx-auto max-w-6xl px-4 sm:px-6 lg:px-8">
        {/* Top bar */}
        <div className="flex h-16 items-center justify-between">
          {/* Logo */}
          <Link to="/" className="shrink-0 flex items-center">
            <Logo iconSize={38} />
          </Link>

          {/* Desktop nav links — hidden on mobile */}
          <div className="hidden md:flex items-center gap-6">
            <Link to="/combos" className="text-sm text-gray-600 hover:text-gray-900">
              {t('nav.combos')}
            </Link>
            <Link to="/tricks" className="text-sm text-gray-600 hover:text-gray-900">
              {t('nav.tricks')}
            </Link>
            {authed && (
              <>
                <Link to="/preferences" className="text-sm text-gray-600 hover:text-gray-900">
                  {t('nav.preferences')}
                </Link>
                {admin && (
                  <>
                    <Link to="/admin/approvals" className="flex items-center gap-1.5 text-sm font-medium text-indigo-600 hover:text-indigo-800">
                      {t('nav.approvals')}
                      {pendingCount > 0 && (
                        <span className="inline-flex h-5 min-w-5 items-center justify-center rounded-full bg-indigo-600 px-1.5 text-xs font-semibold text-white">
                          {pendingCount}
                        </span>
                      )}
                    </Link>
                    <Link to="/admin/users" className="text-sm font-medium text-indigo-600 hover:text-indigo-800">
                      {t('nav.users')}
                    </Link>
                  </>
                )}
              </>
            )}
          </div>

          {/* Desktop account / auth — hidden on mobile */}
          <div className="hidden md:flex items-center gap-3">
            {/* Language toggle */}
            <button
              type="button"
              onClick={toggleLanguage}
              className="rounded-md px-2 py-1 text-base hover:bg-gray-100 border border-gray-200"
              title="Switch language"
            >
              {langFlag}
            </button>

            {authed ? (
              <div className="relative" ref={menuRef}>
                <button
                  onClick={() => setMenuOpen((o) => !o)}
                  className="flex items-center gap-1.5 rounded-md px-3 py-1.5 text-sm font-medium text-gray-700 hover:bg-gray-100"
                >
                  <span>{userName ?? t('nav.myAccount')}</span>
                  <svg className="h-4 w-4 text-gray-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                  </svg>
                </button>
                {menuOpen && (
                  <div className="absolute right-0 z-50 mt-1 w-44 rounded-md border border-gray-200 bg-white shadow-lg">
                    <Link
                      to="/account"
                      onClick={() => setMenuOpen(false)}
                      className="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-50"
                    >
                      {t('nav.myAccount')}
                    </Link>
                    <div className="my-1 border-t border-gray-100" />
                    <button
                      onClick={() => { setMenuOpen(false); handleLogout() }}
                      className="block w-full px-4 py-2 text-left text-sm text-gray-700 hover:bg-gray-50"
                    >
                      {t('nav.logout')}
                    </button>
                  </div>
                )}
              </div>
            ) : (
              <>
                <Button variant="ghost" size="sm" asChild>
                  <Link to="/login">{t('nav.login')}</Link>
                </Button>
                <Button size="sm" asChild>
                  <Link to="/register">{t('nav.register')}</Link>
                </Button>
              </>
            )}
          </div>

          {/* Mobile hamburger button — hidden on md+ */}
          <button
            type="button"
            className="md:hidden inline-flex h-11 w-11 items-center justify-center rounded-md text-gray-700 hover:bg-gray-100"
            onClick={() => setMobileOpen((o) => !o)}
            aria-label={mobileOpen ? t('nav.closeMenu') : t('nav.openMenu')}
          >
            {mobileOpen ? (
              <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
              </svg>
            ) : (
              <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M4 6h16M4 12h16M4 18h16" />
              </svg>
            )}
          </button>
        </div>
      </div>

      {/* Mobile drawer */}
      {mobileOpen && (
        <div className="md:hidden border-t border-gray-100 bg-white px-4 pb-4 pt-2 space-y-0.5">
          <Link
            to="/combos"
            onClick={() => setMobileOpen(false)}
            className="block rounded-md px-3 py-3 text-sm font-medium text-gray-700 hover:bg-gray-50"
          >
            {t('nav.combos')}
          </Link>
          <Link
            to="/tricks"
            onClick={() => setMobileOpen(false)}
            className="block rounded-md px-3 py-3 text-sm font-medium text-gray-700 hover:bg-gray-50"
          >
            {t('nav.tricks')}
          </Link>
          {authed && (
            <>
              <Link
                to="/preferences"
                onClick={() => setMobileOpen(false)}
                className="block rounded-md px-3 py-3 text-sm font-medium text-gray-700 hover:bg-gray-50"
              >
                {t('nav.preferences')}
              </Link>
              {admin && (
                <>
                  <Link
                    to="/admin/approvals"
                    onClick={() => setMobileOpen(false)}
                    className="flex items-center gap-2 rounded-md px-3 py-3 text-sm font-medium text-indigo-600 hover:bg-indigo-50"
                  >
                    {t('nav.approvals')}
                    {pendingCount > 0 && (
                      <span className="inline-flex h-5 min-w-5 items-center justify-center rounded-full bg-indigo-600 px-1.5 text-xs font-semibold text-white">
                        {pendingCount}
                      </span>
                    )}
                  </Link>
                  <Link
                    to="/admin/users"
                    onClick={() => setMobileOpen(false)}
                    className="block rounded-md px-3 py-3 text-sm font-medium text-indigo-600 hover:bg-indigo-50"
                  >
                    {t('nav.users')}
                  </Link>
                </>
              )}
            </>
          )}

          <div className="border-t border-gray-100 pt-2 mt-1 space-y-0.5">
            {authed ? (
              <>
                <Link
                  to="/account"
                  onClick={() => setMobileOpen(false)}
                  className="block rounded-md px-3 py-3 text-sm font-medium text-gray-700 hover:bg-gray-50"
                >
                  {t('nav.myAccountWithName', { name: userName })}
                </Link>
                <button
                  type="button"
                  onClick={() => { setMobileOpen(false); handleLogout() }}
                  className="block w-full rounded-md px-3 py-3 text-left text-sm font-medium text-gray-700 hover:bg-gray-50"
                >
                  {t('nav.logout')}
                </button>
              </>
            ) : (
              <>
                <Link
                  to="/login"
                  onClick={() => setMobileOpen(false)}
                  className="block rounded-md px-3 py-3 text-sm font-medium text-gray-700 hover:bg-gray-50"
                >
                  {t('nav.login')}
                </Link>
                <Link
                  to="/register"
                  onClick={() => setMobileOpen(false)}
                  className="block rounded-md px-3 py-3 text-sm font-medium text-indigo-600 hover:bg-indigo-50"
                >
                  {t('nav.register')}
                </Link>
              </>
            )}
            {/* Language toggle for mobile */}
            <button
              type="button"
              onClick={toggleLanguage}
              className="block w-full rounded-md px-3 py-3 text-left text-sm font-medium text-gray-500 hover:bg-gray-50"
            >
              {langFlag}
            </button>
          </div>
        </div>
      )}
    </nav>
  )
}
