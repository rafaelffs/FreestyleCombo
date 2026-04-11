import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { combosApi, type ComboDto } from '@/lib/api'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'

export function AdminComboReviewsPage() {
  const queryClient = useQueryClient()

  const { data: combos, isLoading, error } = useQuery({
    queryKey: ['pending-combo-reviews'],
    queryFn: () => combosApi.getPendingReview().then((r) => r.data),
  })

  const approveMutation = useMutation({
    mutationFn: (id: string) => combosApi.approveVisibility(id),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['pending-combo-reviews'] }),
  })

  const rejectMutation = useMutation({
    mutationFn: (id: string) => combosApi.rejectVisibility(id),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['pending-combo-reviews'] }),
  })

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Pending Combo Reviews</h1>
        <p className="mt-1 text-sm text-gray-500">
          Approve or reject combos submitted for public visibility.
        </p>
      </div>

      {isLoading && <p className="text-gray-500">Loading…</p>}
      {error && <p className="text-sm text-red-600">Failed to load pending combos.</p>}

      {combos && combos.length === 0 && (
        <p className="text-gray-500">No combos pending review.</p>
      )}

      <div className="space-y-4">
        {combos?.map((combo: ComboDto) => (
          <Card key={combo.id}>
            <CardHeader className="pb-2">
              <div className="flex items-start justify-between gap-4">
                <div>
                  {combo.name && <p className="text-sm font-semibold">{combo.name}</p>}
                  <CardTitle className="text-base font-mono">{combo.displayText}</CardTitle>
                  <p className="text-sm text-gray-500">
                    by <span className="font-medium">{combo.ownerUserName}</span>
                    {' · '}{new Date(combo.createdAt).toLocaleDateString()}
                  </p>
                </div>
                <div className="flex flex-wrap gap-1">
                  <Badge variant="secondary">
                    Avg diff: {combo.averageDifficulty?.toFixed(1) ?? '—'}
                  </Badge>
                  <Badge variant="secondary">{combo.trickCount} tricks</Badge>
                </div>
              </div>
            </CardHeader>
            <CardContent>
              {combo.tricks && combo.tricks.length > 0 && (
                <div className="mb-3 flex flex-wrap gap-1">
                  {combo.tricks.map((t) => (
                    <span
                      key={t.position}
                      className="inline-flex items-center gap-0.5 rounded bg-gray-100 px-2 py-0.5 text-xs font-medium text-gray-700"
                    >
                      {t.position}. {t.abbreviation}
                      {t.noTouch && <span className="text-indigo-500">(nt)</span>}
                      {!t.strongFoot && <span className="text-orange-500">(wf)</span>}
                    </span>
                  ))}
                </div>
              )}
              <div className="flex gap-2">
                <Button
                  size="sm"
                  onClick={() => approveMutation.mutate(combo.id)}
                  disabled={approveMutation.isPending}
                >
                  Approve
                </Button>
                <Button
                  variant="outline"
                  size="sm"
                  className="text-red-600 hover:text-red-700"
                  onClick={() => rejectMutation.mutate(combo.id)}
                  disabled={rejectMutation.isPending}
                >
                  Reject
                </Button>
              </div>
            </CardContent>
          </Card>
        ))}
      </div>
    </div>
  )
}
