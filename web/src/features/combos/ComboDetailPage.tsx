import { useState } from 'react'
import { useParams, Link } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { combosApi } from '@/lib/api'
import { getUserId } from '@/lib/auth'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { RateComboDialog } from './RateComboDialog'

export function ComboDetailPage() {
  const { id } = useParams<{ id: string }>()
  const currentUserId = getUserId()
  const [ratingOpen, setRatingOpen] = useState(false)

  const { data: combo, isLoading, error } = useQuery({
    queryKey: ['combos', id],
    queryFn: () => combosApi.getById(id!).then((r) => r.data),
    enabled: !!id,
  })

  if (isLoading) return <p className="text-gray-500">Loading…</p>
  if (error || !combo) return <p className="text-red-600">Combo not found.</p>

  const isOwner = combo.ownerId === currentUserId

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-3">
        <Link to="/combos/public" className="text-sm text-gray-500 hover:text-gray-700">
          ← Back
        </Link>
      </div>

      <Card>
        <CardHeader>
          <div className="flex items-start justify-between gap-2">
            <CardTitle className="font-mono text-xl">{combo.displayText}</CardTitle>
            <div className="flex flex-wrap gap-1">
              {combo.isPublic ? (
                <Badge>Public</Badge>
              ) : (
                <Badge variant="outline">Private</Badge>
              )}
              {combo.averageRating !== null && (
                <Badge variant="secondary">
                  ★ {combo.averageRating.toFixed(1)} ({combo.ratingCount} ratings)
                </Badge>
              )}
            </div>
          </div>
          <p className="text-sm text-gray-500">
            by {combo.ownerEmail} · {new Date(combo.createdAt).toLocaleDateString()}
          </p>
        </CardHeader>
        <CardContent className="space-y-4">
          {combo.aiDescription && (
            <blockquote className="border-l-4 border-indigo-300 pl-4 text-sm italic text-gray-600">
              {combo.aiDescription}
            </blockquote>
          )}

          <div>
            <h3 className="mb-2 text-sm font-medium text-gray-700">Tricks</h3>
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b text-left text-gray-500">
                    <th className="pb-1 pr-4">#</th>
                    <th className="pb-1 pr-4">Name</th>
                    <th className="pb-1 pr-4">Abbr.</th>
                    <th className="pb-1 pr-4">Difficulty</th>
                    <th className="pb-1 pr-4">Foot</th>
                    <th className="pb-1">No-Touch</th>
                  </tr>
                </thead>
                <tbody>
                  {combo.tricks.map((t) => (
                    <tr key={t.position} className="border-b last:border-0">
                      <td className="py-1.5 pr-4 text-gray-500">{t.position}</td>
                      <td className="py-1.5 pr-4 font-medium">{t.trickName}</td>
                      <td className="py-1.5 pr-4 font-mono text-xs">{t.abbreviation}</td>
                      <td className="py-1.5 pr-4">{t.difficulty}</td>
                      <td className="py-1.5 pr-4">{t.strongFoot ? 'Strong' : 'Weak'}</td>
                      <td className="py-1.5">{t.noTouch ? '✓' : '—'}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>

          <div className="flex gap-2 pt-1">
            <Badge variant="secondary">Total difficulty: {combo.totalDifficulty.toFixed(1)}</Badge>
            <Badge variant="secondary">{combo.trickCount} tricks</Badge>
          </div>

          {!isOwner && currentUserId && (
            <Button variant="outline" onClick={() => setRatingOpen(true)}>
              Rate this combo
            </Button>
          )}
        </CardContent>
      </Card>

      <RateComboDialog
        comboId={combo.id}
        open={ratingOpen}
        onOpenChange={setRatingOpen}
      />
    </div>
  )
}
