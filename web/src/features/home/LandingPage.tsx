import { Link } from 'react-router-dom'
import { isAuthenticated } from '@/lib/auth'
import { SEO } from '@/components/SEO'

export function LandingPage() {
  const authed = isAuthenticated()

  return (
    <div className="space-y-12">
      <SEO
        title="FreestyleCombo — Freestyle Football Combo Generator"
        description="Generate, build and share freestyle football combos. Rate other players' combos and level up your skills."
        path="/"
      />
      {/* Hero */}
      <div className="text-center space-y-4 pt-6 sm:pt-10">
        <h1 className="text-4xl font-extrabold tracking-tight text-gray-900 sm:text-5xl">
          FreestyleCombo
        </h1>
        <p className="mx-auto max-w-xl text-lg text-gray-500">
          Generate, build, and share freestyle football combos. Rate other players' combos and level up your skills.
        </p>

      </div>

      {/* Action cards */}
      <div className="grid gap-4 sm:grid-cols-2">
        {/* Create Combo */}
        {authed ? (
          <Link
            to="/combos/create"
            className="flex flex-col items-start gap-4 rounded-xl border-2 border-gray-200 p-6 text-left hover:border-indigo-400 hover:bg-indigo-50 transition-colors"
          >
            <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-indigo-100 text-2xl">
              ✨
            </div>
            <div>
              <p className="text-lg font-semibold text-gray-900">Create a Combo</p>
              <p className="mt-1 text-sm text-gray-500">
                Auto-generate or manually build a combo from your trick library.
              </p>
            </div>
          </Link>
        ) : (
          <Link
            to="/login"
            className="flex flex-col items-start gap-4 rounded-xl border-2 border-gray-200 p-6 text-left hover:border-indigo-400 hover:bg-indigo-50 transition-colors opacity-75"
          >
            <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-indigo-100 text-2xl">
              ✨
            </div>
            <div>
              <p className="text-lg font-semibold text-gray-900">Create a Combo</p>
              <p className="mt-1 text-sm text-gray-500">
                Auto-generate or manually build a combo from your trick library.
              </p>
              <p className="mt-2 text-xs font-medium text-indigo-600">Login to get started →</p>
            </div>
          </Link>
        )}

        {/* Submit a Trick */}
        <Link
          to="/tricks"
          className="flex flex-col items-start gap-4 rounded-xl border-2 border-gray-200 p-6 text-left hover:border-indigo-400 hover:bg-indigo-50 transition-colors"
        >
          <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-indigo-100 text-2xl">
            🎯
          </div>
          <div>
            <p className="text-lg font-semibold text-gray-900">Trick Library</p>
            <p className="mt-1 text-sm text-gray-500">
              Browse all tricks. Know one that's missing? Login to submit it for review.
            </p>
          </div>
        </Link>
      </div>

      {/* Browse links */}
      <div className="flex flex-wrap justify-center gap-6 border-t border-gray-100 pt-8">
        <Link
          to="/combos"
          className="flex items-center gap-2 text-sm font-medium text-gray-600 hover:text-indigo-600 transition-colors"
        >
          <span>🏆</span> Browse public combos
        </Link>
        <Link
          to="/tricks"
          className="flex items-center gap-2 text-sm font-medium text-gray-600 hover:text-indigo-600 transition-colors"
        >
          <span>📖</span> Browse tricks
        </Link>
      </div>
    </div>
  )
}
