extends Node3D
## Offline CC0 Foley (Kenney), plus original composed loop and tonal race cues.
## Eight pooled voice channels prevent hard-cutting a sound every time a marble collides.
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
var target_marble: RigidBody3D
var enabled := true
var collision_delay := 0.0
var boost_delay := 0.0
var current_channel := 0
var music_target_db := -22.0
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

func _process(delta: float) -> void:
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
        pace_target = -36.0 + energy*14.0 + finish_progress*5.0
        air_target = -52.0 + energy*25.0
        air.pitch_scale = lerpf(0.85,1.5,energy)
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

func begin_race() -> void:
    music_target_db = -20.0 if enabled else -80.0
    race_active = true
    finish_progress = 0.0
    tone("start")

func menu_music() -> void:
    music_target_db = -23.0 if enabled else -80.0
    race_active = false
    finish_progress = 0.0
    target_marble = null

func update_progress(ratio: float) -> void:
    finish_progress = clampf(ratio,0.0,1.0)

func finish_fanfare() -> void:
    _voice(FANFARE,-12.0,1.0)

func boost() -> void:
    if boost_delay <= 0.0:
        tone("boost")
        boost_delay = 1.5

func _on_marble_collision(_body: Node) -> void:
    if collision_delay > 0.0 or not is_instance_valid(target_marble):
        return
    var speed = target_marble.linear_velocity.length()
    if speed < 1.5:
        return
    collision_delay = 0.09 if speed > 7 else 0.17
    var kind = GLASS_HITS if _body is RigidBody3D else WOOD_HITS
    if speed >= 8.5 and haptic_cooldown <= 0.0 and OS.has_feature("mobile"):
        Input.vibrate_handheld(22)
        haptic_cooldown = 0.52
    var idx = rng.randi_range(0,kind.size()-1)
    collision_duck = maxf(collision_duck,clampf(speed*0.35,0.0,3.5))
    _spatial_voice(kind[idx],target_marble.global_position,
        clampf(-17.0+speed*0.57,-18.0,-7.0),rng.randf_range(0.90,1.12))

func toggle_sound() -> bool:
    enabled = not enabled
    var cfg = ConfigFile.new()
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
