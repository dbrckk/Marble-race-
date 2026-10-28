extends Node3D
## Offline CC0 Foley (Kenney), plus original composed loop and tonal race cues.
## Eight pooled voice channels prevent hard-cutting a sound every time a marble collides.
const RaceFeedback = preload("res://scripts/race_feedback.gd")
const SCORE = preload("res://assets/audio/music/marble_workshop.ogg")
const ROLL = preload("res://assets/audio/sfx/wood_roll.ogg")
const AIR = preload("res://assets/audio/sfx/airrush.ogg")
const PERCUSSION = preload("res://assets/audio/music/pace_percussion.ogg")
const FANFARE = preload("res://assets/audio/sfx/fanfare.ogg")
const UI_CLICK = preload("res://assets/audio/sfx/ui_click.ogg")
const UI_SELECT = preload("res://assets/audio/sfx/ui_select.ogg")
const WOOD_HITS = [
    preload("res://assets/audio/sfx/wood_1.ogg"),
    preload("res://assets/audio/sfx/wood_2.ogg"),
    preload("res://assets/audio/sfx/wood_3.ogg")
]
const BUMPER_HITS = [
    preload("res://assets/audio/sfx/bumper_soft.ogg"),
    preload("res://assets/audio/sfx/bumper_hard.ogg")
]
const METAL_HITS = [
    preload("res://assets/audio/sfx/metal_hit_1.ogg"),
    preload("res://assets/audio/sfx/metal_hit_2.ogg")
]
const GLASS_HITS = [
    preload("res://assets/audio/sfx/glass_1.ogg"),
    preload("res://assets/audio/sfx/glass_2.ogg"),
    preload("res://assets/audio/sfx/glass_3.ogg")
]
const TONES = {
    "count": preload("res://assets/audio/sfx/count.ogg"),
    "start": preload("res://assets/audio/sfx/start.ogg"),
    "checkpoint": preload("res://assets/audio/sfx/checkpoint.ogg"),
    "finish": preload("res://assets/audio/sfx/finish.ogg"),
    "boost": preload("res://assets/audio/sfx/boost.ogg")
}
var music: AudioStreamPlayer
var rolling: AudioStreamPlayer3D
var air: AudioStreamPlayer
var percussion: AudioStreamPlayer
var race_active := false
var finish_progress := 0.0
var loudness_offset := 0.0
var haptic_cooldown := 0.0
var channels: Array[AudioStreamPlayer] = []
var spatial_channels: Array[AudioStreamPlayer3D] = []
var mechanism: AudioStreamPlayer3D
var moving_props: Array[Node3D] = []
var mechanism_timer := 0.0
var collision_duck := 0.0
# Play at most one predictive danger cue for each real timed gate per race.
var warned_timed_gates: Dictionary = {}
var target_marble: RigidBody3D
var enabled := true
var collision_delay := 0.0
var boost_delay := 0.0
var current_channel := 0
var music_target_db := -22.0
var track_theme := 0
var pack_pressure_target := 0.0
var pack_pressure := 0.0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
    rng.seed = 5721
    var cfg=ConfigFile.new()
    if cfg.load("user://marble_settings.cfg") == OK:
        enabled = bool(cfg.get_value("audio","enabled",true))
    music = AudioStreamPlayer.new()
    music.name = "OriginalSoundtrack"
    music.stream = SCORE
    if music.stream is AudioStreamOggVorbis:
        (music.stream as AudioStreamOggVorbis).loop = true
    music.volume_db = -24.0 if enabled else -80.0
    add_child(music)
    music.play()
    percussion = AudioStreamPlayer.new()
    percussion.name = "AdaptiveRacePercussion"
    percussion.stream = PERCUSSION
    if percussion.stream is AudioStreamOggVorbis:
        (percussion.stream as AudioStreamOggVorbis).loop = true
    percussion.volume_db = -75.0
    add_child(percussion)
    percussion.play()
    air = AudioStreamPlayer.new()
    air.name = "WindAtHighSpeed"
    air.stream = AIR
    if air.stream is AudioStreamOggVorbis:
        (air.stream as AudioStreamOggVorbis).loop = true
    air.volume_db = -75.0
    add_child(air)
    air.play()
    rolling = AudioStreamPlayer3D.new()
    rolling.name = "WoodenMarbleRolling"
    rolling.stream = ROLL
    if rolling.stream is AudioStreamOggVorbis:
        (rolling.stream as AudioStreamOggVorbis).loop = true
    rolling.volume_db = -55
    rolling.max_distance = 24.0
    rolling.unit_size = 3.0
    add_child(rolling)
    mechanism = AudioStreamPlayer3D.new()
    mechanism.name = "KineticToyMotor"
    mechanism.stream = preload("res://assets/audio/sfx/mechanism_loop.ogg")
    if mechanism.stream is AudioStreamOggVorbis:
        (mechanism.stream as AudioStreamOggVorbis).loop = true
    mechanism.volume_db = -80.0
    mechanism.max_distance = 28.0
    mechanism.unit_size = 4.0
    add_child(mechanism)
    mechanism.play()
    for n in range(7):
        var spatial := AudioStreamPlayer3D.new()
        spatial.name = "ImpactSpatial_%02d" % n
        spatial.max_distance = 34.0
        spatial.unit_size = 4.0
        spatial.volume_db = -25.0
        add_child(spatial)
        spatial_channels.append(spatial)
    for n in range(10):
        var ch = AudioStreamPlayer.new()
        ch.name = "SFX_%02d" % n
        ch.volume_db = -16
        add_child(ch)
        channels.append(ch)

