import { useTranslation } from 'react-i18next'
import { SEO } from '@/components/SEO'

const SUPPORT_EMAIL = 'ffs.rafael@gmail.com'

export function SupportPage() {
  const { t } = useTranslation()

  const faqs = [1, 2, 3] as const

  return (
    <div className="mx-auto max-w-2xl space-y-6 p-6">
      <SEO title="Support — FreestyleCombo" description="Get help with FreestyleCombo." path="/support" />
      <div>
        <h1 className="text-2xl font-bold text-gray-900">{t('legal.support.title')}</h1>
        <p className="mt-1 text-sm text-gray-500">{t('legal.support.intro')}</p>
      </div>
      <a
        href={`mailto:${SUPPORT_EMAIL}`}
        className="inline-block rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700"
      >
        {t('legal.support.emailCta', { email: SUPPORT_EMAIL })}
      </a>
      <div className="space-y-4 pt-2">
        {faqs.map((n) => (
          <section key={n} className="space-y-1">
            <h2 className="text-base font-semibold text-gray-800">{t(`legal.support.faq${n}Question`)}</h2>
            <p className="text-sm text-gray-700">{t(`legal.support.faq${n}Answer`)}</p>
          </section>
        ))}
      </div>
    </div>
  )
}
