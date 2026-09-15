// Brand identity — the "Around The World" mark (orbit ring + ball + bolt +
// travelling satellite ball). Source of truth: design/logo-kit/ (mark/,
// app-icon/, favicon/ SVGs) — this component hand-codes the same shapes
// inline (same convention as every other icon in this codebase) rather than
// loading an external asset, so it stays a single self-contained, freely
// resizable unit with no extra request.
const INDIGO = '#4F46E5'
const VIOLET = '#9C8BFF' // wordmark colour on dark surfaces
const INK = '#15131F'
const BOLT = '#6A54EE'

let _markId = 0

interface AppIconProps {
  size?: number
}

function AppIcon({ size = 64 }: AppIconProps) {
  const uid = `logomark${++_markId}`
  return (
    <svg width={size} height={size} viewBox="0 0 100 100" fill="none" style={{ flexShrink: 0 }}>
      <defs>
        <linearGradient id={uid} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stopColor="#5B4FE9" />
          <stop offset="55%" stopColor="#7A5AF0" />
          <stop offset="100%" stopColor="#8E6BF5" />
        </linearGradient>
      </defs>
      <rect width="100" height="100" rx="23.4" fill={`url(#${uid})`} />
      <ellipse cx="50" cy="50" rx="44" ry="19" transform="rotate(-28 50 50)" fill="none" stroke="#fff" strokeWidth="6.5" opacity={0.7} />
      <circle cx="50" cy="50" r="28" fill="#fff" />
      <path d="M59 13L26 56h19l-4 31 33-44H54z" fill={BOLT} transform="translate(50 50) scale(.56) translate(-50 -50)" />
      <circle cx="88.85" cy="29.36" r="9" fill="#fff" />
    </svg>
  )
}

interface LogoProps {
  iconSize?: number
  darkText?: boolean
}

export function Logo({ iconSize = 38, darkText = false }: LogoProps) {
  const fs = iconSize * 0.34
  const cs = iconSize * 0.55
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: iconSize * 0.42 }}>
      <AppIcon size={iconSize} />
      <div style={{ fontFamily: "'Plus Jakarta Sans', sans-serif", lineHeight: 1 }}>
        <div
          style={{
            fontSize: fs,
            fontWeight: 800,
            letterSpacing: fs * 0.28,
            color: darkText ? VIOLET : INDIGO,
            textTransform: 'uppercase',
            marginBottom: fs * 0.3,
          }}
        >
          Freestyle
        </div>
        <div
          style={{
            fontSize: cs,
            fontWeight: 800,
            color: darkText ? '#fff' : INK,
            letterSpacing: -0.9,
            lineHeight: 0.9,
          }}
        >
          Combo
        </div>
      </div>
    </div>
  )
}
