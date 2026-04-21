import { Helmet } from 'react-helmet-async'

const SITE_URL = import.meta.env.VITE_SITE_URL ?? 'https://fscombo.com'
const SITE_NAME = 'FreestyleCombo'
const DEFAULT_OG_IMAGE = `${SITE_URL}/og-image.svg`

interface SEOProps {
  title: string
  description: string
  path?: string
  image?: string
  noIndex?: boolean
}

export function SEO({ title, description, path, image, noIndex }: SEOProps) {
  const canonical = path ? `${SITE_URL}${path}` : undefined
  const ogImage = image ?? DEFAULT_OG_IMAGE

  return (
    <Helmet>
      <title>{title}</title>
      <meta name="description" content={description} />
      {noIndex && <meta name="robots" content="noindex,nofollow" />}
      {canonical && <link rel="canonical" href={canonical} />}
      <meta property="og:title" content={title} />
      <meta property="og:description" content={description} />
      <meta property="og:site_name" content={SITE_NAME} />
      <meta property="og:image" content={ogImage} />
      {canonical && <meta property="og:url" content={canonical} />}
      <meta name="twitter:card" content="summary_large_image" />
      <meta name="twitter:title" content={title} />
      <meta name="twitter:description" content={description} />
      <meta name="twitter:image" content={ogImage} />
    </Helmet>
  )
}
