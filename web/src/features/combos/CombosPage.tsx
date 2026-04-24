import { useState, useEffect, useRef } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Link } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { combosApi } from '@/lib/api'
import { ComboCard } from './ComboCard'
import { isAuthenticated } from '@/lib/auth'
import { SEO } from '@/components/SEO'

type Tab = 'public' | 'mine' | 'favourites'

const PAGE_SIZE = 10

function useDebounce<T>(value: T, delay: number): T {
  const [debounced, setDebounced] = useState(value)
  useEffect(() => {
    const id = setTimeout(() => setDebounced(value), delay)
    return () => clearTimeout(id)
  }, [value, delay])
  return debounced
}

function Pagination({
  page,
  totalCount,
  pageSize,
  onChange,
}: {
  page: number
  totalCount: number
  pageSize: number
  onChange: (p: number) => void
}) {
  const totalPages = Math.max(1, Math.ceil(totalCount / pageSize))
  if (totalPages <= 1) return null
  return (
    <div className="flex items-center justify-center gap-3 pt-2">
      <button
        onClick={() => onChange(page - 1)}
        disabled={page <= 1}
        className="rounded-md border border-gray-300 px-3 py-1.5 text-sm text-gray-700 hover:bg-gray-50 disabled:opacity-40"
      >
        ← Prev
      </button>
      <span className="text-sm text-gray-600">
        {page} / {totalPages}
      </span>
      <button
        onClick={() => onChange(page + 1)}
        disabled={page >= totalPages}
        className="rounded-md border border-gray-300 px-3 py-1.5 text-sm text-gray-700 hover:bg-gray-50 disabled:opacity-40"
      >
        Next →
      </button>
    </div>
  )
}

export function CombosPage() {
  const authed = isAuthenticated()
  const { t } = useTranslation()
  const [tab, setTab] = useState<Tab>(authed ? 'mine' : 'public')

  const [publicPage, setPublicPage] = useState(1)
  const [minePage, setMinePage] = useState(1)
  const [search, setSearch] = useState('')
  const [sortBy, setSortBy] = useState('')
  const [maxDifficulty, setMaxDifficulty] = useState('')
  const debouncedSearch = useDebounce(search, 350)

  // Reset to page 1 when filters change
  const prevSearch = useRef(debouncedSearch)
  useEffect(() => {
    if (prevSearch.current !== debouncedSearch) {
      setPublicPage(1)
      setMinePage(1)
      prevSearch.current = debouncedSearch
    }
  }, [debouncedSearch])

  const publicQuery = useQuery({
    queryKey: ['combos', 'public', publicPage, sortBy, maxDifficulty, debouncedSearch],
    queryFn: () =>
      combosApi
        .getPublic({
          page: publicPage,
          pageSize: PAGE_SIZE,
          sortBy: sortBy || undefined,
          maxDifficulty: maxDifficulty ? Number(maxDifficulty) : undefined,
          search: debouncedSearch || undefined,
        })
        .then((r) => r.data),
    enabled: tab === 'public',
  })

  const mineQuery = useQuery({
    queryKey: ['combos', 'mine', minePage, debouncedSearch],
    queryFn: () =>
      combosApi
        .getMine({ page: minePage, pageSize: PAGE_SIZE, search: debouncedSearch || undefined })
        .then((r) => r.data),
    enabled: tab === 'mine' && authed,
    staleTime: 0,
  })

  const favouritesQuery = useQuery({
    queryKey: ['combos', 'favourites'],
    queryFn: () => combosApi.getFavourites().then((r) => r.data),
    enabled: tab === 'favourites' && authed,
    staleTime: 0,
  })

  const mineItems = (mineQuery.data?.items ?? []).filter((c) => c.visibility !== 'Public')

  const tabs: { key: Tab; labelKey: string; authOnly?: boolean }[] = [
    { key: 'public', labelKey: 'combos.tabPublic' },
    { key: 'mine', labelKey: 'combos.tabMine', authOnly: true },
    { key: 'favourites', labelKey: 'combos.tabFavourites', authOnly: true },
  ]

  const showFilters = tab === 'public' || tab === 'mine'

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
      <Link
        to="/combos/create"
        className="fixed bottom-6 right-6 z-40 inline-flex h-14 items-center gap-2 rounded-full bg-indigo-600 px-5 text-sm font-semibold text-white shadow-lg transition-colors hover:bg-indigo-700 active:bg-indigo-800"
      >
        <span className="text-lg leading-none">+</span>
        {t('combos.createFab')}
      </Link>

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

      {/* Search + filter bar */}
      {showFilters && (
        <div className="flex flex-wrap gap-2">
          <input
            type="search"
            placeholder={tab === 'public' ? 'Search combos, tricks, users…' : 'Search combos…'}
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="min-w-0 flex-1 rounded-md border border-gray-300 px-3 py-1.5 text-sm placeholder-gray-400 focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500"
          />
          {tab === 'public' && (
            <>
              <select
                value={maxDifficulty}
                onChange={(e) => { setMaxDifficulty(e.target.value); setPublicPage(1) }}
                className="rounded-md border border-gray-300 px-2 py-1.5 text-sm focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500"
              >
                <option value="">All difficulties</option>
                {[3, 5, 7, 10].map((d) => (
                  <option key={d} value={d}>Max {d}</option>
                ))}
              </select>
              <select
                value={sortBy}
                onChange={(e) => { setSortBy(e.target.value); setPublicPage(1) }}
                className="rounded-md border border-gray-300 px-2 py-1.5 text-sm focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500"
              >
                <option value="">Newest</option>
                <option value="difficulty">Difficulty</option>
                <option value="rating">Rating</option>
              </select>
            </>
          )}
        </div>
      )}

      {/* Public tab */}
      {tab === 'public' && (
        <>
          {publicQuery.isLoading && <p className="text-gray-500">{t('common.loading')}</p>}
          {publicQuery.error && <p className="text-red-600">{t('combos.loadingError')}</p>}
          {!publicQuery.isLoading && publicQuery.data?.items.length === 0 && (
            <p className="text-gray-500">{debouncedSearch ? 'No combos matched your search.' : t('combos.noPublic')}</p>
          )}
          <div className="grid gap-4 sm:grid-cols-2 [&>*]:min-w-0">
            {publicQuery.data?.items.map((combo) => (
              <ComboCard key={combo.id} combo={combo} showActions={authed} />
            ))}
          </div>
          <Pagination
            page={publicPage}
            totalCount={publicQuery.data?.totalCount ?? 0}
            pageSize={PAGE_SIZE}
            onChange={setPublicPage}
          />
        </>
      )}

      {/* Mine tab */}
      {tab === 'mine' && authed && (
        <>
          {mineQuery.isLoading && <p className="text-gray-500">{t('common.loading')}</p>}
          {mineQuery.error && <p className="text-red-600">{t('combos.loadingError')}</p>}
          {!mineQuery.isLoading && mineItems.length === 0 && (
            <p className="text-gray-500">
              {debouncedSearch ? 'No combos matched your search.' : (
                <>{t('combos.noMine')}{' '}<Link to="/combos/create" className="text-indigo-600 hover:underline">{t('combos.createOneNow')}</Link></>
              )}
            </p>
          )}
          <div className="grid gap-4 sm:grid-cols-2 [&>*]:min-w-0">
            {mineItems.map((combo) => (
              <ComboCard key={combo.id} combo={combo} showActions />
            ))}
          </div>
          <Pagination
            page={minePage}
            totalCount={mineQuery.data?.totalCount ?? 0}
            pageSize={PAGE_SIZE}
            onChange={setMinePage}
          />
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
