import { useState } from 'react'
import { Link } from 'react-router-dom'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { combosApi, ratingsApi, extractError, type ComboDto } from '@/lib/api'
import { getUserId, isAdmin, isAuthenticated } from '@/lib/auth'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { RateComboDialog } from './RateComboDialog'

interface Props {
  combo: ComboDto
  showActions?: boolean
  onDeleted?: (id: string) => void
}

export function ComboCard({ combo, showActions = false, onDeleted }: Props) {
  const currentUserId = getUserId()
  const authed = isAuthenticated()
  const isOwner = combo.ownerId === currentUserId
  const canDelete = isAdmin() || isOwner
  const queryClient = useQueryClient()
  const [ratingOpen, setRatingOpen] = useState(false)
  const [deleteError, setDeleteError] = useState<string | null>(null)
  const [favoured, setFavoured] = useState(combo.isFavourited ?? false)
  const [favError, setFavError] = useState<string | null>(null)

  const visibilityMutation = useMutation({
    mutationFn: (isPublic: boolean) => combosApi.setPublic(combo.id, isPublic),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['combos'] })
    },
  })

  const deleteMutation = useMutation({
    mutationFn: () => combosApi.delete(combo.id),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['combos'] })
      onDeleted?.(combo.id)
    },
    onError: (err) => setDeleteError(extractError(err, 'Delete failed')),
  })

  const favMutation = useMutation({
    mutationFn: () => favoured ? combosApi.removeFavourite(combo.id) : combosApi.addFavourite(combo.id),
    onSuccess: () => {
      setFavoured((f) => !f)
      setFavError(null)
      void queryClient.invalidateQueries({ queryKey: ['combos'] })
    },
    onError: (err) => setFavError(extractError(err, 'Could not update favourite')),
  })

  return (
    <Card>
      <CardHeader className="pb-2">
        <div className="flex items-start justify-between gap-2">
          <div>
            {combo.name && (
              <p className="text-sm font-semibold text-gray-900">{combo.name}</p>
            )}
            <CardTitle className="text-base font-mono">{combo.displayText}</CardTitle>
            {combo.ownerUserName && (
              <p className="mt-0.5 text-xs text-gray-500">by {combo.ownerUserName}</p>
            )}
          </div>
          <div className="flex flex-wrap gap-1 items-start">
            <Badge variant="secondary">
              Avg diff: {combo.averageDifficulty?.toFixed(1) ?? '—'}
            </Badge>
            {combo.isPublic != null && (
              combo.isPublic ? (
                <Badge>Public</Badge>
              ) : (
                <Badge variant="outline">Private</Badge>
              )
            )}
            {combo.averageRating != null && combo.averageRating > 0 && (
              <Badge variant="secondary">
                ★ {combo.averageRating.toFixed(1)} ({combo.totalRatings ?? combo.ratingCount ?? 0})
              </Badge>
            )}
            {favoured && <Badge variant="secondary">♥ Favourite</Badge>}
          </div>
        </div>
      </CardHeader>
      <CardContent className="space-y-3">
        {/* Trick list */}
        <div className="flex flex-wrap gap-1.5">
          {combo.tricks?.map((t) => (
            <span
              key={t.position}
              className="inline-flex items-center gap-1 rounded bg-gray-100 px-2 py-0.5 text-xs font-medium text-gray-700"
            >
              {t.position}. {t.abbreviation}
              {t.noTouch && <span className="text-indigo-500">(nt)</span>}
              {!t.strongFoot && <span className="text-orange-500">(wk)</span>}
            </span>
          ))}
        </div>

        {/* AI description */}
        {combo.aiDescription && (
          <p className="text-sm italic text-gray-600">"{combo.aiDescription}"</p>
        )}

        {showActions && (
          <div className="flex flex-wrap gap-2 pt-1">
            <Button variant="outline" size="sm" asChild>
              <Link to={`/combos/${combo.id}`}>View details</Link>
            </Button>
            {authed && (
              <Button
                variant="outline"
                size="sm"
                onClick={() => favMutation.mutate()}
                disabled={favMutation.isPending}
                className={favoured ? 'text-pink-600 hover:text-pink-700' : 'text-gray-500'}
              >
                {favoured ? '♥ Unfavourite' : '♡ Favourite'}
              </Button>
            )}
            {!isOwner && currentUserId && (
              <Button variant="outline" size="sm" onClick={() => setRatingOpen(true)}>
                Rate
              </Button>
            )}
            {isOwner && (
              <Button
                variant="outline"
                size="sm"
                onClick={() => visibilityMutation.mutate(!combo.isPublic)}
                disabled={visibilityMutation.isPending}
              >
                {combo.isPublic ? 'Make private' : 'Make public'}
              </Button>
            )}
            {canDelete && (
              <Button
                variant="outline"
                size="sm"
                className="text-red-600 hover:text-red-700"
                onClick={() => {
                  if (confirm('Delete this combo?')) deleteMutation.mutate()
                }}
                disabled={deleteMutation.isPending}
              >
                Delete
              </Button>
            )}
            {favError && <p className="w-full text-xs text-red-600">{favError}</p>}
            {deleteError && <p className="w-full text-xs text-red-600">{deleteError}</p>}
          </div>
        )}
      </CardContent>

      <RateComboDialog
        comboId={combo.id}
        open={ratingOpen}
        onOpenChange={setRatingOpen}
      />
    </Card>
  )
}
