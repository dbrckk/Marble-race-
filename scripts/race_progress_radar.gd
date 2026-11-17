extends Control
## Race progress sampled at 10 Hz. The opponent dots share one 2D draw.
const FINISH_Z := -185.0
const DOT_SIDES := 12
const UPDATE_PERIOD := 0.10
const PLAYER_COLOR := Color("#fff2be")
const OPPONENT_COLOR := Color(0.67,0.83,0.90,0.58)
const FINISHED_COLOR := Color(0.60,0.98,0.71,0.85)
var opponent_dots := MultiMesh.new()
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
    opponent_dots.transform_format = MultiMesh.TRANSFORM_2D
    opponent_dots.use_colors = true
    opponent_dots.mesh = _make_dot()
    opponent_dots.instance_count = owner.MARBLE_COUNT
    reset()

func reset() -> void:
    positions.clear()
    finished.clear()
    player_id = -1
    elapsed = 0.0
    last_count = 0
    opponent_dots.visible_instance_count = 0
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
    var opponent_index := 0
    for i in range(positions.size()):
        if i == player_id:
            continue
        var x: float = lerpf(3.0,width_px-3.0,positions[i])
        var y: float = baseline+float(i%3-1)*2.5
        opponent_dots.set_instance_transform_2d(opponent_index,Transform2D(0.0,Vector2(x,y)))
        opponent_dots.set_instance_color(opponent_index,
            FINISHED_COLOR if finished[i] == 1 else OPPONENT_COLOR)
        opponent_index += 1
    opponent_dots.visible_instance_count = opponent_index
    if opponent_index > 0:
        draw_multimesh(opponent_dots,null)
    if player_id >= 0 and player_id < positions.size():
        var x: float = lerpf(3.0,width_px-3.0,positions[player_id])
        draw_circle(Vector2(x,baseline),4.5,Color(0.04,0.09,0.13,0.95))
        draw_circle(Vector2(x,baseline),3.2,PLAYER_COLOR)

static func _make_dot() -> ArrayMesh:
    var points := PackedVector2Array([Vector2.ZERO])
    var indices := PackedInt32Array()
    for side in range(DOT_SIDES):
        points.append(Vector2.from_angle(TAU*float(side)/DOT_SIDES)*2.0)
        indices.append_array(PackedInt32Array([0,side+1,(side+1)%DOT_SIDES+1]))
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = points
    arrays[Mesh.ARRAY_INDEX] = indices
    var dot := ArrayMesh.new()
    dot.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
    return dot
