extends Node3D
## Offline CC0 Foley (Kenney), plus original composed loop and tonal race cues.
## Eight pooled voice channels prevent hard-cutting a sound every time a marble collides.
const RaceFeedback = preload("res://scripts/race_feedback.gd")
const HazardAudio = preload("res://scripts/hazard_audio.gd")
const SCORE = preload("res://assets/audio/music/marble_workshop.ogg")
# Three separately composed and mastered 12-bar scores, rather than the
# same backing track retuned for every world. All three resolve to the
# EXACT tempo/phrase grid of the existing original percussion stem.
const THEME_SCORES = [
    preload("res://assets/audio/music/woodland_overture.wav"),
    preload("res://assets/audio/music/glacier_prism.wav"),
    preload("res://assets/audio/music/forge_velocity.wav")
]
const THEME_TITLES := ["WOODLAND OVERTURE","GLACIER PRISM","FORGE VELOCITY"]
const MUSIC_FADE_SECONDS := 0.92
const ROLL = preload("res://assets/audio/sfx/wood_roll.ogg")
const BRIDGE_ROLLS := [
    preload("res://assets/audio/sfx/bridge_timber_roll.ogg"),
    preload("res://assets/audio/sfx/bridge_ice_roll.ogg"),
    preload("res://assets/audio/sfx/bridge_steel_roll.ogg")
]
const SURFACE_FADE_SECONDS := 0.22
const ICE_FADE_SECONDS := 0.12
const PASS_MIX_SECONDS := 0.42
const WARNED_BOOST_DB := -29.0
static var pickup_cues: Dictionary = {}
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
var music_previous: AudioStreamPlayer
var music_fade := 1.0
var rolling: AudioStreamPlayer
var bridge_rolling: AudioStreamPlayer
var roll_level_db := -60.0
var bridge_mix := 0.0
var on_bridge := false
var bridge_grounded := false
var on_ice := false
var ice_grounded := false
var ice_skid_target := 0.0
var ice_skid_mix := 0.0
var ice_entry_mix := 0.0
var control_recovery := 0.0
var exit_speed := 0.0
var replica_roll_speed := -1.0
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
var last_impact_intensity := 0.0
var pass_mix_seconds := 0.0
# Play at most one predictive danger cue for each real timed gate per race.
var warned_timed_gates: Dictionary = {}
var warned_vents: Dictionary = {}
var hazard_cues: Array[AudioStreamWAV] = []
var hazard_duck := 0.0
var hazard_cooldown := 0.0
var target_marble: RigidBody3D
var enabled := true
var collision_delay := 0.0
var boost_delay := 0.0
var turbo_requested := false
var turbo_mix := 0.0
var turn_target := 0.0
var turn_mix := 0.0
var current_channel := 0
var music_target_db := -22.0
var track_theme := 0
var flight_intensity_target := 0.0
var flight_intensity := 0.0
var pack_pressure_target := 0.0
var pack_pressure := 0.0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
    rng.seed = 5721
    if pickup_cues.is_empty():
        pickup_cues = {
            "turbo": HazardAudio.render([[0.0,0.23,420.0,1250.0,0.31],
                [0.10,0.18,650.0,1550.0,0.15]],0.30,"Pickup turbo",false,true),
            "spring": HazardAudio.render([[0.0,0.14,470.0,910.0,0.22],
                [0.105,0.16,1180.0,1440.0,0.30]],0.28,"Pickup jump",true),
            "pulse": HazardAudio.render([[0.0,0.25,560.0,260.0,0.42],
                [0.032,0.15,880.0,370.0,0.24]],0.28,"Pickup shockwave",false,true),
            "stabilizer": HazardAudio.render([[0.0,0.125,980.0,760.0,0.14],
                [0.10,0.17,740.0,740.0,0.18]],0.30,"Pickup steady dash",true)
        }
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
    music_previous = AudioStreamPlayer.new()
    music_previous.name = "CrossfadePreviousTheme"
    music_previous.volume_db = -80.0
    add_child(music_previous)
    # A WAV loops at its EXACT frame boundary, preserving the 112 BPM
    # percussion phase over long Android play sessions and repeat races.
    for score in THEME_SCORES:
        if score is AudioStreamWAV:
            score.loop_begin = 0
            # Godot imports WAV to QOA on Android by default. Byte size
            # therefore is NOT the PCM sample count: loop against the
            # decoded 12-bar frame boundary, or QOA loops at ~5 seconds.
            score.loop_end = int(round(score.get_length()*score.mix_rate))
            score.loop_mode = AudioStreamWAV.LOOP_FORWARD
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
    # The local player's rolling belongs to the driver. Changing cameras
    # should not move it further from the listener. Impacts stay spatial.
    rolling = AudioStreamPlayer.new()
    rolling.name = "WoodenMarbleRolling"
    rolling.stream = ROLL
    if rolling.stream is AudioStreamOggVorbis:
        (rolling.stream as AudioStreamOggVorbis).loop = true
    rolling.volume_db = -55
    add_child(rolling)
    bridge_rolling = AudioStreamPlayer.new()
    bridge_rolling.name = "BridgeMarbleRolling"
    bridge_rolling.volume_db = -80.0
    add_child(bridge_rolling)
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
    replica_roll_speed = -1.0
    _clear_bridge_roll()
    if rolling.playing:
        rolling.stop()
    rolling.play()

