import { useRef, useMemo } from 'react'
import { useFrame } from '@react-three/fiber'
import * as THREE from 'three'

// ── Timing (seconds) ──────────────────────────────────────────────────────────
const T_TAP1  = 0.35   // foot meets ball on first juggle
const T_ATW_S = 0.70   // foot arrives at ATW start
const T_ATW_E = 2.10   // ATW complete (1.40 s = 1 rev)
const T_TAP2  = 2.45   // foot meets ball on second juggle
const T_END   = 2.80   // animation done

// ── Physical dimensions ───────────────────────────────────────────────────────
const BALL_R    = 0.115   // ball sphere radius
const FOOT_R    = 0.042   // foot capsule radius
// ATW orbit radius — must exceed BALL_R + FOOT_R + clearance = 0.197
const RADIUS    = 0.25

const THIGH = 0.42
const SHIN  = 0.42
const KICK_HIP = new THREE.Vector3(0.12, 0.85, 0)

// ── Key world positions ───────────────────────────────────────────────────────
const BALL_X = 0.12
const BALL_Z = 0.31         // ball in front of body
// During juggle the ankle sits 0.08m BEHIND the ball in Z so the foot capsule
// (whose centre is 0.08m forward of the ankle) sits directly under the ball.
// This guarantees the shin endpoint never coincides with the ball's XZ position.
const FOOT_Z_TAP  = BALL_Z - 0.08   // = 0.23  ankle z during juggle tap
const FOOT_Z_REST = 0.20             // ankle z at ground rest (within IK reach)

const BALL_HOVER_Y = 0.30
const BALL_TAP_Y  = BALL_HOVER_Y + 0.08   // = 0.38
const FOOT_TAP_Y  = BALL_TAP_Y - BALL_R - FOOT_R   // = 0.223
const FOOT_REST_Y = 0.04
const BALL_REST_Y = FOOT_REST_Y + FOOT_R + BALL_R  // = 0.197

type XYZ = { x: number; y: number; z: number }
type P3  = [number, number, number]

const FOOT_REST: XYZ = { x: BALL_X, y: FOOT_REST_Y, z: FOOT_Z_REST }
const FOOT_TAP:  XYZ = { x: BALL_X, y: FOOT_TAP_Y,  z: FOOT_Z_TAP }
// ATW start: ankle directly in front of ball centre
const FOOT_ATW:  XYZ = { x: BALL_X, y: BALL_HOVER_Y, z: BALL_Z + RADIUS }

const BALL_REST:  XYZ = { x: BALL_X, y: BALL_REST_Y,  z: BALL_Z }
const BALL_TAP:   XYZ = { x: BALL_X, y: BALL_TAP_Y,   z: BALL_Z }
const BALL_HOVER: XYZ = { x: BALL_X, y: BALL_HOVER_Y, z: BALL_Z }

// ── Scratch vectors ───────────────────────────────────────────────────────────
const _foot     = new THREE.Vector3()
const _knee     = new THREE.Vector3()
const _mid      = new THREE.Vector3()
const _dir      = new THREE.Vector3()
const _htf      = new THREE.Vector3()
const _bendHint = new THREE.Vector3(0.1, 0.3, -1).normalize()
const _perp     = new THREE.Vector3()
const _UP       = new THREE.Vector3(0, 1, 0)

const C = { skin: '#f5c5a3', shirt: '#4338ca', pants: '#1e293b', shoe: '#0f172a' } as const

// ── Easing / lerp ─────────────────────────────────────────────────────────────
function ease(t: number) {
  const c = Math.max(0, Math.min(1, t))
  return c * c * (3 - 2 * c)
}
function lerp3(a: XYZ, b: XYZ, t: number): XYZ {
  const e = ease(t)
  return { x: a.x + (b.x - a.x) * e, y: a.y + (b.y - a.y) * e, z: a.z + (b.z - a.z) * e }
}

