import { useTranslation } from 'react-i18next'
import { SEO } from '@/components/SEO'

export function TermsPage() {
  const { t } = useTranslation()

  const sections = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10] as const

  return (
    <div className="mx-auto max-w-2xl space-y-6 p-6">
      <SEO title="Terms of Service — FreestyleCombo" description="The terms that govern your use of FreestyleCombo." path="/terms" />
      <div>
        <h1 className="text-2xl font-bold text-gray-900">{t('legal.terms.title')}</h1>
        <p className="mt-1 text-sm text-gray-500">{t('legal.terms.lastUpdated')}</p>
      </div>
      <p className="text-sm text-gray-700">{t('legal.terms.intro')}</p>
      {sections.map((n) => (
        <section key={n} className="space-y-2">
          <h2 className="text-lg font-semibold text-gray-800">{t(`legal.terms.section${n}Title`)}</h2>
          <p className="whitespace-pre-line text-sm text-gray-700">{t(`legal.terms.section${n}Body`)}</p>
        </section>
      ))}
    </div>
  )
}