func set_bridge_surface(on_deck: bool, touching: bool, replica_speed := -1.0) -> void:
    on_bridge = on_deck
    bridge_grounded = touching
    replica_roll_speed = replica_speed

func set_ice_feedback(on_surface: bool, touching: bool, skid: float, entry := 0.0) -> void:
    on_ice = on_surface
    ice_grounded = touching
    ice_skid_target = clampf(skid,0.0,1.0) if touching and is_finite(skid) else 0.0
    ice_entry_mix = clampf(entry,0.0,1.0) if touching and is_finite(entry) else 0.0

func play_ice_entry() -> void:
    if race_active and hazard_cooldown <= 0.0 and collision_duck < 1.9:
        _voice(GLASS_HITS[2],-23.0,1.27)

func play_grip_return() -> void:
    if race_active and hazard_cooldown <= 0.0 and collision_duck < 1.9:
        _voice(WOOD_HITS[1],-21.0,1.05)

func play_ice_impact(intensity: float) -> void:
    if not enabled or not race_active:
        return
    _collision_haptics(intensity)
    if hazard_cooldown <= 0.0:
        # Short glass attack, distinct from the brighter entry and the wood
        # contact of regained grip. Allow the next grip cue to stay audible.
        collision_duck = maxf(collision_duck,1.2)
        _voice(GLASS_HITS[0],lerpf(-22.0,-12.0,intensity),0.94)

func play_bank_exit() -> void:
    if race_active and hazard_cooldown <= 0.0 and collision_duck < 1.9:
        _voice([WOOD_HITS[0],GLASS_HITS[1],METAL_HITS[0]][track_theme],-25.0,1.05)

func set_control_recovery(weight: float) -> void:
    control_recovery = clampf(weight,0.0,1.0) if is_finite(weight) else 0.0

func _clear_bridge_roll() -> void:
    set_bridge_surface(false,false)
    bridge_mix = 0.0
    bridge_rolling.volume_db = -80.0
    bridge_rolling.stop()
    set_ice_feedback(false,false,0.0)
    ice_skid_mix = 0.0

static func pack_percussion_lift(pressure: float) -> float:
    return 5.5*clampf(pressure,0.0,1.0) if is_finite(pressure) else 0.0

static func pack_wind_trim(pressure: float) -> float:
    return 3.0*clampf(pressure,0.0,1.0) if is_finite(pressure) else 0.0

func set_pack_pressure(value: float) -> void:
    # Never alters physics, coins, finish positions or a multiplayer result.
    # Only one sampled scalar (0-1) is needed, not forty audio players.
    pack_pressure_target = clampf(value,0.0,1.0) if is_finite(value) else 0.0

func set_flight_intensity(weight: float) -> void:
    flight_intensity_target = clampf(weight,0.0,1.0) if is_finite(weight) else 0.0