// ── Animation state machine ───────────────────────────────────────────────────
function getPositions(t: number): { foot: XYZ; ball: XYZ } {
  if (t <= 0)     return { foot: FOOT_REST, ball: BALL_REST }
  if (t >= T_END) return { foot: FOOT_REST, ball: BALL_REST }

  // Phase 1: foot rises, ball tracked on foot top → tap peak
  if (t < T_TAP1) {
    const tn   = t / T_TAP1
    const foot = lerp3(FOOT_REST, FOOT_TAP, tn)
    return { foot, ball: lerp3(BALL_REST, BALL_TAP, tn) }
  }

  // Phase 2: ball floats to hover height, foot moves to ATW start
  if (t < T_ATW_S) {
    const tn = (t - T_TAP1) / (T_ATW_S - T_TAP1)
    return { foot: lerp3(FOOT_TAP, FOOT_ATW, tn), ball: lerp3(BALL_TAP, BALL_HOVER, tn) }
  }

  // Phase 3: ATW — foot orbits, ball hovers
  if (t < T_ATW_E) {
    const tn    = (t - T_ATW_S) / (T_ATW_E - T_ATW_S)
    const angle = tn * Math.PI * 2
    // Circle starts in front of ball (cos(0)=1 → z+RADIUS) and sweeps full loop
    return {
      foot: {
        x: BALL_X - RADIUS * Math.sin(angle),
        y: BALL_HOVER_Y,
        z: BALL_Z + RADIUS * Math.cos(angle),
      },
      ball: BALL_HOVER,
    }
  }

  // Phase 4: foot returns from ATW end to tap position, ball rises to tap height
  if (t < T_TAP2) {
    const tn = (t - T_ATW_E) / (T_TAP2 - T_ATW_E)
    return { foot: lerp3(FOOT_ATW, FOOT_TAP, tn), ball: lerp3(BALL_HOVER, BALL_TAP, tn) }
  }

  // Phase 5: both return to rest
  const tn   = (t - T_TAP2) / (T_END - T_TAP2)
  const foot = lerp3(FOOT_TAP, FOOT_REST, tn)
  return { foot, ball: lerp3(BALL_TAP, BALL_REST, tn) }
}

// ── 2-bone IK ─────────────────────────────────────────────────────────────────
function solveKnee(fx: number, fy: number, fz: number) {
  _foot.set(fx, fy, fz)
  _htf.subVectors(_foot, KICK_HIP)
  const raw = _htf.length()
  const d   = Math.max(Math.abs(THIGH - SHIN) + 0.01, Math.min(THIGH + SHIN - 0.01, raw))
  const cosA = (THIGH * THIGH + d * d - SHIN * SHIN) / (2 * THIGH * d)
  const alpha = Math.acos(Math.max(-1, Math.min(1, cosA)))
  _dir.copy(_htf).normalize()
  _perp.copy(_bendHint).addScaledVector(_dir, -_bendHint.dot(_dir)).normalize()
  _knee
    .copy(KICK_HIP)
    .addScaledVector(_dir, THIGH * Math.cos(alpha))
    .addScaledVector(_perp, THIGH * Math.sin(alpha))
}