func bind_mechanisms(props: Array[Node3D]) -> void:
    moving_props = props.duplicate()

func bind_marble(marble: RigidBody3D) -> void:
    target_marble = marble
    if rolling.playing:
        rolling.stop()
    rolling.play()
    if not marble.body_entered.is_connected(_on_marble_collision):
        marble.body_entered.connect(_on_marble_collision)

static func pack_percussion_lift(pressure: float) -> float:
    return 5.5*clampf(pressure,0.0,1.0) if is_finite(pressure) else 0.0

static func pack_wind_lift(pressure: float) -> float:
    return 2.0*clampf(pressure,0.0,1.0) if is_finite(pressure) else 0.0

func set_pack_pressure(value: float) -> void:
    # Never alters physics, coins, finish positions or a multiplayer result.
    # Only one sampled scalar (0-1) is needed, not forty audio players.
    pack_pressure_target = clampf(value,0.0,1.0) if is_finite(value) else 0.0

func _process(delta: float) -> void:
    # Exponential smoothing makes the score breathe smoothly even as 40
    # marbles weave past each other or Android oscillates between 30/60 Hz.
    pack_pressure = lerpf(pack_pressure,pack_pressure_target,
        RaceFeedback.smooth_factor(delta,3.7))
    collision_delay = maxf(0.0,collision_delay-delta)
    boost_delay = maxf(0.0,boost_delay-delta)
    haptic_cooldown = maxf(0.0,haptic_cooldown-delta)
    collision_duck = move_toward(collision_duck,0.0,delta*9.0)
    music.volume_db = move_toward(music.volume_db,music_target_db + loudness_offset - collision_duck,delta*7.0)
    mechanism_timer -= delta
    if mechanism_timer <= 0.0:
        mechanism_timer = 0.20
        _update_mechanism_sound()
    var pace_target := -72.0
    var air_target := -72.0
    if enabled and race_active and is_instance_valid(target_marble):
        var speed_now = target_marble.linear_velocity.length()
        var energy = clampf((speed_now-3.0)/11.0,0.0,1.0)
        pace_target = -36.0 + energy*14.0 + finish_progress*5.0 + (
            [-1.0,-3.0,2.0][track_theme])+pack_percussion_lift(pack_pressure)
        air_target = -52.0 + energy*25.0+pack_wind_lift(pack_pressure)
        air.pitch_scale = lerpf(0.85,1.5,energy) * [1.0,0.94,1.08][track_theme]
    if not enabled:
        pace_target = -80.0
        air_target = -80.0
    percussion.volume_db = move_toward(percussion.volume_db,pace_target,delta*11.0)
    air.volume_db = move_toward(air.volume_db,air_target,delta*13.0)
    if not is_instance_valid(target_marble) or target_marble.freeze:
        rolling.volume_db = move_toward(rolling.volume_db,-60.0,delta*45.0)
        return
    if not enabled:
        rolling.volume_db = -80.0
        return
    rolling.global_position = target_marble.global_position
    var speed = target_marble.linear_velocity.length()
    rolling.volume_db = move_toward(rolling.volume_db,clampf(-37.0+speed*1.45,-46.0,-13.0),delta*26)
    rolling.pitch_scale = clampf(0.63+speed*0.06,0.73,1.65)