func set_drive_context(turbo: bool, turn: float, exit_weight := 0.0) -> void:
    # The HUD has already dispatched its earliest warning for this frame.
    if turbo and not turbo_requested:
        boost()
    turbo_requested = turbo
    turn_target = clampf(turn,0.0,1.0) if is_finite(turn) else 0.0
    exit_speed = clampf(exit_weight,0.0,1.0) if is_finite(exit_weight) else 0.0

func touchdown(grade: String, impact_speed: float) -> void:
    # Already bundled CC0/original cues; no new concurrent audio channel.
    if grade == "BIG AIR":
        _voice(TONES["finish"],-23.0,1.43)
        _voice(TONES["checkpoint"],-19.0,1.30)
    elif grade == "PERFECT LANDING":
        _voice(TONES["checkpoint"],-20.0,1.54)
        _voice(GLASS_HITS[0],-26.0,1.16)
    else:
        _voice(WOOD_HITS[1],-23.0,0.96)
    collision_delay = maxf(collision_delay,0.12)
    if enabled and grade == "BIG AIR" and impact_speed >= 3.0 and (
            haptic_cooldown <= 0.0 and OS.has_feature("mobile")):
        Input.vibrate_handheld(16)
        haptic_cooldown = 0.42

func _process(delta: float) -> void:
    flight_intensity = lerpf(flight_intensity,flight_intensity_target,
        RaceFeedback.smooth_factor(delta,7.0))
    # Exponential smoothing makes the score breathe smoothly even as 40
    # marbles weave past each other or Android oscillates between 30/60 Hz.
    pack_pressure = lerpf(pack_pressure,pack_pressure_target,
        RaceFeedback.smooth_factor(delta,3.7))
    collision_delay = maxf(0.0,collision_delay-delta)
    boost_delay = maxf(0.0,boost_delay-delta)
    haptic_cooldown = maxf(0.0,haptic_cooldown-delta)
    collision_duck = move_toward(collision_duck,0.0,delta*9.0)
    pass_mix_seconds = maxf(0.0,pass_mix_seconds-delta)
    hazard_cooldown = maxf(0.0,hazard_cooldown-delta)
    hazard_duck = move_toward(hazard_duck,0.0,delta*13.0)
    var priority_duck := maxf(collision_duck,hazard_duck)
    var warning_active := hazard_cooldown > 0.0
    var turbo_target := 1.0 if turbo_requested and not warning_active else 0.0
    turbo_mix = lerpf(turbo_mix,turbo_target,RaceFeedback.smooth_factor(delta,9.0))
    turn_mix = lerpf(turn_mix,turn_target,RaceFeedback.smooth_factor(delta,7.0))
    ice_skid_mix = lerpf(ice_skid_mix,ice_skid_target,RaceFeedback.smooth_factor(delta,10.0))
    var music_mix_db := music_target_db+loudness_offset-priority_duck
    if music_fade < 1.0:
        music_fade = minf(1.0,music_fade+maxf(0.0,delta)/MUSIC_FADE_SECONDS)
        # Equal-power fades keep perceived loudness stable even in menu
        # transitions, without an extra music bus or a CPU audio thread.
        var incoming: float = sin(music_fade*PI*0.5)
        var outgoing: float = cos(music_fade*PI*0.5)
        music.volume_db = music_mix_db+linear_to_db(maxf(0.001,incoming))
        if music_previous.playing:
            music_previous.volume_db = music_mix_db+linear_to_db(
                maxf(0.001,outgoing))
        if music_fade >= 1.0:
            music_previous.stop()
    else:
        var music_response := 55.0 if priority_duck > 0.0 and music_mix_db < music.volume_db else 7.0
        music.volume_db = move_toward(music.volume_db,music_mix_db,delta*music_response)
    mechanism_timer -= delta
    if mechanism_timer <= 0.0:
        mechanism_timer = 0.20
        _update_mechanism_sound()
    var pace_target := -72.0
    var air_target := -72.0
    var speed := _rolling_speed()
    if enabled and speed >= 0.0:
        var energy := clampf((speed-3.0)/11.0,0.0,1.0)
        pace_target = -36.0 + energy*14.0 + finish_progress*5.0 + (
            [-1.0,-3.0,2.0][track_theme])+pack_percussion_lift(pack_pressure)
        var wind_duck := maxf(hazard_duck*1.8,collision_duck*2.2)
        wind_duck = maxf(wind_duck,maxf(4.5*pass_mix_seconds/PASS_MIX_SECONDS,3.6*ice_skid_mix))
        wind_duck = maxf(wind_duck,5.0*control_recovery)
        wind_duck = maxf(wind_duck,ice_entry_mix*3.2)
        var corner := turn_mix*(1.0-flight_intensity)
        var thrust := 0.0 if warning_active else turbo_mix
        var release := exit_speed*(1.0-flight_intensity)*(1.0-corner)*(
            1.0-clampf(wind_duck/2.5,0.0,1.0)) if not warning_active and not turbo_requested else 0.0
        air_target = -52.0+energy*25.0+flight_intensity*7.0+thrust*2.6*(1.0-corner)-maxf(
            maxf(pack_wind_trim(pack_pressure)*(1.0-flight_intensity),corner*3.8),wind_duck)
        air_target += 2.8*release
        pace_target -= maxf(priority_duck,ice_entry_mix*2.3)
        air.pitch_scale = (lerpf(0.85,1.5,energy)+thrust*0.09+release*0.055)*(1.0-0.06*corner)*[
            1.0,0.94,1.08][track_theme]
    if not enabled:
        pace_target = -80.0
        air_target = -80.0
    var pace_response := 48.0 if priority_duck > 0.0 and pace_target < percussion.volume_db else 11.0
    percussion.volume_db = move_toward(percussion.volume_db,pace_target,delta*pace_response)
    var wind_response := 110.0 if air_target < air.volume_db else 16.0
    air.volume_db = move_toward(air.volume_db,air_target,delta*wind_response)
    _update_rolling(delta)