// ── ATW animation controller ──────────────────────────────────────────────────
function ATWAnimation({ playing, onComplete }: { playing: boolean; onComplete: () => void }) {
  const thighRef   = useRef<THREE.Mesh>(null!)
  const shinRef    = useRef<THREE.Mesh>(null!)
  const kneeRef    = useRef<THREE.Mesh>(null!)
  const footRef    = useRef<THREE.Group>(null!)
  const ballRef    = useRef<THREE.Mesh>(null!)
  const time       = useRef(0)
  const wasPlaying = useRef(false)
  const completed  = useRef(false)

  useFrame((_, dt) => {
    if (!thighRef.current || !shinRef.current || !kneeRef.current || !footRef.current || !ballRef.current) return

    if (playing && !wasPlaying.current) {
      time.current  = 0
      completed.current = false
    }
    wasPlaying.current = playing

    if (playing && !completed.current) {
      time.current += dt
      if (time.current >= T_END) {
        completed.current = true
        onComplete()
      }
    }

    const t = Math.min(time.current, T_END)
    const { foot, ball } = getPositions(t)

    // ── Kicking leg IK ────────────────────────────────────────────────────────
    solveKnee(foot.x, foot.y, foot.z)

    _mid.addVectors(KICK_HIP, _knee).multiplyScalar(0.5)
    thighRef.current.position.copy(_mid)
    _dir.subVectors(_knee, KICK_HIP).normalize()
    thighRef.current.quaternion.setFromUnitVectors(_UP, _dir)

    _mid.addVectors(_knee, _foot).multiplyScalar(0.5)
    shinRef.current.position.copy(_mid)
    _dir.subVectors(_foot, _knee).normalize()
    shinRef.current.quaternion.setFromUnitVectors(_UP, _dir)

    kneeRef.current.position.copy(_knee)
    footRef.current.position.copy(_foot)

    // During ATW: rotate foot TANGENT to circle so it never points toward ball
    if (t >= T_ATW_S && t <= T_ATW_E) {
      const tn    = (t - T_ATW_S) / (T_ATW_E - T_ATW_S)
      const angle = tn * Math.PI * 2
      // Tangent direction of the circle: d/d(angle) of (−sin,0,+cos) = (−cos,0,−sin)
      // We want local-Z to point along that direction:
      // rotation.y = atan2(tangent.x, tangent.z) = atan2(−cos(a), −sin(a))
      footRef.current.rotation.y = Math.atan2(-Math.cos(angle), -Math.sin(angle))
    } else {
      footRef.current.rotation.y = 0
    }

    // ── Ball ──────────────────────────────────────────────────────────────────
    ballRef.current.position.set(ball.x, ball.y, ball.z)
    if (playing && !completed.current) {
      ballRef.current.rotation.x += dt * 2.5
      ballRef.current.rotation.z += dt * 1.5
    }
  })

  const thighCapLen = Math.max(0.001, THIGH - 2 * 0.056)
  const shinCapLen  = Math.max(0.001, SHIN  - 2 * 0.046)

  return (
    <group>
      <mesh ref={thighRef}>
        <capsuleGeometry args={[0.056, thighCapLen, 4, 10]} />
        <meshStandardMaterial color={C.pants} roughness={0.7} />
      </mesh>
      <mesh ref={shinRef}>
        <capsuleGeometry args={[0.046, shinCapLen, 4, 10]} />
        <meshStandardMaterial color={C.pants} roughness={0.7} />
      </mesh>
      <mesh ref={kneeRef}>
        <sphereGeometry args={[0.052, 12, 12]} />
        <meshStandardMaterial color={C.pants} roughness={0.7} />
      </mesh>
      <group ref={footRef}>
        {/* Foot capsule pointing forward (+Z) from ankle */}
        <mesh rotation={[Math.PI / 2, 0, 0]} position={[0, 0, 0.08]}>
          <capsuleGeometry args={[FOOT_R, 0.13, 4, 8]} />
          <meshStandardMaterial color={C.shoe} roughness={0.9} />
        </mesh>
        {/* Ankle joint sphere */}
        <mesh>
          <sphereGeometry args={[0.042, 10, 10]} />
          <meshStandardMaterial color={C.pants} roughness={0.7} />
        </mesh>
      </group>
      <mesh ref={ballRef}>
        <sphereGeometry args={[BALL_R, 20, 20]} />
        <meshStandardMaterial color="#f8fafc" roughness={0.25} metalness={0.05} />
      </mesh>
    </group>
  )
}

// ── Static figure ─────────────────────────────────────────────────────────────

function Limb({ a, b, r = 0.04, color = C.pants }: { a: P3; b: P3; r?: number; color?: string }) {
  const av  = new THREE.Vector3(...a)
  const bv  = new THREE.Vector3(...b)
  const dir = bv.clone().sub(av)
  const len = dir.length()
  const mid = av.clone().lerp(bv, 0.5)
  const q   = new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0, 1, 0), dir.normalize())
  return (
    <mesh position={mid.toArray() as P3} quaternion={q}>
      <capsuleGeometry args={[r, Math.max(0.001, len - 2 * r), 4, 10]} />
      <meshStandardMaterial color={color} roughness={0.7} />
    </mesh>
  )
}

function Joint({ pos, r, color }: { pos: P3; r: number; color: string }) {
  return (
    <mesh position={pos}>
      <sphereGeometry args={[r, 12, 12]} />
      <meshStandardMaterial color={color} roughness={0.7} />
    </mesh>
  )
}

function Torso() {
  const points = useMemo(() => [
    new THREE.Vector2(0.005, 0.00),
    new THREE.Vector2(0.135, 0.02),
    new THREE.Vector2(0.130, 0.08),
    new THREE.Vector2(0.095, 0.26),
    new THREE.Vector2(0.115, 0.36),
    new THREE.Vector2(0.152, 0.50),
    new THREE.Vector2(0.158, 0.58),
    new THREE.Vector2(0.140, 0.62),
    new THREE.Vector2(0.005, 0.63),
  ], [])
  return (
    <group position={[0, 0.88, 0]}>
      <mesh>
        <latheGeometry args={[points, 20]} />
        <meshStandardMaterial color={C.shirt} side={THREE.DoubleSide} roughness={0.75} />
      </mesh>
    </group>
  )
}

