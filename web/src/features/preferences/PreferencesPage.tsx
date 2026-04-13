import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { preferencesApi, extractError, type UserPreference, type PreferencePayload } from '@/lib/api'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'

const DEFAULTS: PreferencePayload = {
  name: '',
  comboLength: 6,
  maxDifficulty: 10,
  strongFootPercentage: 60,
  noTouchPercentage: 30,
  maxConsecutiveNoTouch: 2,
  includeCrossOver: true,
  includeKnee: true,
  allowedRevolutions: [],
}

function PreferenceForm({
  initial,
  onSave,
  onCancel,
  isPending,
  error,
}: {
  initial: PreferencePayload
  onSave: (p: PreferencePayload) => void
  onCancel: () => void
  isPending: boolean
  error: string | null
}) {
  const [form, setForm] = useState<PreferencePayload>(initial)

  function update<K extends keyof PreferencePayload>(key: K, value: PreferencePayload[K]) {
    setForm((prev) => ({ ...prev, [key]: value }))
  }

  return (
    <form
      onSubmit={(e) => {
        e.preventDefault()
        onSave(form)
      }}
      className="space-y-4"
    >
      <div className="space-y-1">
        <Label>Name</Label>
        <Input
          required
          maxLength={100}
          placeholder="e.g. NT Combinations"
          value={form.name}
          onChange={(e) => update('name', e.target.value)}
        />
      </div>

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 md:grid-cols-3">
        <div className="space-y-1">
          <Label>Combo Length</Label>
          <Input type="number" min={1} max={100} value={form.comboLength} onChange={(e) => update('comboLength', Number(e.target.value))} />
        </div>
        <div className="space-y-1">
          <Label>Max Difficulty</Label>
          <Input type="number" min={1} max={10} value={form.maxDifficulty} onChange={(e) => update('maxDifficulty', Number(e.target.value))} />
        </div>
        <div className="space-y-1">
          <Label>Strong Foot %</Label>
          <Input type="number" min={0} max={100} value={form.strongFootPercentage} onChange={(e) => update('strongFootPercentage', Number(e.target.value))} />
        </div>
        <div className="space-y-1">
          <Label>No-Touch %</Label>
          <Input type="number" min={0} max={100} value={form.noTouchPercentage} onChange={(e) => update('noTouchPercentage', Number(e.target.value))} />
        </div>
        <div className="space-y-1">
          <Label>Max Consecutive NT</Label>
          <Input type="number" min={0} max={30} value={form.maxConsecutiveNoTouch} onChange={(e) => update('maxConsecutiveNoTouch', Number(e.target.value))} />
        </div>
      </div>

      <div className="flex flex-wrap gap-4">
        <div className="flex items-center gap-2">
          <input id="pf-crossover" type="checkbox" checked={form.includeCrossOver} onChange={(e) => update('includeCrossOver', e.target.checked)} className="h-4 w-4 rounded border-gray-300 text-indigo-600" />
          <Label htmlFor="pf-crossover">Include Crossover</Label>
        </div>
        <div className="flex items-center gap-2">
          <input id="pf-knee" type="checkbox" checked={form.includeKnee} onChange={(e) => update('includeKnee', e.target.checked)} className="h-4 w-4 rounded border-gray-300 text-indigo-600" />
          <Label htmlFor="pf-knee">Include Knee</Label>
        </div>
      </div>

      {error && <p className="text-sm text-red-600">{error}</p>}

      <div className="flex gap-2">
        <Button type="submit" disabled={isPending}>
          {isPending ? 'Saving…' : 'Save'}
        </Button>
        <Button type="button" variant="ghost" onClick={onCancel}>
          Cancel
        </Button>
      </div>
    </form>
  )
}

