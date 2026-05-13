import { useState, useRef, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { useQuery, useMutation } from '@tanstack/react-query'
import { useTranslation } from 'react-i18next'
import { GripVertical, ChevronDown, ChevronUp } from 'lucide-react'
import { FootToggle } from '@/components/ui/foot-toggle'
import { combosApi, tricksApi, preferencesApi, extractError, type GenerateComboOverrides, type TrickItem, type ComboItem, type BuildComboTrickItem } from '@/lib/api'
import { isAuthenticated, setPendingCombo } from '@/lib/auth'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'

function diffColor(d: number): string {
  if (d <= 4) return 'bg-green-100 text-green-800'
  if (d <= 7) return 'bg-yellow-100 text-yellow-800'
  return 'bg-red-100 text-red-800'
}

const GENERATE_DEFAULTS: GenerateComboOverrides = {
  comboLength: 5,
  maxDifficulty: 10,
  strongFootPercentage: 50,
  noTouchPercentage: 30,
  maxConsecutiveNoTouch: 2,
  includeCrossOver: true,
  includeKnee: true,
}

interface TrickSlotItem extends BuildComboTrickItem {
  type: 'trick'
  trickName: string
  abbreviation: string
  crossOver: boolean
  isTransition: boolean
}

interface SubComboSlotItem extends BuildComboTrickItem {
  type: 'combo'
  comboName: string
  trickCount: number
  totalDifficulty: number
  trickSlots: { abbreviation: string; noTouch: boolean }[]
}

type SlotItem = TrickSlotItem | SubComboSlotItem

function applyNoTouchRules(slots: SlotItem[]): SlotItem[] {
  return slots.map((slot, i) => {
    if (slot.type === 'combo') return slot
    const prevSlot = slots[i - 1]
    const afterTransition = i === 0 || (prevSlot.type === 'trick' && prevSlot.isTransition)
    return slot.crossOver && !afterTransition && !slot.isTransition ? slot : { ...slot, noTouch: false }
  })
}

export function CreateComboPage() {
  const navigate = useNavigate()
  const authed = isAuthenticated()
  const { t } = useTranslation()
  const [mode, setMode] = useState<'choose' | 'generate' | 'build'>('choose')
  const [mobileBuildTab, setMobileBuildTab] = useState<'tricks' | 'combo'>('tricks')

  // Shared name field
  const [name, setName] = useState('')

  // Generate state
  const [selectedPrefId, setSelectedPrefId] = useState<string | null>(null)
  const [overrides, setOverrides] = useState<GenerateComboOverrides>(GENERATE_DEFAULTS)
  const [previewWarnings, setPreviewWarnings] = useState<string[]>([])

  // Build state
  const [abbrevOnly, setAbbrevOnly] = useState(false)
  const [search, setSearch] = useState('')
  const [slots, setSlots] = useState<SlotItem[]>([])
  const [expandedSlots, setExpandedSlots] = useState<Set<number>>(new Set())
  const [isPublic, setIsPublic] = useState(false)
  const [buildError, setBuildError] = useState<string | null>(null)
  const dragIndex = useRef<number | null>(null)
  const [dragOverIndex, setDragOverIndex] = useState<number | null>(null)
  const touchDragOverIndex = useRef<number | null>(null)
  const [touchHeldIndex, setTouchHeldIndex] = useState<number | null>(null)
  const slotsContainerRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const el = slotsContainerRef.current
    if (!el) return
    const onTouchStart = (e: TouchEvent) => {
      if ((e.target as HTMLElement).closest('[data-drag-handle]')) e.preventDefault()
    }
    const onTouchMove = (e: TouchEvent) => { if (dragIndex.current !== null) e.preventDefault() }
    el.addEventListener('touchstart', onTouchStart, { passive: false })
    el.addEventListener('touchmove', onTouchMove, { passive: false })
    return () => {
      el.removeEventListener('touchstart', onTouchStart)
      el.removeEventListener('touchmove', onTouchMove)
    }
  }, [])

  const { data: trickListItems = [], isLoading: tricksLoading } = useQuery({
    queryKey: ['tricks'],
    queryFn: () => tricksApi.getAll().then((r) => r.data),
    enabled: mode === 'build',
  })

  const tricks = trickListItems.filter((item): item is TrickItem => item.type === 'trick')
  const comboItems = trickListItems.filter((item): item is ComboItem => item.type === 'combo')

  const { data: savedPrefs = [] } = useQuery({
    queryKey: ['preferences'],
    queryFn: () => preferencesApi.getAll().then((r) => r.data),
    enabled: mode === 'generate' && authed,
  })

  const selectedPref = selectedPrefId ? savedPrefs.find((p) => p.id === selectedPrefId) ?? null : null

  const previewMutation = useMutation({
    mutationFn: () => combosApi.preview(selectedPrefId, selectedPrefId ? undefined : overrides),
    onSuccess: ({ data }) => {
      setPreviewWarnings(data.warnings)
      setSlots(
        applyNoTouchRules(
          data.tricks.map((t_): TrickSlotItem => ({
            type: 'trick',
            trickId: t_.trickId,
            position: t_.position,
            strongFoot: t_.strongFoot,
            noTouch: t_.noTouch,
            trickName: t_.trickName,
            abbreviation: t_.abbreviation,
            crossOver: t_.crossOver,
            isTransition: t_.isTransition,
          })),
        ),
      )
      setMobileBuildTab('combo')
      setMode('build')
    },
  })

  function serializeSlots(): BuildComboTrickItem[] {
    return slots.map((slot) => {
      if (slot.type === 'combo') {
        return { subComboId: slot.subComboId, position: slot.position, strongFoot: false, noTouch: false }
      }
      return { trickId: slot.trickId, position: slot.position, strongFoot: slot.strongFoot, noTouch: slot.noTouch }
    })
  }

  function handleSave() {
    if (!authed) {
      setPendingCombo({
        tricks: slots.filter((s) => s.type === 'trick' && !!s.trickId).map((s) => ({ trickId: s.trickId!, position: s.position, strongFoot: s.strongFoot, noTouch: s.noTouch })),
        name: name || undefined,
        isPublic,
      })
      navigate('/register')
      return
    }
    buildMutation.mutate()
  }

  const buildMutation = useMutation({
    mutationFn: () => combosApi.build(serializeSlots(), isPublic, name || undefined),
    onSuccess: ({ data }) => { navigate(`/combos/${data.id}`) },
    onError: (err) => setBuildError(extractError(err, t('create.buildFailed'))),
  })

  function updateOverride<K extends keyof GenerateComboOverrides>(key: K, value: GenerateComboOverrides[K]) {
    setOverrides((prev) => ({ ...prev, [key]: value }))
  }

  function addTrick(trick: TrickItem) {
    setSlots((prev) => {
      const next: SlotItem[] = [...prev, { type: 'trick', trickId: trick.id, position: prev.length + 1, strongFoot: true, noTouch: false, trickName: trick.name, abbreviation: trick.abbreviation, crossOver: trick.crossOver, isTransition: trick.isTransition }]
      return applyNoTouchRules(next)
    })
    if (window.innerWidth < 1024) setMobileBuildTab('combo')
  }

  function addCombo(combo: ComboItem) {
    setSlots((prev) => {
      const next: SlotItem[] = [...prev, {
        type: 'combo',
        subComboId: combo.id,
        position: prev.length + 1,
        strongFoot: false,
        noTouch: false,
        comboName: combo.name,
        trickCount: combo.trickCount,
        totalDifficulty: combo.totalDifficulty,
        trickSlots: combo.tricks.filter((t) => t.type === 'trick').map((t) => ({ abbreviation: t.abbreviation, noTouch: t.noTouch })),
      }]
      return applyNoTouchRules(next)
    })
    if (window.innerWidth < 1024) setMobileBuildTab('combo')
  }

  function removeSlot(index: number) {
    setSlots((prev) => prev.filter((_, i) => i !== index).map((s, i) => ({ ...s, position: i + 1 })))
  }

  function reorderSlots(from: number, to: number) {
    setSlots((prev) => {
      const next = [...prev]
      const [moved] = next.splice(from, 1)
      next.splice(to, 0, moved)
      return applyNoTouchRules(next.map((s, i) => ({ ...s, position: i + 1 })))
    })
  }

  function toggleStrongFoot(index: number) {
    setSlots((prev) => prev.map((s, i) => (i === index && s.type === 'trick' ? { ...s, strongFoot: !s.strongFoot } : s)))
  }

  function toggleNoTouch(index: number) {
    setSlots((prev) => prev.map((s, i) => {
      if (i !== index || s.type !== 'trick') return s
      const prevSlot = prev[index - 1]
      const afterTransition = index === 0 || (prevSlot.type === 'trick' && prevSlot.isTransition)
      if (!s.crossOver || afterTransition) return s
      return { ...s, noTouch: !s.noTouch }
    }))
  }

  function toggleExpandSlot(index: number) {
    setExpandedSlots((prev) => {
      const next = new Set(prev)
      if (next.has(index)) next.delete(index)
      else next.add(index)
      return next
    })
  }

  const filteredTricks = tricks.filter(
    (tr) => tr.name.toLowerCase().includes(search.toLowerCase()) || tr.abbreviation.toLowerCase().includes(search.toLowerCase()),
  )

  const filteredCombos = comboItems.filter(
    (c) => c.name.toLowerCase().includes(search.toLowerCase()),
  )

  // Calculate summary expanding sub-combo tricks
  const { totalTricks, totalDifficulty } = slots.reduce(
    (acc, s) => {
      if (s.type === 'trick') {
        const tr = tricks.find((tr) => tr.id === s.trickId)
        return { totalTricks: acc.totalTricks + 1, totalDifficulty: acc.totalDifficulty + (tr?.difficulty ?? 0) }
      } else {
        return {
          totalTricks: acc.totalTricks + s.trickCount,
          totalDifficulty: acc.totalDifficulty + s.totalDifficulty,
        }
      }
    },
    { totalTricks: 0, totalDifficulty: 0 },
  )

  const previewError = previewMutation.error ? extractError(previewMutation.error, t('create.previewFailed')) : null

  const guestBanner = !authed && (
    <div className="rounded-lg border border-blue-200 bg-blue-50 px-4 py-3 text-sm text-blue-800">
      {t('create.guestBanner')}{' '}
      <a href="/register" className="font-medium underline hover:text-blue-900">{t('create.guestSignUp')}</a>
      {' '}{t('auth.alreadyHaveAccount').includes('?') ? 'or' : t('common.cancel').toLowerCase()}{' '}
      <a href="/login" className="font-medium underline hover:text-blue-900">{t('create.guestLogIn')}</a>.
    </div>
  )

  // ── Choose mode ───────────────────────────────────────────────────────────
  if (mode === 'choose') {
    return (
      <div className="space-y-6">
        {guestBanner}
        <div>
          <h1 className="text-2xl font-bold text-gray-900">{t('create.title')}</h1>
          <p className="mt-1 text-sm text-gray-500">{t('create.subtitle')}</p>
        </div>
        <div className="grid gap-4 sm:grid-cols-2">
          <button
            type="button"
            onClick={() => setMode('generate')}
            className="flex flex-col items-start gap-3 rounded-xl border-2 border-gray-200 p-6 text-left hover:border-indigo-400 hover:bg-indigo-50 transition-colors"
          >
            <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-indigo-100 text-xl">✨</div>
            <div>
              <p className="font-semibold text-gray-900">{t('create.autoGenerate')}</p>
              <p className="mt-1 text-sm text-gray-500">{t('create.autoGenerateDesc')}</p>
            </div>
          </button>
          <button
            type="button"
            onClick={() => setMode('build')}
            className="flex flex-col items-start gap-3 rounded-xl border-2 border-gray-200 p-6 text-left hover:border-indigo-400 hover:bg-indigo-50 transition-colors"
          >
            <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-indigo-100 text-xl">🔧</div>
            <div>
              <p className="font-semibold text-gray-900">{t('create.buildManually')}</p>
              <p className="mt-1 text-sm text-gray-500">{t('create.buildManuallyDesc')}</p>
            </div>
          </button>
        </div>
      </div>
    )
  }

  // ── Generate mode ─────────────────────────────────────────────────────────
  if (mode === 'generate') {
    return (
      <div className="space-y-6">
        {guestBanner}
        <div className="flex items-start gap-3">
          <Button variant="ghost" size="sm" onClick={() => setMode('choose')} className="mt-1 shrink-0">
            {t('create.back')}
          </Button>
          <div>
            <h1 className="text-2xl font-bold text-gray-900">{t('create.autoGenerateTitle')}</h1>
            <p className="mt-1 text-sm text-gray-500">{t('create.autoGenerateSubtitle')}</p>
          </div>
        </div>

        {/* Name field at the top */}
        <div className="space-y-1">
          <Label htmlFor="combo-name">{t('create.comboNameLabel')}</Label>
          <Input id="combo-name" placeholder={t('create.comboNamePlaceholder')} value={name} onChange={(e) => setName(e.target.value)} maxLength={100} />
        </div>

        <Card>
          <CardHeader><CardTitle>{t('create.optionsTitle')}</CardTitle></CardHeader>
          <CardContent className="space-y-4">
            {/* Preference selector — only for authenticated users */}
            {authed && (
              <div className="space-y-1">
                <Label htmlFor="gen-pref">{t('create.preference')}</Label>
                <select
                  id="gen-pref"
                  value={selectedPrefId ?? ''}
                  onChange={(e) => setSelectedPrefId(e.target.value || null)}
                  className="w-full rounded-md border border-gray-300 bg-white px-3 py-2 text-sm shadow-sm focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                >
                  <option value="">{t('create.custom')}</option>
                  {savedPrefs.map((p) => (
                    <option key={p.id} value={p.id}>{p.name}</option>
                  ))}
                </select>
              </div>
            )}

            {/* Fields — editable when Custom, read-only when preference selected */}
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 md:grid-cols-3">
              <div className="space-y-1">
                <Label>{t('create.comboLength')}</Label>
                <Input
                  type="number" min={1} max={100}
                  value={selectedPref ? selectedPref.comboLength : overrides.comboLength}
                  readOnly={!!selectedPref}
                  disabled={!!selectedPref}
                  onChange={(e) => updateOverride('comboLength', Number(e.target.value))}
                  className={selectedPref ? 'bg-gray-50 text-gray-500' : ''}
                />
              </div>
              <div className="space-y-1">
                <Label>{t('create.maxDifficulty')}</Label>
                <Input
                  type="number" min={1} max={10}
                  value={selectedPref ? selectedPref.maxDifficulty : overrides.maxDifficulty}
                  readOnly={!!selectedPref}
                  disabled={!!selectedPref}
                  onChange={(e) => updateOverride('maxDifficulty', Number(e.target.value))}
                  className={selectedPref ? 'bg-gray-50 text-gray-500' : ''}
                />
              </div>
              <div className="space-y-1">
                <Label>{t('create.strongFootPct')}</Label>
                <Input
                  type="number" min={0} max={100}
                  value={selectedPref ? selectedPref.strongFootPercentage : overrides.strongFootPercentage}
                  readOnly={!!selectedPref}
                  disabled={!!selectedPref}
                  onChange={(e) => updateOverride('strongFootPercentage', Number(e.target.value))}
                  className={selectedPref ? 'bg-gray-50 text-gray-500' : ''}
                />
              </div>
              <div className="space-y-1">
                <Label>{t('create.noTouchPct')}</Label>
                <Input
                  type="number" min={0} max={100}
                  value={selectedPref ? selectedPref.noTouchPercentage : overrides.noTouchPercentage}
                  readOnly={!!selectedPref}
                  disabled={!!selectedPref}
                  onChange={(e) => updateOverride('noTouchPercentage', Number(e.target.value))}
                  className={selectedPref ? 'bg-gray-50 text-gray-500' : ''}
                />
              </div>
              <div className="space-y-1">
                <Label>{t('create.maxConsecutiveNT')}</Label>
                <Input
                  type="number" min={0} max={30}
                  value={selectedPref ? selectedPref.maxConsecutiveNoTouch : overrides.maxConsecutiveNoTouch}
                  readOnly={!!selectedPref}
                  disabled={!!selectedPref}
                  onChange={(e) => updateOverride('maxConsecutiveNoTouch', Number(e.target.value))}
                  className={selectedPref ? 'bg-gray-50 text-gray-500' : ''}
                />
              </div>
              <div className="flex flex-col gap-2 pt-1">
                <div className="flex items-center gap-2">
                  <input
                    id="gen-crossover" type="checkbox"
                    checked={selectedPref ? selectedPref.includeCrossOver : (overrides.includeCrossOver ?? true)}
                    disabled={!!selectedPref}
                    onChange={(e) => updateOverride('includeCrossOver', e.target.checked)}
                    className="h-4 w-4 rounded border-gray-300 text-indigo-600 disabled:opacity-50"
                  />
                  <Label htmlFor="gen-crossover" className={selectedPref ? 'text-gray-400' : ''}>{t('create.includeCrossover')}</Label>
                </div>
                <div className="flex items-center gap-2">
                  <input
                    id="gen-knee" type="checkbox"
                    checked={selectedPref ? selectedPref.includeKnee : (overrides.includeKnee ?? true)}
                    disabled={!!selectedPref}
                    onChange={(e) => updateOverride('includeKnee', e.target.checked)}
                    className="h-4 w-4 rounded border-gray-300 text-indigo-600 disabled:opacity-50"
                  />
                  <Label htmlFor="gen-knee" className={selectedPref ? 'text-gray-400' : ''}>{t('create.includeKnee')}</Label>
                </div>
              </div>
            </div>

            {selectedPref && (
              <p className="text-xs text-gray-400">
                {t('create.lockedPref', { name: selectedPref.name })}
              </p>
            )}

            {previewError && <p className="text-sm text-red-600">{previewError}</p>}

            <Button onClick={() => previewMutation.mutate()} disabled={previewMutation.isPending} className="w-full sm:w-auto">
              {previewMutation.isPending ? t('create.generating') : t('create.generateCombo')}
            </Button>
          </CardContent>
        </Card>
      </div>
    )
  }

  // ── Build mode ────────────────────────────────────────────────────────────
  return (
    <div className="space-y-6">
      {guestBanner}
      <div className="flex items-start gap-3">
        <Button variant="ghost" size="sm" onClick={() => { setMode('choose'); setSlots([]); setPreviewWarnings([]) }} className="mt-1 shrink-0">
          {t('create.back')}
        </Button>
        <div>
          <h1 className="text-2xl font-bold text-gray-900">{t('create.buildTitle')}</h1>
          <p className="mt-1 text-sm text-gray-500">{t('create.buildSubtitle')}</p>
        </div>
      </div>

      {/* Name field at the top */}
      <div className="space-y-1">
        <Label htmlFor="combo-name">{t('create.comboNameLabel')}</Label>
        <Input id="combo-name" placeholder={t('create.comboNamePlaceholder')} value={name} onChange={(e) => setName(e.target.value)} maxLength={100} />
      </div>

      {previewWarnings.length > 0 && (
        <div className="rounded-lg border border-yellow-200 bg-yellow-50 px-4 py-3 space-y-1">
          {previewWarnings.map((w, i) => (
            <p key={i} className="text-sm text-yellow-800">{w}</p>
          ))}
        </div>
      )}

      {/* Mobile tab switcher — only visible below lg */}
      <div className="flex border-b border-gray-200 lg:hidden">
        <button
          type="button"
          onClick={() => setMobileBuildTab('tricks')}
          className={`flex-1 py-3 text-sm font-medium transition-colors ${mobileBuildTab === 'tricks' ? 'border-b-2 border-indigo-600 text-indigo-600' : 'text-gray-500 hover:text-gray-700'}`}
        >
          {t('create.tabTricks')} {(filteredTricks.length + filteredCombos.length) > 0 && `(${filteredTricks.length + filteredCombos.length})`}
        </button>
        <button
          type="button"
          onClick={() => setMobileBuildTab('combo')}
          className={`flex-1 py-3 text-sm font-medium transition-colors ${mobileBuildTab === 'combo' ? 'border-b-2 border-indigo-600 text-indigo-600' : 'text-gray-500 hover:text-gray-700'}`}
        >
          {t('create.tabCombo')} {slots.length > 0 && `(${slots.length})`}
        </button>
      </div>

      <div className="lg:grid lg:gap-6 lg:grid-cols-2">
        {/* Left — trick picker */}
        <Card className={mobileBuildTab === 'tricks' ? 'block' : 'hidden lg:block'}>
          <CardHeader>
            <div className="flex items-center justify-between">
              <CardTitle>{t('create.availableTricks')}</CardTitle>
              <label className="flex items-center gap-1.5 text-xs text-gray-500 cursor-pointer select-none">
                <input type="checkbox" checked={abbrevOnly} onChange={(e) => setAbbrevOnly(e.target.checked)} className="h-3.5 w-3.5 rounded border-gray-300 text-indigo-600" />
                {t('create.abbrevOnly')}
              </label>
            </div>
          </CardHeader>
          <CardContent className="space-y-3">
            <Input placeholder={t('create.searchTricks')} value={search} onChange={(e) => setSearch(e.target.value)} />
            {tricksLoading ? (
              <p className="text-sm text-gray-500">{t('common.loading')}</p>
            ) : (
              <div className="max-h-[60vh] overflow-y-auto divide-y divide-gray-100 lg:max-h-[480px]">
                {filteredCombos.map((combo) => (
                  <button key={combo.id} type="button" onClick={() => addCombo(combo)} className="flex w-full items-center justify-between px-2 py-2 text-left hover:bg-indigo-50 transition-colors border-l-2 border-indigo-300">
                    <div>
                      <span className="text-sm font-semibold text-indigo-700">{combo.name}</span>
                      <span className="ml-2 text-xs text-gray-400">
                        {t('createCombo.comboSlotLabel', { count: combo.trickCount, total: combo.totalDifficulty })}
                      </span>
                    </div>
                    <Badge variant="secondary" className="text-indigo-600 bg-indigo-50">combo</Badge>
                  </button>
                ))}
                {filteredTricks.map((trick) => (
                  <button key={trick.id} type="button" onClick={() => addTrick(trick)} className="flex w-full items-center justify-between px-2 py-2 text-left hover:bg-indigo-50 transition-colors">
                    <div>
                      <span className="font-mono text-xs font-semibold text-gray-900">{trick.abbreviation}</span>
                      {!abbrevOnly && <span className="ml-2 text-sm text-gray-500">{trick.name}</span>}
                    </div>
                    <div className="flex items-center gap-1">
                      {trick.crossOver && <Badge variant="secondary">CO</Badge>}
                      {trick.knee && <Badge variant="secondary">K</Badge>}
                      <span className={`inline-flex items-center rounded px-1.5 py-0.5 text-xs font-medium ${diffColor(trick.difficulty)}`}>{trick.difficulty}</span>
                    </div>
                  </button>
                ))}
                {filteredTricks.length === 0 && filteredCombos.length === 0 && <p className="py-4 text-center text-sm text-gray-400">{t('create.noTricksMatch')}</p>}
              </div>
            )}
          </CardContent>
        </Card>

        {/* Right — combo builder */}
        <Card className={mobileBuildTab === 'combo' ? 'block' : 'hidden lg:block'}>
          <CardHeader>
            <div className="flex items-center justify-between">
              <CardTitle>{t('create.myComboTitle')}</CardTitle>
              {slots.length > 0 && <span className="text-sm text-gray-500">{t('create.tricksSummary', { count: totalTricks, totalDiff: totalDifficulty })}</span>}
            </div>
          </CardHeader>
          <CardContent className="space-y-3">
            {slots.length === 0 && (
              <p className="py-4 text-center text-sm text-gray-400 lg:hidden">
                {t('create.tapTricksHint')}
              </p>
            )}
            {slots.length === 0 && <p className="py-4 text-center text-sm text-gray-400 hidden lg:block">{t('create.clickTricksHint')}</p>}
            <div className="space-y-2" ref={slotsContainerRef}>
              {slots.map((slot, i) => (
                <div
                  key={i}
                  data-drag-index={i}
                  draggable
                  onDragStart={() => { dragIndex.current = i }}
                  onDragOver={(e) => { e.preventDefault(); setDragOverIndex(i) }}
                  onDrop={(e) => {
                    e.preventDefault()
                    if (dragIndex.current !== null && dragIndex.current !== i) reorderSlots(dragIndex.current, i)
                    dragIndex.current = null
                    setDragOverIndex(null)
                  }}
                  onDragEnd={() => { dragIndex.current = null; setDragOverIndex(null) }}
                  onTouchStart={(e) => { if ((e.target as HTMLElement).closest('[data-drag-handle]')) { dragIndex.current = i; setTouchHeldIndex(i) } }}
                  onTouchMove={(e) => {
                    const touch = e.touches[0]
                    const el = document.elementFromPoint(touch.clientX, touch.clientY)
                    const slotEl = el?.closest('[data-drag-index]')
                    if (slotEl) {
                      const idx = parseInt(slotEl.getAttribute('data-drag-index') ?? '-1', 10)
                      if (idx >= 0) { touchDragOverIndex.current = idx; setDragOverIndex(idx) }
                    }
                  }}
                  onTouchEnd={() => {
                    if (dragIndex.current !== null && touchDragOverIndex.current !== null && dragIndex.current !== touchDragOverIndex.current)
                      reorderSlots(dragIndex.current, touchDragOverIndex.current)
                    dragIndex.current = null
                    touchDragOverIndex.current = null
                    setDragOverIndex(null)
                    setTouchHeldIndex(null)
                  }}
                  className={`rounded-lg border transition-colors select-none ${dragOverIndex === i ? 'border-indigo-400 bg-indigo-50' : slot.type === 'combo' ? 'border-indigo-200' : 'border-gray-200'} ${touchHeldIndex === i ? 'drag-shaking' : ''}`}
                >
                  <div className="flex items-center gap-3 px-3 py-2">
                    <span data-drag-handle style={{ touchAction: 'none' }} className="shrink-0 cursor-grab active:cursor-grabbing p-2 -m-2 touch-none">
                      <GripVertical className="w-4 h-4 text-gray-300 pointer-events-none" />
                    </span>
                    <span className="w-5 shrink-0 text-xs font-bold text-gray-400">{slot.position}</span>
                    {slot.type === 'trick' ? (() => {
                      const trickSlot = slot
                      const prevSlot = i > 0 ? slots[i - 1] : null
                      const ntDisabled = trickSlot.isTransition || !trickSlot.crossOver || i === 0 || (prevSlot?.type === 'trick' && prevSlot.isTransition)
                      return (
                      <>
                        <div className="flex-1 min-w-0">
                          <span className="font-mono text-xs font-semibold text-gray-900">{trickSlot.abbreviation}</span>
                          {!abbrevOnly && <span className="ml-1.5 text-sm text-gray-500">{trickSlot.trickName}</span>}
                        </div>
                        <FootToggle value={trickSlot.strongFoot} onChange={() => toggleStrongFoot(i)} disabled={trickSlot.isTransition} />
                        <label className={`flex items-center gap-1 text-xs cursor-pointer ${ntDisabled ? 'text-gray-300 cursor-not-allowed' : 'text-gray-600'}`}>
                          <input type="checkbox" checked={trickSlot.noTouch} onChange={() => toggleNoTouch(i)} disabled={ntDisabled} className="h-3.5 w-3.5 rounded border-gray-300 text-indigo-600 disabled:opacity-40" />
                          NT
                        </label>
                      </>
                      )
                    })() : (
                      <>
                        <div className="flex-1 min-w-0">
                          <span className="text-sm font-semibold text-indigo-700">{slot.comboName}</span>
                        </div>
                        <button
                          type="button"
                          onClick={() => toggleExpandSlot(i)}
                          className="text-gray-400 hover:text-indigo-600 transition-colors p-1"
                          title={expandedSlots.has(i) ? t('createCombo.collapseSlot') : t('createCombo.expandSlot')}
                        >
                          {expandedSlots.has(i) ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />}
                        </button>
                      </>
                    )}
                    <button type="button" onClick={() => removeSlot(i)} className="text-gray-400 hover:text-red-500 text-lg leading-none" title="Remove">×</button>
                  </div>
                  {slot.type === 'combo' && expandedSlots.has(i) && (
                    <div className="px-10 pb-2 flex flex-wrap gap-1">
                      {slot.trickSlots.map((ts, j) => (
                        <span key={j} className="inline-flex items-center gap-0.5 rounded bg-indigo-50 px-1.5 py-0.5 text-xs font-mono text-indigo-700">
                          {ts.abbreviation}
                          {ts.noTouch && <span className="text-indigo-400">(nt)</span>}
                        </span>
                      ))}
                    </div>
                  )}
                </div>
              ))}
            </div>

            {slots.length > 0 && (
              <div className="space-y-3 border-t border-gray-100 pt-3">
                <label className="flex items-center gap-2 text-sm cursor-pointer">
                  <input type="checkbox" checked={isPublic} onChange={(e) => setIsPublic(e.target.checked)} className="h-4 w-4 rounded border-gray-300 text-indigo-600" />
                  {t('create.submitForReview')}
                </label>
                {buildError && <p className="text-sm text-red-600">{buildError}</p>}
                <Button onClick={handleSave} disabled={buildMutation.isPending || slots.length === 0} className="w-full">
                  {buildMutation.isPending ? t('create.savingCombo') : authed ? t('create.saveCombo') : t('create.signUpToSave')}
                </Button>
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
