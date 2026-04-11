import { useState } from 'react'
import { Link } from 'react-router-dom'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { combosApi, extractError, type ComboDto } from '@/lib/api'
import { getUserId, isAuthenticated } from '@/lib/auth'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { RateComboDialog } from './RateComboDialog'

interface Props {
  combo: ComboDto
  showActions?: boolean
}

function GlobeIcon() {
  return (
    <svg viewBox="0 0 24 24" className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth="1.8" aria-hidden="true">
      <circle cx="12" cy="12" r="9" />
      <path d="M3 12h18" />
      <path d="M12 3a14 14 0 0 1 0 18" />
      <path d="M12 3a14 14 0 0 0 0 18" />
    </svg>
  )
}

function HeartIconFilled() {
  return (
    <svg viewBox="0 0 24 24" className="h-4 w-4" fill="currentColor" aria-hidden="true">
      <path d="M12 21c-.3 0-.6-.1-.8-.3C7 17 3 13.5 3 9.6C3 6.5 5.4 4 8.4 4c1.6 0 3 .7 3.9 1.9C13.2 4.7 14.6 4 16.2 4C19.6 4 22 6.5 22 9.6c0 3.9-4 7.4-8.2 11.1c-.2.2-.5.3-.8.3z" />
    </svg>
  )
}

function HeartIconOutline() {
  return (
    <svg viewBox="0 0 24 24" className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth="1.8" aria-hidden="true">
      <path d="M12 20.7l-.7-.6C7.2 16.5 4 13.6 4 10.2C4 7.7 6 5.7 8.5 5.7c1.5 0 2.9.7 3.8 1.9c.9-1.2 2.3-1.9 3.8-1.9c2.5 0 4.5 2 4.5 4.5c0 3.4-3.2 6.3-7.3 9.9l-.7.6z" />
    </svg>
  )
}

export function ComboCard({ combo, showActions = false }: Props) {
  const currentUserId = getUserId()
  const authed = isAuthenticated()
  const isOwner = combo.ownerId === currentUserId
  const queryClient = useQueryClient()
  const [ratingOpen, setRatingOpen] = useState(false)
  const [favoured, setFavoured] = useState(combo.isFavourited ?? false)
  const [favError, setFavError] = useState<string | null>(null)

  const visibilityMutation = useMutation({
    mutationFn: (isPublic: boolean) => combosApi.setPublic(combo.id, isPublic),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['combos'] })
    },
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

  const visibilityState = combo.visibility === 'PendingReview'
    ? 'pending'
    : (combo.visibility === 'Public' || combo.isPublic === true)
      ? 'public'
      : 'private'

  return (
    <Card>
      <CardHeader className="pb-2">
        <div className="flex items-start justify-between gap-2">
          <div className="min-w-0 flex-1">
            <div className="mb-2 flex items-center gap-2">
              {authed && (
                <button
                  type="button"
                  onClick={() => favMutation.mutate()}
                  disabled={favMutation.isPending}
                  className={`inline-flex h-8 w-8 cursor-pointer items-center justify-center rounded-md border border-gray-200 bg-white transition-colors disabled:cursor-not-allowed ${
                    favoured ? 'text-pink-600 hover:text-pink-500' : 'text-gray-500 hover:text-pink-400'
                  }`}
                  title={favoured ? 'Unfavourite' : 'Favourite'}
                >
                  {favoured ? <HeartIconFilled /> : <HeartIconOutline />}
                </button>
              )}
              {isOwner && (
                <button
                  type="button"
                  onClick={() => {
                    if (visibilityState === 'private') {
                      const ok = confirm('Set this combo as public and send it for approval?')
                      if (ok) visibilityMutation.mutate(true)
                    }
                  }}
                  disabled={visibilityMutation.isPending}
                  className={`inline-flex h-8 w-8 cursor-pointer items-center justify-center rounded-md border border-gray-200 bg-white transition-colors disabled:cursor-not-allowed ${
                    visibilityState === 'pending'
                      ? 'text-yellow-500'
                      : visibilityState === 'public'
                        ? 'text-blue-600'
                        : 'text-gray-500 hover:text-gray-600'
                  }`}
                  title={
                    visibilityState === 'pending'
                      ? 'Pending approval'
                      : visibilityState === 'public'
                        ? 'Public'
                        : 'Private'
                  }
                >
                  <GlobeIcon />
                </button>
              )}
            </div>
            <div className="min-w-0">
              {combo.name && (
                <p className="text-sm font-semibold text-gray-900 truncate">{combo.name}</p>
              )}
              <CardTitle className="text-base font-mono truncate">{combo.displayText}</CardTitle>
            </div>
            {combo.ownerUserName && (
              <p className="mt-0.5 text-xs text-gray-500">by {combo.ownerUserName}</p>
            )}
          </div>
          <div className="flex flex-wrap gap-1 items-start">
            <Badge variant="secondary">
              Avg diff: {combo.averageDifficulty?.toFixed(1) ?? '—'}
            </Badge>
            {combo.averageRating != null && combo.averageRating > 0 && (
              <Badge variant="secondary">
                ★ {combo.averageRating.toFixed(1)} ({combo.totalRatings ?? combo.ratingCount ?? 0})
              </Badge>
            )}
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
              {!t.strongFoot && <span className="text-orange-500">(wf)</span>}
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
            {!isOwner && currentUserId && (
              <Button variant="outline" size="sm" onClick={() => setRatingOpen(true)}>
                Rate
              </Button>
            )}
            {favError && <p className="w-full text-xs text-red-600">{favError}</p>}
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
