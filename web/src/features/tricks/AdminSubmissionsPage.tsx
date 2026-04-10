import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { trickSubmissionsApi, type TrickSubmissionDto } from '@/lib/api'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'

export function AdminSubmissionsPage() {
  const queryClient = useQueryClient()

  const { data: submissions, isLoading, error } = useQuery({
    queryKey: ['pending-submissions'],
    queryFn: () => trickSubmissionsApi.getPending().then((r) => r.data),
  })

  const approveMutation = useMutation({
    mutationFn: (id: string) => trickSubmissionsApi.approve(id),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['pending-submissions'] }),
  })

  const rejectMutation = useMutation({
    mutationFn: (id: string) => trickSubmissionsApi.reject(id),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['pending-submissions'] }),
  })

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Pending Trick Submissions</h1>
        <p className="mt-1 text-sm text-gray-500">
          Review and approve or reject tricks submitted by users.
        </p>
      </div>

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
                  <dt className="text-gray-500">Motion</dt>
                  <dd className="font-medium">{s.motion}</dd>
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
  )
}
