import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Pencil, KeyRound, ShieldCheck, ShieldOff, Trash2 } from 'lucide-react'
import { adminApi, extractError, type AdminUserDto } from '@/lib/api'
import { getUserId } from '@/lib/auth'

export function AdminUsersPage() {
  const qc = useQueryClient()
  const currentUserId = getUserId()

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
    onError: (err) => setEditError(extractError(err, 'Failed to update user.')),
  })

  const resetPassword = useMutation({
    mutationFn: (id: string) => adminApi.resetUserPassword(id, resetPw),
    onSuccess: () => {
      setResetId(null)
      setResetPw('')
      setResetError('')
    },
    onError: (err) => setResetError(extractError(err, 'Failed to reset password.')),
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
    onError: (err) => setDeleteError(extractError(err, 'Failed to delete user.')),
  })

  if (isLoading) return <p className="p-6 text-sm text-gray-500">Loading…</p>

  return (
    <div className="mx-auto max-w-5xl p-6">
      <h1 className="mb-6 text-2xl font-bold text-gray-900">Users</h1>

      <div className="overflow-hidden rounded-lg border border-gray-200 bg-white">
        <table className="w-full text-sm">
          <thead className="border-b border-gray-200 bg-gray-50 text-left">
            <tr>
              <th className="px-4 py-3 font-medium text-gray-600">Username</th>
              <th className="px-4 py-3 font-medium text-gray-600">Email</th>
              <th className="px-4 py-3 font-medium text-gray-600">Role</th>
              <th className="px-4 py-3 font-medium text-gray-600">Combos</th>
              <th className="px-4 py-3 font-medium text-gray-600">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {users?.map((user) => (
              <tr key={user.id} className="hover:bg-gray-50">
                <td className="px-4 py-3 font-medium text-gray-900">
                  {user.userName}
                  {user.id === currentUserId && (
                    <span className="ml-2 text-xs text-gray-400">(you)</span>
                  )}
                </td>
                <td className="px-4 py-3 text-gray-600">{user.email}</td>
                <td className="px-4 py-3">
                  {user.isAdmin ? (
                    <span className="inline-flex items-center rounded-full bg-indigo-100 px-2 py-0.5 text-xs font-medium text-indigo-700">
                      Admin
                    </span>
                  ) : (
                    <span className="text-gray-400">User</span>
                  )}
                </td>
                <td className="px-4 py-3 text-gray-600">{user.comboCount}</td>
                <td className="px-4 py-3">
                  <div className="flex items-center gap-1.5">
                    <button
                      onClick={() => startEdit(user)}
                      title="Edit user"
                      className="inline-flex h-8 w-8 cursor-pointer items-center justify-center rounded-md border border-indigo-200 bg-white text-indigo-600 transition-colors hover:border-indigo-300 hover:bg-indigo-50"
                    >
                      <Pencil className="h-4 w-4" />
                    </button>
                    <button
                      onClick={() => { setResetId(user.id); setResetPw(''); setResetError('') }}
                      title="Reset password"
                      className="inline-flex h-8 w-8 cursor-pointer items-center justify-center rounded-md border border-yellow-200 bg-white text-yellow-600 transition-colors hover:border-yellow-300 hover:bg-yellow-50"
                    >
                      <KeyRound className="h-4 w-4" />
                    </button>
                    <button
                      onClick={() => toggleRole.mutate({ id: user.id, isAdmin: !user.isAdmin })}
                      disabled={toggleRole.isPending}
                      title={user.isAdmin ? 'Revoke admin' : 'Make admin'}
                      className="inline-flex h-8 w-8 cursor-pointer items-center justify-center rounded-md border border-gray-200 bg-white text-gray-600 transition-colors hover:border-gray-300 hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-50"
                    >
                      {user.isAdmin ? <ShieldOff className="h-4 w-4" /> : <ShieldCheck className="h-4 w-4" />}
                    </button>
                    {user.id !== currentUserId && (
                      <button
                        onClick={() => { setDeleteId(user.id); setDeleteError('') }}
                        title="Delete user"
                        className="inline-flex h-8 w-8 cursor-pointer items-center justify-center rounded-md border border-red-200 bg-white text-red-600 transition-colors hover:border-red-300 hover:bg-red-50"
                      >
                        <Trash2 className="h-4 w-4" />
                      </button>
                    )}
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Edit modal */}
      {editingId && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40">
          <div className="w-full max-w-sm rounded-lg bg-white p-6 shadow-xl">
            <h2 className="mb-4 text-lg font-semibold">Edit User</h2>
            <div className="space-y-3">
              <div>
                <label className="mb-1 block text-sm font-medium text-gray-700">Username</label>
                <input
                  type="text"
                  value={editUserName}
                  onChange={(e) => setEditUserName(e.target.value)}
                  className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm"
                />
              </div>
              <div>
                <label className="mb-1 block text-sm font-medium text-gray-700">Email</label>
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
                Cancel
              </button>
              <button
                onClick={() => updateUser.mutate(editingId)}
                disabled={updateUser.isPending}
                className="rounded-md bg-indigo-600 px-4 py-2 text-sm text-white hover:bg-indigo-700 disabled:opacity-50"
              >
                {updateUser.isPending ? 'Saving…' : 'Save'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Reset password modal */}
      {resetId && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40">
          <div className="w-full max-w-sm rounded-lg bg-white p-6 shadow-xl">
            <h2 className="mb-4 text-lg font-semibold">Reset Password</h2>
            <div className="space-y-3">
              <div>
                <label className="mb-1 block text-sm font-medium text-gray-700">New password</label>
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
                Cancel
              </button>
              <button
                onClick={() => resetPassword.mutate(resetId)}
                disabled={resetPassword.isPending || resetPw.length < 6}
                className="rounded-md bg-yellow-500 px-4 py-2 text-sm text-white hover:bg-yellow-600 disabled:opacity-50"
              >
                {resetPassword.isPending ? 'Resetting…' : 'Reset'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Delete confirm modal */}
      {deleteId && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40">
          <div className="w-full max-w-sm rounded-lg bg-white p-6 shadow-xl">
            <h2 className="mb-2 text-lg font-semibold">Delete User</h2>
            <p className="mb-4 text-sm text-gray-600">
              This will permanently delete the user and all their data. This cannot be undone.
            </p>
            {deleteError && <p className="mb-2 text-sm text-red-600">{deleteError}</p>}
            <div className="flex justify-end gap-2">
              <button
                onClick={() => setDeleteId(null)}
                className="rounded-md border border-gray-300 px-4 py-2 text-sm text-gray-700 hover:bg-gray-50"
              >
                Cancel
              </button>
              <button
                onClick={() => deleteUser.mutate(deleteId)}
                disabled={deleteUser.isPending}
                className="rounded-md bg-red-600 px-4 py-2 text-sm text-white hover:bg-red-700 disabled:opacity-50"
              >
                {deleteUser.isPending ? 'Deleting…' : 'Delete'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
