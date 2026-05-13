import { useState, useRef, useEffect } from 'react'
import { useParams, Link, useNavigate } from 'react-router-dom'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { useTranslation } from 'react-i18next'
import { GripVertical, ChevronDown, ChevronUp } from 'lucide-react'
import { FootToggle } from '@/components/ui/foot-toggle'
import { combosApi, tricksApi, extractError, type BuildComboTrickItem, type TrickItem } from '@/lib/api'
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

function prevIsCrossOver(slots: SlotItem[], i: number): boolean {
  if (i === 0) return false
  const prev = slots[i - 1]
  return prev.crossOver && !prev.isTransition
}

function applyNoTouchRules(slots: SlotItem[]): SlotItem[] {
  return slots.map((slot, i) => {
    if (slot.isTransition) return { ...slot, noTouch: false }
    return prevIsCrossOver(slots, i) ? slot : { ...slot, noTouch: false }
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
  const [expandedSubCombos, setExpandedSubCombos] = useState<Set<number>>(new Set())

  // Edit state
  const [editName, setEditName] = useState('')
  const [deleteError, setDeleteError] = useState<string | null>(null)
  const [editSlots, setEditSlots] = useState<SlotItem[]>([])
  const [trickSearch, setTrickSearch] = useState('')
  const [editError, setEditError] = useState<string | null>(null)
  const editDragIndex = useRef<number | null>(null)
  const [editDragOverIndex, setEditDragOverIndex] = useState<number | null>(null)
  const editTouchDragOverIndex = useRef<number | null>(null)
  const [editTouchHeldIndex, setEditTouchHeldIndex] = useState<number | null>(null)
  const editSlotsContainerRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const el = editSlotsContainerRef.current
    if (!el) return
    const onTouchStart = (e: TouchEvent) => {
      if ((e.target as HTMLElement).closest('[data-drag-handle]')) e.preventDefault()
    }
    const onTouchMove = (e: TouchEvent) => { if (editDragIndex.current !== null) e.preventDefault() }
    el.addEventListener('touchstart', onTouchStart, { passive: false })
    el.addEventListener('touchmove', onTouchMove, { passive: false })
    return () => {
      el.removeEventListener('touchstart', onTouchStart)
      el.removeEventListener('touchmove', onTouchMove)
    }
  }, [])

  const { data: combo, isLoading, error } = useQuery({
    queryKey: ['combos', id],
    queryFn: () => combosApi.getById(id!).then((r) => r.data),
    enabled: !!id,
  })

  const { data: tricks = [] } = useQuery({
    queryKey: ['tricks'],
    queryFn: () => tricksApi.getAll().then((r) => r.data.filter((item): item is TrickItem => item.type === 'trick')),
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

  const [abbrevOnly, setAbbrevOnly] = useState(false)
  const [reusableError, setReusableError] = useState<string | null>(null)
  const reusableMutation = useMutation({
    mutationFn: (isReusable: boolean) => combosApi.setReusable(id!, isReusable),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['combos', id] })
      setReusableError(null)
    },
    onError: (err) => setReusableError(extractError(err, t('comboDetail.setReusableFailed'))),
  })

  if (isLoading) return <p className="text-gray-500">{t('comboDetail.loading')}</p>
  if (error || !combo) return <p className="text-red-600">{t('comboDetail.notFound')}</p>

  const isOwner = combo.ownerId === currentUserId
  const canDelete = isOwner || isAdmin()

  function startEdit() {
    setEditName(combo!.name ?? '')
    setEditSlots(
      applyNoTouchRules(
        (combo!.tricks ?? []).flatMap((t_) => {
          if (t_.type === 'trick') {
            return [{
              trickId: t_.trickId,
              position: t_.position,
              strongFoot: t_.strongFoot,
              noTouch: t_.noTouch,
              trickName: t_.name ?? '',
              abbreviation: t_.abbreviation,
              crossOver: t_.crossOver,
              isTransition: t_.isTransition,
            }]
          }
          // Sub-combo slots: expand to individual tricks for editing
          return t_.subComboTricks.map((st) => ({
            trickId: st.trickId,
            position: st.position,
            strongFoot: st.strongFoot,
            noTouch: st.noTouch,
            trickName: st.name ?? '',
            abbreviation: st.abbreviation,
            crossOver: st.crossOver,
            isTransition: st.isTransition,
          }))
        }),
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
      if (s.isTransition || !prevIsCrossOver(prev, index)) return s
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
              {combo.ownerUserName && !combo.isReusable && (
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
            <div className="flex items-center justify-between mb-2">
              <h3 className="text-sm font-medium text-gray-700">{t('comboDetail.tricksHeader')}</h3>
              <label className="flex items-center gap-1.5 text-xs text-gray-500 cursor-pointer select-none">
                <input type="checkbox" checked={abbrevOnly} onChange={(e) => setAbbrevOnly(e.target.checked)} className="h-3.5 w-3.5 rounded border-gray-300 text-indigo-600" />
                {t('comboDetail.abbrevOnly')}
              </label>
            </div>
            <div className="space-y-1">
              {(combo.tricks ?? []).map((trick) => {
                if (trick.type === 'trick') {
                  return (
                    <div key={trick.position} className="flex items-center gap-2 rounded border border-gray-200 px-2 py-1.5">
                      <span className="w-4 shrink-0 text-xs font-bold text-gray-400">{trick.position}</span>
                      <div className="flex-1 min-w-0">
                        <span className="font-mono text-xs font-semibold text-gray-900">{trick.abbreviation}</span>
                        {!abbrevOnly && <span className="ml-1.5 text-sm text-gray-500">{trick.name}</span>}
                      </div>
                      <span className={`inline-flex items-center rounded px-1.5 py-0.5 text-xs font-medium ${diffColor(trick.difficulty ?? 0)}`}>{trick.difficulty}</span>
                      <FootToggle value={trick.strongFoot} onChange={() => {}} />
                      <span className={`inline-flex items-center rounded px-1.5 py-0.5 text-xs font-semibold ${trick.noTouch ? 'bg-indigo-100 text-indigo-700' : 'bg-gray-100 text-gray-400'}`}>NT</span>
                    </div>
                  )
                }
                // Sub-combo slot
                const isExpanded = expandedSubCombos.has(trick.position)
                const toggleExpand = () =>
                  setExpandedSubCombos((prev) => {
                    const next = new Set(prev)
                    if (next.has(trick.position)) next.delete(trick.position)
                    else next.add(trick.position)
                    return next
                  })
                return (
                  <div key={`subcombo-${trick.position}`} className="rounded border border-indigo-200 bg-indigo-50 overflow-hidden">
                    <button
                      type="button"
                      onClick={toggleExpand}
                      className="flex w-full items-center gap-2 px-2 py-1.5 text-left"
                    >
                      <span className="w-4 shrink-0 text-xs font-bold text-gray-400">{trick.position}</span>
                      <span className="flex-1 text-sm font-semibold text-indigo-800">
                        {trick.subComboName ?? t('comboDetail.subCombo')}
                        <span className="ml-1 font-normal text-xs text-indigo-500">({trick.subComboTricks.length} {t('comboDetail.tricks')})</span>
                      </span>
                      {isExpanded ? <ChevronUp className="w-3.5 h-3.5 text-indigo-400" /> : <ChevronDown className="w-3.5 h-3.5 text-indigo-400" />}
                    </button>
                    {isExpanded && (
                      <div className="border-t border-indigo-100 divide-y divide-indigo-100">
                        {trick.subComboTricks.map((st) => (
                          <div key={`subcombo-${trick.position}-${st.position}`} className="flex items-center gap-2 px-2 py-1.5 pl-8 bg-indigo-50/40">
                            <div className="flex-1 min-w-0">
                              <span className="font-mono text-xs font-semibold text-gray-700">{st.abbreviation}</span>
                              {!abbrevOnly && <span className="ml-1.5 text-xs text-gray-500">{st.name}</span>}
                            </div>
                            <span className={`inline-flex items-center rounded px-1.5 py-0.5 text-xs font-medium ${diffColor(st.difficulty ?? 0)}`}>{st.difficulty}</span>
                            <FootToggle value={st.strongFoot} onChange={() => {}} />
                            <span className={`inline-flex items-center rounded px-1.5 py-0.5 text-xs font-semibold ${st.noTouch ? 'bg-indigo-100 text-indigo-700' : 'bg-gray-100 text-gray-400'}`}>NT</span>
                          </div>
                        ))}
                      </div>
                    )}
                  </div>
                )
              })}
            </div>
          </div>

          <div className="flex gap-2 pt-1">
            <Badge variant="secondary">{t('comboDetail.avgDifficulty', { value: combo.totalDifficulty ?? '—' })}</Badge>
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

          {isAdmin() && combo.visibility === 'Public' && (
            <div className="flex items-center gap-3 pt-1">
              <span className="text-sm font-medium text-gray-700">{t('comboDetail.reusable')}</span>
              <button
                type="button"
                role="switch"
                aria-checked={combo.isReusable}
                disabled={reusableMutation.isPending}
                onClick={() => reusableMutation.mutate(!combo.isReusable)}
                className={`relative inline-flex h-6 w-11 shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2 disabled:opacity-50 ${combo.isReusable ? 'bg-indigo-600' : 'bg-gray-200'}`}
              >
                <span
                  className={`pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition-transform ${combo.isReusable ? 'translate-x-5' : 'translate-x-0'}`}
                />
              </button>
              {reusableError && <p className="text-sm text-red-600">{reusableError}</p>}
            </div>
          )}
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
                <div className="space-y-1 max-h-[40vh] overflow-y-auto lg:max-h-60" ref={editSlotsContainerRef}>
                  {editSlots.length === 0 && <p className="text-sm text-gray-400 py-2">{t('comboDetail.noTricksAdded')}</p>}
                  {editSlots.map((slot, i) => (
                    <div
                      key={i}
                      data-drag-index={i}
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
                      onTouchStart={(e) => { if ((e.target as HTMLElement).closest('[data-drag-handle]')) { editDragIndex.current = i; setEditTouchHeldIndex(i) } }}
                      onTouchMove={(e) => {
                        const touch = e.touches[0]
                        const el = document.elementFromPoint(touch.clientX, touch.clientY)
                        const slotEl = el?.closest('[data-drag-index]')
                        if (slotEl) {
                          const idx = parseInt(slotEl.getAttribute('data-drag-index') ?? '-1', 10)
                          if (idx >= 0) { editTouchDragOverIndex.current = idx; setEditDragOverIndex(idx) }
                        }
                      }}
                      onTouchEnd={() => {
                        if (editDragIndex.current !== null && editTouchDragOverIndex.current !== null && editDragIndex.current !== editTouchDragOverIndex.current)
                          reorderEditSlots(editDragIndex.current, editTouchDragOverIndex.current)
                        editDragIndex.current = null
                        editTouchDragOverIndex.current = null
                        setEditDragOverIndex(null)
                        setEditTouchHeldIndex(null)
                      }}
                      className={`flex items-center gap-2 rounded border px-2 py-1.5 transition-colors select-none ${editDragOverIndex === i ? 'border-indigo-400 bg-indigo-50' : 'border-gray-200'} ${editTouchHeldIndex === i ? 'drag-shaking' : ''}`}
                    >
                      <span data-drag-handle style={{ touchAction: 'none' }} className="shrink-0 cursor-grab active:cursor-grabbing p-2 -m-2 touch-none">
                        <GripVertical className="w-3.5 h-3.5 text-gray-300 pointer-events-none" />
                      </span>
                      <span className="w-4 shrink-0 text-xs font-bold text-gray-400">{slot.position}</span>
                      <span className="flex-1 text-sm">{slot.trickName} <span className="font-mono text-xs text-gray-400">{slot.abbreviation}</span></span>
                      <FootToggle value={slot.strongFoot} onChange={() => toggleSF(i)} />
                      {(() => {
                        const ntDisabled = slot.isTransition || !prevIsCrossOver(editSlots, i)
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
