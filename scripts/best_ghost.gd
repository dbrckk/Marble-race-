extends Node3D
## Race against a previous personal finish, with no physics, networking, or accounts.
## Sampling 10 Hz caps storage and rendering work on Android.
const SAVE_PATH := "user://marble_ghosts.cfg"
const SAMPLE_SECONDS := 0.10
const MAX_SAMPLES := 1800
const MAX_WORLD := 10000.0

var replay_samples := PackedVector3Array()
var recording := PackedVector3Array()
var best_time := 0.0
var replay_available := false
var race_enabled := false
var recording_elapsed := 0.0
var key := ""
var sphere: MeshInstance3D

func _ready() -> void:
    sphere = MeshInstance3D.new()
    sphere.name = "PersonalBestGhost"
    var mesh := SphereMesh.new()
    mesh.radius = 0.36
    mesh.height = 0.72
    mesh.radial_segments = 16
    mesh.rings = 8
    sphere.mesh = mesh
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.albedo_color = Color(0.38,0.94,1.0,0.31)
    material.emission_enabled = true
    material.emission = Color(0.1,0.45,0.6)
    material.emission_energy_multiplier = 0.55
    material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
    sphere.material_override = material
    add_child(sphere)
    visible = false

func storage_key(track: int, variation: int, perk: String) -> String:
    return "track_%d_variation_%d_perk_%s" % [
        clampi(track,0,2),clampi(variation,0,2),perk.sha256_text().substr(0,10)
    ]

func begin(track: int, variation: int, perk: String, enabled: bool) -> void:
    recording.clear()
    replay_samples.clear()
    best_time = 0.0
    replay_available = false
    recording_elapsed = 0.0
    race_enabled = enabled
    visible = false
    key = storage_key(track,variation,perk)
    if not enabled:
        return
    var cfg := ConfigFile.new()
    if cfg.load(SAVE_PATH) != OK:
        return
    var stored_time: float = float(cfg.get_value(key,"best_time",0.0))
    var samples: Variant = cfg.get_value(key,"points",PackedVector3Array())
    if stored_time <= 0.0 or stored_time > 500.0 or not (samples is PackedVector3Array):
        return
    if samples.size() < 3 or samples.size() > MAX_SAMPLES:
        return
    for position in samples:
        if not position.is_finite() or position.length() > MAX_WORLD:
            return
    replay_samples = samples
    best_time = stored_time
    replay_available = true

func tick(elapsed: float, current_pos: Vector3, quality: int) -> void:
    if not race_enabled:
        visible = false
        return
    if is_finite(elapsed) and elapsed >= 0.0 and elapsed <= 180.0 and (
        current_pos.is_finite() and current_pos.length() <= MAX_WORLD
    ):
        if recording.is_empty():
            recording.append(current_pos)
        while recording_elapsed + SAMPLE_SECONDS <= elapsed and recording.size() < MAX_SAMPLES:
            recording_elapsed += SAMPLE_SECONDS
            recording.append(current_pos)
    visible = replay_available and quality > 0 and elapsed < best_time and replay_samples.size() >= 3
    if visible:
        var frame: float = clampf(elapsed / SAMPLE_SECONDS,0.0,float(replay_samples.size()-1))
        var index: int = mini(int(floorf(frame)),replay_samples.size()-2)
        sphere.global_position = replay_samples[index].lerp(
            replay_samples[index+1],frame-float(index))

func gap_text(player_pos: Vector3) -> String:
    if not replay_available:
        return ""
    if not visible:
        return "YOUR BEST %.1fs" % best_time
    var metres: int = mini(999,int(roundf(absf(player_pos.z-sphere.global_position.z))))
    if player_pos.z < sphere.global_position.z:
        return "YOU AHEAD %dm  |  BEST %.1fs" % [metres,best_time]
    return "GHOST AHEAD %dm  |  BEST %.1fs" % [metres,best_time]

func finish(elapsed: float, completed: bool) -> bool:
    visible = false
    if not race_enabled or not completed or not is_finite(elapsed) or elapsed < 0.1:
        return false
    if recording.size() < 3 or recording.size() >= MAX_SAMPLES:
        return false
    if best_time > 0.0 and elapsed >= best_time:
        return false
    # If this completes, it becomes the next ghost for the same course layout and perk.
    var cfg := ConfigFile.new()
    cfg.load(SAVE_PATH)
    cfg.set_value(key,"best_time",elapsed)
    cfg.set_value(key,"points",recording)
    if cfg.save(SAVE_PATH) != OK:
        return false
    best_time = elapsed
    return true

func stop() -> void:
    race_enabled = false
    visible = false
    recording.clear()