func _rolling_speed() -> float:
    if not race_active or not is_instance_valid(target_marble):
        return -1.0
    if target_marble.freeze:
        return replica_roll_speed
    var velocity := target_marble.linear_velocity
    return Vector2(velocity.x,velocity.z).length()

func _update_rolling(delta: float) -> void:
    if not enabled:
        rolling.volume_db = -80.0
        return
    var speed := _rolling_speed()
    if speed < 0.0:
        roll_level_db = move_toward(roll_level_db,-60.0,delta*45.0)
        rolling.volume_db = roll_level_db
        if bridge_mix > 0.0:
            _clear_bridge_roll()
        return
    var foreground := maxf(hazard_duck*0.56,collision_duck*0.48)
    var corner := turn_mix*(1.0-flight_intensity)
    var corner_roll := corner*2.2*clampf(speed/13.0,0.0,1.0)*(1.0-clampf(foreground/2.0,0.0,1.0))
    var recovery_roll := 2.6*control_recovery*(1.0-clampf(foreground/2.0,0.0,1.0))
    var rolling_target := clampf(-41.0+speed*1.65,-48.0,-17.0)-foreground-flight_intensity*14.0+maxf(corner_roll,recovery_roll)
    var using_surface_loop := on_ice or on_bridge
    var floor_missing := (on_ice and not ice_grounded) or (on_bridge and not bridge_grounded)
    if floor_missing:
        rolling_target = minf(rolling_target,-51.0)
    var response := 26.0
    if using_surface_loop:
        response = 105.0 if floor_missing else 42.0
    if control_recovery > 0.0:
        response = maxf(response,56.0)
    roll_level_db = move_toward(roll_level_db,rolling_target,delta*response)
    rolling.pitch_scale = clampf(0.63+speed*0.06,0.73,1.65)
    var fade_seconds := ICE_FADE_SECONDS if on_ice else SURFACE_FADE_SECONDS
    bridge_mix = move_toward(bridge_mix,float(using_surface_loop),delta/fade_seconds)
    var angle := bridge_mix*PI*0.5
    rolling.volume_db = roll_level_db+linear_to_db(maxf(0.001,cos(angle)))
    if bridge_mix == 0.0:
        if bridge_rolling.playing:
            bridge_rolling.stop()
        return
    bridge_rolling.pitch_scale = rolling.pitch_scale*(1.0+ice_skid_mix*0.08)
    var stream: AudioStreamOggVorbis = BRIDGE_ROLLS[track_theme]
    if bridge_rolling.stream != stream:
        stream.loop = true
        bridge_rolling.stream = stream
    # Match the quiet board loop while keeping a little extra floor detail.
    var entry_lift := 2.4*ice_entry_mix*(1.0-clampf(foreground/1.9,0.0,1.0))
    bridge_rolling.volume_db = roll_level_db-4.0+linear_to_db(maxf(0.001,sin(angle)))+entry_lift
    if not bridge_rolling.playing:
        bridge_rolling.play()

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
    p.volume_db = minf(loudness,WARNED_BOOST_DB) if (
        hazard_cooldown > 0.0 and _ducks_for_hazard(stream)) else loudness
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
    var next_score: AudioStream = THEME_SCORES[track_theme]
    if is_instance_valid(music) and music.stream != next_score:
        # Keep the old composition phase alive just long enough for a
        # smooth equal-power handover. No per-frame synthesis or downloads.
        if is_instance_valid(music_previous):
            music_previous.stop()
            music_previous.stream = music.stream
            music_previous.pitch_scale = music.pitch_scale
            music_previous.volume_db = music.volume_db
            music_previous.play(music.get_playback_position())
        music.stream = next_score
        music.pitch_scale = 1.0
        music.volume_db = -78.0
        music_fade = 0.0
        music.play()
        if is_instance_valid(percussion):
            # Start the pre-rendered score and the original 112 BPM stem
            # on the same beat after every biome switch.
            percussion.stop()
            percussion.play()
    # All original compositions have the SAME 112 BPM/12-bar musical grid.
    # A retuned percussion stem would drift off the drum hits, so it stays
    # at neutral pitch regardless of track. Wind can remain biome-specific.
    if is_instance_valid(percussion):
        percussion.pitch_scale = 1.0
    if is_instance_valid(air):
        air.pitch_scale = [1.0,0.93,1.10][track_theme]

