import { REV_MAX, REV_MIN, REV_STEP } from '@/lib/revolutionRange'

interface RevRangeSliderProps {
  min: number
  max: number
  onChange: (min: number, max: number) => void
  disabled?: boolean
}

const THUMB_CLASS =
  '[&::-webkit-slider-thumb]:appearance-none [&::-webkit-slider-thumb]:h-4 [&::-webkit-slider-thumb]:w-4 ' +
  '[&::-webkit-slider-thumb]:rounded-full [&::-webkit-slider-thumb]:border-2 [&::-webkit-slider-thumb]:bg-white ' +
  '[&::-webkit-slider-thumb]:pointer-events-auto [&::-webkit-slider-thumb]:cursor-pointer ' +
  '[&::-moz-range-thumb]:h-4 [&::-moz-range-thumb]:w-4 [&::-moz-range-thumb]:rounded-full ' +
  '[&::-moz-range-thumb]:border-2 [&::-moz-range-thumb]:bg-white [&::-moz-range-thumb]:pointer-events-auto ' +
  '[&::-moz-range-thumb]:cursor-pointer [&::-webkit-slider-runnable-track]:bg-transparent ' +
  '[&::-moz-range-track]:bg-transparent'

/**
 * Two overlaid native range inputs is a standard CSS-only dual-range-slider
 * pattern: each input is full-width and pointer-events-none except its own
 * thumb, so only the thumbs are draggable, not the track between them. When
 * min and max are very close, the two thumbs can be fiddly to grab
 * independently—a known limitation of this pattern.
 */
export function RevRangeSlider({ min, max, onChange, disabled = false }: RevRangeSliderProps) {
  const isFullRange = min <= REV_MIN && max >= REV_MAX
  const label = isFullRange ? 'All revolutions' : `Revs: ${min.toFixed(1)} – ${max.toFixed(1)}`
  const thumbBorder = disabled
    ? '[&::-webkit-slider-thumb]:border-gray-300 [&::-moz-range-thumb]:border-gray-300'
    : '[&::-webkit-slider-thumb]:border-indigo-600 [&::-moz-range-thumb]:border-indigo-600'

  function handleMinChange(value: number) {
    onChange(Math.min(value, max), max)
  }

  function handleMaxChange(value: number) {
    onChange(min, Math.max(value, min))
  }

  return (
    <div className="space-y-1">
      <span className={`text-sm ${disabled ? 'text-gray-400' : 'text-gray-700'}`}>{label}</span>
      <div className="relative h-6">
        <div className="absolute top-1/2 left-0 right-0 h-1 -translate-y-1/2 rounded-full bg-gray-200" />
        <div
          className={`absolute top-1/2 h-1 -translate-y-1/2 rounded-full ${disabled ? 'bg-gray-300' : 'bg-indigo-500'}`}
          style={{
            left: `${((min - REV_MIN) / (REV_MAX - REV_MIN)) * 100}%`,
            right: `${100 - ((max - REV_MIN) / (REV_MAX - REV_MIN)) * 100}%`,
          }}
        />
        <input
          type="range"
          min={REV_MIN}
          max={REV_MAX}
          step={REV_STEP}
          value={min}
          disabled={disabled}
          onChange={(e) => handleMinChange(Number(e.target.value))}
          aria-label="Minimum revolutions"
          className={`pointer-events-none absolute inset-x-0 top-0 h-6 w-full appearance-none bg-transparent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-500 focus-visible:ring-offset-2 ${THUMB_CLASS} ${thumbBorder}`}
        />
        <input
          type="range"
          min={REV_MIN}
          max={REV_MAX}
          step={REV_STEP}
          value={max}
          disabled={disabled}
          onChange={(e) => handleMaxChange(Number(e.target.value))}
          aria-label="Maximum revolutions"
          className={`pointer-events-none absolute inset-x-0 top-0 h-6 w-full appearance-none bg-transparent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-500 focus-visible:ring-offset-2 ${THUMB_CLASS} ${thumbBorder}`}
        />
      </div>
    </div>
  )
}
