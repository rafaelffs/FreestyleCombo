import { Link } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { isAuthenticated } from '@/lib/auth'
import { SEO } from '@/components/SEO'

export function LandingPage() {
  const authed = isAuthenticated()
  const { t } = useTranslation()

  return (
    <div className="space-y-12">
      <SEO
        title="FreestyleCombo — Freestyle Football Combo Generator"
        description="Generate, build and share freestyle football combos. Rate other players' combos and level up your skills."
        path="/"
      />
      {/* Hero */}
      <div className="text-center space-y-4 pt-6 sm:pt-10">
        <h1 className="text-4xl font-extrabold tracking-tight text-gray-900 sm:text-5xl">
          FreestyleCombo
        </h1>
        <p className="mx-auto max-w-xl text-lg text-gray-500">
          {t('home.subtitle')}
        </p>
      </div>

      {/* Action cards */}
      <div className="grid grid-cols-2 gap-3 sm:gap-4">
        {/* Create Combo */}
        {authed ? (
          <Link
            to="/combos/create"
            className="flex flex-col items-center gap-3 rounded-xl border-2 border-gray-200 p-4 text-center sm:items-start sm:p-6 sm:text-left hover:border-indigo-400 hover:bg-indigo-50 transition-colors"
          >
            <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-indigo-100 text-xl sm:h-12 sm:w-12 sm:text-2xl">
              ✨
            </div>
            <div>
              <p className="text-sm font-semibold text-gray-900 sm:text-lg">{t('home.createCombo')}</p>
              <p className="mt-1 hidden text-sm text-gray-500 sm:block">
                {t('home.createComboDesc')}
              </p>
            </div>
          </Link>
        ) : (
          <Link
            to="/combos/create"
            className="flex flex-col items-center gap-3 rounded-xl border-2 border-gray-200 p-4 text-center sm:items-start sm:p-6 sm:text-left hover:border-indigo-400 hover:bg-indigo-50 transition-colors"
          >
            <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-indigo-100 text-xl sm:h-12 sm:w-12 sm:text-2xl">
              ✨
            </div>
            <div>
              <p className="text-sm font-semibold text-gray-900 sm:text-lg">{t('home.createCombo')}</p>
              <p className="mt-1 hidden text-sm text-gray-500 sm:block">
                {t('home.createComboDesc')}
              </p>
            </div>
          </Link>
        )}

        {/* Trick Library */}
        <Link
          to="/tricks"
          className="flex flex-col items-center gap-3 rounded-xl border-2 border-gray-200 p-4 text-center sm:items-start sm:p-6 sm:text-left hover:border-indigo-400 hover:bg-indigo-50 transition-colors"
        >
          <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-indigo-100 text-xl sm:h-12 sm:w-12 sm:text-2xl">
            🎯
          </div>
          <div>
            <p className="text-sm font-semibold text-gray-900 sm:text-lg">{t('home.trickLibrary')}</p>
            <p className="mt-1 hidden text-sm text-gray-500 sm:block">
              {t('home.trickLibraryDesc')}
            </p>
          </div>
        </Link>
      </div>

      {/* Browse links */}
      <div className="flex flex-wrap justify-center gap-6 border-t border-gray-100 pt-8">
        <Link
          to="/combos"
          className="flex items-center gap-2 text-sm font-medium text-gray-600 hover:text-indigo-600 transition-colors"
        >
          <span>🏆</span> {t('home.browsePublicCombos')}
        </Link>
        <Link
          to="/tricks"
          className="flex items-center gap-2 text-sm font-medium text-gray-600 hover:text-indigo-600 transition-colors"
        >
          <span>📖</span> {t('home.browseTricks')}
        </Link>
      </div>
    </div>
  )
}
