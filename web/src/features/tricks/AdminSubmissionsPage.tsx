import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { combosApi, type ComboDto } from '@/lib/api'
import { trickSubmissionsApi, type TrickSubmissionDto } from '@/lib/api'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'

export function AdminSubmissionsPage() {
  const queryClient = useQueryClient()
  const [processingComboId, setProcessingComboId] = useState<string | null>(null)

  const { data: submissions, isLoading, error } = useQuery({
    queryKey: ['pending-submissions'],
    queryFn: () => trickSubmissionsApi.getPending().then((r) => r.data),
  })

  const {
    data: pendingCombos,
    isLoading: combosLoading,
    error: combosError,
  } = useQuery({
    queryKey: ['pending-combo-reviews'],
    queryFn: () => combosApi.getPendingReview().then((r) => r.data),
  })

  const invalidateAll = () => {
    void queryClient.invalidateQueries({ queryKey: ['pending-submissions'] })
    void queryClient.invalidateQueries({ queryKey: ['pending-combo-reviews'] })
    void queryClient.invalidateQueries({ queryKey: ['pending-count'] })
  }

  const approveMutation = useMutation({
    mutationFn: (id: string) => trickSubmissionsApi.approve(id),
    onSuccess: invalidateAll,
  })

  const rejectMutation = useMutation({
    mutationFn: (id: string) => trickSubmissionsApi.reject(id),
    onSuccess: invalidateAll,
  })

  const approveComboMutation = useMutation({
    mutationFn: (id: string) => { setProcessingComboId(id); return combosApi.approveVisibility(id) },
    onSettled: () => setProcessingComboId(null),
    onSuccess: invalidateAll,
  })

  const rejectComboMutation = useMutation({
    mutationFn: (id: string) => { setProcessingComboId(id); return combosApi.rejectVisibility(id) },
    onSettled: () => setProcessingComboId(null),
    onSuccess: invalidateAll,
  })

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Approvals</h1>
        <p className="mt-1 text-sm text-gray-500">
          Review pending combo publication requests and trick submissions.
        </p>
      </div>

      <div className="space-y-3">
        <h2 className="text-lg font-semibold text-gray-900">Combo Publication Requests</h2>
        {combosLoading && <p className="text-gray-500">Loading…</p>}
        {combosError && <p className="text-sm text-red-600">Failed to load pending combos.</p>}
        {pendingCombos && pendingCombos.length === 0 && (
          <p className="text-gray-500">No combos pending review.</p>
        )}
        <div className="space-y-4">
          {pendingCombos?.map((combo: ComboDto) => (
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
                    onClick={() => approveComboMutation.mutate(combo.id)}
                    disabled={processingComboId === combo.id}
                  >
                    Approve
                  </Button>
                  <Button
                    variant="outline"
                    size="sm"
                    className="text-red-600 hover:text-red-700"
                    onClick={() => rejectComboMutation.mutate(combo.id)}
                    disabled={processingComboId === combo.id}
                  >
                    Reject
                  </Button>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      </div>

      <div className="space-y-3">
        <h2 className="text-lg font-semibold text-gray-900">Trick Submissions</h2>
        {isLoading && <p className="text-gray-500">Loading…</p>}
        {error && <p className="text-sm text-red-600">Failed to load submissions.</p>}
      {submissions && submissions.length === 0 && (
        <p className="text-gray-500">No pending submissions.</p>
      )}
      <div className="space-y-4">
        {submissions?.map((s: TrickSubmissionDto) => (
          <Card key={s.id}>
            <CardHeader className="pb-2">
              <div className="flex items-start justify-between gap-4">
                <div>
                  <CardTitle className="text-base">{s.name}</CardTitle>
                  <p className="text-sm text-gray-500">
                    <span className="font-mono">{s.abbreviation}</span> · submitted by{' '}
                    <span className="font-medium">{s.submittedByUserName}</span> ·{' '}
                    {new Date(s.submittedAt).toLocaleDateString()}
                  </p>
                </div>
                <Badge variant="secondary">Pending</Badge>
              </div>
            </CardHeader>
            <CardContent>
              <dl className="grid grid-cols-3 gap-x-4 gap-y-1 text-sm sm:grid-cols-5 mb-4">
                <div>
                  <dt className="text-gray-500">Revs</dt>
                  <dd className="font-medium">{s.revolution}</dd>
                </div>
                <div>
                  <dt className="text-gray-500">Difficulty</dt>
                  <dd className="font-medium">{s.difficulty}</dd>
                </div>
                <div>
                  <dt className="text-gray-500">Common Level</dt>
                  <dd className="font-medium">{s.commonLevel}</dd>
                </div>
                <div>
                  <dt className="text-gray-500">CrossOver</dt>
                  <dd className="font-medium">{s.crossOver ? 'Yes' : 'No'}</dd>
                </div>
                <div>
                  <dt className="text-gray-500">Knee</dt>
                  <dd className="font-medium">{s.knee ? 'Yes' : 'No'}</dd>
                </div>
              </dl>

              <div className="flex gap-2">
                <Button
                  size="sm"
                  onClick={() => approveMutation.mutate(s.id)}
                  disabled={approveMutation.isPending || rejectMutation.isPending}
                >
                  Approve
                </Button>
                <Button
                  size="sm"
                  variant="destructive"
                  onClick={() => rejectMutation.mutate(s.id)}
                  disabled={approveMutation.isPending || rejectMutation.isPending}
                >
                  Reject
                </Button>
              </div>
            </CardContent>
          </Card>
        ))}
      </div>
      </div>
    </div>
  )
}