func _update_mechanism_sound() -> void:
    if not enabled or not race_active or not is_instance_valid(target_marble):
        mechanism.volume_db = -80.0
        return
    var best_dist := 30.0
    var nearest: Node3D = null
    for prop in moving_props:
        if not is_instance_valid(prop):
            continue
        var dist := prop.global_position.distance_to(target_marble.global_position)
        if dist < best_dist:
            best_dist = dist
            nearest = prop
    if nearest:
        mechanism.global_position = nearest.global_position
        mechanism.volume_db = -24.0 + clampf(best_dist* -0.34,-16.0,0.0)
        mechanism.pitch_scale = clampf(float(nearest.get_meta("spin_speed",1.1)),0.82,1.3)
    else:
        mechanism.volume_db = -80.0

func _spatial_voice(stream: AudioStream, at: Vector3, loudness: float, pitch: float) -> void:
    if not enabled:
        return
    var channel: AudioStreamPlayer3D = null
    for speaker in spatial_channels:
        if not speaker.playing:
            channel = speaker
            break
    if channel == null:
        channel = spatial_channels[rng.randi_range(0,spatial_channels.size()-1)]
    channel.global_position = at
    channel.stream = stream
    channel.volume_db = loudness
    channel.pitch_scale = pitch
    channel.play()

func _voice(stream: AudioStream, loudness := -10.0, pitch := 1.0) -> void:
    if not enabled:
        return
    var p = channels[current_channel]
    current_channel = (current_channel + 1) % channels.size()
    p.stream = stream
    p.pitch_scale = pitch
    p.volume_db = loudness
    p.play()

func ui_click() -> void:
    _voice(UI_CLICK,-18.0,1.0)

func ui_select() -> void:
    _voice(UI_SELECT,-12.0,1.04)

func tone(key: String) -> void:
    if TONES.has(key):
        _voice(TONES[key],-13.0,1.0)

func set_track_theme(track: int) -> void:
    track_theme = clampi(track,0,2)
    # Distinct playback treatment per biome without introducing copyrighted audio.
    # Keep tempo variance subtle enough to preserve the score's pitch character.
    if is_instance_valid(music):
        music.pitch_scale = [1.0,0.94,1.07][track_theme]
    if is_instance_valid(percussion):
        percussion.pitch_scale = [1.0,0.89,1.13][track_theme]
    if is_instance_valid(air):
        air.pitch_scale = [1.0,0.93,1.10][track_theme]

func begin_race() -> void:
    warned_timed_gates.clear()
    pack_pressure = 0.0
    pack_pressure_target = 0.0
    music_target_db = ([-20.0,-22.5,-18.5][track_theme]) if enabled else -80.0
    race_active = true
    finish_progress = 0.0
    tone("start")

func menu_music() -> void:
    pack_pressure = 0.0
    pack_pressure_target = 0.0
    music_target_db = -23.0 if enabled else -80.0
    race_active = false
    finish_progress = 0.0
    target_marble = null

func update_progress(ratio: float) -> void:
    finish_progress = clampf(ratio,0.0,1.0)

func finish_fanfare() -> void:
    _voice(FANFARE,-12.0,1.0)

func race_moment(kind: String) -> void:
    # Reserved, quiet licensed cues. The existing boost and finishing
    # fanfare remain authoritative over these optional race-direction pings.
    if not enabled:
        return
    match kind:
        "overtake":
            _voice(UI_SELECT,-22.0,1.30)
            _voice(TONES["checkpoint"],-25.0,1.16)
        "duel":
            # One short, quiet crowd-race ping per truly sustained side duel.
            # Existing licensed UI sample, no new persistent mixer channel.
            _voice(UI_SELECT,-25.0,1.06)
        "final_stretch":
            _voice(TONES["checkpoint"],-23.0,0.86)
        "photo_finish":
            _voice(TONES["finish"],-19.0,1.28)
        "slipstream":
            # Subtle engagement cue; reuse the original licensed race sound
            # rather than streaming or adding a loud continuous effect.
            _voice(TONES["boost"],-24.0,0.84)

