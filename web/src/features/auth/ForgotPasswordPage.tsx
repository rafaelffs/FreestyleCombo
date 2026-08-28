import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useMutation } from '@tanstack/react-query'
import { useTranslation } from 'react-i18next'
import { authApi, extractError } from '@/lib/api'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { SEO } from '@/components/SEO'

export function ForgotPasswordPage() {
  const navigate = useNavigate()
  const { t } = useTranslation()
  const [step, setStep] = useState<'request' | 'reset'>('request')
  const [email, setEmail] = useState('')
  const [code, setCode] = useState('')
  const [newPassword, setNewPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [confirmError, setConfirmError] = useState('')

  const requestCode = useMutation({
    mutationFn: () => authApi.forgotPassword(email),
    onSuccess: () => setStep('reset'),
  })

  const resetPassword = useMutation({
    mutationFn: () => authApi.resetPassword(email, code, newPassword),
    onSuccess: () => navigate('/login'),
  })

  function handleRequestSubmit(e: React.FormEvent) {
    e.preventDefault()
    requestCode.mutate()
  }

  function handleResetSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (newPassword !== confirmPassword) {
      setConfirmError(t('auth.passwordMismatch'))
      return
    }
    setConfirmError('')
    resetPassword.mutate()
  }

  const requestError = requestCode.error ? extractError(requestCode.error, t('auth.forgotPasswordFailed')) : null
  const resetError = resetPassword.error ? extractError(resetPassword.error, t('auth.resetPasswordFailed')) : null

  return (
    <div className="flex min-h-[70vh] items-center justify-center">
      <SEO
        title="Forgot Password — FreestyleCombo"
        description="Reset your FreestyleCombo password."
        path="/forgot-password"
        noIndex
      />
      <Card className="w-full max-w-sm">
        <CardHeader>
          <CardTitle>{t('auth.forgotPasswordTitle')}</CardTitle>
          <CardDescription>
            {step === 'request' ? t('auth.forgotPasswordDesc') : t('auth.resetPasswordDesc')}
          </CardDescription>
        </CardHeader>
        <CardContent>
          {step === 'request' ? (
            <form onSubmit={handleRequestSubmit} className="space-y-4">
              <div className="space-y-1">
                <Label htmlFor="email">{t('auth.email')}</Label>
                <Input
                  id="email"
                  type="email"
                  autoComplete="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  required
                />
              </div>
              {requestError && <p className="text-sm text-red-600">{requestError}</p>}
              <Button type="submit" className="w-full" disabled={requestCode.isPending}>
                {requestCode.isPending ? t('auth.sendingCode') : t('auth.sendCode')}
              </Button>
              <p className="text-center text-sm text-gray-500">
                <Link to="/login" className="text-indigo-600 hover:underline">
                  {t('auth.backToSignIn')}
                </Link>
              </p>
            </form>
          ) : (
            <form onSubmit={handleResetSubmit} className="space-y-4">
              <p className="text-sm text-gray-500">{t('auth.codeSentTo', { email })}</p>
              <div className="space-y-1">
                <Label htmlFor="code">{t('auth.resetCode')}</Label>
                <Input
                  id="code"
                  type="text"
                  inputMode="numeric"
                  maxLength={6}
                  value={code}
                  onChange={(e) => setCode(e.target.value)}
                  required
                />
              </div>
              <div className="space-y-1">
                <Label htmlFor="newPassword">{t('auth.newPassword')}</Label>
                <Input
                  id="newPassword"
                  type="password"
                  autoComplete="new-password"
                  minLength={6}
                  value={newPassword}
                  onChange={(e) => setNewPassword(e.target.value)}
                  required
                />
              </div>
              <div className="space-y-1">
                <Label htmlFor="confirmPassword">{t('auth.confirmNewPassword')}</Label>
                <Input
                  id="confirmPassword"
                  type="password"
                  autoComplete="new-password"
                  value={confirmPassword}
                  onChange={(e) => setConfirmPassword(e.target.value)}
                  required
                />
              </div>
              {confirmError && <p className="text-sm text-red-600">{confirmError}</p>}
              {resetError && <p className="text-sm text-red-600">{resetError}</p>}
              <Button type="submit" className="w-full" disabled={resetPassword.isPending}>
                {resetPassword.isPending ? t('auth.resettingPassword') : t('auth.resetPassword')}
              </Button>
              <p className="text-center text-sm text-gray-500">
                <button
                  type="button"
                  onClick={() => setStep('request')}
                  className="text-indigo-600 hover:underline"
                >
                  {t('auth.resendCode')}
                </button>
              </p>
            </form>
          )}
        </CardContent>
      </Card>
    </div>
  )
}
