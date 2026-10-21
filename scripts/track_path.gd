extends RefCounted
## Shared deterministic centerline for all course physics, AI, and visual systems.
## Geometry remains downhill in world -Z so legacy race timers and ranking
## are unchanged. Fade both ends for safe start grid and finish alignment.
const COURSE_START_Z := 12.0
const COURSE_SPAN := 210.0
const AMPLITUDES := [0.85,1.45,2.15]
const WAVELENGTHS := [34.0,28.0,25.0]

static func center_at(z: float, track: int) -> float:
    var which: int = clampi(track,0,2)
    var travelled: float = clampf(COURSE_START_Z-z,0.0,COURSE_SPAN)
    var envelope: float = sin(PI*travelled/COURSE_SPAN)
    return AMPLITUDES[which]*sin(travelled/WAVELENGTHS[which])*envelope

static func section_center(section: int, track: int) -> float:
    return center_at(8.0-float(section)*12.0,track)

static func inside_safe_line(position: Vector3, track: int) -> bool:
    return absf(position.x-center_at(position.z,track)) < 6.52

static func section_seam_z(section: int) -> float:
    return 2.0-float(section)*12.0

static func seam_drift(section: int, track: int) -> float:
    return section_center(section+1,track)-section_center(section,track)
