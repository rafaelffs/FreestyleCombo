import { useState, useRef } from 'react'
import { useParams, Link, useNavigate } from 'react-router-dom'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { useTranslation } from 'react-i18next'
import { GripVertical } from 'lucide-react'
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
  isTransition: boolean
}

function applyNoTouchRules(slots: SlotItem[]): SlotItem[] {
  return slots.map((slot, i) => {
    const afterTransition = i === 0 || slots[i - 1].isTransition
    return slot.crossOver && !afterTransition ? slot : { ...slot, noTouch: false }
  })
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
  const { t } = useTranslation()
  const [ratingOpen, setRatingOpen] = useState(false)
  const [editing, setEditing] = useState(false)

  // Edit state
  const [editName, setEditName] = useState('')
  const [deleteError, setDeleteError] = useState<string | null>(null)
  const [editSlots, setEditSlots] = useState<SlotItem[]>([])
  const [trickSearch, setTrickSearch] = useState('')
  const [editError, setEditError] = useState<string | null>(null)
  const editDragIndex = useRef<number | null>(null)
  const [editDragOverIndex, setEditDragOverIndex] = useState<number | null>(null)

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
    onError: (err) => setEditError(extractError(err, t('comboDetail.updateFailed'))),
  })

  const deleteMutation = useMutation({
    mutationFn: () => combosApi.delete(id!),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['combos'] })
      navigate('/combos')
    },
    onError: (err) => setDeleteError(extractError(err, t('comboDetail.deleteFailed'))),
  })

  if (isLoading) return <p className="text-gray-500">{t('comboDetail.loading')}</p>
  if (error || !combo) return <p className="text-red-600">{t('comboDetail.notFound')}</p>

  const isOwner = combo.ownerId === currentUserId
  const canDelete = isOwner || isAdmin()

  function startEdit() {
    setEditName(combo!.name ?? '')
    setEditSlots(
      applyNoTouchRules(
        (combo!.tricks ?? []).map((t_) => ({
          trickId: t_.trickId,
          position: t_.position,
          strongFoot: t_.strongFoot,
          noTouch: t_.noTouch,
          trickName: t_.name ?? '',
          abbreviation: t_.abbreviation,
          crossOver: t_.crossOver,
          isTransition: t_.isTransition,
        })),
      ),
    )
    setTrickSearch('')
    setEditError(null)
    setEditing(true)
  }

  function addTrick(trick: { id: string; name: string; abbreviation: string; crossOver: boolean; isTransition: boolean }) {
    setEditSlots((prev) => {
      const next = [...prev, { trickId: trick.id, position: prev.length + 1, strongFoot: true, noTouch: false, trickName: trick.name, abbreviation: trick.abbreviation, crossOver: trick.crossOver, isTransition: trick.isTransition }]
      return applyNoTouchRules(next)
    })
  }

  function removeSlot(index: number) {
    setEditSlots((prev) => prev.filter((_, i) => i !== index).map((s, i) => ({ ...s, position: i + 1 })))
  }

  function reorderEditSlots(from: number, to: number) {
    setEditSlots((prev) => {
      const next = [...prev]
      const [moved] = next.splice(from, 1)
      next.splice(to, 0, moved)
      return applyNoTouchRules(next.map((s, i) => ({ ...s, position: i + 1 })))
    })
  }

  function toggleSF(index: number) {
    setEditSlots((prev) => prev.map((s, i) => (i === index ? { ...s, strongFoot: !s.strongFoot } : s)))
  }

  function toggleNT(index: number) {
    setEditSlots((prev) => prev.map((s, i) => {
      if (i !== index) return s
      const afterTransition = index === 0 || prev[index - 1].isTransition
      if (!s.crossOver || afterTransition) return s
      return { ...s, noTouch: !s.noTouch }
    }))
  }

  const filteredTricks = tricks.filter(
    (t_) => t_.name.toLowerCase().includes(trickSearch.toLowerCase()) || t_.abbreviation.toLowerCase().includes(trickSearch.toLowerCase()),
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
          {t('comboDetail.back')}
        </Link>
      </div>

      <Card>
        <CardHeader>
          <div className="flex items-start justify-between gap-2">
            <div>
              {combo.name && <p className="text-sm font-semibold text-gray-900 mb-1">{combo.name}</p>}
              <CardTitle className="font-mono text-xl">{combo.displayText}</CardTitle>
              {combo.ownerUserName && (
                <p className="text-sm text-gray-500 mt-0.5">{t('combos.by')} {combo.ownerUserName}</p>
              )}
            </div>
            <div className="flex flex-wrap gap-1">
              {combo.averageRating != null && combo.averageRating > 0 && (
                <Badge variant="secondary">
                  ★ {combo.averageRating.toFixed(1)} ({t('comboDetail.ratings', { count: combo.totalRatings ?? combo.ratingCount ?? 0 })})
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
            <h3 className="mb-2 text-sm font-medium text-gray-700">{t('comboDetail.tricksHeader')}</h3>
            <div className="overflow-x-auto -mx-4 sm:mx-0">
              <table className="w-full min-w-[400px] text-sm">
                <thead>
                  <tr className="border-b text-left text-gray-500">
                    <th className="pb-1 pr-4">{t('comboDetail.colPosition')}</th>
                    <th className="pb-1 pr-4">{t('comboDetail.colName')}</th>
                    <th className="pb-1 pr-4">{t('comboDetail.colAbbr')}</th>
                    <th className="pb-1 pr-4">{t('comboDetail.colDifficulty')}</th>
                    <th className="pb-1 pr-4">{t('comboDetail.colFoot')}</th>
                    <th className="pb-1">{t('comboDetail.colNoTouch')}</th>
                  </tr>
                </thead>
                <tbody>
                  {(combo.tricks ?? []).map((trick) => (
                    <tr key={trick.position} className="border-b last:border-0">
                      <td className="py-1.5 pr-4 text-gray-500">{trick.position}</td>
                      <td className="py-1.5 pr-4 font-medium">{trick.name}</td>
                      <td className="py-1.5 pr-4 font-mono text-xs">{trick.abbreviation}</td>
                      <td className="py-1.5 pr-4">{trick.difficulty}</td>
                      <td className="py-1.5 pr-4">{trick.strongFoot ? t('comboDetail.footStrong') : t('comboDetail.footWeak')}</td>
                      <td className="py-1.5">{trick.noTouch ? '✓' : '—'}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>

          <div className="flex gap-2 pt-1">
            <Badge variant="secondary">{t('comboDetail.avgDifficulty', { value: combo.averageDifficulty?.toFixed(1) ?? '—' })}</Badge>
            <Badge variant="secondary">{t('comboDetail.trickCount', { count: combo.trickCount })}</Badge>
          </div>

          <div className="flex gap-2 flex-wrap">
            {!isOwner && currentUserId && (
              <Button variant="outline" onClick={() => setRatingOpen(true)}>
                {t('comboDetail.rateCombo')}
              </Button>
            )}
            {isOwner && !editing && (
              <Button variant="outline" onClick={startEdit}>
                {t('comboDetail.editCombo')}
              </Button>
            )}
            {canDelete && (
              <Button
                variant="outline"
                className="text-red-600 hover:text-red-700"
                onClick={() => {
                  if (confirm(t('comboDetail.deleteConfirm'))) {
                    deleteMutation.mutate()
                  }
                }}
                disabled={deleteMutation.isPending}
              >
                {t('comboDetail.deleteCombo')}
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
            <CardTitle>{t('comboDetail.editTitle')}</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-1">
              <Label htmlFor="edit-name">{t('comboDetail.comboNameLabel')}</Label>
              <Input id="edit-name" value={editName} onChange={(e) => setEditName(e.target.value)} placeholder={t('comboDetail.comboNamePlaceholder')} maxLength={100} />
            </div>

            <div className="grid gap-4 lg:grid-cols-2">
              {/* Trick picker */}
              <div className="space-y-2">
                <p className="text-sm font-medium text-gray-700">{t('comboDetail.addTricks')}</p>
                <Input placeholder={t('comboDetail.searchPlaceholder')} value={trickSearch} onChange={(e) => setTrickSearch(e.target.value)} />
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
                <p className="text-sm font-medium text-gray-700">{t('comboDetail.comboSlotCount', { count: editSlots.length })}</p>
                <div className="space-y-1 max-h-[40vh] overflow-y-auto lg:max-h-60">
                  {editSlots.length === 0 && <p className="text-sm text-gray-400 py-2">{t('comboDetail.noTricksAdded')}</p>}
                  {editSlots.map((slot, i) => (
                    <div
                      key={i}
                      draggable
                      onDragStart={() => { editDragIndex.current = i }}
                      onDragOver={(e) => { e.preventDefault(); setEditDragOverIndex(i) }}
                      onDrop={(e) => {
                        e.preventDefault()
                        if (editDragIndex.current !== null && editDragIndex.current !== i) reorderEditSlots(editDragIndex.current, i)
                        editDragIndex.current = null
                        setEditDragOverIndex(null)
                      }}
                      onDragEnd={() => { editDragIndex.current = null; setEditDragOverIndex(null) }}
                      className={`flex items-center gap-2 rounded border px-2 py-1.5 transition-colors ${editDragOverIndex === i ? 'border-indigo-400 bg-indigo-50' : 'border-gray-200'}`}
                    >
                      <GripVertical className="w-3.5 h-3.5 shrink-0 text-gray-300 cursor-grab active:cursor-grabbing" />
                      <span className="w-4 shrink-0 text-xs font-bold text-gray-400">{slot.position}</span>
                      <span className="flex-1 text-sm">{slot.trickName} <span className="font-mono text-xs text-gray-400">{slot.abbreviation}</span></span>
                      <label className="flex items-center gap-0.5 text-xs text-gray-600 cursor-pointer">
                        <input type="checkbox" checked={slot.strongFoot} onChange={() => toggleSF(i)} className="h-3 w-3" /> SF
                      </label>
                      {(() => {
                        const ntDisabled = !slot.crossOver || i === 0 || editSlots[i - 1].isTransition
                        return (
                          <label className={`flex items-center gap-0.5 text-xs cursor-pointer ${ntDisabled ? 'text-gray-300 cursor-not-allowed' : 'text-gray-600'}`}>
                            <input type="checkbox" checked={slot.noTouch} onChange={() => toggleNT(i)} disabled={ntDisabled} className="h-3 w-3" /> NT
                          </label>
                        )
                      })()}
                      <button type="button" onClick={() => removeSlot(i)} className="text-gray-400 hover:text-red-500 text-base leading-none">×</button>
                    </div>
                  ))}
                </div>
              </div>
            </div>

            {editError && <p className="text-sm text-red-600">{editError}</p>}

            <div className="flex gap-2">
              <Button onClick={() => updateMutation.mutate()} disabled={updateMutation.isPending || editSlots.length === 0}>
                {updateMutation.isPending ? t('common.saving') : t('comboDetail.saveChanges')}
              </Button>
              <Button variant="outline" onClick={() => setEditing(false)}>{t('common.cancel')}</Button>
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