func begin_race() -> void:
    flight_intensity = 0.0
    flight_intensity_target = 0.0
    warned_timed_gates.clear()
    warned_vents.clear()
    if hazard_cues.is_empty() and enabled:
        hazard_cues = HazardAudio.build()
    _reset_priority_mix()
    pack_pressure = 0.0
    pack_pressure_target = 0.0
    music_target_db = ([-20.0,-22.5,-18.5][track_theme]) if enabled else -80.0
    race_active = true
    finish_progress = 0.0
    tone("start")

func menu_music() -> void:
    flight_intensity = 0.0
    flight_intensity_target = 0.0
    pack_pressure = 0.0
    pack_pressure_target = 0.0
    music_target_db = -23.0 if enabled else -80.0
    race_active = false
    finish_progress = 0.0
    target_marble = null
    _reset_priority_mix()
    _clear_bridge_roll()

func _reset_priority_mix() -> void:
    collision_delay = 0.0
    collision_duck = 0.0
    last_impact_intensity = 0.0
    pass_mix_seconds = 0.0
    hazard_duck = 0.0
    hazard_cooldown = 0.0
    turbo_requested = false
    turbo_mix = 0.0
    turn_target = 0.0
    turn_mix = 0.0
    boost_delay = 0.0
    control_recovery = 0.0
    exit_speed = 0.0

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
            if hazard_cooldown <= 0.0 and collision_duck < 1.9:
                pass_mix_seconds = PASS_MIX_SECONDS
                _voice(UI_SELECT,-22.0,1.30)
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
    if blocking:
        _warn_hazard(warned_timed_gates,index,track_theme)

func warn_vent(index: int) -> void:
    if track_theme == 2:
        _warn_hazard(warned_vents,index,3)

func _warn_hazard(played: Dictionary, index: int, cue: int) -> void:
    if not enabled or not race_active or index < 0 or played.has(index) or hazard_cooldown > 0.0:
        return
    if hazard_cues.is_empty():
        hazard_cues = HazardAudio.build()
    played[index] = true
    hazard_cooldown = 0.36
    hazard_duck = 4.5
    for voice in channels:
        if voice.playing and _ducks_for_hazard(voice.stream):
            voice.volume_db = minf(voice.volume_db,WARNED_BOOST_DB)
    _voice(hazard_cues[cue],-15.0)

