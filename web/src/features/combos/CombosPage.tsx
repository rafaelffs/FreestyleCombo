import { useState } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { Link } from 'react-router-dom'
import { combosApi } from '@/lib/api'
import { ComboCard } from './ComboCard'
import { Button } from '@/components/ui/button'
import { isAuthenticated } from '@/lib/auth'

export function CombosPage() {
  const authed = isAuthenticated()
  const [tab, setTab] = useState<'public' | 'mine'>(authed ? 'mine' : 'public')
  const queryClient = useQueryClient()

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

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Combos</h1>
          <p className="mt-1 text-sm text-gray-500">Browse public combos or view your own.</p>
        </div>
        {authed && (
          <Button asChild>
            <Link to="/combos/create">Create new</Link>
          </Button>
        )}
      </div>

      {/* Tab bar */}
      <div className="flex gap-1 border-b border-gray-200">
        <button
          onClick={() => setTab('public')}
          className={`px-4 py-2 text-sm font-medium transition-colors ${
            tab === 'public'
              ? 'border-b-2 border-indigo-600 text-indigo-600'
              : 'text-gray-500 hover:text-gray-900'
          }`}
        >
          Public
        </button>
        {authed && (
          <button
            onClick={() => setTab('mine')}
            className={`px-4 py-2 text-sm font-medium transition-colors ${
              tab === 'mine'
                ? 'border-b-2 border-indigo-600 text-indigo-600'
                : 'text-gray-500 hover:text-gray-900'
            }`}
          >
            Mine
          </button>
        )}
      </div>

      {/* Public tab */}
      {tab === 'public' && (
        <>
          {publicQuery.isLoading && <p className="text-gray-500">Loading…</p>}
          {publicQuery.error && <p className="text-red-600">Failed to load combos.</p>}
          {publicQuery.data?.length === 0 && <p className="text-gray-500">No public combos yet.</p>}
          <div className="grid gap-4 sm:grid-cols-2">
            {publicQuery.data?.map((combo) => (
              <ComboCard
                key={combo.id}
                combo={combo}
                showActions={authed}
                onDeleted={() => void queryClient.invalidateQueries({ queryKey: ['combos', 'public'] })}
              />
            ))}
          </div>
        </>
      )}

      {/* Mine tab */}
      {tab === 'mine' && authed && (
        <>
          {mineQuery.isLoading && <p className="text-gray-500">Loading…</p>}
          {mineQuery.error && <p className="text-red-600">Failed to load combos.</p>}
          {mineQuery.data?.length === 0 && (
            <p className="text-gray-500">
              You haven't created any combos yet.{' '}
              <Link to="/combos/create" className="text-indigo-600 hover:underline">
                Create one now!
              </Link>
            </p>
          )}
          <div className="grid gap-4 sm:grid-cols-2">
            {mineQuery.data?.map((combo) => (
              <ComboCard
                key={combo.id}
                combo={combo}
                showActions
                onDeleted={() => void queryClient.invalidateQueries({ queryKey: ['combos', 'mine'] })}
              />
            ))}
          </div>
        </>
      )}
    </div>
  )
}
