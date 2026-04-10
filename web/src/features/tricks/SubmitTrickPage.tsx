import { useState } from 'react'
import { useMutation } from '@tanstack/react-query'
import { trickSubmissionsApi, type SubmitTrickRequest } from '@/lib/api'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'

const DEFAULTS: SubmitTrickRequest = {
  name: '',
  abbreviation: '',
  crossOver: false,
  knee: false,
  motion: 1,
  difficulty: 1,
  commonLevel: 5,
}

export function SubmitTrickPage() {
  const [form, setForm] = useState(DEFAULTS)
  const [submitted, setSubmitted] = useState(false)

  function update<K extends keyof SubmitTrickRequest>(key: K, value: SubmitTrickRequest[K]) {
    setForm((prev) => ({ ...prev, [key]: value }))
  }

  const { mutate, isPending, error } = useMutation({
    mutationFn: () => trickSubmissionsApi.submit(form),
    onSuccess: () => {
      setForm(DEFAULTS)
      setSubmitted(true)
      setTimeout(() => setSubmitted(false), 3000)
    },
  })

  const errorMessage = error
    ? (error as { response?: { data?: { error?: string } } }).response?.data?.error ?? 'Submission failed.'
    : null

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Submit a Trick</h1>
        <p className="mt-1 text-sm text-gray-500">
          Suggest a new trick to be added to the library. It will be reviewed by an admin before going live.
        </p>
      </div>

      <Card className="max-w-xl">
        <CardHeader>
          <CardTitle>Trick Details</CardTitle>
          <CardDescription>Fill in all fields accurately.</CardDescription>
        </CardHeader>
        <CardContent>
          <form
            onSubmit={(e) => {
              e.preventDefault()
              mutate()
            }}
            className="space-y-5"
          >
            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-1">
                <Label>Name</Label>
                <Input
                  value={form.name}
                  onChange={(e) => update('name', e.target.value)}
                  placeholder="e.g. Crossover"
                  required
                />
              </div>
              <div className="space-y-1">
                <Label>Abbreviation</Label>
                <Input
                  value={form.abbreviation}
                  onChange={(e) => update('abbreviation', e.target.value)}
                  placeholder="e.g. CO"
                  required
                />
              </div>
              <div className="space-y-1">
                <Label>Motion</Label>
                <Input
                  type="number"
                  min={0.5}
                  max={10}
                  step={0.5}
                  value={form.motion}
                  onChange={(e) => update('motion', Number(e.target.value))}
                />
              </div>
              <div className="space-y-1">
                <Label>Difficulty (1–10)</Label>
                <Input
                  type="number"
                  min={1}
                  max={10}
                  value={form.difficulty}
                  onChange={(e) => update('difficulty', Number(e.target.value))}
                />
              </div>
              <div className="space-y-1">
                <Label>Common Level (1–10)</Label>
                <Input
                  type="number"
                  min={1}
                  max={10}
                  value={form.commonLevel}
                  onChange={(e) => update('commonLevel', Number(e.target.value))}
                />
              </div>
            </div>

            <div className="flex flex-wrap gap-4">
              <div className="flex items-center gap-2">
                <input
                  id="crossover"
                  type="checkbox"
                  checked={form.crossOver}
                  onChange={(e) => update('crossOver', e.target.checked)}
                  className="h-4 w-4 rounded border-gray-300 text-indigo-600"
                />
                <Label htmlFor="crossover">CrossOver</Label>
              </div>
              <div className="flex items-center gap-2">
                <input
                  id="knee"
                  type="checkbox"
                  checked={form.knee}
                  onChange={(e) => update('knee', e.target.checked)}
                  className="h-4 w-4 rounded border-gray-300 text-indigo-600"
                />
                <Label htmlFor="knee">Knee</Label>
              </div>
            </div>

            {errorMessage && <p className="text-sm text-red-600">{errorMessage}</p>}
            {submitted && (
              <p className="text-sm text-green-600">
                Trick submitted! It will be reviewed by an admin.
              </p>
            )}

            <Button type="submit" disabled={isPending}>
              {isPending ? 'Submitting…' : 'Submit Trick'}
            </Button>
          </form>
        </CardContent>
      </Card>
    </div>
  )
}
