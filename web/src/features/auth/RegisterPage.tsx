import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useMutation } from '@tanstack/react-query'
import { useTranslation } from 'react-i18next'
import { authApi, combosApi, extractError } from '@/lib/api'
import { setToken, getPendingCombo, clearPendingCombo } from '@/lib/auth'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { SEO } from '@/components/SEO'

export function RegisterPage() {
  const navigate = useNavigate()
  const { t } = useTranslation()
  const [email, setEmail] = useState('')
  const [userName, setUserName] = useState('')
  const [password, setPassword] = useState('')

  const { mutate, isPending, error } = useMutation({
    mutationFn: () => authApi.register(email, userName, password),
    onSuccess: async ({ data }) => {
      setToken(data.token, data.userId)
      const pending = getPendingCombo()
      if (pending) {
        try {
          await combosApi.build(pending.tricks, pending.isPublic, pending.name)
        } finally {
          clearPendingCombo()
        }
        navigate('/combos')
      } else {
        navigate('/combos/create')
      }
    },
  })

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    mutate()
  }

  const errorMessage = error ? extractError(error, t('auth.registrationFailed')) : null

  return (
    <div className="flex min-h-[70vh] items-center justify-center">
      <SEO
        title="Register — FreestyleCombo"
        description="Create a free account to generate and share freestyle football combos."
        path="/register"
      />
      <Card className="w-full max-w-sm">
        <CardHeader>
          <CardTitle>{t('auth.createAccount')}</CardTitle>
          <CardDescription>{t('auth.createAccountDesc')}</CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit} className="space-y-4">
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
            <div className="space-y-1">
              <Label htmlFor="userName">{t('auth.username')}</Label>
              <Input
                id="userName"
                type="text"
                autoComplete="username"
                value={userName}
                onChange={(e) => setUserName(e.target.value)}
                required
                minLength={3}
                maxLength={50}
              />
            </div>
            <div className="space-y-1">
              <Label htmlFor="password">{t('auth.password')}</Label>
              <Input
                id="password"
                type="password"
                autoComplete="new-password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
                minLength={6}
              />
            </div>
            {errorMessage && (
              <p className="text-sm text-red-600">{errorMessage}</p>
            )}
            <Button type="submit" className="w-full" disabled={isPending}>
              {isPending ? t('auth.creatingAccount') : t('auth.createAccount')}
            </Button>
            <p className="text-center text-sm text-gray-500">
              {t('auth.alreadyHaveAccount')}{' '}
              <Link to="/login" className="text-indigo-600 hover:underline">
                {t('auth.signIn')}
              </Link>
            </p>
          </form>
        </CardContent>
      </Card>
    </div>
  )
}
