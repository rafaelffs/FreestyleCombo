import { useParams } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { accountApi } from '@/lib/api'
import { SEO } from '@/components/SEO'

export function UserProfilePage() {
  const { id } = useParams<{ id: string }>()

  const { data: profile, isLoading, isError } = useQuery({
    queryKey: ['user-profile', id],
    queryFn: () => accountApi.getPublicProfile(id!).then((r) => r.data),
    enabled: !!id,
  })

  if (isLoading) return <p className="p-6 text-sm text-gray-500">Loading…</p>
  if (isError || !profile) {
    return <p className="p-6 text-sm text-red-500">User not found.</p>
  }

  return (
    <div className="mx-auto max-w-md p-6">
      <SEO
        title={`${profile.userName}'s Profile — FreestyleCombo`}
        description={`View ${profile.userName}'s freestyle football profile and combos.`}
        path={`/users/${id}`}
      />
      <div className="rounded-lg border border-gray-200 bg-white p-6 text-center shadow-sm">
        <div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-indigo-100 text-2xl font-bold text-indigo-600">
          {profile.userName.charAt(0).toUpperCase()}
        </div>
        <h1 className="text-xl font-bold text-gray-900">{profile.userName}</h1>
        <p className="mt-1 text-sm text-gray-500">{profile.email}</p>
      </div>
    </div>
  )
}
