import { useState } from 'react'
import { useQuery, useMutation } from '@tanstack/react-query'
import { combosApi, tricksApi, extractError, type ComboDto, type GenerateComboOverrides, type TrickDto, type BuildComboTrickItem } from '@/lib/api'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { ComboCard } from './ComboCard'

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
  const [mode, setMode] = useState<'choose' | 'generate' | 'build'>('choose')

  // Generate state
  const [usePrefs, setUsePrefs] = useState(false)
  const [overrides, setOverrides] = useState<GenerateComboOverrides>(GENERATE_DEFAULTS)
  const [generateResult, setGenerateResult] = useState<ComboDto | null>(null)
  const [generateName, setGenerateName] = useState('')

  // Build state
  const [search, setSearch] = useState('')
  const [slots, setSlots] = useState<SlotItem[]>([])
  const [isPublic, setIsPublic] = useState(false)
  const [buildName, setBuildName] = useState('')
  const [buildResult, setBuildResult] = useState<ComboDto | null>(null)
  const [buildError, setBuildError] = useState<string | null>(null)

  const { data: tricks = [], isLoading: tricksLoading } = useQuery({
    queryKey: ['tricks'],
    queryFn: () => tricksApi.getAll().then((r) => r.data),
    enabled: mode === 'build',
  })

  const generateMutation = useMutation({
    mutationFn: () => combosApi.generate(usePrefs, usePrefs ? undefined : overrides, generateName || undefined),
    onSuccess: ({ data }) => setGenerateResult(data),
  })

  const buildMutation = useMutation({
    mutationFn: () =>
      combosApi.build(
        slots.map(({ trickId, position, strongFoot, noTouch }) => ({ trickId, position, strongFoot, noTouch })),
        isPublic,
        buildName || undefined,
      ),
    onSuccess: ({ data }) => { setBuildResult(data); setBuildError(null) },
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

  const generateError = generateMutation.error ? extractError(generateMutation.error, 'Generation failed') : null

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
            <p className="mt-1 text-sm text-gray-500">Build a freestyle football combo based on your settings.</p>
          </div>
        </div>

        <Card>
          <CardHeader><CardTitle>Options</CardTitle></CardHeader>
          <CardContent className="space-y-4">
            <div className="flex items-center gap-3">
              <input
                id="gen-usePrefs"
                type="checkbox"
                checked={usePrefs}
                onChange={(e) => setUsePrefs(e.target.checked)}
                className="h-4 w-4 rounded border-gray-300 text-indigo-600"
              />
              <Label htmlFor="gen-usePrefs">Use my saved preferences</Label>
            </div>

            {!usePrefs && (
              <div className="grid grid-cols-2 gap-4 sm:grid-cols-3">
                <div className="space-y-1">
                  <Label>Combo Length</Label>
                  <Input type="number" min={1} max={100} value={overrides.comboLength} onChange={(e) => updateOverride('comboLength', Number(e.target.value))} />
                </div>
                <div className="space-y-1">
                  <Label>Max Difficulty</Label>
                  <Input type="number" min={1} max={10} value={overrides.maxDifficulty} onChange={(e) => updateOverride('maxDifficulty', Number(e.target.value))} />
                </div>
                <div className="space-y-1">
                  <Label>Strong Foot %</Label>
                  <Input type="number" min={0} max={100} value={overrides.strongFootPercentage} onChange={(e) => updateOverride('strongFootPercentage', Number(e.target.value))} />
                </div>
                <div className="space-y-1">
                  <Label>No-Touch %</Label>
                  <Input type="number" min={0} max={100} value={overrides.noTouchPercentage} onChange={(e) => updateOverride('noTouchPercentage', Number(e.target.value))} />
                </div>
                <div className="space-y-1">
                  <Label>Max Consecutive NT</Label>
                  <Input type="number" min={0} max={30} value={overrides.maxConsecutiveNoTouch} onChange={(e) => updateOverride('maxConsecutiveNoTouch', Number(e.target.value))} />
                </div>
                <div className="flex flex-col gap-2 pt-1">
                  <div className="flex items-center gap-2">
                    <input id="gen-crossover" type="checkbox" checked={overrides.includeCrossOver} onChange={(e) => updateOverride('includeCrossOver', e.target.checked)} className="h-4 w-4 rounded border-gray-300 text-indigo-600" />
                    <Label htmlFor="gen-crossover">Include Crossover</Label>
                  </div>
                  <div className="flex items-center gap-2">
                    <input id="gen-knee" type="checkbox" checked={overrides.includeKnee} onChange={(e) => updateOverride('includeKnee', e.target.checked)} className="h-4 w-4 rounded border-gray-300 text-indigo-600" />
                    <Label htmlFor="gen-knee">Include Knee</Label>
                  </div>
                </div>
              </div>
            )}

            <div className="space-y-1">
              <Label htmlFor="gen-name">Combo name (optional)</Label>
              <Input id="gen-name" placeholder="e.g. My signature combo" value={generateName} onChange={(e) => setGenerateName(e.target.value)} maxLength={100} />
            </div>

            {generateError && <p className="text-sm text-red-600">{generateError}</p>}

            <Button onClick={() => generateMutation.mutate()} disabled={generateMutation.isPending} className="w-full sm:w-auto">
              {generateMutation.isPending ? 'Generating…' : 'Generate Combo'}
            </Button>
          </CardContent>
        </Card>

        {generateResult && (
          <div className="space-y-3">
            <div className="flex items-center gap-2">
              <h2 className="text-lg font-semibold">Result</h2>
              <Badge variant="secondary">{generateResult.trickCount} tricks</Badge>
            </div>
            <ComboCard combo={generateResult} showActions />
          </div>
        )}
      </div>
    )
  }

  // ── Build mode ────────────────────────────────────────────────────────────
  return (
    <div className="space-y-6">
      <div className="flex items-start gap-3">
        <Button variant="ghost" size="sm" onClick={() => setMode('choose')} className="mt-1 shrink-0">
          ← Back
        </Button>
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Build Combo</h1>
          <p className="mt-1 text-sm text-gray-500">Pick tricks one by one and configure each slot manually.</p>
        </div>
      </div>

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
                      <span className="text-sm font-medium">{trick.name}</span>
                      <span className="ml-2 font-mono text-xs text-gray-500">{trick.abbreviation}</span>
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
                    <span className="text-sm font-medium">{slot.trickName}</span>
                    <span className="ml-1.5 font-mono text-xs text-gray-500">{slot.abbreviation}</span>
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
                <div className="space-y-1">
                  <Label htmlFor="build-name">Combo name (optional)</Label>
                  <Input id="build-name" placeholder="e.g. My signature combo" value={buildName} onChange={(e) => setBuildName(e.target.value)} maxLength={100} />
                </div>
                <label className="flex items-center gap-2 text-sm cursor-pointer">
                  <input type="checkbox" checked={isPublic} onChange={(e) => setIsPublic(e.target.checked)} className="h-4 w-4 rounded border-gray-300 text-indigo-600" />
                  Make public
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

      {buildResult && (
        <div className="space-y-3">
          <div className="flex items-center gap-2">
            <h2 className="text-lg font-semibold">Saved!</h2>
            <Badge variant="secondary">{buildResult.trickCount} tricks</Badge>
          </div>
          <ComboCard combo={buildResult} showActions />
        </div>
      )}
    </div>
  )
}
