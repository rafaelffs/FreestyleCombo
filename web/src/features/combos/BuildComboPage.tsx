import { useState } from 'react'
import { useQuery, useMutation } from '@tanstack/react-query'
import { tricksApi, combosApi, extractError, type TrickDto, type BuildComboTrickItem, type ComboDto } from '@/lib/api'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Badge } from '@/components/ui/badge'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { ComboCard } from './ComboCard'

function diffColor(d: number): string {
  if (d <= 4) return 'bg-green-100 text-green-800'
  if (d <= 7) return 'bg-yellow-100 text-yellow-800'
  return 'bg-red-100 text-red-800'
}

interface SlotItem extends BuildComboTrickItem {
  trickName: string
  abbreviation: string
  crossOver: boolean
}

export function BuildComboPage() {
  const [search, setSearch] = useState('')
  const [slots, setSlots] = useState<SlotItem[]>([])
  const [isPublic, setIsPublic] = useState(false)
  const [comboName, setComboName] = useState('')
  const [result, setResult] = useState<ComboDto | null>(null)
  const [buildError, setBuildError] = useState<string | null>(null)

  const { data: tricks = [], isLoading } = useQuery({
    queryKey: ['tricks'],
    queryFn: () => tricksApi.getAll().then((r) => r.data),
  })

  const buildMutation = useMutation({
    mutationFn: () =>
      combosApi.build(
        slots.map(({ trickId, position, strongFoot, noTouch }) => ({
          trickId,
          position,
          strongFoot,
          noTouch,
        })),
        isPublic,
        comboName || undefined,
      ),
    onSuccess: ({ data }) => {
      setResult(data)
      setBuildError(null)
    },
    onError: (err) => setBuildError(extractError(err, 'Build failed')),
  })

  function addTrick(trick: TrickDto) {
    setSlots((prev) => [
      ...prev,
      {
        trickId: trick.id,
        position: prev.length + 1,
        strongFoot: true,
        noTouch: false,
        trickName: trick.name,
        abbreviation: trick.abbreviation,
        crossOver: trick.crossOver,
      },
    ])
  }

  function removeSlot(index: number) {
    setSlots((prev) => {
      const next = prev.filter((_, i) => i !== index)
      return next.map((s, i) => ({ ...s, position: i + 1 }))
    })
  }

  function toggleStrongFoot(index: number) {
    setSlots((prev) =>
      prev.map((s, i) => (i === index ? { ...s, strongFoot: !s.strongFoot } : s)),
    )
  }

  function toggleNoTouch(index: number) {
    setSlots((prev) =>
      prev.map((s, i) => {
        if (i !== index) return s
        if (!s.crossOver) return s
        return { ...s, noTouch: !s.noTouch }
      }),
    )
  }

  const filtered = tricks.filter(
    (t) =>
      t.name.toLowerCase().includes(search.toLowerCase()) ||
      t.abbreviation.toLowerCase().includes(search.toLowerCase()),
  )

  const avgDiff =
    slots.length > 0
      ? slots.reduce((sum, s) => {
          const trick = tricks.find((t) => t.id === s.trickId)
          return sum + (trick?.difficulty ?? 0)
        }, 0) / slots.length
      : 0

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Build Combo</h1>
        <p className="mt-1 text-sm text-gray-500">
          Pick tricks one by one and configure each slot manually.
        </p>
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        {/* Left — trick picker */}
        <Card>
          <CardHeader>
            <CardTitle>Available Tricks</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            <Input
              placeholder="Search by name or abbreviation…"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
            {isLoading ? (
              <p className="text-sm text-gray-500">Loading…</p>
            ) : (
              <div className="max-h-[480px] overflow-y-auto divide-y divide-gray-100">
                {filtered.map((trick) => (
                  <button
                    key={trick.id}
                    type="button"
                    onClick={() => addTrick(trick)}
                    className="flex w-full items-center justify-between px-2 py-2 text-left hover:bg-indigo-50 transition-colors"
                  >
                    <div>
                      <span className="text-sm font-medium">{trick.name}</span>
                      <span className="ml-2 font-mono text-xs text-gray-500">{trick.abbreviation}</span>
                    </div>
                    <div className="flex items-center gap-1">
                      {trick.crossOver && <Badge variant="secondary">CO</Badge>}
                      {trick.knee && <Badge variant="secondary">K</Badge>}
                      <span className={`inline-flex items-center rounded px-1.5 py-0.5 text-xs font-medium ${diffColor(trick.difficulty)}`}>
                        {trick.difficulty}
                      </span>
                    </div>
                  </button>
                ))}
                {filtered.length === 0 && (
                  <p className="py-4 text-center text-sm text-gray-400">No tricks match.</p>
                )}
              </div>
            )}
          </CardContent>
        </Card>

        {/* Right — combo builder */}
        <Card>
          <CardHeader>
            <div className="flex items-center justify-between">
              <CardTitle>My Combo</CardTitle>
              {slots.length > 0 && (
                <span className="text-sm text-gray-500">
                  {slots.length} tricks · avg diff {avgDiff.toFixed(1)}
                </span>
              )}
            </div>
          </CardHeader>
          <CardContent className="space-y-3">
            {slots.length === 0 && (
              <p className="py-4 text-center text-sm text-gray-400">
                Click tricks on the left to add them.
              </p>
            )}
            <div className="space-y-2">
              {slots.map((slot, i) => (
                <div
                  key={i}
                  className="flex items-center gap-3 rounded-lg border border-gray-200 px-3 py-2"
                >
                  <span className="w-5 shrink-0 text-xs font-bold text-gray-400">{slot.position}</span>
                  <div className="flex-1 min-w-0">
                    <span className="text-sm font-medium">{slot.trickName}</span>
                    <span className="ml-1.5 font-mono text-xs text-gray-500">{slot.abbreviation}</span>
                  </div>
                  <label className="flex items-center gap-1 text-xs text-gray-600 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={slot.strongFoot}
                      onChange={() => toggleStrongFoot(i)}
                      className="h-3.5 w-3.5 rounded border-gray-300 text-indigo-600"
                    />
                    SF
                  </label>
                  <label
                    className={`flex items-center gap-1 text-xs cursor-pointer ${
                      slot.crossOver ? 'text-gray-600' : 'text-gray-300 cursor-not-allowed'
                    }`}
                  >
                    <input
                      type="checkbox"
                      checked={slot.noTouch}
                      onChange={() => toggleNoTouch(i)}
                      disabled={!slot.crossOver}
                      className="h-3.5 w-3.5 rounded border-gray-300 text-indigo-600 disabled:opacity-40"
                    />
                    NT
                  </label>
                  <button
                    type="button"
                    onClick={() => removeSlot(i)}
                    className="text-gray-400 hover:text-red-500 text-lg leading-none"
                    title="Remove"
                  >
                    ×
                  </button>
                </div>
              ))}
            </div>

            {slots.length > 0 && (
              <div className="space-y-3 border-t border-gray-100 pt-3">
                <div className="space-y-1">
                  <Label htmlFor="comboName">Combo name (optional)</Label>
                  <Input
                    id="comboName"
                    placeholder="e.g. My signature combo"
                    value={comboName}
                    onChange={(e) => setComboName(e.target.value)}
                    maxLength={100}
                  />
                </div>
                <label className="flex items-center gap-2 text-sm cursor-pointer">
                  <input
                    type="checkbox"
                    checked={isPublic}
                    onChange={(e) => setIsPublic(e.target.checked)}
                    className="h-4 w-4 rounded border-gray-300 text-indigo-600"
                  />
                  Make public
                </label>
                {buildError && <p className="text-sm text-red-600">{buildError}</p>}
                <Button
                  onClick={() => buildMutation.mutate()}
                  disabled={buildMutation.isPending || slots.length === 0}
                  className="w-full"
                >
                  {buildMutation.isPending ? 'Saving…' : 'Save Combo'}
                </Button>
              </div>
            )}
          </CardContent>
        </Card>
      </div>

      {result && (
        <div className="space-y-3">
          <div className="flex items-center gap-2">
            <h2 className="text-lg font-semibold">Saved!</h2>
            <Badge variant="secondary">{result.trickCount} tricks</Badge>
          </div>
          <ComboCard combo={result} showActions />
        </div>
      )}
    </div>
  )
}
