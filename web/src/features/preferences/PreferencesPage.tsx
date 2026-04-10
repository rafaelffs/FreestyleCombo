import { useEffect, useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { preferencesApi, extractError, type UserPreference } from '@/lib/api'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'

const DEFAULTS: Omit<UserPreference, 'id' | 'userId'> = {
  comboLength: 5,
  maxDifficulty: 10,
  strongFootPercentage: 50,
  noTouchPercentage: 30,
  maxConsecutiveNoTouch: 2,
  includeCrossOver: true,
  includeKnee: true,
  allowedMotions: [],
}

export function PreferencesPage() {
  const queryClient = useQueryClient()
  const [form, setForm] = useState(DEFAULTS)
  const [saved, setSaved] = useState(false)

  const { data, isLoading } = useQuery({
    queryKey: ['preferences'],
    queryFn: () =>
      preferencesApi.get().then((r) => r.data).catch(() => null),
  })

  useEffect(() => {
    if (data) {
      const { id: _id, userId: _uid, ...rest } = data
      setForm(rest)
    }
  }, [data])

  const { mutate, isPending, error } = useMutation({
    mutationFn: () => preferencesApi.upsert(form),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['preferences'] })
      setSaved(true)
      setTimeout(() => setSaved(false), 2000)
    },
  })

  function update<K extends keyof typeof form>(key: K, value: (typeof form)[K]) {
    setForm((prev) => ({ ...prev, [key]: value }))
  }

  const errorMessage = error ? extractError(error, 'Save failed') : null

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Preferences</h1>
        <p className="mt-1 text-sm text-gray-500">
          Your default settings when generating combos with "Use my saved preferences".
        </p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Combo Settings</CardTitle>
          <CardDescription>These are applied when you generate with saved preferences.</CardDescription>
        </CardHeader>
        <CardContent>
          {isLoading ? (
            <p className="text-gray-500">Loading…</p>
          ) : (
            <form
              onSubmit={(e) => {
                e.preventDefault()
                mutate()
              }}
              className="space-y-5"
            >
              <div className="grid grid-cols-2 gap-4 sm:grid-cols-3">
                <div className="space-y-1">
                  <Label>Combo Length</Label>
                  <Input
                    type="number"
                    min={1}
                    max={100}
                    value={form.comboLength}
                    onChange={(e) => update('comboLength', Number(e.target.value))}
                  />
                </div>
                <div className="space-y-1">
                  <Label>Max Difficulty</Label>
                  <Input
                    type="number"
                    min={1}
                    max={10}
                    value={form.maxDifficulty}
                    onChange={(e) => update('maxDifficulty', Number(e.target.value))}
                  />
                </div>
                <div className="space-y-1">
                  <Label>Strong Foot %</Label>
                  <Input
                    type="number"
                    min={0}
                    max={100}
                    value={form.strongFootPercentage}
                    onChange={(e) => update('strongFootPercentage', Number(e.target.value))}
                  />
                </div>
                <div className="space-y-1">
                  <Label>No-Touch %</Label>
                  <Input
                    type="number"
                    min={0}
                    max={100}
                    value={form.noTouchPercentage}
                    onChange={(e) => update('noTouchPercentage', Number(e.target.value))}
                  />
                </div>
                <div className="space-y-1">
                  <Label>Max Consecutive NT</Label>
                  <Input
                    type="number"
                    min={0}
                    max={30}
                    value={form.maxConsecutiveNoTouch}
                    onChange={(e) => update('maxConsecutiveNoTouch', Number(e.target.value))}
                  />
                </div>
              </div>

              <div className="flex flex-wrap gap-4">
                <div className="flex items-center gap-2">
                  <input
                    id="crossover"
                    type="checkbox"
                    checked={form.includeCrossOver}
                    onChange={(e) => update('includeCrossOver', e.target.checked)}
                    className="h-4 w-4 rounded border-gray-300 text-indigo-600"
                  />
                  <Label htmlFor="crossover">Include Crossover</Label>
                </div>
                <div className="flex items-center gap-2">
                  <input
                    id="knee"
                    type="checkbox"
                    checked={form.includeKnee}
                    onChange={(e) => update('includeKnee', e.target.checked)}
                    className="h-4 w-4 rounded border-gray-300 text-indigo-600"
                  />
                  <Label htmlFor="knee">Include Knee</Label>
                </div>
              </div>

              {errorMessage && <p className="text-sm text-red-600">{errorMessage}</p>}
              {saved && <p className="text-sm text-green-600">Preferences saved!</p>}

              <Button type="submit" disabled={isPending}>
                {isPending ? 'Saving…' : 'Save preferences'}
              </Button>
            </form>
          )}
        </CardContent>
      </Card>
    </div>
  )
}
