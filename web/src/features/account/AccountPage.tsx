import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { accountApi, extractError } from '@/lib/api'
import { setUserName } from '@/lib/auth'
import { SEO } from '@/components/SEO'

export function AccountPage() {
  const qc = useQueryClient()

  const { data: profile, isLoading } = useQuery({
    queryKey: ['account-profile'],
    queryFn: () => accountApi.getProfile().then((r) => r.data),
  })

  // ── Edit Profile ──────────────────────────────────────────────────────────
  const [editUserName, setEditUserName] = useState('')
  const [editEmail, setEditEmail] = useState('')
  const [profileError, setProfileError] = useState('')
  const [profileSuccess, setProfileSuccess] = useState('')

  const updateProfile = useMutation({
    mutationFn: () =>
      accountApi.updateProfile({
        userName: editUserName || undefined,
        email: editEmail || undefined,
      }),
    onSuccess: (res) => {
      setProfileSuccess('Profile updated.')
      setProfileError('')
      setEditUserName('')
      setEditEmail('')
      if (res.data.userName) setUserName(res.data.userName)
      qc.invalidateQueries({ queryKey: ['account-profile'] })
    },
    onError: (err) => {
      setProfileError(extractError(err, 'Failed to update profile.'))
      setProfileSuccess('')
    },
  })

  // ── Change Password ────────────────────────────────────────────────────────
  const [currentPw, setCurrentPw] = useState('')
  const [newPw, setNewPw] = useState('')
  const [confirmPw, setConfirmPw] = useState('')
  const [pwError, setPwError] = useState('')
  const [pwSuccess, setPwSuccess] = useState('')

  const changePassword = useMutation({
    mutationFn: () =>
      accountApi.changePassword({ currentPassword: currentPw, newPassword: newPw }),
    onSuccess: () => {
      setPwSuccess('Password changed.')
      setPwError('')
      setCurrentPw('')
      setNewPw('')
      setConfirmPw('')
    },
    onError: (err) => {
      setPwError(extractError(err, 'Failed to change password.'))
      setPwSuccess('')
    },
  })

  function handlePasswordSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (newPw !== confirmPw) {
      setPwError('New passwords do not match.')
      return
    }
    changePassword.mutate()
  }

  if (isLoading) return <p className="p-6 text-sm text-gray-500">Loading…</p>

  return (
    <div className="mx-auto max-w-xl space-y-8 p-6">
      <SEO title="My Account — FreestyleCombo" description="Manage your FreestyleCombo account settings." noIndex />
      <h1 className="text-2xl font-bold text-gray-900">My Account</h1>

      {/* Current info */}
      <div className="rounded-lg border border-gray-200 bg-white p-5">
        <h2 className="mb-4 text-lg font-semibold text-gray-800">Profile</h2>
        <div className="mb-4 space-y-1 text-sm text-gray-600">
          <p><span className="font-medium text-gray-700">Username:</span> {profile?.userName}</p>
          <p><span className="font-medium text-gray-700">Email:</span> {profile?.email}</p>
        </div>

        <form
          onSubmit={(e) => { e.preventDefault(); updateProfile.mutate() }}
          className="space-y-3"
        >
          <div>
            <label className="mb-1 block text-sm font-medium text-gray-700">New username</label>
            <input
              type="text"
              value={editUserName}
              onChange={(e) => setEditUserName(e.target.value)}
              placeholder={profile?.userName}
              className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
          </div>
          <div>
            <label className="mb-1 block text-sm font-medium text-gray-700">New email</label>
            <input
              type="email"
              value={editEmail}
              onChange={(e) => setEditEmail(e.target.value)}
              placeholder={profile?.email}
              className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
          </div>
          {profileError && <p className="text-sm text-red-600">{profileError}</p>}
          {profileSuccess && <p className="text-sm text-green-600">{profileSuccess}</p>}
          <button
            type="submit"
            disabled={updateProfile.isPending || (!editUserName && !editEmail)}
            className="rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700 disabled:opacity-50"
          >
            {updateProfile.isPending ? 'Saving…' : 'Save changes'}
          </button>
        </form>
      </div>

      {/* Change Password */}
      <div className="rounded-lg border border-gray-200 bg-white p-5">
        <h2 className="mb-4 text-lg font-semibold text-gray-800">Change Password</h2>
        <form onSubmit={handlePasswordSubmit} className="space-y-3">
          <div>
            <label className="mb-1 block text-sm font-medium text-gray-700">Current password</label>
            <input
              type="password"
              value={currentPw}
              onChange={(e) => setCurrentPw(e.target.value)}
              required
              className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
          </div>
          <div>
            <label className="mb-1 block text-sm font-medium text-gray-700">New password</label>
            <input
              type="password"
              value={newPw}
              onChange={(e) => setNewPw(e.target.value)}
              required
              minLength={6}
              className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
          </div>
          <div>
            <label className="mb-1 block text-sm font-medium text-gray-700">Confirm new password</label>
            <input
              type="password"
              value={confirmPw}
              onChange={(e) => setConfirmPw(e.target.value)}
              required
              className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
          </div>
          {pwError && <p className="text-sm text-red-600">{pwError}</p>}
          {pwSuccess && <p className="text-sm text-green-600">{pwSuccess}</p>}
          <button
            type="submit"
            disabled={changePassword.isPending}
            className="rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700 disabled:opacity-50"
          >
            {changePassword.isPending ? 'Changing…' : 'Change password'}
          </button>
        </form>
      </div>
    </div>
  )
}
