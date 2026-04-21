const PURPLE = '#5B4AD4'
const PURPLE_L = '#7C6EF0'
const DARK = '#1C1B2E'

let _fbId = 0

interface FootballProps {
  size?: number
  ballColor?: string
  patchColor?: string
  strokeColor?: string
  tilt?: number
}

function Football({ size = 52, ballColor = '#fff', patchColor = PURPLE, strokeColor, tilt = 0 }: FootballProps) {
  const uid = `fb${++_fbId}`
  const sc = strokeColor ?? patchColor
  const r = size * 0.46
  const cx = size / 2
  const cy = size / 2
  const sw = r * 0.068

  const inner = Array.from({ length: 5 }, (_, i) => {
    const a = ((i * 72) - 90 + tilt) * (Math.PI / 180)
    return [cx + r * 0.34 * Math.cos(a), cy + r * 0.34 * Math.sin(a)] as [number, number]
  })

  const outer = Array.from({ length: 5 }, (_, i) => {
    const a = ((i * 72) - 54 + tilt) * (Math.PI / 180)
    return [cx + r * 0.75 * Math.cos(a), cy + r * 0.75 * Math.sin(a)] as [number, number]
  })

  const outerPts = (ox: number, oy: number, idx: number) =>
    Array.from({ length: 5 }, (_, j) => {
      const a = ((j * 72) - 90 + idx * 72 + tilt) * (Math.PI / 180)
      return `${ox + r * 0.23 * Math.cos(a)},${oy + r * 0.23 * Math.sin(a)}`
    }).join(' ')

  const seams: string[] = []
  inner.forEach(([ix, iy], i) => {
    const pairs: [number, number, number, number][] = [
      [ix, iy, outer[i][0], outer[i][1]],
      [ix, iy, outer[(i + 4) % 5][0], outer[(i + 4) % 5][1]],
    ]
    pairs.forEach(([x1, y1, x2, y2]) => {
      const mx = (x1 + x2) / 2
      const my = (y1 + y2) / 2
      const dx = mx - cx
      const dy = my - cy
      const l = Math.sqrt(dx * dx + dy * dy) || 1
      seams.push(`M${x1},${y1} Q${mx + (dx / l) * r * 0.1},${my + (dy / l) * r * 0.1} ${x2},${y2}`)
    })
  })

  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} fill="none">
      <defs>
        <clipPath id={uid}>
          <circle cx={cx} cy={cy} r={r} />
        </clipPath>
      </defs>
      <circle cx={cx} cy={cy} r={r} fill={ballColor} />
      <g clipPath={`url(#${uid})`}>
        {outer.map(([ox, oy], i) => (
          <polygon key={i} points={outerPts(ox, oy, i)} fill={patchColor} />
        ))}
        <polygon points={inner.map(([x, y]) => `${x},${y}`).join(' ')} fill={patchColor} />
        {seams.map((d, i) => (
          <path key={i} d={d} stroke={sc} strokeWidth={sw} strokeLinecap="round" />
        ))}
      </g>
      <circle cx={cx} cy={cy} r={r} stroke={sc} strokeWidth={sw * 0.5} opacity={0.2} />
    </svg>
  )
}

interface AppIconProps {
  size?: number
}

function AppIcon({ size = 64 }: AppIconProps) {
  const br = size * 0.26
  return (
    <div
      style={{
        width: size,
        height: size,
        borderRadius: br,
        flexShrink: 0,
        background: `linear-gradient(145deg, ${PURPLE_L} 0%, ${PURPLE} 100%)`,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        boxShadow: `0 4px 16px ${PURPLE}44`,
      }}
    >
      <Football size={size * 0.72} ballColor="#fff" patchColor={PURPLE} strokeColor={PURPLE} tilt={15} />
    </div>
  )
}

interface LogoProps {
  iconSize?: number
  darkText?: boolean
}

export function Logo({ iconSize = 38, darkText = false }: LogoProps) {
  const textColor = darkText ? '#fff' : DARK
  const fs = iconSize * 0.34
  const cs = iconSize * 0.55
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: iconSize * 0.42 }}>
      <AppIcon size={iconSize} />
      <div style={{ fontFamily: "'Plus Jakarta Sans', sans-serif", lineHeight: 1 }}>
        <div
          style={{
            fontSize: fs,
            fontWeight: 600,
            letterSpacing: fs * 0.22,
            color: darkText ? PURPLE_L : PURPLE,
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
            color: textColor,
            letterSpacing: -0.5,
            lineHeight: 0.9,
          }}
        >
          Combo
        </div>
      </div>
    </div>
  )
}
