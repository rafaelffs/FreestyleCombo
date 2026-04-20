import { Helmet } from 'react-helmet-async'

const SITE_URL = import.meta.env.VITE_SITE_URL ?? 'https://freestylecombo.com'
const SITE_NAME = 'FreestyleCombo'

interface SEOProps {
  title: string
  description: string
  path?: string
  noIndex?: boolean
}

export function SEO({ title, description, path, noIndex }: SEOProps) {
  const canonical = path ? `${SITE_URL}${path}` : undefined

  return (
    <Helmet>
      <title>{title}</title>
      <meta name="description" content={description} />
      {noIndex && <meta name="robots" content="noindex,nofollow" />}
      {canonical && <link rel="canonical" href={canonical} />}
      <meta property="og:title" content={title} />
      <meta property="og:description" content={description} />
      <meta property="og:site_name" content={SITE_NAME} />
      {canonical && <meta property="og:url" content={canonical} />}
      <meta name="twitter:title" content={title} />
      <meta name="twitter:description" content={description} />
    </Helmet>
  )
}
