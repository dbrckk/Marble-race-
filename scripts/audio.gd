extends Node3D
## Offline CC0 Foley (Kenney), plus original composed loop and tonal race cues.
## Eight pooled voice channels prevent hard-cutting a sound every time a marble collides.
const SCORE = preload("res://assets/audio/music/marble_workshop.ogg")
const ROLL = preload("res://assets/audio/sfx/wood_roll.ogg")
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
var channels: Array[AudioStreamPlayer] = []
var target_marble: RigidBody3D
var enabled := true
var collision_delay := 0.0
var boost_delay := 0.0
var current_channel := 0
var music_target_db := -22.0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
    rng.seed = 5721
    music = AudioStreamPlayer.new()
    music.name = "OriginalSoundtrack"
    music.stream = SCORE
    if music.stream is AudioStreamOggVorbis:
        (music.stream as AudioStreamOggVorbis).loop = true
    music.volume_db = -24
    add_child(music)
    music.play()
    rolling = AudioStreamPlayer3D.new()
    rolling.name = "WoodenMarbleRolling"
    rolling.stream = ROLL
    if rolling.stream is AudioStreamOggVorbis:
        (rolling.stream as AudioStreamOggVorbis).loop = true
    rolling.volume_db = -55
    rolling.max_distance = 24.0
    rolling.unit_size = 3.0
    add_child(rolling)
    for n in range(10):
        var ch = AudioStreamPlayer.new()
        ch.name = "SFX_%02d" % n
        ch.volume_db = -16
        add_child(ch)
        channels.append(ch)

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
    music.volume_db = move_toward(music.volume_db,music_target_db,delta*7.0)
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
    music_target_db = -17.5 if enabled else -80.0
    tone("start")

func menu_music() -> void:
    music_target_db = -22.0 if enabled else -80.0
    target_marble = null

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
    var kind = GLASS_HITS if rng.randf()<0.35 else WOOD_HITS
    var idx = rng.randi_range(0,kind.size()-1)
    _voice(kind[idx],clampf(-25.0+speed*0.8,-25.0,-12.0),rng.randf_range(0.91,1.15))

func toggle_sound() -> bool:
    enabled = not enabled
    music_target_db = -80 if not enabled else -19
    music.volume_db = music_target_db
    rolling.volume_db = -80 if not enabled else -36
    return enabled
