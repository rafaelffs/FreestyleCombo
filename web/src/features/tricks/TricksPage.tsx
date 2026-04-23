import { useMemo, useRef, useEffect, useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { useTranslation } from 'react-i18next'
import { tricksApi, trickSubmissionsApi, extractError, type TrickDto, type SubmitTrickRequest } from '@/lib/api'
import { isAdmin, isAuthenticated } from '@/lib/auth'
import { SEO } from '@/components/SEO'
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

type SortKey = 'abbreviation' | 'name' | 'revolution' | 'difficulty' | 'crossOver' | 'knee'
type SortDir = 'asc' | 'desc'

const SUBMIT_DEFAULTS: SubmitTrickRequest = {
  name: '',
  abbreviation: '',
  crossOver: false,
  knee: false,
  revolution: 1,
  difficulty: 1,
  commonLevel: 5,
}

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
  revolution: 1,
  difficulty: 1,
  commonLevel: 1,
  isTransition: false,
  createdBy: null,
  dateCreated: null,
  notes: null,
}

interface SortHeaderProps {
  label: string
  col: SortKey
  sortKey: SortKey
  sortDir: SortDir
  onSort: (col: SortKey) => void
  className?: string
  center?: boolean
}

function SortHeader({ label, col, sortKey, sortDir, onSort, className = '', center }: SortHeaderProps) {
  const active = sortKey === col
  return (
    <th
      onClick={() => onSort(col)}
      className={`cursor-pointer select-none px-4 py-3 text-xs font-medium uppercase text-gray-500 hover:text-gray-800 ${center ? 'text-center' : 'text-left'} ${className}`}
    >
      <span className={`inline-flex items-center gap-1 ${center ? 'justify-center w-full' : ''}`}>
        {label}
        <span className={`text-[10px] ${active ? 'text-indigo-500' : 'text-gray-300'}`}>
          {active ? (sortDir === 'asc' ? '▲' : '▼') : '⇅'}
        </span>
      </span>
    </th>
  )
}

