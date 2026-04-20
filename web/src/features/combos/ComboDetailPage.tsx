import { useState } from 'react'
import { useParams, Link, useNavigate } from 'react-router-dom'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { combosApi, tricksApi, extractError, type BuildComboTrickItem } from '@/lib/api'
import { getUserId, isAdmin } from '@/lib/auth'
import { SEO } from '@/components/SEO'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { RateComboDialog } from './RateComboDialog'

interface SlotItem extends BuildComboTrickItem {
  trickName: string
  abbreviation: string
  crossOver: boolean
}

function diffColor(d: number): string {
  if (d <= 4) return 'bg-green-100 text-green-800'
  if (d <= 7) return 'bg-yellow-100 text-yellow-800'
  return 'bg-red-100 text-red-800'
}

export function ComboDetailPage() {
  const { id } = useParams<{ id: string }>()
  const currentUserId = getUserId()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [ratingOpen, setRatingOpen] = useState(false)
  const [editing, setEditing] = useState(false)

  // Edit state
  const [editName, setEditName] = useState('')
  const [deleteError, setDeleteError] = useState<string | null>(null)
  const [editSlots, setEditSlots] = useState<SlotItem[]>([])
  const [trickSearch, setTrickSearch] = useState('')
  const [editError, setEditError] = useState<string | null>(null)

  const { data: combo, isLoading, error } = useQuery({
    queryKey: ['combos', id],
    queryFn: () => combosApi.getById(id!).then((r) => r.data),
    enabled: !!id,
  })

  const { data: tricks = [] } = useQuery({
    queryKey: ['tricks'],
    queryFn: () => tricksApi.getAll().then((r) => r.data),
    enabled: editing,
  })

  const updateMutation = useMutation({
    mutationFn: () =>
      combosApi.update(id!, {
        name: editName || null,
        tricks: editSlots.map(({ trickId, position, strongFoot, noTouch }) => ({ trickId, position, strongFoot, noTouch })),
      }),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['combos', id] })
      void queryClient.invalidateQueries({ queryKey: ['combos'] })
      setEditing(false)
      setEditError(null)
    },
    onError: (err) => setEditError(extractError(err, 'Update failed')),
  })

  const deleteMutation = useMutation({
    mutationFn: () => combosApi.delete(id!),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['combos'] })
      navigate('/combos')
    },
    onError: (err) => setDeleteError(extractError(err, 'Delete failed')),
  })

  if (isLoading) return <p className="text-gray-500">Loading…</p>
  if (error || !combo) return <p className="text-red-600">Combo not found.</p>

  const isOwner = combo.ownerId === currentUserId
  const canDelete = isOwner || isAdmin()

  function startEdit() {
    setEditName(combo!.name ?? '')
    setEditSlots(
      (combo!.tricks ?? []).map((t) => ({
        trickId: t.trickId,
        position: t.position,
        strongFoot: t.strongFoot,
        noTouch: t.noTouch,
        trickName: t.name ?? '',
        abbreviation: t.abbreviation,
        crossOver: false, // will be re-populated when tricks load
      })),
    )
    setTrickSearch('')
    setEditError(null)
    setEditing(true)
  }

  function addTrick(trick: { id: string; name: string; abbreviation: string; crossOver: boolean }) {
    setEditSlots((prev) => [
      ...prev,
      { trickId: trick.id, position: prev.length + 1, strongFoot: true, noTouch: false, trickName: trick.name, abbreviation: trick.abbreviation, crossOver: trick.crossOver },
    ])
  }

  function removeSlot(index: number) {
    setEditSlots((prev) => prev.filter((_, i) => i !== index).map((s, i) => ({ ...s, position: i + 1 })))
  }

  function toggleSF(index: number) {
    setEditSlots((prev) => prev.map((s, i) => (i === index ? { ...s, strongFoot: !s.strongFoot } : s)))
  }

  function toggleNT(index: number) {
    setEditSlots((prev) => prev.map((s, i) => {
      if (i !== index || !s.crossOver) return s
      return { ...s, noTouch: !s.noTouch }
    }))
  }

  const filteredTricks = tricks.filter(
    (t) => t.name.toLowerCase().includes(trickSearch.toLowerCase()) || t.abbreviation.toLowerCase().includes(trickSearch.toLowerCase()),
  )

  return (
    <div className="space-y-6">
      <SEO
        title={`${combo.name ?? 'Combo'} — FreestyleCombo`}
        description={combo.aiDescription ?? `A freestyle football combo with ${combo.trickCount} tricks.`}
        path={`/combos/${id}`}
      />
      <div className="flex items-center gap-3">
        <Link to="/combos" className="text-sm text-gray-500 hover:text-gray-700">
          ← Back
        </Link>
      </div>

      <Card>
        <CardHeader>
          <div className="flex items-start justify-between gap-2">
            <div>
              {combo.name && <p className="text-sm font-semibold text-gray-900 mb-1">{combo.name}</p>}
              <CardTitle className="font-mono text-xl">{combo.displayText}</CardTitle>
              {combo.ownerUserName && (
                <p className="text-sm text-gray-500 mt-0.5">by {combo.ownerUserName}</p>
              )}
            </div>
            <div className="flex flex-wrap gap-1">
              {combo.averageRating != null && combo.averageRating > 0 && (
                <Badge variant="secondary">
                  ★ {combo.averageRating.toFixed(1)} ({combo.totalRatings ?? combo.ratingCount ?? 0} ratings)
                </Badge>
              )}
            </div>
          </div>
        </CardHeader>
        <CardContent className="space-y-4">
          {combo.aiDescription && (
            <blockquote className="border-l-4 border-indigo-300 pl-4 text-sm italic text-gray-600">
              {combo.aiDescription}
            </blockquote>
          )}

          <div>
            <h3 className="mb-2 text-sm font-medium text-gray-700">Tricks</h3>
            <div className="overflow-x-auto -mx-4 sm:mx-0">
              <table className="w-full min-w-[400px] text-sm">
                <thead>
                  <tr className="border-b text-left text-gray-500">
                    <th className="pb-1 pr-4">#</th>
                    <th className="pb-1 pr-4">Name</th>
                    <th className="pb-1 pr-4">Abbr.</th>
                    <th className="pb-1 pr-4">Difficulty</th>
                    <th className="pb-1 pr-4">Foot</th>
                    <th className="pb-1">No-Touch</th>
                  </tr>
                </thead>
                <tbody>
                  {(combo.tricks ?? []).map((t) => (
                    <tr key={t.position} className="border-b last:border-0">
                      <td className="py-1.5 pr-4 text-gray-500">{t.position}</td>
                      <td className="py-1.5 pr-4 font-medium">{t.name}</td>
                      <td className="py-1.5 pr-4 font-mono text-xs">{t.abbreviation}</td>
                      <td className="py-1.5 pr-4">{t.difficulty}</td>
                      <td className="py-1.5 pr-4">{t.strongFoot ? 'Strong' : 'Weak'}</td>
                      <td className="py-1.5">{t.noTouch ? '✓' : '—'}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>

          <div className="flex gap-2 pt-1">
            <Badge variant="secondary">Avg difficulty: {combo.averageDifficulty?.toFixed(1) ?? '—'}</Badge>
            <Badge variant="secondary">{combo.trickCount} tricks</Badge>
          </div>

          <div className="flex gap-2 flex-wrap">
            {!isOwner && currentUserId && (
              <Button variant="outline" onClick={() => setRatingOpen(true)}>
                Rate this combo
              </Button>
            )}
            {isOwner && !editing && (
              <Button variant="outline" onClick={startEdit}>
                Edit combo
              </Button>
            )}
            {canDelete && (
              <Button
                variant="outline"
                className="text-red-600 hover:text-red-700"
                onClick={() => {
                  if (confirm('Delete this combo? This action cannot be undone.')) {
                    deleteMutation.mutate()
                  }
                }}
                disabled={deleteMutation.isPending}
              >
                Delete combo
              </Button>
            )}
          </div>
          {deleteError && <p className="text-sm text-red-600">{deleteError}</p>}
        </CardContent>
      </Card>

      {/* Inline edit panel */}
      {editing && (
        <Card>
          <CardHeader>
            <CardTitle>Edit Combo</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-1">
              <Label htmlFor="edit-name">Combo name</Label>
              <Input id="edit-name" value={editName} onChange={(e) => setEditName(e.target.value)} placeholder="e.g. My signature combo" maxLength={100} />
            </div>

            <div className="grid gap-4 lg:grid-cols-2">
              {/* Trick picker */}
              <div className="space-y-2">
                <p className="text-sm font-medium text-gray-700">Add tricks</p>
                <Input placeholder="Search…" value={trickSearch} onChange={(e) => setTrickSearch(e.target.value)} />
                <div className="max-h-[40vh] overflow-y-auto divide-y divide-gray-100 rounded border lg:max-h-60">
                  {filteredTricks.map((trick) => (
                    <button key={trick.id} type="button" onClick={() => addTrick(trick)} className="flex w-full items-center justify-between px-2 py-1.5 text-left hover:bg-indigo-50 transition-colors">
                      <span className="text-sm">{trick.name} <span className="font-mono text-xs text-gray-400">{trick.abbreviation}</span></span>
                      <span className={`inline-flex items-center rounded px-1.5 py-0.5 text-xs font-medium ${diffColor(trick.difficulty)}`}>{trick.difficulty}</span>
                    </button>
                  ))}
                </div>
              </div>

              {/* Slot list */}
              <div className="space-y-2">
                <p className="text-sm font-medium text-gray-700">Combo ({editSlots.length} tricks)</p>
                <div className="space-y-1 max-h-[40vh] overflow-y-auto lg:max-h-60">
                  {editSlots.length === 0 && <p className="text-sm text-gray-400 py-2">No tricks added.</p>}
                  {editSlots.map((slot, i) => (
                    <div key={i} className="flex items-center gap-2 rounded border border-gray-200 px-2 py-1.5">
                      <span className="w-4 shrink-0 text-xs font-bold text-gray-400">{slot.position}</span>
                      <span className="flex-1 text-sm">{slot.trickName} <span className="font-mono text-xs text-gray-400">{slot.abbreviation}</span></span>
                      <label className="flex items-center gap-0.5 text-xs text-gray-600 cursor-pointer">
                        <input type="checkbox" checked={slot.strongFoot} onChange={() => toggleSF(i)} className="h-3 w-3" /> SF
                      </label>
                      <label className={`flex items-center gap-0.5 text-xs cursor-pointer ${slot.crossOver ? 'text-gray-600' : 'text-gray-300 cursor-not-allowed'}`}>
                        <input type="checkbox" checked={slot.noTouch} onChange={() => toggleNT(i)} disabled={!slot.crossOver} className="h-3 w-3" /> NT
                      </label>
                      <button type="button" onClick={() => removeSlot(i)} className="text-gray-400 hover:text-red-500 text-base leading-none">×</button>
                    </div>
                  ))}
                </div>
              </div>
            </div>

            {editError && <p className="text-sm text-red-600">{editError}</p>}

            <div className="flex gap-2">
              <Button onClick={() => updateMutation.mutate()} disabled={updateMutation.isPending || editSlots.length === 0}>
                {updateMutation.isPending ? 'Saving…' : 'Save changes'}
              </Button>
              <Button variant="outline" onClick={() => setEditing(false)}>Cancel</Button>
            </div>
          </CardContent>
        </Card>
      )}

      <RateComboDialog
        comboId={combo.id}
        open={ratingOpen}
        onOpenChange={setRatingOpen}
      />
    </div>
  )
}
