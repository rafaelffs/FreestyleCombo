import { Link, Outlet } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { Navbar } from './Navbar'

export function Layout() {
  const { t } = useTranslation()

  return (
    <div className="min-h-screen bg-gray-50">
      <Navbar />
      <main className="mx-auto max-w-6xl px-4 py-4 sm:px-6 sm:py-8 lg:px-8">
        <Outlet />
      </main>
      <footer className="mx-auto max-w-6xl px-4 py-6 sm:px-6 lg:px-8">
        <div className="flex flex-wrap justify-center gap-4 border-t border-gray-200 pt-6 text-xs text-gray-500">
          <Link to="/privacy" className="hover:text-indigo-600">{t('footer.privacy')}</Link>
          <Link to="/terms" className="hover:text-indigo-600">{t('footer.terms')}</Link>
          <Link to="/support" className="hover:text-indigo-600">{t('footer.support')}</Link>
        </div>
      </footer>
    </div>
  )
}
