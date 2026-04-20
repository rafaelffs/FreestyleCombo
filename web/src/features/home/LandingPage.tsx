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

        {!authed && (
          <div className="space-y-3 pt-2">
            <p className="text-sm text-gray-500">
              Register or login to generate a combo or submit a trick.
            </p>
            <div className="flex justify-center gap-3">
              <Link
                to="/register"
                className="inline-flex h-10 items-center rounded-md bg-indigo-600 px-5 text-sm font-semibold text-white hover:bg-indigo-700 transition-colors"
              >
                Register
              </Link>
              <Link
                to="/login"
                className="inline-flex h-10 items-center rounded-md border border-gray-300 bg-white px-5 text-sm font-semibold text-gray-700 hover:bg-gray-50 transition-colors"
              >
                Login
              </Link>
            </div>
          </div>
        )}
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
        {authed ? (
          <Link
            to="/tricks"
            className="flex flex-col items-start gap-4 rounded-xl border-2 border-gray-200 p-6 text-left hover:border-indigo-400 hover:bg-indigo-50 transition-colors"
          >
            <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-indigo-100 text-2xl">
              🎯
            </div>
            <div>
              <p className="text-lg font-semibold text-gray-900">Submit a Trick</p>
              <p className="mt-1 text-sm text-gray-500">
                Know a trick that's not in the library? Submit it for review.
              </p>
            </div>
          </Link>
        ) : (
          <Link
            to="/login"
            className="flex flex-col items-start gap-4 rounded-xl border-2 border-gray-200 p-6 text-left hover:border-indigo-400 hover:bg-indigo-50 transition-colors opacity-75"
          >
            <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-indigo-100 text-2xl">
              🎯
            </div>
            <div>
              <p className="text-lg font-semibold text-gray-900">Submit a Trick</p>
              <p className="mt-1 text-sm text-gray-500">
                Know a trick that's not in the library? Submit it for review.
              </p>
              <p className="mt-2 text-xs font-medium text-indigo-600">Login to get started →</p>
            </div>
          </Link>
        )}
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
