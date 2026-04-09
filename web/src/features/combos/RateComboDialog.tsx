import { useState } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { ratingsApi } from '@/lib/api'
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from '@/components/ui/dialog'
import { Button } from '@/components/ui/button'

interface Props {
  comboId: string
  open: boolean
  onOpenChange: (open: boolean) => void
}

export function RateComboDialog({ comboId, open, onOpenChange }: Props) {
  const [score, setScore] = useState(0)
  const queryClient = useQueryClient()

  const { mutate, isPending, error } = useMutation({
    mutationFn: () => ratingsApi.rate(comboId, score),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['combos'] })
      onOpenChange(false)
    },
  })

  const errorMessage = error
    ? (error as { response?: { data?: { message?: string } } }).response?.data?.message ?? 'Rating failed'
    : null

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-sm">
        <DialogHeader>
          <DialogTitle>Rate this combo</DialogTitle>
          <DialogDescription>Select a score from 1 to 5</DialogDescription>
        </DialogHeader>
        <div className="flex justify-center gap-2">
          {[1, 2, 3, 4, 5].map((s) => (
            <button
              key={s}
              onClick={() => setScore(s)}
              className={`text-2xl transition-transform hover:scale-110 ${
                score >= s ? 'text-yellow-400' : 'text-gray-300'
              }`}
            >
              ★
            </button>
          ))}
        </div>
        {errorMessage && <p className="text-sm text-red-600 text-center">{errorMessage}</p>}
        <Button onClick={() => mutate()} disabled={isPending || score === 0} className="w-full">
          {isPending ? 'Submitting…' : 'Submit rating'}
        </Button>
      </DialogContent>
    </Dialog>
  )
}