func course_event(kind: String) -> void:
    match kind:
        "speed":
            _voice(TONES["boost"],-14.0,0.91)
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
        "bridge_gate_1":
            _voice(TONES["checkpoint"],-19.0,1.05)
        "bridge_gate_2":
            _voice(TONES["checkpoint"],-18.0,1.24)
        "bridge_perfect":
            _voice(TONES["checkpoint"],-15.0,1.48)
            _voice(TONES["boost"],-18.0,1.34)
        "near_miss":
            _voice(TONES["checkpoint"],-17.0,1.33)
            _voice(TONES["boost"],-20.0,1.09)
        "near_miss_precision":
            _voice(TONES["checkpoint"],-17.0,1.46)
            _voice(TONES["boost"],-22.0,1.20)
        "near_miss_chain":
            _voice(TONES["checkpoint"],-16.0,1.60)
            _voice(TONES["boost"],-19.0,1.30)

func _ducks_for_hazard(stream: AudioStream) -> bool:
    return stream == TONES["boost"] or pickup_cues.find_key(stream) != null

func item_pickup(kind: String) -> void:
    var cue: AudioStreamWAV = pickup_cues.get(kind)
    if cue != null:
        _voice(cue,-12.0)

func boost() -> void:
    if enabled and race_active and boost_delay <= 0.0 and hazard_cooldown <= 0.0:
        tone("boost")
        boost_delay = 1.5

func _on_marble_collision(other: Node) -> void:
    if not enabled or not race_active or not is_instance_valid(target_marble):
        return
    var intensity: float = RaceFeedback.impact_intensity(
        target_marble.linear_velocity,other)
    if intensity < 0.14:
        return
    if collision_delay > 0.0 and intensity < last_impact_intensity+0.27:
        return
    last_impact_intensity = intensity
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
    _collision_haptics(intensity)
    var idx: int = rng.randi_range(0,samples.size()-1)
    if contact == "bumper" and other.name.begins_with("PinballKicker_"):
        # The existing soft/hard CC0 samples now distinguish a true
        # spring-post tap from a strong rebound. Keep the same voice pool.
        idx = 1 if intensity >= 0.55 else 0
    var loudness := lerpf(-24.0,-8.0,intensity)
    if contact == "glass":
        # Frequent light contacts in a pack should sound like glass
        # chatter and leave room for real impacts and track warnings.
        loudness -= lerpf(1.5,5.0,pack_pressure)*(1.0-smoothstep(0.24,0.70,intensity))
    collision_duck = maxf(collision_duck,3.5*smoothstep(0.18,1.0,intensity))
    _spatial_voice(samples[idx],target_marble.global_position,
        loudness,rng.randf_range(0.94,1.08)*
        lerpf(0.90,1.08,intensity))

func _collision_haptics(intensity: float) -> void:
    if intensity > 0.40 and haptic_cooldown <= 0.0 and OS.has_feature("mobile"):
        Input.vibrate_handheld(12 if intensity < 0.70 else 26)
        haptic_cooldown = 0.48

func toggle_sound() -> bool:
    enabled = not enabled
    var cfg = ConfigFile.new()
    cfg.load("user://marble_settings.cfg")
    cfg.set_value("audio","enabled",enabled)
    cfg.save("user://marble_settings.cfg")
    music_target_db = -80 if not enabled else -19
    music.volume_db = music_target_db
    if is_instance_valid(music_previous):
        music_previous.volume_db = -80.0 if not enabled else (
            music_previous.volume_db)
    percussion.volume_db = -80.0 if not enabled else -45.0
    air.volume_db = -80.0 if not enabled else -50.0
    rolling.volume_db = -80 if not enabled else -36
    mechanism.volume_db = -80 if not enabled else -30
    if not enabled:
        _reset_priority_mix()
        _clear_bridge_roll()
        for speaker in channels:
            speaker.stop()
        for speaker in spatial_channels:
            speaker.stop()
    return enabled
