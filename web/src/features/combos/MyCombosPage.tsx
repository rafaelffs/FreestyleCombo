import { useQuery } from '@tanstack/react-query'
import { combosApi } from '@/lib/api'
import { ComboCard } from './ComboCard'
import { Button } from '@/components/ui/button'
import { Link } from 'react-router-dom'

export function MyCombosPage() {
  const { data, isLoading, error } = useQuery({
    queryKey: ['combos', 'mine'],
    queryFn: () => combosApi.getMine().then((r) => r.data.items),
  })

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">My Combos</h1>
          <p className="mt-1 text-sm text-gray-500">All combos you've generated.</p>
        </div>
        <Button asChild>
          <Link to="/generate">Generate new</Link>
        </Button>
      </div>

      {isLoading && <p className="text-gray-500">Loading…</p>}
      {error && <p className="text-red-600">Failed to load combos.</p>}
      {data?.length === 0 && (
        <p className="text-gray-500">
          You haven't generated any combos yet.{' '}
          <Link to="/generate" className="text-indigo-600 hover:underline">
            Generate one now!
          </Link>
        </p>
      )}

      <div className="grid gap-4 sm:grid-cols-2">
        {data?.map((combo) => (
          <ComboCard key={combo.id} combo={combo} showActions />
        ))}
      </div>
    </div>
  )
}
