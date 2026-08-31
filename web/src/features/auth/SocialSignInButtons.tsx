import { useEffect, useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { authApi, extractError } from '@/lib/api'

declare global {
  interface Window {
    google?: {
      accounts: {
        id: {
          initialize: (config: { client_id: string; callback: (response: { credential: string }) => void }) => void
          renderButton: (parent: HTMLElement, options: Record<string, unknown>) => void
        }
      }
    }
    AppleID?: {
      auth: {
        init: (config: { clientId: string; scope: string; redirectURI: string; usePopup: boolean }) => void
        signIn: () => Promise<{ authorization: { id_token: string } }>
      }
    }
  }
}

const scriptPromises = new Map<string, Promise<void>>()

function loadScript(id: string, src: string): Promise<void> {
  const cached = scriptPromises.get(id)
  if (cached) return cached

  const promise = new Promise<void>((resolve, reject) => {
    const existing = document.getElementById(id)
    if (existing) {
      resolve()
      return
    }
    const script = document.createElement('script')
    script.id = id
    script.src = src
    script.async = true
    script.onload = () => resolve()
    script.onerror = () => reject(new Error(`Failed to load ${src}`))
    document.head.appendChild(script)
  })
  scriptPromises.set(id, promise)
  return promise
}

interface Props {
  onSignedIn: (token: string, userId: string) => void
  onError: (message: string) => void
}

export function SocialSignInButtons({ onSignedIn, onError }: Props) {
  const { t } = useTranslation()
  const googleButtonRef = useRef<HTMLDivElement>(null)
  const [appleReady, setAppleReady] = useState(false)
  const appleClientId = import.meta.env.VITE_APPLE_CLIENT_ID as string | undefined
  const googleClientId = import.meta.env.VITE_GOOGLE_CLIENT_ID as string | undefined

  useEffect(() => {
    if (!googleClientId) return
    loadScript('google-identity-script', 'https://accounts.google.com/gsi/client')
      .then(() => {
        if (!window.google || !googleButtonRef.current) {
          onError(t('auth.loginFailed'))
          return
        }
        window.google.accounts.id.initialize({
          client_id: googleClientId,
          callback: async (response) => {
            try {
              const { data } = await authApi.signInWithGoogle(response.credential)
              onSignedIn(data.token, data.userId)
            } catch (err) {
              onError(extractError(err, t('auth.loginFailed')))
            }
          },
        })
        window.google.accounts.id.renderButton(googleButtonRef.current, {
          theme: 'outline',
          size: 'large',
          shape: 'pill',
          text: 'continue_with',
          width: 320,
        })
      })
      .catch(() => onError(t('auth.loginFailed')))
  }, [googleClientId, onError, onSignedIn, t])

  useEffect(() => {
    if (!appleClientId) return
    loadScript('apple-id-script', 'https://appleid.cdn-apple.com/appleauth/static/jsapi/appleid/1/en_US/appleid.auth.js')
      .then(() => {
        if (!window.AppleID) {
          onError(t('auth.loginFailed'))
          return
        }
        window.AppleID.auth.init({
          clientId: appleClientId,
          scope: 'name email',
          redirectURI: window.location.origin + '/login',
          usePopup: true,
        })
        setAppleReady(true)
      })
      .catch(() => onError(t('auth.loginFailed')))
  }, [appleClientId, onError, t])

  async function handleAppleSignIn() {
    if (!window.AppleID) return
    try {
      const res = await window.AppleID.auth.signIn()
      const { data } = await authApi.signInWithApple(res.authorization.id_token)
      onSignedIn(data.token, data.userId)
    } catch (err) {
      onError(extractError(err, t('auth.loginFailed')))
    }
  }

  if (!googleClientId && !appleClientId) return null

  return (
    <div className="space-y-3">
      <div className="flex items-center gap-3">
        <div className="h-px flex-1 bg-gray-200" />
        <span className="text-xs text-gray-400">{t('auth.orDivider')}</span>
        <div className="h-px flex-1 bg-gray-200" />
      </div>
      {googleClientId && <div ref={googleButtonRef} className="flex justify-center" />}
      {appleClientId && appleReady && (
        <button
          type="button"
          onClick={handleAppleSignIn}
          className="flex w-full items-center justify-center gap-2 rounded-full border border-gray-900 bg-black py-2.5 text-sm font-medium text-white hover:bg-gray-800"
        >
          {t('auth.continueWithApple')}
        </button>
      )}
    </div>
  )
}
