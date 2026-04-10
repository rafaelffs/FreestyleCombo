import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { tricksApi, extractError, type TrickDto } from '@/lib/api'
import { isAdmin } from '@/lib/auth'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Badge } from '@/components/ui/badge'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'

function diffColor(d: number): string {
  if (d <= 4) return 'bg-green-100 text-green-800'
  if (d <= 7) return 'bg-yellow-100 text-yellow-800'
  return 'bg-red-100 text-red-800'
}

const EMPTY_FORM: Omit<TrickDto, 'id'> = {
  name: '',
  abbreviation: '',
  crossOver: false,
  knee: false,
  motion: 1,
  difficulty: 1,
  commonLevel: 1,
}

export function TricksPage() {
  const queryClient = useQueryClient()
  const admin = isAdmin()

  const [search, setSearch] = useState('')
  const [filterCrossOver, setFilterCrossOver] = useState<boolean | undefined>(undefined)
  const [filterKnee, setFilterKnee] = useState<boolean | undefined>(undefined)
  const [maxDiff, setMaxDiff] = useState<number | undefined>(undefined)

  const [editTrick, setEditTrick] = useState<TrickDto | null>(null)
  const [editForm, setEditForm] = useState<Omit<TrickDto, 'id'>>(EMPTY_FORM)
  const [editError, setEditError] = useState<string | null>(null)
  const [deleteError, setDeleteError] = useState<string | null>(null)

  const { data: tricks = [], isLoading } = useQuery({
    queryKey: ['tricks', filterCrossOver, filterKnee, maxDiff],
    queryFn: () =>
      tricksApi
        .getAll({
          crossOver: filterCrossOver,
          knee: filterKnee,
          maxDifficulty: maxDiff,
        })
        .then((r) => r.data),
  })

  const updateMutation = useMutation({
    mutationFn: (data: Omit<TrickDto, 'id'>) => tricksApi.update(editTrick!.id, data),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['tricks'] })
      setEditTrick(null)
      setEditError(null)
    },
    onError: (err) => setEditError(extractError(err, 'Update failed')),
  })

  const deleteMutation = useMutation({
    mutationFn: (id: string) => tricksApi.delete(id),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['tricks'] })
      setDeleteError(null)
    },
    onError: (err) => setDeleteError(extractError(err, 'Delete failed')),
  })

  function openEdit(trick: TrickDto) {
    setEditTrick(trick)
    const { id: _id, ...rest } = trick
    setEditForm(rest)
    setEditError(null)
  }

  function handleEditSubmit(e: React.FormEvent) {
    e.preventDefault()
    updateMutation.mutate(editForm)
  }

  const filtered = tricks.filter((t) =>
    t.name.toLowerCase().includes(search.toLowerCase()) ||
    t.abbreviation.toLowerCase().includes(search.toLowerCase()),
  )

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Tricks</h1>
        <p className="mt-1 text-sm text-gray-500">Browse all freestyle football tricks.</p>
      </div>

      {/* Filters */}
      <Card>
        <CardContent className="pt-4">
          <div className="flex flex-wrap items-end gap-4">
            <div className="flex-1 space-y-1 min-w-[160px]">
              <Label>Search</Label>
              <Input
                placeholder="Name or abbreviation"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
              />
            </div>
            <div className="space-y-1">
              <Label>Max Difficulty</Label>
              <Input
                type="number"
                min={1}
                max={10}
                placeholder="Any"
                className="w-24"
                value={maxDiff ?? ''}
                onChange={(e) =>
                  setMaxDiff(e.target.value ? Number(e.target.value) : undefined)
                }
              />
            </div>
            <div className="flex items-center gap-4 pb-0.5">
              <label className="flex items-center gap-1.5 text-sm cursor-pointer">
                <input
                  type="checkbox"
                  checked={filterCrossOver === true}
                  onChange={(e) =>
                    setFilterCrossOver(e.target.checked ? true : undefined)
                  }
                  className="h-4 w-4 rounded border-gray-300 text-indigo-600"
                />
                CrossOver only
              </label>
              <label className="flex items-center gap-1.5 text-sm cursor-pointer">
                <input
                  type="checkbox"
                  checked={filterKnee === true}
                  onChange={(e) =>
                    setFilterKnee(e.target.checked ? true : undefined)
                  }
                  className="h-4 w-4 rounded border-gray-300 text-indigo-600"
                />
                Knee only
              </label>
            </div>
          </div>
        </CardContent>
      </Card>

      {deleteError && <p className="text-sm text-red-600">{deleteError}</p>}

      {/* Table */}
      {isLoading ? (
        <p className="text-gray-500">Loading…</p>
      ) : (
        <div className="overflow-x-auto rounded-lg border border-gray-200">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 text-xs uppercase text-gray-500">
              <tr>
                <th className="px-4 py-3 text-left">Name</th>
                <th className="px-4 py-3 text-left">Abbrev</th>
                <th className="px-4 py-3 text-center">Motion</th>
                <th className="px-4 py-3 text-center">Diff</th>
                <th className="px-4 py-3 text-center">CO</th>
                <th className="px-4 py-3 text-center">Knee</th>
                {admin && <th className="px-4 py-3 text-right">Actions</th>}
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {filtered.map((trick) => (
                <tr key={trick.id} className="hover:bg-gray-50">
                  <td className="px-4 py-2 font-medium">{trick.name}</td>
                  <td className="px-4 py-2 font-mono text-xs text-gray-600">{trick.abbreviation}</td>
                  <td className="px-4 py-2 text-center">{trick.motion}</td>
                  <td className="px-4 py-2 text-center">
                    <span className={`inline-flex items-center rounded px-1.5 py-0.5 text-xs font-medium ${diffColor(trick.difficulty)}`}>
                      {trick.difficulty}
                    </span>
                  </td>
                  <td className="px-4 py-2 text-center">
                    {trick.crossOver ? <Badge variant="secondary">CO</Badge> : '—'}
                  </td>
                  <td className="px-4 py-2 text-center">
                    {trick.knee ? <Badge variant="secondary">K</Badge> : '—'}
                  </td>
                  {admin && (
                    <td className="px-4 py-2 text-right">
                      <div className="flex justify-end gap-2">
                        <Button variant="outline" size="sm" onClick={() => openEdit(trick)}>
                          Edit
                        </Button>
                        <Button
                          variant="outline"
                          size="sm"
                          className="text-red-600 hover:text-red-700"
                          disabled={deleteMutation.isPending}
                          onClick={() => {
                            if (confirm(`Delete "${trick.name}"?`)) deleteMutation.mutate(trick.id)
                          }}
                        >
                          Delete
                        </Button>
                      </div>
                    </td>
                  )}
                </tr>
              ))}
              {filtered.length === 0 && (
                <tr>
                  <td colSpan={admin ? 7 : 6} className="px-4 py-6 text-center text-gray-400">
                    No tricks found.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      )}

      {/* Edit dialog */}
      <Dialog open={editTrick !== null} onOpenChange={(open) => !open && setEditTrick(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Edit Trick</DialogTitle>
          </DialogHeader>
          <form onSubmit={handleEditSubmit} className="space-y-4">
            <div className="grid grid-cols-2 gap-3">
              <div className="col-span-2 space-y-1">
                <Label>Name</Label>
                <Input
                  value={editForm.name}
                  onChange={(e) => setEditForm((f) => ({ ...f, name: e.target.value }))}
                  maxLength={100}
                  required
                />
              </div>
              <div className="space-y-1">
                <Label>Abbreviation</Label>
                <Input
                  value={editForm.abbreviation}
                  onChange={(e) => setEditForm((f) => ({ ...f, abbreviation: e.target.value }))}
                  maxLength={20}
                  required
                />
              </div>
              <div className="space-y-1">
                <Label>Motion</Label>
                <Input
                  type="number"
                  min={0.5}
                  max={10}
                  step={0.5}
                  value={editForm.motion}
                  onChange={(e) => setEditForm((f) => ({ ...f, motion: Number(e.target.value) }))}
                  required
                />
              </div>
              <div className="space-y-1">
                <Label>Difficulty (1-10)</Label>
                <Input
                  type="number"
                  min={1}
                  max={10}
                  value={editForm.difficulty}
                  onChange={(e) => setEditForm((f) => ({ ...f, difficulty: Number(e.target.value) }))}
                  required
                />
              </div>
              <div className="space-y-1">
                <Label>Common Level (1-10)</Label>
                <Input
                  type="number"
                  min={1}
                  max={10}
                  value={editForm.commonLevel}
                  onChange={(e) => setEditForm((f) => ({ ...f, commonLevel: Number(e.target.value) }))}
                  required
                />
              </div>
            </div>
            <div className="flex gap-6">
              <label className="flex items-center gap-2 text-sm cursor-pointer">
                <input
                  type="checkbox"
                  checked={editForm.crossOver}
                  onChange={(e) => setEditForm((f) => ({ ...f, crossOver: e.target.checked }))}
                  className="h-4 w-4 rounded border-gray-300 text-indigo-600"
                />
                CrossOver
              </label>
              <label className="flex items-center gap-2 text-sm cursor-pointer">
                <input
                  type="checkbox"
                  checked={editForm.knee}
                  onChange={(e) => setEditForm((f) => ({ ...f, knee: e.target.checked }))}
                  className="h-4 w-4 rounded border-gray-300 text-indigo-600"
                />
                Knee
              </label>
            </div>
            {editError && <p className="text-sm text-red-600">{editError}</p>}
            <div className="flex justify-end gap-2">
              <Button type="button" variant="outline" onClick={() => setEditTrick(null)}>
                Cancel
              </Button>
              <Button type="submit" disabled={updateMutation.isPending}>
                {updateMutation.isPending ? 'Saving…' : 'Save'}
              </Button>
            </div>
          </form>
        </DialogContent>
      </Dialog>
    </div>
  )
}
