import { Suspense, useState } from 'react'
import { Canvas } from '@react-three/fiber'
import { OrbitControls } from '@react-three/drei'
import { useTranslation } from 'react-i18next'
import { SEO } from '@/components/SEO'
import { AroundTheWorldContent } from './scenes/AroundTheWorld'

const TRICKS = [
  {
    id: 'atw',
    name: 'Around the World',
    abbr: 'ATW',
    description:
      "The ball is lifted to ankle height and the dominant foot makes one complete horizontal revolution around it before the ball is caught. The glowing ring shows the foot's circular path.",
  },
]

export function AnimationPage() {
  const { t } = useTranslation()
  const [selectedId, setSelectedId] = useState('atw')
  const [playing, setPlaying] = useState(false)

  const trick = TRICKS.find((tr) => tr.id === selectedId)!

  return (
    <>
      <SEO title={t('animation.pageTitle')} description={t('animation.pageSubtitle')} />
      <div className="mx-auto max-w-5xl px-4 sm:px-6 lg:px-8 py-8 space-y-6">
        {/* Header */}
        <div>
          <h1 className="text-2xl font-bold text-gray-900">{t('animation.pageTitle')}</h1>
          <p className="mt-1 text-sm text-gray-500">{t('animation.pageSubtitle')}</p>
        </div>

        {/* Trick list */}
        <div className="space-y-2">
          {TRICKS.map((tr) => (
            <button
              key={tr.id}
              type="button"
              onClick={() => {
                setSelectedId(tr.id)
                setPlaying(false)
              }}
              className={[
                'w-full flex items-center justify-between rounded-xl border px-5 py-4 text-left transition-colors',
                selectedId === tr.id
                  ? 'border-indigo-400 bg-indigo-50 ring-1 ring-indigo-400'
                  : 'border-gray-200 bg-white hover:border-gray-300',
              ].join(' ')}
            >
              <div className="flex items-center gap-3">
                <span className="rounded bg-indigo-100 px-2 py-0.5 text-xs font-bold text-indigo-700">
                  {tr.abbr}
                </span>
                <span className="text-sm font-medium text-gray-900">{tr.name}</span>
              </div>
              {/* Play / Pause button — only visible on selected trick */}
              {selectedId === tr.id && (
                <button
                  type="button"
                  onClick={(e) => {
                    e.stopPropagation()
                    setPlaying((p) => !p)
                  }}
                  className="inline-flex h-9 w-9 items-center justify-center rounded-full bg-indigo-600 text-white shadow hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-1 transition-colors"
                  aria-label={playing ? t('animation.pause') : t('animation.play')}
                >
                  {playing ? (
                    /* Pause icon */
                    <svg viewBox="0 0 20 20" fill="currentColor" className="h-4 w-4">
                      <rect x="5" y="4" width="3" height="12" rx="1" />
                      <rect x="12" y="4" width="3" height="12" rx="1" />
                    </svg>
                  ) : (
                    /* Play icon */
                    <svg viewBox="0 0 20 20" fill="currentColor" className="h-4 w-4">
                      <path d="M6.3 2.841A1.5 1.5 0 004 4.11v11.78a1.5 1.5 0 002.3 1.269l9.344-5.89a1.5 1.5 0 000-2.538L6.3 2.84z" />
                    </svg>
                  )}
                </button>
              )}
            </button>
          ))}
        </div>

        {/* 3-D canvas */}
        <div
          className="overflow-hidden rounded-xl border border-gray-200"
          style={{ height: 500, background: '#0f172a' }}
        >
          <Canvas camera={{ position: [1.5, 1.6, 2.8], fov: 45 }}>
            <Suspense fallback={null}>
              {selectedId === 'atw' && (
                <AroundTheWorldContent
                  playing={playing}
                  onComplete={() => setPlaying(false)}
                />
              )}
              <OrbitControls
                target={[0.1, 0.7, 0.1]}
                minDistance={1.5}
                maxDistance={6}
                maxPolarAngle={Math.PI / 2}
                enablePan={false}
              />
            </Suspense>
          </Canvas>
        </div>

        {/* Trick description + drag hint */}
        <div className="rounded-xl border border-gray-200 bg-white px-5 py-4 space-y-1">
          <div className="flex items-center gap-2">
            <span className="text-base font-semibold text-gray-900">{trick.name}</span>
            <span className="rounded bg-indigo-100 px-2 py-0.5 text-xs font-bold text-indigo-700">
              {trick.abbr}
            </span>
          </div>
          <p className="text-sm text-gray-600">{trick.description}</p>
          <p className="pt-1 text-xs text-gray-400">{t('animation.hint')}</p>
        </div>
      </div>
    </>
  )
}
