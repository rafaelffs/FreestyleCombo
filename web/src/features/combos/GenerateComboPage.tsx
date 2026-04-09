import { useState } from 'react'
import { useMutation } from '@tanstack/react-query'
import { combosApi, type ComboDto, type GenerateComboOverrides } from '@/lib/api'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { ComboCard } from './ComboCard'

const DEFAULTS: GenerateComboOverrides = {
  comboLength: 5,
  maxDifficulty: 10,
  strongFootPercentage: 50,
  noTouchPercentage: 30,
  maxConsecutiveNoTouch: 2,
  includeCrossOver: true,
  includeKnee: true,
}

export function GenerateComboPage() {
  const [usePrefs, setUsePrefs] = useState(false)
  const [overrides, setOverrides] = useState<GenerateComboOverrides>(DEFAULTS)
  const [result, setResult] = useState<ComboDto | null>(null)

  const { mutate, isPending, error } = useMutation({
    mutationFn: () => combosApi.generate(usePrefs, usePrefs ? undefined : overrides),
    onSuccess: ({ data }) => setResult(data),
  })

  function update<K extends keyof GenerateComboOverrides>(key: K, value: GenerateComboOverrides[K]) {
    setOverrides((prev) => ({ ...prev, [key]: value }))
  }

  const errorMessage = error
    ? (error as { response?: { data?: { message?: string } } }).response?.data?.message ?? 'Generation failed'
    : null

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Generate Combo</h1>
        <p className="mt-1 text-sm text-gray-500">Build a freestyle football combo based on your settings.</p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Options</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="flex items-center gap-3">
            <input
              id="usePrefs"
              type="checkbox"
              checked={usePrefs}
              onChange={(e) => setUsePrefs(e.target.checked)}
              className="h-4 w-4 rounded border-gray-300 text-indigo-600"
            />
            <Label htmlFor="usePrefs">Use my saved preferences</Label>
          </div>

          {!usePrefs && (
            <div className="grid grid-cols-2 gap-4 sm:grid-cols-3">
              <div className="space-y-1">
                <Label>Combo Length</Label>
                <Input
                  type="number"
                  min={1}
                  max={20}
                  value={overrides.comboLength}
                  onChange={(e) => update('comboLength', Number(e.target.value))}
                />
              </div>
              <div className="space-y-1">
                <Label>Max Difficulty</Label>
                <Input
                  type="number"
                  min={1}
                  max={10}
                  value={overrides.maxDifficulty}
                  onChange={(e) => update('maxDifficulty', Number(e.target.value))}
                />
              </div>
              <div className="space-y-1">
                <Label>Strong Foot %</Label>
                <Input
                  type="number"
                  min={0}
                  max={100}
                  value={overrides.strongFootPercentage}
                  onChange={(e) => update('strongFootPercentage', Number(e.target.value))}
                />
              </div>
              <div className="space-y-1">
                <Label>No-Touch %</Label>
                <Input
                  type="number"
                  min={0}
                  max={100}
                  value={overrides.noTouchPercentage}
                  onChange={(e) => update('noTouchPercentage', Number(e.target.value))}
                />
              </div>
              <div className="space-y-1">
                <Label>Max Consecutive NT</Label>
                <Input
                  type="number"
                  min={0}
                  max={10}
                  value={overrides.maxConsecutiveNoTouch}
                  onChange={(e) => update('maxConsecutiveNoTouch', Number(e.target.value))}
                />
              </div>
              <div className="flex flex-col gap-2 pt-1">
                <div className="flex items-center gap-2">
                  <input
                    id="crossover"
                    type="checkbox"
                    checked={overrides.includeCrossOver}
                    onChange={(e) => update('includeCrossOver', e.target.checked)}
                    className="h-4 w-4 rounded border-gray-300 text-indigo-600"
                  />
                  <Label htmlFor="crossover">Include Crossover</Label>
                </div>
                <div className="flex items-center gap-2">
                  <input
                    id="knee"
                    type="checkbox"
                    checked={overrides.includeKnee}
                    onChange={(e) => update('includeKnee', e.target.checked)}
                    className="h-4 w-4 rounded border-gray-300 text-indigo-600"
                  />
                  <Label htmlFor="knee">Include Knee</Label>
                </div>
              </div>
            </div>
          )}

          {errorMessage && <p className="text-sm text-red-600">{errorMessage}</p>}

          <Button onClick={() => mutate()} disabled={isPending} className="w-full sm:w-auto">
            {isPending ? 'Generating…' : 'Generate Combo'}
          </Button>
        </CardContent>
      </Card>

      {result && (
        <div className="space-y-3">
          <div className="flex items-center gap-2">
            <h2 className="text-lg font-semibold">Result</h2>
            <Badge variant="secondary">{result.trickCount} tricks</Badge>
          </div>
          <ComboCard combo={result} showActions />
        </div>
      )}
    </div>
  )
}
