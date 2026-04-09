import { useQuery } from '@tanstack/react-query'
import { combosApi } from '@/lib/api'
import { ComboCard } from './ComboCard'
import { isAuthenticated } from '@/lib/auth'

export function PublicCombosPage() {
  const { data, isLoading, error } = useQuery({
    queryKey: ['combos', 'public'],
    queryFn: () => combosApi.getPublic().then((r) => r.data),
  })

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Public Combos</h1>
        <p className="mt-1 text-sm text-gray-500">Combos shared by the community.</p>
      </div>

      {isLoading && <p className="text-gray-500">Loading…</p>}
      {error && <p className="text-red-600">Failed to load combos.</p>}
      {data?.length === 0 && <p className="text-gray-500">No public combos yet.</p>}

      <div className="grid gap-4 sm:grid-cols-2">
        {data?.map((combo) => (
          <ComboCard key={combo.id} combo={combo} showActions={isAuthenticated()} />
        ))}
      </div>
    </div>
  )
}