export function TricksPage() {
  const queryClient = useQueryClient()
  const admin = isAdmin()
  const authed = isAuthenticated()
  const { t } = useTranslation()

  // Filters
  const [search, setSearch] = useState('')
  const [minDiff, setMinDiff] = useState<number | undefined>()
  const [maxDiff, setMaxDiff] = useState<number | undefined>()
  const [filterRevs, setFilterRevs] = useState<number[]>([])
  const [revDropdownOpen, setRevDropdownOpen] = useState(false)
  const revDropdownRef = useRef<HTMLDivElement>(null)
  const [filterCrossOver, setFilterCrossOver] = useState(false)
  const [filterKnee, setFilterKnee] = useState(false)

  // Sort
  const [sortKey, setSortKey] = useState<SortKey>('abbreviation')
  const [sortDir, setSortDir] = useState<SortDir>('asc')

  // Info modal
  const [infoTrick, setInfoTrick] = useState<TrickDto | null>(null)

  // Create (admin)
  const [showCreate, setShowCreate] = useState(false)
  const [createForm, setCreateForm] = useState<Omit<TrickDto, 'id'>>(EMPTY_FORM)
  const [createError, setCreateError] = useState<string | null>(null)

  // Edit / delete
  const [editTrick, setEditTrick] = useState<TrickDto | null>(null)
  const [editForm, setEditForm] = useState<Omit<TrickDto, 'id'>>(EMPTY_FORM)
  const [editError, setEditError] = useState<string | null>(null)
  const [deleteError, setDeleteError] = useState<string | null>(null)

  // Submit
  const [showSubmit, setShowSubmit] = useState(false)
  const [submitForm, setSubmitForm] = useState<SubmitTrickRequest>(SUBMIT_DEFAULTS)
  const [submitted, setSubmitted] = useState(false)

  function updateSubmit<K extends keyof SubmitTrickRequest>(key: K, value: SubmitTrickRequest[K]) {
    setSubmitForm((prev) => ({ ...prev, [key]: value }))
  }

  // Close rev dropdown when clicking outside
  useEffect(() => {
    function handler(e: MouseEvent) {
      if (revDropdownRef.current && !revDropdownRef.current.contains(e.target as Node)) {
        setRevDropdownOpen(false)
      }
    }
    document.addEventListener('mousedown', handler)
    return () => document.removeEventListener('mousedown', handler)
  }, [])

  const submitMutation = useMutation({
    mutationFn: () => trickSubmissionsApi.submit(submitForm),
    onSuccess: () => {
      setSubmitForm(SUBMIT_DEFAULTS)
      setSubmitted(true)
      setShowSubmit(false)
      setTimeout(() => setSubmitted(false), 3000)
    },
  })

  const { data: tricks = [], isLoading } = useQuery({
    queryKey: ['tricks'],
    queryFn: () => tricksApi.getAll().then((r) => r.data),
  })

  const createMutation = useMutation({
    mutationFn: (data: Omit<TrickDto, 'id'>) => tricksApi.create(data),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['tricks'] })
      setShowCreate(false)
      setCreateForm(EMPTY_FORM)
      setCreateError(null)
    },
    onError: (err) => setCreateError(extractError(err, t('tricks.createFailed'))),
  })

  const updateMutation = useMutation({
    mutationFn: (data: Omit<TrickDto, 'id'>) => tricksApi.update(editTrick!.id, data),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['tricks'] })
      setEditTrick(null)
      setEditError(null)
    },
    onError: (err) => setEditError(extractError(err, t('tricks.updateFailed'))),
  })

  const deleteMutation = useMutation({
    mutationFn: (id: string) => tricksApi.delete(id),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['tricks'] })
      setDeleteError(null)
    },
    onError: (err) => setDeleteError(extractError(err, t('tricks.deleteFailed'))),
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

  function handleSort(col: SortKey) {
    if (sortKey === col) {
      setSortDir((d) => (d === 'asc' ? 'desc' : 'asc'))
    } else {
      setSortKey(col)
      setSortDir('asc')
    }
  }

  function toggleRev(rev: number) {
    setFilterRevs((prev) =>
      prev.includes(rev) ? prev.filter((r) => r !== rev) : [...prev, rev],
    )
  }

  const revOptions = useMemo(
    () => [...new Set(tricks.map((tr) => tr.revolution))].sort((a, b) => a - b),
    [tricks],
  )

  const filtered = useMemo(() => {
    const q = search.toLowerCase()
    let list = tricks.filter(
      (tr) =>
        (q === '' || tr.name.toLowerCase().includes(q) || tr.abbreviation.toLowerCase().includes(q)) &&
        (minDiff === undefined || tr.difficulty >= minDiff) &&
        (maxDiff === undefined || tr.difficulty <= maxDiff) &&
        (filterRevs.length === 0 || filterRevs.includes(tr.revolution)) &&
        (!filterCrossOver || tr.crossOver) &&
        (!filterKnee || tr.knee),
    )

    list = [...list].sort((a, b) => {
      let av: string | number
      let bv: string | number
      switch (sortKey) {
        case 'abbreviation': av = a.abbreviation; bv = b.abbreviation; break
        case 'name': av = a.name; bv = b.name; break
        case 'revolution': av = a.revolution; bv = b.revolution; break
        case 'difficulty': av = a.difficulty; bv = b.difficulty; break
        case 'crossOver': av = a.crossOver ? 1 : 0; bv = b.crossOver ? 1 : 0; break
        case 'knee': av = a.knee ? 1 : 0; bv = b.knee ? 1 : 0; break
        default: av = ''; bv = ''
      }
      if (av < bv) return sortDir === 'asc' ? -1 : 1
      if (av > bv) return sortDir === 'asc' ? 1 : -1
      return 0
    })

    return list
  }, [tricks, search, minDiff, maxDiff, filterRevs, filterCrossOver, filterKnee, sortKey, sortDir])

  const revDropdownLabel = filterRevs.length === 0
    ? t('tricks.filterAny')
    : filterRevs.length === 1
      ? t('tricks.filterRevSingular', { count: filterRevs[0] })
      : t('tricks.filterRevCount', { count: filterRevs.length })

  return (
    <div className="space-y-6">
      <SEO
        title="Trick Library — FreestyleCombo"
        description="Browse all freestyle football tricks, filter by difficulty, and submit new tricks for review."
        path="/tricks"
      />
      <div>
        <h1 className="text-2xl font-bold text-gray-900">{t('tricks.pageTitle')}</h1>
        <p className="mt-1 text-sm text-gray-500">{t('tricks.pageSubtitle')}</p>
      </div>

      {/* FAB */}
      {authed && (
        <button
          type="button"
          onClick={() => {
            if (admin) {
              setCreateForm(EMPTY_FORM)
              setCreateError(null)
              setShowCreate(true)
            } else {
              setShowSubmit((v) => !v)
            }
          }}
          className="fixed bottom-6 right-6 z-40 inline-flex h-14 cursor-pointer items-center gap-2 rounded-full bg-indigo-600 px-5 text-sm font-semibold text-white shadow-lg transition-colors hover:bg-indigo-700 active:bg-indigo-800"
        >
          <span className="text-lg leading-none">{showSubmit ? '✕' : '+'}</span>
          {showSubmit ? t('tricks.fabCancel') : t('tricks.fabSubmit')}
        </button>
      )}

      {submitted && <p className="text-sm text-green-600">{t('tricks.submitted')}</p>}

      {/* Inline submit form */}
      {showSubmit && (
        <Card>
          <CardHeader><CardTitle>{t('tricks.submitTitle')}</CardTitle></CardHeader>
          <CardContent>
            <form
              onSubmit={(e) => { e.preventDefault(); submitMutation.mutate() }}
              className="space-y-4"
            >
              <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 md:grid-cols-3">
                <div className="space-y-1">
                  <Label>{t('tricks.fieldAbbreviation')}</Label>
                  <Input value={submitForm.abbreviation} onChange={(e) => updateSubmit('abbreviation', e.target.value)} placeholder="e.g. CO" required />
                </div>
                <div className="space-y-1">
                  <Label>{t('tricks.fieldName')}</Label>
                  <Input value={submitForm.name} onChange={(e) => updateSubmit('name', e.target.value)} placeholder="e.g. Crossover" required />
                </div>
                <div className="space-y-1">
                  <Label>{t('tricks.fieldRevolution')}</Label>
                  <Input type="number" min={0.5} max={4} step={0.5} value={submitForm.revolution} onChange={(e) => updateSubmit('revolution', Number(e.target.value))} />
                </div>
                <div className="space-y-1">
                  <Label>{t('tricks.fieldDifficulty')}</Label>
                  <Input type="number" min={1} max={10} value={submitForm.difficulty} onChange={(e) => updateSubmit('difficulty', Number(e.target.value))} />
                </div>
                <div className="space-y-1">
                  <Label>{t('tricks.fieldCommonLevel')}</Label>
                  <Input type="number" min={1} max={10} value={submitForm.commonLevel} onChange={(e) => updateSubmit('commonLevel', Number(e.target.value))} />
                </div>
              </div>
              <div className="flex flex-wrap gap-4">
                <div className="flex items-center gap-2">
                  <input id="sub-crossover" type="checkbox" checked={submitForm.crossOver} onChange={(e) => updateSubmit('crossOver', e.target.checked)} className="h-4 w-4 rounded border-gray-300 text-indigo-600" />
                  <Label htmlFor="sub-crossover">{t('tricks.fieldCrossOver')}</Label>
                </div>
                <div className="flex items-center gap-2">
                  <input id="sub-knee" type="checkbox" checked={submitForm.knee} onChange={(e) => updateSubmit('knee', e.target.checked)} className="h-4 w-4 rounded border-gray-300 text-indigo-600" />
                  <Label htmlFor="sub-knee">{t('tricks.fieldKnee')}</Label>
                </div>
              </div>
              {submitMutation.error && (
                <p className="text-sm text-red-600">{extractError(submitMutation.error, t('tricks.submissionFailed'))}</p>
              )}
              <Button type="submit" disabled={submitMutation.isPending}>
                {submitMutation.isPending ? t('tricks.submitting') : t('tricks.submitTrick')}
              </Button>
            </form>
          </CardContent>
        </Card>
      )}

      {/* Filters */}
      <Card>
        <CardContent className="pt-4">
          <div className="grid grid-cols-2 gap-3 sm:flex sm:flex-wrap sm:items-end">
            {/* Search — full width on mobile */}
            <div className="col-span-2 space-y-1 sm:flex-1 sm:min-w-[160px]">
              <Label>{t('tricks.filterSearch')}</Label>
              <Input
                placeholder={t('tricks.filterSearchPlaceholder')}
                value={search}
                onChange={(e) => setSearch(e.target.value)}
              />
            </div>

            {/* Min / Max Difficulty */}
            <div className="space-y-1">
              <Label>{t('tricks.filterMinDiff')}</Label>
              <Input
                type="number"
                min={1}
                max={10}
                placeholder="1"
                className="w-full sm:w-20"
                value={minDiff ?? ''}
                onChange={(e) => setMinDiff(e.target.value ? Number(e.target.value) : undefined)}
              />
            </div>
            <div className="space-y-1">
              <Label>{t('tricks.filterMaxDiff')}</Label>
              <Input
                type="number"
                min={1}
                max={10}
                placeholder="10"
                className="w-full sm:w-20"
                value={maxDiff ?? ''}
                onChange={(e) => setMaxDiff(e.target.value ? Number(e.target.value) : undefined)}
              />
            </div>

            {/* Revolutions dropdown */}
            <div className="space-y-1" ref={revDropdownRef}>
              <Label>{t('tricks.filterRevolutions')}</Label>
              <div className="relative">
                <button
                  type="button"
                  onClick={() => setRevDropdownOpen((o) => !o)}
                  className="flex h-10 w-full items-center justify-between gap-2 rounded-md border border-gray-300 bg-white px-3 text-sm hover:border-gray-400 sm:w-auto sm:min-w-[110px]"
                >
                  <span className="text-gray-700">{revDropdownLabel}</span>
                  <svg className="h-4 w-4 text-gray-400 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                  </svg>
                </button>
                {revDropdownOpen && (
                  <div className="absolute left-0 top-full z-50 mt-1 w-44 rounded-md border border-gray-200 bg-white shadow-lg">
                    {filterRevs.length > 0 && (
                      <>
                        <button
                          type="button"
                          onClick={() => setFilterRevs([])}
                          className="block w-full px-3 py-1.5 text-left text-xs text-indigo-600 hover:bg-gray-50"
                        >
                          {t('tricks.filterClearSelection')}
                        </button>
                        <div className="border-t border-gray-100" />
                      </>
                    )}
                    <div className="max-h-48 overflow-y-auto py-1">
                      {revOptions.map((rev) => (
                        <label
                          key={rev}
                          className="flex cursor-pointer items-center gap-2 px-3 py-1.5 hover:bg-gray-50"
                        >
                          <input
                            type="checkbox"
                            checked={filterRevs.includes(rev)}
                            onChange={() => toggleRev(rev)}
                            className="h-3.5 w-3.5 rounded border-gray-300 text-indigo-600"
                          />
                          <span className="text-sm text-gray-700">
                            {rev !== 1 ? t('tricks.filterRevOptionPlural', { rev }) : t('tricks.filterRevOption', { rev })}
                          </span>
                        </label>
                      ))}
                    </div>
                  </div>
                )}
              </div>
            </div>

            {/* CO / Knee checkboxes — spans full width on mobile */}
            <div className="col-span-2 flex items-center gap-4 pb-0.5 sm:col-span-1">
              <label className="flex items-center gap-1.5 text-sm cursor-pointer">
                <input
                  type="checkbox"
                  checked={filterCrossOver}
                  onChange={(e) => setFilterCrossOver(e.target.checked)}
                  className="h-4 w-4 rounded border-gray-300 text-indigo-600"
                />
                {t('tricks.filterCOOnly')}
              </label>
              <label className="flex items-center gap-1.5 text-sm cursor-pointer">
                <input
                  type="checkbox"
                  checked={filterKnee}
                  onChange={(e) => setFilterKnee(e.target.checked)}
                  className="h-4 w-4 rounded border-gray-300 text-indigo-600"
                />
                {t('tricks.filterKneeOnly')}
              </label>
            </div>
          </div>
        </CardContent>
      </Card>

      {deleteError && <p className="text-sm text-red-600">{deleteError}</p>}

      {/* Table */}
      {isLoading ? (
        <p className="text-gray-500">{t('common.loading')}</p>
      ) : (
        <div className="overflow-x-auto -mx-4 sm:mx-0 rounded-lg border border-gray-200">
          <table className="w-full min-w-[480px] text-sm">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <SortHeader label={t('tricks.colAbbrev')} col="abbreviation" sortKey={sortKey} sortDir={sortDir} onSort={handleSort} />
                <SortHeader label={t('tricks.colName')} col="name" sortKey={sortKey} sortDir={sortDir} onSort={handleSort} />
                <SortHeader label={t('tricks.colRevs')} col="revolution" sortKey={sortKey} sortDir={sortDir} onSort={handleSort} center />
                <SortHeader label={t('tricks.colDiff')} col="difficulty" sortKey={sortKey} sortDir={sortDir} onSort={handleSort} center />
                <SortHeader label={t('tricks.colCO')} col="crossOver" sortKey={sortKey} sortDir={sortDir} onSort={handleSort} center />
                <SortHeader label={t('tricks.colKnee')} col="knee" sortKey={sortKey} sortDir={sortDir} onSort={handleSort} center />
                <th className="w-8 px-2 py-3" />
                {admin && <th className="px-4 py-3 text-right text-xs font-medium uppercase text-gray-500">{t('tricks.colActions')}</th>}
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {filtered.map((trick) => (
                <tr key={trick.id} className="hover:bg-gray-50">
                  <td className="px-4 py-2 font-mono text-xs font-semibold text-gray-900">{trick.abbreviation}</td>
                  <td className="px-4 py-2 text-gray-700">{trick.name}</td>
                  <td className="px-4 py-2 text-center text-gray-600">{trick.revolution}</td>
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
                  <td className="px-2 py-2 text-center">
                    <button
                      type="button"
                      onClick={() => setInfoTrick(trick)}
                      className="inline-flex h-5 w-5 items-center justify-center rounded-full border border-gray-300 text-[10px] font-bold text-gray-400 hover:border-indigo-400 hover:text-indigo-500"
                      title={t('tricks.infoTooltip')}
                    >
                      ?
                    </button>
                  </td>
                  {admin && (
                    <td className="px-4 py-2 text-right">
                      <div className="flex justify-end gap-2">
                        <Button variant="outline" size="sm" onClick={() => openEdit(trick)}>
                          {t('tricks.actionEdit')}
                        </Button>
                        <Button
                          variant="outline"
                          size="sm"
                          className="text-red-600 hover:text-red-700"
                          disabled={deleteMutation.isPending}
                          onClick={() => {
                            if (confirm(t('tricks.deleteConfirm', { name: trick.name }))) deleteMutation.mutate(trick.id)
                          }}
                        >
                          {t('tricks.actionDelete')}
                        </Button>
                      </div>
                    </td>
                  )}
                </tr>
              ))}
              {filtered.length === 0 && (
                <tr>
                  <td colSpan={admin ? 8 : 7} className="px-4 py-6 text-center text-gray-400">
                    {t('tricks.noTricksFound')}
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      )}

      {/* Create dialog (admin) */}
      <Dialog open={showCreate} onOpenChange={(open) => !open && setShowCreate(false)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{t('tricks.addTrick')}</DialogTitle>
          </DialogHeader>
          <form onSubmit={(e) => { e.preventDefault(); createMutation.mutate(createForm) }} className="space-y-4">
            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
              <div className="space-y-1">
                <Label>{t('tricks.fieldAbbreviation')}</Label>
                <Input value={createForm.abbreviation} onChange={(e) => setCreateForm((f) => ({ ...f, abbreviation: e.target.value }))} maxLength={20} required />
              </div>
              <div className="space-y-1">
                <Label>{t('tricks.fieldName')}</Label>
                <Input value={createForm.name} onChange={(e) => setCreateForm((f) => ({ ...f, name: e.target.value }))} maxLength={100} required />
              </div>
              <div className="space-y-1">
                <Label>{t('tricks.fieldRevolution')}</Label>
                <Input type="number" min={0.5} max={10} step={0.5} value={createForm.revolution} onChange={(e) => setCreateForm((f) => ({ ...f, revolution: Number(e.target.value) }))} required />
              </div>
              <div className="space-y-1">
                <Label>{t('tricks.fieldDifficulty110')}</Label>
                <Input type="number" min={1} max={10} value={createForm.difficulty} onChange={(e) => setCreateForm((f) => ({ ...f, difficulty: Number(e.target.value) }))} required />
              </div>
              <div className="space-y-1">
                <Label>{t('tricks.fieldCommonLevel110')}</Label>
                <Input type="number" min={1} max={10} value={createForm.commonLevel} onChange={(e) => setCreateForm((f) => ({ ...f, commonLevel: Number(e.target.value) }))} required />
              </div>
            </div>
            <div className="flex gap-6">
              <label className="flex items-center gap-2 text-sm cursor-pointer">
                <input type="checkbox" checked={createForm.crossOver} onChange={(e) => setCreateForm((f) => ({ ...f, crossOver: e.target.checked }))} className="h-4 w-4 rounded border-gray-300 text-indigo-600" />
                {t('tricks.fieldCrossOver')}
              </label>
              <label className="flex items-center gap-2 text-sm cursor-pointer">
                <input type="checkbox" checked={createForm.knee} onChange={(e) => setCreateForm((f) => ({ ...f, knee: e.target.checked }))} className="h-4 w-4 rounded border-gray-300 text-indigo-600" />
                {t('tricks.fieldKnee')}
              </label>
            </div>
            <div className="border-t pt-3 grid grid-cols-1 gap-3 sm:grid-cols-2">
              <div className="space-y-1">
                <Label>{t('tricks.fieldCreatedBy')}</Label>
                <Input value={createForm.createdBy ?? ''} onChange={(e) => setCreateForm((f) => ({ ...f, createdBy: e.target.value || null }))} maxLength={100} placeholder={t('tricks.infoNotSet')} />
              </div>
              <div className="space-y-1">
                <Label>{t('tricks.fieldDateCreated')}</Label>
                <Input type="date" value={createForm.dateCreated ?? ''} onChange={(e) => setCreateForm((f) => ({ ...f, dateCreated: e.target.value || null }))} />
              </div>
              <div className="space-y-1 sm:col-span-2">
                <Label>{t('tricks.fieldNotes')}</Label>
                <textarea value={createForm.notes ?? ''} onChange={(e) => setCreateForm((f) => ({ ...f, notes: e.target.value || null }))} maxLength={500} rows={3} placeholder={t('tricks.infoNotSet')} className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
            </div>
            {createError && <p className="text-sm text-red-600">{createError}</p>}
            <div className="flex justify-end gap-2">
              <Button type="button" variant="outline" onClick={() => setShowCreate(false)}>{t('common.cancel')}</Button>
              <Button type="submit" disabled={createMutation.isPending}>{createMutation.isPending ? t('common.saving') : t('tricks.addTrick')}</Button>
            </div>
          </form>
        </DialogContent>
      </Dialog>

      {/* Info modal */}
      <Dialog open={infoTrick !== null} onOpenChange={(open) => !open && setInfoTrick(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{infoTrick?.name}</DialogTitle>
          </DialogHeader>
          <dl className="space-y-3 text-sm">
            <div>
              <dt className="text-xs font-medium uppercase text-gray-500">{t('tricks.fieldCreatedBy')}</dt>
              <dd className="mt-0.5 text-gray-800">{infoTrick?.createdBy || <span className="text-gray-400">{t('tricks.infoNotSet')}</span>}</dd>
            </div>
            <div>
              <dt className="text-xs font-medium uppercase text-gray-500">{t('tricks.fieldDateCreated')}</dt>
              <dd className="mt-0.5 text-gray-800">{infoTrick?.dateCreated || <span className="text-gray-400">{t('tricks.infoNotSet')}</span>}</dd>
            </div>
            <div>
              <dt className="text-xs font-medium uppercase text-gray-500">{t('tricks.fieldNotes')}</dt>
              <dd className="mt-0.5 whitespace-pre-wrap text-gray-800">{infoTrick?.notes || <span className="text-gray-400">{t('tricks.infoNotSet')}</span>}</dd>
            </div>
          </dl>
        </DialogContent>
      </Dialog>

      {/* Edit dialog */}
      <Dialog open={editTrick !== null} onOpenChange={(open) => !open && setEditTrick(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{t('tricks.editTrickTitle')}</DialogTitle>
          </DialogHeader>
          <form onSubmit={handleEditSubmit} className="space-y-4">
            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
              <div className="space-y-1">
                <Label>{t('tricks.fieldAbbreviation')}</Label>
                <Input
                  value={editForm.abbreviation}
                  onChange={(e) => setEditForm((f) => ({ ...f, abbreviation: e.target.value }))}
                  maxLength={20}
                  required
                />
              </div>
              <div className="space-y-1">
                <Label>{t('tricks.fieldName')}</Label>
                <Input
                  value={editForm.name}
                  onChange={(e) => setEditForm((f) => ({ ...f, name: e.target.value }))}
                  maxLength={100}
                  required
                />
              </div>
              <div className="space-y-1">
                <Label>{t('tricks.fieldRevolution')}</Label>
                <Input
                  type="number"
                  min={0.5}
                  max={10}
                  step={0.5}
                  value={editForm.revolution}
                  onChange={(e) => setEditForm((f) => ({ ...f, revolution: Number(e.target.value) }))}
                  required
                />
              </div>
              <div className="space-y-1">
                <Label>{t('tricks.fieldDifficulty110')}</Label>
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
                <Label>{t('tricks.fieldCommonLevel110')}</Label>
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
                {t('tricks.fieldCrossOver')}
              </label>
              <label className="flex items-center gap-2 text-sm cursor-pointer">
                <input
                  type="checkbox"
                  checked={editForm.knee}
                  onChange={(e) => setEditForm((f) => ({ ...f, knee: e.target.checked }))}
                  className="h-4 w-4 rounded border-gray-300 text-indigo-600"
                />
                {t('tricks.fieldKnee')}
              </label>
            </div>
            <div className="border-t pt-3 grid grid-cols-1 gap-3 sm:grid-cols-2">
              <div className="space-y-1">
                <Label>{t('tricks.fieldCreatedBy')}</Label>
                <Input
                  value={editForm.createdBy ?? ''}
                  onChange={(e) => setEditForm((f) => ({ ...f, createdBy: e.target.value || null }))}
                  maxLength={100}
                  placeholder={t('tricks.infoNotSet')}
                />
              </div>
              <div className="space-y-1">
                <Label>{t('tricks.fieldDateCreated')}</Label>
                <Input
                  type="date"
                  value={editForm.dateCreated ?? ''}
                  onChange={(e) => setEditForm((f) => ({ ...f, dateCreated: e.target.value || null }))}
                />
              </div>
              <div className="space-y-1 sm:col-span-2">
                <Label>{t('tricks.fieldNotes')}</Label>
                <textarea
                  value={editForm.notes ?? ''}
                  onChange={(e) => setEditForm((f) => ({ ...f, notes: e.target.value || null }))}
                  maxLength={500}
                  rows={3}
                  placeholder={t('tricks.infoNotSet')}
                  className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
                />
              </div>
            </div>
            {editError && <p className="text-sm text-red-600">{editError}</p>}
            <div className="flex justify-end gap-2">
              <Button type="button" variant="outline" onClick={() => setEditTrick(null)}>
                {t('common.cancel')}
              </Button>
              <Button type="submit" disabled={updateMutation.isPending}>
                {updateMutation.isPending ? t('common.saving') : t('common.save')}
              </Button>
            </div>
          </form>
        </DialogContent>
      </Dialog>
    </div>
  )
}
