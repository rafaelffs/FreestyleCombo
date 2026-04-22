import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useMutation } from '@tanstack/react-query'
import { authApi, combosApi, extractError } from '@/lib/api'
import { setToken, getPendingCombo, clearPendingCombo } from '@/lib/auth'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { SEO } from '@/components/SEO'

export function LoginPage() {
  const navigate = useNavigate()
  const [credential, setCredential] = useState('')
  const [password, setPassword] = useState('')

  const { mutate, isPending, error } = useMutation({
    mutationFn: () => authApi.login(credential, password),
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

  const errorMessage = error ? extractError(error, 'Login failed') : null

  return (
    <div className="flex min-h-[70vh] items-center justify-center">
      <SEO
        title="Login — FreestyleCombo"
        description="Log in to your FreestyleCombo account."
        path="/login"
      />
      <Card className="w-full max-w-sm">
        <CardHeader>
          <CardTitle>Sign in</CardTitle>
          <CardDescription>Enter your credentials to continue</CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="space-y-1">
              <Label htmlFor="credential">Email or Username</Label>
              <Input
                id="credential"
                type="text"
                autoComplete="username"
                value={credential}
                onChange={(e) => setCredential(e.target.value)}
                required
              />
            </div>
            <div className="space-y-1">
              <Label htmlFor="password">Password</Label>
              <Input
                id="password"
                type="password"
                autoComplete="current-password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
              />
            </div>
            {errorMessage && (
              <p className="text-sm text-red-600">{errorMessage}</p>
            )}
            <Button type="submit" className="w-full" disabled={isPending}>
              {isPending ? 'Signing in…' : 'Sign in'}
            </Button>
            <p className="text-center text-sm text-gray-500">
              No account?{' '}
              <Link to="/register" className="text-indigo-600 hover:underline">
                Register
              </Link>
            </p>
          </form>
        </CardContent>
      </Card>
    </div>
  )
}
