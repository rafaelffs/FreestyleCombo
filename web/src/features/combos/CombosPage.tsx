import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Link } from 'react-router-dom'
import { combosApi } from '@/lib/api'
import { ComboCard } from './ComboCard'
import { isAuthenticated } from '@/lib/auth'
import { SEO } from '@/components/SEO'

type Tab = 'public' | 'mine' | 'favourites'

export function CombosPage() {
  const authed = isAuthenticated()
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

  const tabs: { key: Tab; label: string; authOnly?: boolean }[] = [
    { key: 'public', label: 'Public (All)' },
    { key: 'mine', label: 'Mine', authOnly: true },
    { key: 'favourites', label: 'Favourites', authOnly: true },
  ]

  return (
    <div className="space-y-6">
      <SEO
        title="Public Combos — FreestyleCombo"
        description="Browse and rate freestyle football combos shared by the community."
        path="/combos"
      />
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Combos</h1>
        <p className="mt-1 text-sm text-gray-500">Browse public combos or view your own.</p>
      </div>

      {/* FAB */}
      {authed && (
        <Link
          to="/combos/create"
          className="fixed bottom-6 right-6 z-40 inline-flex h-14 items-center gap-2 rounded-full bg-indigo-600 px-5 text-sm font-semibold text-white shadow-lg transition-colors hover:bg-indigo-700 active:bg-indigo-800"
        >
          <span className="text-lg leading-none">+</span>
          Create
        </Link>
      )}

      {/* Tab bar */}
      <div className="flex gap-1 border-b border-gray-200">
        {tabs.map(({ key, label, authOnly }) => {
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
              {label}
            </button>
          )
        })}
      </div>

      {/* Public (All) tab */}
      {tab === 'public' && (
        <>
          {publicQuery.isLoading && <p className="text-gray-500">Loading…</p>}
          {publicQuery.error && <p className="text-red-600">Failed to load combos.</p>}
          {publicQuery.data?.length === 0 && <p className="text-gray-500">No public combos yet.</p>}
          <div className="grid gap-4 sm:grid-cols-2">
            {publicQuery.data?.map((combo) => (
              <ComboCard key={combo.id} combo={combo} showActions={authed} />
            ))}
          </div>
        </>
      )}

      {/* Mine tab */}
      {tab === 'mine' && authed && (
        <>
          {mineQuery.isLoading && <p className="text-gray-500">Loading…</p>}
          {mineQuery.error && <p className="text-red-600">Failed to load combos.</p>}
          {!mineQuery.isLoading && mineItems.length === 0 && (
            <p className="text-gray-500">
              You haven't created any private combos yet.{' '}
              <Link to="/combos/create" className="text-indigo-600 hover:underline">
                Create one now!
              </Link>
            </p>
          )}
          <div className="grid gap-4 sm:grid-cols-2">
            {mineItems.map((combo) => (
              <ComboCard key={combo.id} combo={combo} showActions />
            ))}
          </div>
        </>
      )}

      {/* Favourites tab */}
      {tab === 'favourites' && authed && (
        <>
          {favouritesQuery.isLoading && <p className="text-gray-500">Loading…</p>}
          {favouritesQuery.error && <p className="text-red-600">Failed to load favourites.</p>}
          {!favouritesQuery.isLoading && favouritesQuery.data?.length === 0 && (
            <p className="text-gray-500">You haven't favourited any combos yet.</p>
          )}
          <div className="grid gap-4 sm:grid-cols-2">
            {favouritesQuery.data?.map((combo) => (
              <ComboCard key={combo.id} combo={combo} showActions />
            ))}
          </div>
        </>
      )}
    </div>
  )
}
