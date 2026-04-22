import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Link } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { combosApi } from '@/lib/api'
import { ComboCard } from './ComboCard'
import { isAuthenticated } from '@/lib/auth'
import { SEO } from '@/components/SEO'

type Tab = 'public' | 'mine' | 'favourites'

export function CombosPage() {
  const authed = isAuthenticated()
  const { t } = useTranslation()
  const [tab, setTab] = useState<Tab>(authed ? 'mine' : 'public')

  const publicQuery = useQuery({
    queryKey: ['combos', 'public'],
    queryFn: () => combosApi.getPublic().then((r) => r.data.items),
    enabled: tab === 'public',
  })

  const mineQuery = useQuery({
    queryKey: ['combos', 'mine'],
    queryFn: () => combosApi.getMine().then((r) => r.data.items),
    enabled: tab === 'mine' && authed,
    staleTime: 0,
  })

  const favouritesQuery = useQuery({
    queryKey: ['combos', 'favourites'],
    queryFn: () => combosApi.getFavourites().then((r) => r.data),
    enabled: tab === 'favourites' && authed,
    staleTime: 0,
  })

  // Mine only shows Private + PendingReview (not Public)
  const mineItems = mineQuery.data?.filter((c) => c.visibility !== 'Public') ?? []

  const tabs: { key: Tab; labelKey: string; authOnly?: boolean }[] = [
    { key: 'public', labelKey: 'combos.tabPublic' },
    { key: 'mine', labelKey: 'combos.tabMine', authOnly: true },
    { key: 'favourites', labelKey: 'combos.tabFavourites', authOnly: true },
  ]

  return (
    <div className="space-y-6">
      <SEO
        title="Public Combos — FreestyleCombo"
        description="Browse and rate freestyle football combos shared by the community."
        path="/combos"
      />
      <div>
        <h1 className="text-2xl font-bold text-gray-900">{t('combos.pageTitle')}</h1>
        <p className="mt-1 text-sm text-gray-500">{t('combos.pageSubtitle')}</p>
      </div>

      {/* FAB */}
      {authed && (
        <Link
          to="/combos/create"
          className="fixed bottom-6 right-6 z-40 inline-flex h-14 items-center gap-2 rounded-full bg-indigo-600 px-5 text-sm font-semibold text-white shadow-lg transition-colors hover:bg-indigo-700 active:bg-indigo-800"
        >
          <span className="text-lg leading-none">+</span>
          {t('combos.createFab')}
        </Link>
      )}

      {/* Tab bar */}
      <div className="flex gap-1 border-b border-gray-200">
        {tabs.map(({ key, labelKey, authOnly }) => {
          if (authOnly && !authed) return null
          return (
            <button
              key={key}
              onClick={() => setTab(key)}
              className={`px-4 py-2 text-sm font-medium transition-colors ${
                tab === key
                  ? 'border-b-2 border-indigo-600 text-indigo-600'
                  : 'text-gray-500 hover:text-gray-900'
              }`}
            >
              {t(labelKey)}
            </button>
          )
        })}
      </div>

      {/* Public (All) tab */}
      {tab === 'public' && (
        <>
          {publicQuery.isLoading && <p className="text-gray-500">{t('common.loading')}</p>}
          {publicQuery.error && <p className="text-red-600">{t('combos.loadingError')}</p>}
          {publicQuery.data?.length === 0 && <p className="text-gray-500">{t('combos.noPublic')}</p>}
          <div className="grid gap-4 sm:grid-cols-2 [&>*]:min-w-0">
            {publicQuery.data?.map((combo) => (
              <ComboCard key={combo.id} combo={combo} showActions={authed} />
            ))}
          </div>
        </>
      )}

      {/* Mine tab */}
      {tab === 'mine' && authed && (
        <>
          {mineQuery.isLoading && <p className="text-gray-500">{t('common.loading')}</p>}
          {mineQuery.error && <p className="text-red-600">{t('combos.loadingError')}</p>}
          {!mineQuery.isLoading && mineItems.length === 0 && (
            <p className="text-gray-500">
              {t('combos.noMine')}{' '}
              <Link to="/combos/create" className="text-indigo-600 hover:underline">
                {t('combos.createOneNow')}
              </Link>
            </p>
          )}
          <div className="grid gap-4 sm:grid-cols-2 [&>*]:min-w-0">
            {mineItems.map((combo) => (
              <ComboCard key={combo.id} combo={combo} showActions />
            ))}
          </div>
        </>
      )}

      {/* Favourites tab */}
      {tab === 'favourites' && authed && (
        <>
          {favouritesQuery.isLoading && <p className="text-gray-500">{t('common.loading')}</p>}
          {favouritesQuery.error && <p className="text-red-600">{t('combos.favouritesError')}</p>}
          {!favouritesQuery.isLoading && favouritesQuery.data?.length === 0 && (
            <p className="text-gray-500">{t('combos.noFavourites')}</p>
          )}
          <div className="grid gap-4 sm:grid-cols-2 [&>*]:min-w-0">
            {favouritesQuery.data?.map((combo) => (
              <ComboCard key={combo.id} combo={combo} showActions />
            ))}
          </div>
        </>
      )}
    </div>
  )
}
