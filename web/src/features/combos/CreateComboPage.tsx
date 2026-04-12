import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useQuery, useMutation } from '@tanstack/react-query'
import { combosApi, tricksApi, preferencesApi, extractError, type GenerateComboOverrides, type TrickDto, type BuildComboTrickItem } from '@/lib/api'
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

interface SlotItem extends BuildComboTrickItem {
  trickName: string
  abbreviation: string
  crossOver: boolean
}

export function CreateComboPage() {
  const navigate = useNavigate()
  const [mode, setMode] = useState<'choose' | 'generate' | 'build'>('choose')

  // Shared name field
  const [name, setName] = useState('')

  // Generate state
  const [selectedPrefId, setSelectedPrefId] = useState<string | null>(null)
  const [overrides, setOverrides] = useState<GenerateComboOverrides>(GENERATE_DEFAULTS)
  const [previewWarnings, setPreviewWarnings] = useState<string[]>([])

  // Build state
  const [search, setSearch] = useState('')
  const [slots, setSlots] = useState<SlotItem[]>([])
  const [isPublic, setIsPublic] = useState(false)
  const [buildError, setBuildError] = useState<string | null>(null)

  const { data: tricks = [], isLoading: tricksLoading } = useQuery({
    queryKey: ['tricks'],
    queryFn: () => tricksApi.getAll().then((r) => r.data),
    enabled: mode === 'build',
  })

  const { data: savedPrefs = [] } = useQuery({
    queryKey: ['preferences'],
    queryFn: () => preferencesApi.getAll().then((r) => r.data),
    enabled: mode === 'generate',
  })

  // When a preference is selected, find its values for the read-only display
  const selectedPref = selectedPrefId ? savedPrefs.find((p) => p.id === selectedPrefId) ?? null : null

  const previewMutation = useMutation({
    mutationFn: () => combosApi.preview(selectedPrefId, selectedPrefId ? undefined : overrides),
    onSuccess: ({ data }) => {
      setPreviewWarnings(data.warnings)
      setSlots(
        data.tricks.map((t) => ({
          trickId: t.trickId,
          position: t.position,
          strongFoot: t.strongFoot,
          noTouch: t.noTouch,
          trickName: t.trickName,
          abbreviation: t.abbreviation,
          crossOver: t.crossOver,
        })),
      )
      setMode('build')
    },
  })

  const buildMutation = useMutation({
    mutationFn: () =>
      combosApi.build(
        slots.map(({ trickId, position, strongFoot, noTouch }) => ({ trickId, position, strongFoot, noTouch })),
        isPublic,
        name || undefined,
      ),
    onSuccess: ({ data }) => { navigate(`/combos/${data.id}`) },
    onError: (err) => setBuildError(extractError(err, 'Build failed')),
  })

  function updateOverride<K extends keyof GenerateComboOverrides>(key: K, value: GenerateComboOverrides[K]) {
    setOverrides((prev) => ({ ...prev, [key]: value }))
  }

  function addTrick(trick: TrickDto) {
    setSlots((prev) => [
      ...prev,
      { trickId: trick.id, position: prev.length + 1, strongFoot: true, noTouch: false, trickName: trick.name, abbreviation: trick.abbreviation, crossOver: trick.crossOver },
    ])
  }

  function removeSlot(index: number) {
    setSlots((prev) => prev.filter((_, i) => i !== index).map((s, i) => ({ ...s, position: i + 1 })))
  }

  function toggleStrongFoot(index: number) {
    setSlots((prev) => prev.map((s, i) => (i === index ? { ...s, strongFoot: !s.strongFoot } : s)))
  }

  function toggleNoTouch(index: number) {
    setSlots((prev) => prev.map((s, i) => {
      if (i !== index || !s.crossOver) return s
      return { ...s, noTouch: !s.noTouch }
    }))
  }

  const filteredTricks = tricks.filter(
    (t) => t.name.toLowerCase().includes(search.toLowerCase()) || t.abbreviation.toLowerCase().includes(search.toLowerCase()),
  )

  const avgDiff = slots.length > 0
    ? slots.reduce((sum, s) => { const t = tricks.find((t) => t.id === s.trickId); return sum + (t?.difficulty ?? 0) }, 0) / slots.length
    : 0

  const previewError = previewMutation.error ? extractError(previewMutation.error, 'Preview failed') : null

  // ── Choose mode ───────────────────────────────────────────────────────────
  if (mode === 'choose') {
    return (
      <div className="space-y-6">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Create Combo</h1>
          <p className="mt-1 text-sm text-gray-500">How would you like to create your combo?</p>
        </div>
        <div className="grid gap-4 sm:grid-cols-2">
          <button
            type="button"
            onClick={() => setMode('generate')}
            className="flex flex-col items-start gap-3 rounded-xl border-2 border-gray-200 p-6 text-left hover:border-indigo-400 hover:bg-indigo-50 transition-colors"
          >
            <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-indigo-100 text-xl">✨</div>
            <div>
              <p className="font-semibold text-gray-900">Auto-generate</p>
              <p className="mt-1 text-sm text-gray-500">Let the app build a combo based on your settings.</p>
            </div>
          </button>
          <button
            type="button"
            onClick={() => setMode('build')}
            className="flex flex-col items-start gap-3 rounded-xl border-2 border-gray-200 p-6 text-left hover:border-indigo-400 hover:bg-indigo-50 transition-colors"
          >
            <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-indigo-100 text-xl">🔧</div>
            <div>
              <p className="font-semibold text-gray-900">Build manually</p>
              <p className="mt-1 text-sm text-gray-500">Pick tricks one by one and configure each slot.</p>
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
        <div className="flex items-start gap-3">
          <Button variant="ghost" size="sm" onClick={() => setMode('choose')} className="mt-1 shrink-0">
            ← Back
          </Button>
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Auto-generate Combo</h1>
            <p className="mt-1 text-sm text-gray-500">Configure settings and generate — you'll be able to edit before saving.</p>
          </div>
        </div>

        {/* Name field at the top */}
        <div className="space-y-1">
          <Label htmlFor="combo-name">Combo name (optional)</Label>
          <Input id="combo-name" placeholder="e.g. My signature combo" value={name} onChange={(e) => setName(e.target.value)} maxLength={100} />
        </div>

        <Card>
          <CardHeader><CardTitle>Options</CardTitle></CardHeader>
          <CardContent className="space-y-4">
            {/* Preference selector */}
            <div className="space-y-1">
              <Label htmlFor="gen-pref">Preference</Label>
              <select
                id="gen-pref"
                value={selectedPrefId ?? ''}
                onChange={(e) => setSelectedPrefId(e.target.value || null)}
                className="w-full rounded-md border border-gray-300 bg-white px-3 py-2 text-sm shadow-sm focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500"
              >
                <option value="">Custom</option>
                {savedPrefs.map((p) => (
                  <option key={p.id} value={p.id}>{p.name}</option>
                ))}
              </select>
            </div>

            {/* Fields — editable when Custom, read-only when preference selected */}
            <div className="grid grid-cols-2 gap-4 sm:grid-cols-3">
              <div className="space-y-1">
                <Label>Combo Length</Label>
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
                <Label>Max Difficulty</Label>
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
                <Label>Strong Foot %</Label>
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
                <Label>No-Touch %</Label>
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
                <Label>Max Consecutive NT</Label>
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
                  <Label htmlFor="gen-crossover" className={selectedPref ? 'text-gray-400' : ''}>Include Crossover</Label>
                </div>
                <div className="flex items-center gap-2">
                  <input
                    id="gen-knee" type="checkbox"
                    checked={selectedPref ? selectedPref.includeKnee : (overrides.includeKnee ?? true)}
                    disabled={!!selectedPref}
                    onChange={(e) => updateOverride('includeKnee', e.target.checked)}
                    className="h-4 w-4 rounded border-gray-300 text-indigo-600 disabled:opacity-50"
                  />
                  <Label htmlFor="gen-knee" className={selectedPref ? 'text-gray-400' : ''}>Include Knee</Label>
                </div>
              </div>
            </div>

            {selectedPref && (
              <p className="text-xs text-gray-400">
                Fields are locked to the "{selectedPref.name}" preference. Select "Custom" to edit.
              </p>
            )}

            {previewError && <p className="text-sm text-red-600">{previewError}</p>}

            <Button onClick={() => previewMutation.mutate()} disabled={previewMutation.isPending} className="w-full sm:w-auto">
              {previewMutation.isPending ? 'Generating…' : 'Generate Combo'}
            </Button>
          </CardContent>
        </Card>
      </div>
    )
  }

  // ── Build mode ────────────────────────────────────────────────────────────
  return (
    <div className="space-y-6">
      <div className="flex items-start gap-3">
        <Button variant="ghost" size="sm" onClick={() => { setMode('choose'); setSlots([]); setPreviewWarnings([]) }} className="mt-1 shrink-0">
          ← Back
        </Button>
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Build Combo</h1>
          <p className="mt-1 text-sm text-gray-500">Pick tricks one by one and configure each slot manually.</p>
        </div>
      </div>

      {/* Name field at the top */}
      <div className="space-y-1">
        <Label htmlFor="combo-name">Combo name (optional)</Label>
        <Input id="combo-name" placeholder="e.g. My signature combo" value={name} onChange={(e) => setName(e.target.value)} maxLength={100} />
      </div>

      {previewWarnings.length > 0 && (
        <div className="rounded-lg border border-yellow-200 bg-yellow-50 px-4 py-3 space-y-1">
          {previewWarnings.map((w, i) => (
            <p key={i} className="text-sm text-yellow-800">{w}</p>
          ))}
        </div>
      )}

      <div className="grid gap-6 lg:grid-cols-2">
        {/* Left — trick picker */}
        <Card>
          <CardHeader><CardTitle>Available Tricks</CardTitle></CardHeader>
          <CardContent className="space-y-3">
            <Input placeholder="Search by name or abbreviation…" value={search} onChange={(e) => setSearch(e.target.value)} />
            {tricksLoading ? (
              <p className="text-sm text-gray-500">Loading…</p>
            ) : (
              <div className="max-h-[480px] overflow-y-auto divide-y divide-gray-100">
                {filteredTricks.map((trick) => (
                  <button key={trick.id} type="button" onClick={() => addTrick(trick)} className="flex w-full items-center justify-between px-2 py-2 text-left hover:bg-indigo-50 transition-colors">
                    <div>
                      <span className="font-mono text-xs font-semibold text-gray-900">{trick.abbreviation}</span>
                      <span className="ml-2 text-sm text-gray-500">{trick.name}</span>
                    </div>
                    <div className="flex items-center gap-1">
                      {trick.crossOver && <Badge variant="secondary">CO</Badge>}
                      {trick.knee && <Badge variant="secondary">K</Badge>}
                      <span className={`inline-flex items-center rounded px-1.5 py-0.5 text-xs font-medium ${diffColor(trick.difficulty)}`}>{trick.difficulty}</span>
                    </div>
                  </button>
                ))}
                {filteredTricks.length === 0 && <p className="py-4 text-center text-sm text-gray-400">No tricks match.</p>}
              </div>
            )}
          </CardContent>
        </Card>

        {/* Right — combo builder */}
        <Card>
          <CardHeader>
            <div className="flex items-center justify-between">
              <CardTitle>My Combo</CardTitle>
              {slots.length > 0 && <span className="text-sm text-gray-500">{slots.length} tricks · avg diff {avgDiff.toFixed(1)}</span>}
            </div>
          </CardHeader>
          <CardContent className="space-y-3">
            {slots.length === 0 && <p className="py-4 text-center text-sm text-gray-400">Click tricks on the left to add them.</p>}
            <div className="space-y-2">
              {slots.map((slot, i) => (
                <div key={i} className="flex items-center gap-3 rounded-lg border border-gray-200 px-3 py-2">
                  <span className="w-5 shrink-0 text-xs font-bold text-gray-400">{slot.position}</span>
                  <div className="flex-1 min-w-0">
                    <span className="font-mono text-xs font-semibold text-gray-900">{slot.abbreviation}</span>
                    <span className="ml-1.5 text-sm text-gray-500">{slot.trickName}</span>
                  </div>
                  <label className="flex items-center gap-1 text-xs text-gray-600 cursor-pointer">
                    <input type="checkbox" checked={slot.strongFoot} onChange={() => toggleStrongFoot(i)} className="h-3.5 w-3.5 rounded border-gray-300 text-indigo-600" />
                    SF
                  </label>
                  <label className={`flex items-center gap-1 text-xs cursor-pointer ${slot.crossOver ? 'text-gray-600' : 'text-gray-300 cursor-not-allowed'}`}>
                    <input type="checkbox" checked={slot.noTouch} onChange={() => toggleNoTouch(i)} disabled={!slot.crossOver} className="h-3.5 w-3.5 rounded border-gray-300 text-indigo-600 disabled:opacity-40" />
                    NT
                  </label>
                  <button type="button" onClick={() => removeSlot(i)} className="text-gray-400 hover:text-red-500 text-lg leading-none" title="Remove">×</button>
                </div>
              ))}
            </div>

            {slots.length > 0 && (
              <div className="space-y-3 border-t border-gray-100 pt-3">
                <label className="flex items-center gap-2 text-sm cursor-pointer">
                  <input type="checkbox" checked={isPublic} onChange={(e) => setIsPublic(e.target.checked)} className="h-4 w-4 rounded border-gray-300 text-indigo-600" />
                  Submit for public review
                </label>
                {buildError && <p className="text-sm text-red-600">{buildError}</p>}
                <Button onClick={() => buildMutation.mutate()} disabled={buildMutation.isPending || slots.length === 0} className="w-full">
                  {buildMutation.isPending ? 'Saving…' : 'Save Combo'}
                </Button>
              </div>
            )}
          </CardContent>
        </Card>
      </div>

    </div>
  )
}
