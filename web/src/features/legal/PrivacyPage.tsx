import { useTranslation } from 'react-i18next'
import { SEO } from '@/components/SEO'

export function PrivacyPage() {
  const { t } = useTranslation()

  const sections = [1, 2, 3, 4, 5, 6, 7, 8, 9] as const

  return (
    <div className="mx-auto max-w-2xl space-y-6 p-6">
      <SEO title="Privacy Policy — FreestyleCombo" description="How FreestyleCombo collects, uses and protects your data." path="/privacy" />
      <div>
        <h1 className="text-2xl font-bold text-gray-900">{t('legal.privacy.title')}</h1>
        <p className="mt-1 text-sm text-gray-500">{t('legal.privacy.lastUpdated')}</p>
      </div>
      <p className="text-sm text-gray-700">{t('legal.privacy.intro')}</p>
      {sections.map((n) => (
        <section key={n} className="space-y-2">
          <h2 className="text-lg font-semibold text-gray-800">{t(`legal.privacy.section${n}Title`)}</h2>
          <p className="whitespace-pre-line text-sm text-gray-700">{t(`legal.privacy.section${n}Body`)}</p>
        </section>
      ))}
    </div>
  )
}
