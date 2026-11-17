extends Control
## Pure 2D race-position overlay. No world meshes, shaders, physics, or
## per-frame allocation. 40 marbles -> at most 40 tiny draw calls at 10 Hz.
const FINISH_Z := -185.0
const UPDATE_PERIOD := 0.10
const PLAYER_COLOR := Color("#fff2be")
const OPPONENT_COLOR := Color(0.67,0.83,0.90,0.58)
const FINISHED_COLOR := Color(0.60,0.98,0.71,0.85)
var stage: Node3D
var elapsed := 0.0
var positions := PackedFloat32Array()
var finished := PackedByteArray()
var player_id := -1
var last_count := 0
var updates := 0

func configure(owner: Node3D) -> void:
    stage = owner
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    clip_contents = true
    reset()

func reset() -> void:
    positions.clear()
    finished.clear()
    player_id = -1
    elapsed = 0.0
    last_count = 0
    queue_redraw()

static func progress_at(z: float) -> float:
    return clampf(-z / -FINISH_Z,0.0,1.0)

func sample(delta: float) -> void:
    if not is_instance_valid(stage) or not visible:
        return
    elapsed += maxf(0.0,delta)
    if elapsed < UPDATE_PERIOD:
        return
    elapsed = fmod(elapsed,UPDATE_PERIOD)
    positions.clear()
    finished.clear()
    player_id = -1
    for marble in stage.racers:
        if not is_instance_valid(marble):
            continue
        if marble == stage.player:
            player_id = positions.size()
        positions.append(progress_at(marble.global_position.z))
        finished.append(1 if marble.finished else 0)
    last_count = positions.size()
    updates += 1
    queue_redraw()

func _draw() -> void:
    if positions.is_empty():
        return
    var width_px: float = maxf(1.0,size.x)
    var height_px: float = maxf(1.0,size.y)
    var baseline: float = height_px*0.52
    # Endpoints and centreline provide spatial context; progress remains
    # independent of local rank, multiplayer claims and career records.
    draw_line(Vector2(3.0,baseline),Vector2(width_px-3.0,baseline),
        Color(0.78,0.81,0.83,0.35),1.5)
    for i in range(positions.size()):
        if i == player_id:
            continue
        var x: float = lerpf(3.0,width_px-3.0,positions[i])
        var y: float = baseline+float(i%3-1)*2.5
        draw_circle(Vector2(x,y),2.0,
            FINISHED_COLOR if finished[i] == 1 else OPPONENT_COLOR)
    if player_id >= 0 and player_id < positions.size():
        var x: float = lerpf(3.0,width_px-3.0,positions[player_id])
        draw_circle(Vector2(x,baseline),4.5,Color(0.04,0.09,0.13,0.95))
        draw_circle(Vector2(x,baseline),3.2,PLAYER_COLOR)
