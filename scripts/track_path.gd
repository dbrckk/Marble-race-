extends RefCounted
## Shared deterministic centerline for all course physics, AI, and visual systems.
## Geometry remains downhill in world -Z so legacy race timers and ranking
## are unchanged. Fade both ends for safe start grid and finish alignment.
const COURSE_START_Z := 12.0
const COURSE_SPAN := 210.0
# The geometry and physics share these relief curves, rather than drawing
# a fake rollercoaster behind a perfectly flat racing surface.
const AMPLITUDES := [1.1,1.9,2.65]
const WAVELENGTHS := [32.0,28.0,26.0]
# Secondary, biome-specific turns produce recognizable sequences of chicanes
# instead of three scaled versions of one sine-wave course. The smooth
# endpoint envelope keeps the start grid and finish gate aligned.
# The Forge chicane frequency/amplitude are bounded by real rail seam
# overlap, not a visual-only spline. Stronger 4-cycle oscillations shifted
# consecutive 12-metre modules by 2.52m and failed physical guard checks.
const SECONDARY_AMPLITUDES := [0.36,0.78,0.60]
const SECONDARY_CYCLES := [2.0,3.0,3.0]
const SECONDARY_PHASES := [0.15,0.42,0.72]
const BASE_SLOPE := 0.085
const RELIEF_AMPLITUDES := [0.55,1.10,1.45]
const RELIEF_CYCLES := [1.45,2.0,2.5]
const RELIEF_PHASES := [0.06,0.13,0.22]

static func height_at(z: float, track: int) -> float:
    # A continuous smooth physical course profile. Fade to the original
    # downhill grade at BOTH endpoints so the grid and finish remain level
    # with their exterior surroundings and the route stays traversable.
    var selected: int = clampi(track,0,2)
    var progress: float = clampf((COURSE_START_Z-z)/COURSE_SPAN,0.0,1.0)
    var envelope: float = pow(sin(PI*progress),2.0)
    var crest: float = RELIEF_AMPLITUDES[selected]*envelope*sin(
        TAU*(RELIEF_CYCLES[selected]*progress+RELIEF_PHASES[selected]))
    return z*BASE_SLOPE+crest

static func grade_at(z: float, track: int) -> float:
    # Local derivative determines the angle of every *physical* plank,
    # safety rail, shortcut deck and visual decoration. Finite differences
    # avoid mismatched hand-coded derivative and sample an exact same curve.
    return (height_at(z+0.5,track)-height_at(z-0.5,track))

static func center_at(z: float, track: int) -> float:
    var which: int = clampi(track,0,2)
    var travelled: float = clampf(COURSE_START_Z-z,0.0,COURSE_SPAN)
    var envelope: float = sin(PI*travelled/COURSE_SPAN)
    var progress: float = travelled/COURSE_SPAN
    var secondary_envelope: float = envelope*envelope
    var primary: float = AMPLITUDES[which]*sin(travelled/WAVELENGTHS[which])*envelope
    var chicane: float = SECONDARY_AMPLITUDES[which]*secondary_envelope*sin(
        TAU*(SECONDARY_CYCLES[which]*progress+SECONDARY_PHASES[which]))
    return primary+chicane

static func section_center(section: int, track: int) -> float:
    return center_at(8.0-float(section)*12.0,track)

static func inside_safe_line(position: Vector3, track: int) -> bool:
    return absf(position.x-center_at(position.z,track)) < 6.52

static func section_seam_z(section: int) -> float:
    return 2.0-float(section)*12.0

static func seam_drift(section: int, track: int) -> float:
    return section_center(section+1,track)-section_center(section,track)