func warn_timed_gate(index: int, blocking: bool) -> void:
    # A short original countdown tone makes a single danger cue per gate,
    # avoiding irritating warning loops or adding any audio mixer voices.
    # Open Forge pistons are deliberately silent: never warn of false danger.
    if not enabled or not race_active or not blocking or index < 0 or (
        warned_timed_gates.has(index)):
        return
    warned_timed_gates[index] = true
    _voice(TONES["count"],-20.0,[1.26,1.03,0.84][track_theme])

func course_event(kind: String) -> void:
    match kind:
        "speed":
            _voice(TONES["boost"],-14.0,0.91)
        "ice":
            _voice(GLASS_HITS[0],-17.0,1.20)
        "vent":
            _voice(METAL_HITS[1],-10.0,0.77)
        "shortcut":
            _voice(TONES["boost"],-10.0,1.35)
            _voice(TONES["checkpoint"],-15.0,1.02)
        "jump":
            _voice(TONES["boost"],-18.0,1.58)
            _voice(GLASS_HITS[0],-22.0,1.30)
        "apex":
            # Two already-bundled cues, no extra player or streaming asset.
            _voice(TONES["checkpoint"],-17.0,1.52)
            _voice(TONES["boost"],-21.0,1.25)
        "near_miss":
            _voice(TONES["checkpoint"],-17.0,1.33)
            _voice(TONES["boost"],-20.0,1.09)
        "near_miss_precision":
            _voice(TONES["checkpoint"],-17.0,1.46)
            _voice(TONES["boost"],-22.0,1.20)
        "near_miss_chain":
            _voice(TONES["checkpoint"],-16.0,1.60)
            _voice(TONES["boost"],-19.0,1.30)

func item_pickup(kind: String) -> void:
    # Distinct pitch and voice combination of existing bundled audio.
    match kind:
        "turbo":
            _voice(TONES["boost"],-7.0,1.28)
        "spring":
            _voice(TONES["checkpoint"],-10.0,1.48)
        "pulse":
            _voice(BUMPER_HITS[1],-8.0,0.85)
        _:
            _voice(UI_SELECT,-9.0,1.12)

func boost() -> void:
    if boost_delay <= 0.0:
        tone("boost")
        boost_delay = 1.5

func _on_marble_collision(other: Node) -> void:
    if collision_delay > 0.0 or not is_instance_valid(target_marble):
        return
    var intensity: float = RaceFeedback.impact_intensity(
        target_marble.linear_velocity,other)
    if intensity < 0.14:
        return
    var contact: String = RaceFeedback.collision_kind(other)
    collision_delay = RaceFeedback.feedback_interval(intensity)
    var samples: Array
    match contact:
        "mechanism":
            samples = METAL_HITS
        "bumper":
            samples = BUMPER_HITS
        "glass":
            samples = GLASS_HITS
        _:
            samples = WOOD_HITS
    if intensity > 0.40 and haptic_cooldown <= 0.0 and OS.has_feature("mobile"):
        # Vibration follows actual relative contact severity, not simply
        # rolling speed. Ignore repeated harmless board touch events.
        Input.vibrate_handheld(12 if intensity < 0.70 else 26)
        haptic_cooldown = 0.48
    var idx: int = rng.randi_range(0,samples.size()-1)
    if contact == "bumper" and other.name.begins_with("PinballKicker_"):
        # The existing soft/hard CC0 samples now distinguish a true
        # spring-post tap from a strong rebound. Keep the same voice pool.
        idx = 1 if intensity >= 0.55 else 0
    collision_duck = maxf(collision_duck,lerpf(0.4,2.8,intensity))
    _spatial_voice(samples[idx],target_marble.global_position,
        lerpf(-24.0,-8.0,intensity),rng.randf_range(0.94,1.08)*
        lerpf(0.90,1.08,intensity))

func toggle_sound() -> bool:
    enabled = not enabled
    var cfg = ConfigFile.new()
    cfg.load("user://marble_settings.cfg")
    cfg.set_value("audio","enabled",enabled)
    cfg.save("user://marble_settings.cfg")
    music_target_db = -80 if not enabled else -19
    music.volume_db = music_target_db
    percussion.volume_db = -80.0 if not enabled else -45.0
    air.volume_db = -80.0 if not enabled else -50.0
    rolling.volume_db = -80 if not enabled else -36
    mechanism.volume_db = -80 if not enabled else -30
    if not enabled:
        for speaker in spatial_channels:
            speaker.stop()
    return enabled
