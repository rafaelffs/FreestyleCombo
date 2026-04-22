import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { useTranslation } from 'react-i18next'
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
  const { t } = useTranslation()

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
        <Label>{t('preferences.fieldName')}</Label>
        <Input
          required
          maxLength={100}
          placeholder={t('preferences.fieldNamePlaceholder')}
          value={form.name}
          onChange={(e) => update('name', e.target.value)}
        />
      </div>

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 md:grid-cols-3">
        <div className="space-y-1">
          <Label>{t('preferences.comboLength')}</Label>
          <Input type="number" min={1} max={100} value={form.comboLength} onChange={(e) => update('comboLength', Number(e.target.value))} />
        </div>
        <div className="space-y-1">
          <Label>{t('preferences.maxDifficulty')}</Label>
          <Input type="number" min={1} max={10} value={form.maxDifficulty} onChange={(e) => update('maxDifficulty', Number(e.target.value))} />
        </div>
        <div className="space-y-1">
          <Label>{t('preferences.strongFootPct')}</Label>
          <Input type="number" min={0} max={100} value={form.strongFootPercentage} onChange={(e) => update('strongFootPercentage', Number(e.target.value))} />
        </div>
        <div className="space-y-1">
          <Label>{t('preferences.noTouchPct')}</Label>
          <Input type="number" min={0} max={100} value={form.noTouchPercentage} onChange={(e) => update('noTouchPercentage', Number(e.target.value))} />
        </div>
        <div className="space-y-1">
          <Label>{t('preferences.maxConsecutiveNT')}</Label>
          <Input type="number" min={0} max={30} value={form.maxConsecutiveNoTouch} onChange={(e) => update('maxConsecutiveNoTouch', Number(e.target.value))} />
        </div>
      </div>

      <div className="flex flex-wrap gap-4">
        <div className="flex items-center gap-2">
          <input id="pf-crossover" type="checkbox" checked={form.includeCrossOver} onChange={(e) => update('includeCrossOver', e.target.checked)} className="h-4 w-4 rounded border-gray-300 text-indigo-600" />
          <Label htmlFor="pf-crossover">{t('preferences.includeCrossover')}</Label>
        </div>
        <div className="flex items-center gap-2">
          <input id="pf-knee" type="checkbox" checked={form.includeKnee} onChange={(e) => update('includeKnee', e.target.checked)} className="h-4 w-4 rounded border-gray-300 text-indigo-600" />
          <Label htmlFor="pf-knee">{t('preferences.includeKnee')}</Label>
        </div>
      </div>

      {error && <p className="text-sm text-red-600">{error}</p>}

      <div className="flex gap-2">
        <Button type="submit" disabled={isPending}>
          {isPending ? t('common.saving') : t('common.save')}
        </Button>
        <Button type="button" variant="ghost" onClick={onCancel}>
          {t('common.cancel')}
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
  const { t } = useTranslation()

  const updateMutation = useMutation({
    mutationFn: (payload: PreferencePayload) => preferencesApi.update(pref.id, payload),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['preferences'] })
      setEditing(false)
    },
  })

  const updateError = updateMutation.error ? extractError(updateMutation.error, t('preferences.saveFailed')) : null

  const stats = t('preferences.stats', {
    length: pref.comboLength,
    maxDiff: pref.maxDifficulty,
    sf: pref.strongFootPercentage,
    nt: pref.noTouchPercentage,
  })

  if (editing) {
    return (
      <Card>
        <CardHeader>
          <CardTitle className="text-base">{t('preferences.editPrefTitle')}</CardTitle>
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
            {pref.includeCrossOver ? 'CO ✓' : 'CO ✗'} · {pref.includeKnee ? `${t('preferences.kneeLabel')} ✓` : `${t('preferences.kneeLabel')} ✗`} · {t('preferences.maxConsecLabel')} {pref.maxConsecutiveNoTouch}
          </p>
        </div>
        <div className="flex shrink-0 gap-2">
          <Button variant="ghost" size="sm" onClick={() => setEditing(true)}>
            {t('common.edit')}
          </Button>
          {deleteConfirm ? (
            <div className="flex gap-1">
              <Button variant="destructive" size="sm" onClick={() => onDelete(pref.id)}>
                {t('preferences.confirmDelete')}
              </Button>
              <Button variant="ghost" size="sm" onClick={() => setDeleteConfirm(false)}>
                {t('common.no')}
              </Button>
            </div>
          ) : (
            <Button variant="ghost" size="sm" className="text-red-600 hover:text-red-700" onClick={() => setDeleteConfirm(true)}>
              {t('common.delete')}
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
  const { t } = useTranslation()

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

  const createError = createMutation.error ? extractError(createMutation.error, t('preferences.createFailed')) : null

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">{t('preferences.pageTitle')}</h1>
        <p className="mt-1 text-sm text-gray-500">
          {t('preferences.pageSubtitle')}
        </p>
      </div>

      {/* FAB */}
      <button
        type="button"
        onClick={() => setCreating((v) => !v)}
        className="fixed bottom-6 right-6 z-40 inline-flex h-14 cursor-pointer items-center gap-2 rounded-full bg-indigo-600 px-5 text-sm font-semibold text-white shadow-lg transition-colors hover:bg-indigo-700 active:bg-indigo-800"
      >
        <span className="text-lg leading-none">{creating ? '✕' : '+'}</span>
        {creating ? t('common.cancel') : t('preferences.fabNew')}
      </button>

      {creating && (
        <Card>
          <CardHeader>
            <CardTitle className="text-base">{t('preferences.newPrefTitle')}</CardTitle>
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
        <p className="text-gray-500">{t('common.loading')}</p>
      ) : prefs.length === 0 && !creating ? (
        <p className="text-sm text-gray-400">{t('preferences.noneYet')}</p>
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
