import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Pencil, KeyRound, ShieldCheck, ShieldOff, Trash2 } from 'lucide-react'
import { useTranslation } from 'react-i18next'
import { adminApi, extractError, type AdminUserDto } from '@/lib/api'
import { getUserId } from '@/lib/auth'

function RoleBadge({ isAdmin }: { isAdmin: boolean }) {
  const { t } = useTranslation()
  return isAdmin ? (
    <span className="inline-flex items-center rounded-full bg-indigo-100 px-2 py-0.5 text-xs font-medium text-indigo-700">
      {t('adminUsers.roleAdmin')}
    </span>
  ) : (
    <span className="text-gray-400 text-xs">{t('adminUsers.roleUser')}</span>
  )
}

export function AdminUsersPage() {
  const qc = useQueryClient()
  const currentUserId = getUserId()
  const { t } = useTranslation()

  const { data: users, isLoading } = useQuery({
    queryKey: ['admin-users'],
    queryFn: () => adminApi.getUsers().then((r) => r.data),
  })

  const [editingId, setEditingId] = useState<string | null>(null)
  const [editUserName, setEditUserName] = useState('')
  const [editEmail, setEditEmail] = useState('')
  const [editError, setEditError] = useState('')

  const [resetId, setResetId] = useState<string | null>(null)
  const [resetPw, setResetPw] = useState('')
  const [resetError, setResetError] = useState('')

  const [deleteId, setDeleteId] = useState<string | null>(null)
  const [deleteError, setDeleteError] = useState('')

  function startEdit(user: AdminUserDto) {
    setEditingId(user.id)
    setEditUserName(user.userName)
    setEditEmail(user.email)
    setEditError('')
  }

  const updateUser = useMutation({
    mutationFn: (id: string) =>
      adminApi.updateUser(id, { userName: editUserName, email: editEmail }),
    onSuccess: () => {
      setEditingId(null)
      qc.invalidateQueries({ queryKey: ['admin-users'] })
    },
    onError: (err) => setEditError(extractError(err, t('adminUsers.failedUpdate'))),
  })

  const resetPassword = useMutation({
    mutationFn: (id: string) => adminApi.resetUserPassword(id, resetPw),
    onSuccess: () => {
      setResetId(null)
      setResetPw('')
      setResetError('')
    },
    onError: (err) => setResetError(extractError(err, t('adminUsers.failedResetPw'))),
  })

  const toggleRole = useMutation({
    mutationFn: ({ id, isAdmin }: { id: string; isAdmin: boolean }) =>
      adminApi.updateUserRole(id, isAdmin),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['admin-users'] }),
  })

  const deleteUser = useMutation({
    mutationFn: (id: string) => adminApi.deleteUser(id),
    onSuccess: () => {
      setDeleteId(null)
      setDeleteError('')
      qc.invalidateQueries({ queryKey: ['admin-users'] })
    },
    onError: (err) => setDeleteError(extractError(err, t('adminUsers.failedDelete'))),
  })

  if (isLoading) return <p className="text-sm text-gray-500">{t('common.loading')}</p>

  function ActionButtons({ user }: { user: AdminUserDto }) {
    return (
      <>
        <button
          onClick={() => startEdit(user)}
          title={t('adminUsers.editUserTitle')}
          className="inline-flex h-11 w-11 cursor-pointer items-center justify-center rounded-md border border-indigo-200 bg-white text-indigo-600 transition-colors hover:border-indigo-300 hover:bg-indigo-50"
        >
          <Pencil className="h-4 w-4" />
        </button>
        <button
          onClick={() => { setResetId(user.id); setResetPw(''); setResetError('') }}
          title={t('adminUsers.resetPasswordTitle')}
          className="inline-flex h-11 w-11 cursor-pointer items-center justify-center rounded-md border border-yellow-200 bg-white text-yellow-600 transition-colors hover:border-yellow-300 hover:bg-yellow-50"
        >
          <KeyRound className="h-4 w-4" />
        </button>
        <button
          onClick={() => toggleRole.mutate({ id: user.id, isAdmin: !user.isAdmin })}
          disabled={toggleRole.isPending}
          title={user.isAdmin ? t('adminUsers.revokeAdmin') : t('adminUsers.makeAdmin')}
          className="inline-flex h-11 w-11 cursor-pointer items-center justify-center rounded-md border border-gray-200 bg-white text-gray-600 transition-colors hover:border-gray-300 hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {user.isAdmin ? <ShieldOff className="h-4 w-4" /> : <ShieldCheck className="h-4 w-4" />}
        </button>
        {user.id !== currentUserId && (
          <button
            onClick={() => { setDeleteId(user.id); setDeleteError('') }}
            title={t('adminUsers.deleteUserTitle')}
            className="inline-flex h-11 w-11 cursor-pointer items-center justify-center rounded-md border border-red-200 bg-white text-red-600 transition-colors hover:border-red-300 hover:bg-red-50"
          >
            <Trash2 className="h-4 w-4" />
          </button>
        )}
      </>
    )
  }

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold text-gray-900">{t('adminUsers.pageTitle')}</h1>

      {/* Desktop table — hidden on mobile */}
      <div className="hidden sm:block overflow-hidden rounded-lg border border-gray-200 bg-white">
        <table className="w-full text-sm">
          <thead className="border-b border-gray-200 bg-gray-50 text-left">
            <tr>
              <th className="px-4 py-3 font-medium text-gray-600">{t('adminUsers.colUsername')}</th>
              <th className="px-4 py-3 font-medium text-gray-600">{t('adminUsers.colEmail')}</th>
              <th className="px-4 py-3 font-medium text-gray-600">{t('adminUsers.colRole')}</th>
              <th className="px-4 py-3 font-medium text-gray-600">{t('adminUsers.colCombos')}</th>
              <th className="px-4 py-3 font-medium text-gray-600">{t('adminUsers.colActions')}</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {users?.map((user) => (
              <tr key={user.id} className="hover:bg-gray-50">
                <td className="px-4 py-3 font-medium text-gray-900">
                  {user.userName}
                  {user.id === currentUserId && (
                    <span className="ml-2 text-xs text-gray-400">{t('adminUsers.you')}</span>
                  )}
                </td>
                <td className="px-4 py-3 text-gray-600">{user.email}</td>
                <td className="px-4 py-3">
                  <RoleBadge isAdmin={user.isAdmin} />
                </td>
                <td className="px-4 py-3 text-gray-600">{user.comboCount}</td>
                <td className="px-4 py-3">
                  <div className="flex items-center gap-1.5">
                    <ActionButtons user={user} />
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Mobile card list — hidden on sm+ */}
      <div className="space-y-3 sm:hidden">
        {users?.map((user) => (
          <div key={user.id} className="rounded-lg border border-gray-200 bg-white p-4 space-y-3">
            <div className="flex items-start justify-between gap-2">
              <div className="min-w-0">
                <p className="font-semibold text-gray-900 truncate">
                  {user.userName}
                  {user.id === currentUserId && (
                    <span className="ml-2 text-xs text-gray-400">{t('adminUsers.you')}</span>
                  )}
                </p>
                <p className="text-sm text-gray-500 truncate">{user.email}</p>
                <p className="text-xs text-gray-400 mt-0.5">{t('adminUsers.comboCount', { count: user.comboCount })}</p>
              </div>
              <RoleBadge isAdmin={user.isAdmin} />
            </div>
            <div className="flex gap-2">
              <ActionButtons user={user} />
            </div>
          </div>
        ))}
      </div>

      {/* Edit modal */}
      {editingId && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
          <div className="w-full max-w-sm rounded-lg bg-white p-6 shadow-xl">
            <h2 className="mb-4 text-lg font-semibold">{t('adminUsers.editModalTitle')}</h2>
            <div className="space-y-3">
              <div>
                <label className="mb-1 block text-sm font-medium text-gray-700">{t('adminUsers.fieldUsername')}</label>
                <input
                  type="text"
                  value={editUserName}
                  onChange={(e) => setEditUserName(e.target.value)}
                  className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm"
                />
              </div>
              <div>
                <label className="mb-1 block text-sm font-medium text-gray-700">{t('adminUsers.fieldEmail')}</label>
                <input
                  type="email"
                  value={editEmail}
                  onChange={(e) => setEditEmail(e.target.value)}
                  className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm"
                />
              </div>
              {editError && <p className="text-sm text-red-600">{editError}</p>}
            </div>
            <div className="mt-4 flex justify-end gap-2">
              <button
                onClick={() => setEditingId(null)}
                className="rounded-md border border-gray-300 px-4 py-2 text-sm text-gray-700 hover:bg-gray-50"
              >
                {t('common.cancel')}
              </button>
              <button
                onClick={() => updateUser.mutate(editingId)}
                disabled={updateUser.isPending}
                className="rounded-md bg-indigo-600 px-4 py-2 text-sm text-white hover:bg-indigo-700 disabled:opacity-50"
              >
                {updateUser.isPending ? t('common.saving') : t('common.save')}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Reset password modal */}
      {resetId && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
          <div className="w-full max-w-sm rounded-lg bg-white p-6 shadow-xl">
            <h2 className="mb-4 text-lg font-semibold">{t('adminUsers.resetModalTitle')}</h2>
            <div className="space-y-3">
              <div>
                <label className="mb-1 block text-sm font-medium text-gray-700">{t('adminUsers.fieldNewPassword')}</label>
                <input
                  type="password"
                  value={resetPw}
                  onChange={(e) => setResetPw(e.target.value)}
                  minLength={6}
                  className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm"
                />
              </div>
              {resetError && <p className="text-sm text-red-600">{resetError}</p>}
            </div>
            <div className="mt-4 flex justify-end gap-2">
              <button
                onClick={() => setResetId(null)}
                className="rounded-md border border-gray-300 px-4 py-2 text-sm text-gray-700 hover:bg-gray-50"
              >
                {t('common.cancel')}
              </button>
              <button
                onClick={() => resetPassword.mutate(resetId)}
                disabled={resetPassword.isPending || resetPw.length < 6}
                className="rounded-md bg-yellow-500 px-4 py-2 text-sm text-white hover:bg-yellow-600 disabled:opacity-50"
              >
                {resetPassword.isPending ? t('adminUsers.resetting') : t('adminUsers.reset')}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Delete confirm modal */}
      {deleteId && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
          <div className="w-full max-w-sm rounded-lg bg-white p-6 shadow-xl">
            <h2 className="mb-2 text-lg font-semibold">{t('adminUsers.deleteModalTitle')}</h2>
            <p className="mb-4 text-sm text-gray-600">
              {t('adminUsers.deleteWarning')}
            </p>
            {deleteError && <p className="mb-2 text-sm text-red-600">{deleteError}</p>}
            <div className="flex justify-end gap-2">
              <button
                onClick={() => setDeleteId(null)}
                className="rounded-md border border-gray-300 px-4 py-2 text-sm text-gray-700 hover:bg-gray-50"
              >
                {t('common.cancel')}
              </button>
              <button
                onClick={() => deleteUser.mutate(deleteId)}
                disabled={deleteUser.isPending}
                className="rounded-md bg-red-600 px-4 py-2 text-sm text-white hover:bg-red-700 disabled:opacity-50"
              >
                {deleteUser.isPending ? t('common.deleting') : t('common.delete')}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