function StaticFigure() {
  const SH_L: P3  = [-0.20, 1.48, 0.00]
  const SH_R: P3  = [ 0.20, 1.48, 0.00]
  const EL_L: P3  = [-0.37, 1.16, 0.06]
  const EL_R: P3  = [ 0.37, 1.16, 0.06]
  const HND_L: P3 = [-0.42, 0.88, 0.10]
  const HND_R: P3 = [ 0.42, 0.88, 0.10]
  const HIP_L: P3 = [-0.12, 0.88, 0.00]
  const KN_L: P3  = [-0.14, 0.44, 0.04]
  const AN_L: P3  = [-0.14, 0.04, 0.08]
  return (
    <group>
      <mesh position={[0, 1.69, 0]}>
        <sphereGeometry args={[0.155, 20, 20]} />
        <meshStandardMaterial color={C.skin} roughness={0.6} />
      </mesh>
      <Limb a={[0, 1.52, 0]} b={[0, 1.62, 0]} r={0.052} color={C.skin} />
      <Torso />
      <Joint pos={SH_L}  r={0.057} color={C.shirt} />
      <Joint pos={SH_R}  r={0.057} color={C.shirt} />
      <Limb  a={SH_L}   b={EL_L}  r={0.038} color={C.shirt} />
      <Joint pos={EL_L}  r={0.038} color={C.shirt} />
      <Limb  a={EL_L}   b={HND_L} r={0.032} color={C.skin}  />
      <Joint pos={HND_L} r={0.042} color={C.skin}  />
      <Limb  a={SH_R}   b={EL_R}  r={0.038} color={C.shirt} />
      <Joint pos={EL_R}  r={0.038} color={C.shirt} />
      <Limb  a={EL_R}   b={HND_R} r={0.032} color={C.skin}  />
      <Joint pos={HND_R} r={0.042} color={C.skin}  />
      <Joint pos={HIP_L} r={0.062} color={C.pants} />
      <Limb  a={HIP_L}  b={KN_L}  r={0.056} color={C.pants} />
      <Joint pos={KN_L}  r={0.052} color={C.pants} />
      <Limb  a={KN_L}   b={AN_L}  r={0.046} color={C.pants} />
      <Joint pos={AN_L}  r={0.042} color={C.pants} />
      <mesh position={[-0.13, 0.042, 0.17]} rotation={[Math.PI / 2, 0, 0]}>
        <capsuleGeometry args={[0.042, 0.13, 4, 8]} />
        <meshStandardMaterial color={C.shoe} roughness={0.9} />
      </mesh>
      <Joint pos={[0.12, 0.88, 0]} r={0.062} color={C.pants} />
    </group>
  )
}

// ── Exported scene content ────────────────────────────────────────────────────

export function AroundTheWorldContent({
  playing,
  onComplete,
}: {
  playing: boolean
  onComplete: () => void
}) {
  const ringPos: P3 = [BALL_X, BALL_HOVER_Y, BALL_Z]
  return (
    <>
      <color attach="background" args={['#0f172a']} />
      <ambientLight intensity={0.55} />
      <directionalLight position={[3, 5, 3]}   intensity={1.5} castShadow />
      <directionalLight position={[-2, 3, -1]} intensity={0.4} color="#a5b4fc" />
      <pointLight       position={[0, 2, 1]}   intensity={0.3} color="#e0e7ff" />

      <StaticFigure />
      <ATWAnimation playing={playing} onComplete={onComplete} />

      {/* Foot path ring — matches the actual ATW orbit radius */}
      <mesh position={ringPos} rotation={[Math.PI / 2, 0, 0]}>
        <torusGeometry args={[RADIUS, 0.007, 8, 64]} />
        <meshStandardMaterial color="#6366f1" emissive="#6366f1" emissiveIntensity={1} transparent opacity={0.55} />
      </mesh>

      <mesh rotation={[-Math.PI / 2, 0, 0]}>
        <planeGeometry args={[6, 6]} />
        <meshStandardMaterial color="#0f2040" roughness={1} />
      </mesh>
      <gridHelper args={[6, 12, '#1e3a5f', '#1e3a5f']} position={[0, 0.001, 0]} />
    </>
  )
}