function PreferenceCard({
  pref,
  onDelete,
}: {
  pref: UserPreference
  onDelete: (id: string) => void
}) {
  const [editing, setEditing] = useState(false)
  const [deleteConfirm, setDeleteConfirm] = useState(false)
  const queryClient = useQueryClient()

  const updateMutation = useMutation({
    mutationFn: (payload: PreferencePayload) => preferencesApi.update(pref.id, payload),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['preferences'] })
      setEditing(false)
    },
  })

  const updateError = updateMutation.error ? extractError(updateMutation.error, 'Save failed') : null

  const stats = `Length ${pref.comboLength} · Diff ≤${pref.maxDifficulty} · SF ${pref.strongFootPercentage}% · NT ${pref.noTouchPercentage}%`

  if (editing) {
    return (
      <Card>
        <CardHeader>
          <CardTitle className="text-base">Edit preference</CardTitle>
        </CardHeader>
        <CardContent>
          <PreferenceForm
            initial={{ name: pref.name, comboLength: pref.comboLength, maxDifficulty: pref.maxDifficulty, strongFootPercentage: pref.strongFootPercentage, noTouchPercentage: pref.noTouchPercentage, maxConsecutiveNoTouch: pref.maxConsecutiveNoTouch, includeCrossOver: pref.includeCrossOver, includeKnee: pref.includeKnee, allowedRevolutions: pref.allowedRevolutions }}
            onSave={(p) => updateMutation.mutate(p)}
            onCancel={() => setEditing(false)}
            isPending={updateMutation.isPending}
            error={updateError}
          />
        </CardContent>
      </Card>
    )
  }

  return (
    <Card>
      <CardContent className="flex items-start justify-between gap-4 pt-4">
        <div className="min-w-0 flex-1">
          <p className="font-semibold text-gray-900">{pref.name}</p>
          <p className="mt-0.5 text-xs text-gray-500">{stats}</p>
          <p className="mt-0.5 text-xs text-gray-400">
            {pref.includeCrossOver ? 'CO ✓' : 'CO ✗'} · {pref.includeKnee ? 'Knee ✓' : 'Knee ✗'} · Max consec NT {pref.maxConsecutiveNoTouch}
          </p>
        </div>
        <div className="flex shrink-0 gap-2">
          <Button variant="ghost" size="sm" onClick={() => setEditing(true)}>
            Edit
          </Button>
          {deleteConfirm ? (
            <div className="flex gap-1">
              <Button variant="destructive" size="sm" onClick={() => onDelete(pref.id)}>
                Confirm
              </Button>
              <Button variant="ghost" size="sm" onClick={() => setDeleteConfirm(false)}>
                No
              </Button>
            </div>
          ) : (
            <Button variant="ghost" size="sm" className="text-red-600 hover:text-red-700" onClick={() => setDeleteConfirm(true)}>
              Delete
            </Button>
          )}
        </div>
      </CardContent>
    </Card>
  )
}

export function PreferencesPage() {
  const queryClient = useQueryClient()
  const [creating, setCreating] = useState(false)

  const { data: prefs = [], isLoading } = useQuery({
    queryKey: ['preferences'],
    queryFn: () => preferencesApi.getAll().then((r) => r.data),
  })

  const createMutation = useMutation({
    mutationFn: (payload: PreferencePayload) => preferencesApi.create(payload),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['preferences'] })
      setCreating(false)
    },
  })

  const deleteMutation = useMutation({
    mutationFn: (id: string) => preferencesApi.remove(id),
    onSuccess: () => void queryClient.invalidateQueries({ queryKey: ['preferences'] }),
  })

  const createError = createMutation.error ? extractError(createMutation.error, 'Create failed') : null

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Preferences</h1>
          <p className="mt-1 text-sm text-gray-500">
            Save named preference presets to quickly apply when generating combos.
          </p>
        </div>
        {!creating && (
          <Button onClick={() => setCreating(true)}>+ New preference</Button>
        )}
      </div>

      {creating && (
        <Card>
          <CardHeader>
            <CardTitle className="text-base">New preference</CardTitle>
          </CardHeader>
          <CardContent>
            <PreferenceForm
              initial={DEFAULTS}
              onSave={(p) => createMutation.mutate(p)}
              onCancel={() => setCreating(false)}
              isPending={createMutation.isPending}
              error={createError}
            />
          </CardContent>
        </Card>
      )}

      {isLoading ? (
        <p className="text-gray-500">Loading…</p>
      ) : prefs.length === 0 && !creating ? (
        <p className="text-sm text-gray-400">No preferences saved yet. Create one to get started.</p>
      ) : (
        <div className="space-y-3">
          {prefs.map((pref) => (
            <PreferenceCard
              key={pref.id}
              pref={pref}
              onDelete={(id) => deleteMutation.mutate(id)}
            />
          ))}
        </div>
      )}
    </div>
  )
}
