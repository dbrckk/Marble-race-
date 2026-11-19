extends Node3D
## Sparse arcade pickups. The offline game or dedicated server owns effects.
## Computer-controlled marbles never collect or activate an item.
const ITEM_Z := [-28.0, -79.0, -128.0, -169.0]
const ITEM_X := [-2.8, 2.8, -2.0, 2.0]
# Solo slots in course order. Each row is a layout, and each pair is
# (distance along the course, lateral offset from its actual centerline).
const SOLO_LINES := [
    [
        [Vector2(-21.7,-1.65), Vector2(-95.1,2.20), Vector2(-129.4,-1.55), Vector2(-166.0,1.45)],
        [Vector2(-21.7,1.65), Vector2(-95.1,2.20), Vector2(-129.4,1.85), Vector2(-166.0,-1.45)],
        [Vector2(-21.7,-1.65), Vector2(-95.1,2.20), Vector2(-129.4,-1.85), Vector2(-166.0,1.45)]
    ],
    # Glacier: jump near the ice, shockwave on the main route, steady
    # dash through the late ice section, then boost on the run home.
    [
        [Vector2(-21.0,2.55), Vector2(-82.0,1.80), Vector2(-139.0,-1.80), Vector2(-174.5,1.80)],
        [Vector2(-21.0,-1.80), Vector2(-82.0,-1.80), Vector2(-141.0,1.80), Vector2(-175.0,-1.80)],
        [Vector2(-20.0,-1.80), Vector2(-83.0,1.80), Vector2(-135.0,-1.80), Vector2(-176.0,1.80)]
    ],
    # Forge: shockwave in early traffic, steady dash on the main route,
    # turbo on the open side of the final piston, jump ahead of the last vent.
    [
        [Vector2(-24.0,1.15), Vector2(-83.0,1.80), Vector2(-143.0,1.80), Vector2(-164.0,1.15)],
        [Vector2(-25.0,-1.80), Vector2(-83.0,-1.80), Vector2(-143.0,-1.80), Vector2(-166.0,-2.55)],
        [Vector2(-24.0,-1.80), Vector2(-83.0,1.80), Vector2(-143.0,1.80), Vector2(-164.0,-1.80)]
    ]
]
const PICKUP_RADIUS_SQUARED := 3.1
const PACK_MARK_MIN_DISTANCE := 2.3
const PACK_MARK_REACH := 15.0
# The physical shockwave is a true radial, same-deck interaction. Remote
# clients only render the confirmed result; no client can apply its impulse.
const PULSE_RANGE := 4.12
const PULSE_MIN_DISTANCE := 0.32
const PULSE_VERTICAL_LIMIT := 1.20
const PULSE_HORIZONTAL_IMPULSE := 4.15
const PULSE_LIFT_IMPULSE := 1.10
const PULSE_VISUAL_DURATION := 0.52
const ACTIVATION_DURATION := 0.38
const ITEM_KINDS := ["turbo", "spring", "pulse", "stabilizer"]
const ITEM_NAMES := ["TURBO", "JUMP", "SHOCKWAVE", "STEADY DASH"]
const TRACK_PATH = preload("res://scripts/track_path.gd")
const RARE_ART = preload("res://scripts/rare_item_art.gd")
const RaceFeedback = preload("res://scripts/race_feedback.gd")
const COLORS := [
    Color("#5ff0ff"), Color("#fce67b"), Color("#df90ff"), Color("#70edb8")
]
var game: Node3D
var items: Array[Node3D] = []
var used: Dictionary = {}
var clock := 0.0
# Reused scratch list: scan the 30 marbles ONCE per physics frame, then
# test pickup collisions for only the 1-4 authoritative human racers.
var eligible_collectors: Array[RigidBody3D] = []
var pulse_ring: MeshInstance3D
var pulse_material: StandardMaterial3D
var pulse_remaining := 0.0
var pulse_hit_mask := 0
var visual_quality := 1
var confirmed_pulses := 0
var activation_mesh: MeshInstance3D
var activation_material: StandardMaterial3D
var activation_remaining := 0.0
var activation_kind := ""
var activation_origin := Vector3.ZERO

static func kind_at(index: int, track: int) -> String:
    return ITEM_KINDS[posmod(index+clampi(track,0,2),ITEM_KINDS.size())]

static func label_at(index: int, track: int) -> String:
    return ITEM_NAMES[posmod(index+clampi(track,0,2),ITEM_NAMES.size())]

static func lane_offset(index: int, track: int, variation: int, solo := true) -> float:
    return _line_at(index,track,variation,solo).y

static func placement_at(index: int, track: int, variation: int, solo := true) -> Vector3:
    var line := _line_at(index,track,variation,solo)
    return Vector3(TRACK_PATH.center_at(line.x,track)+line.y,
        TRACK_PATH.height_at(line.x,track)+1.05,line.x)

static func _line_at(index: int, track: int, variation: int, solo: bool) -> Vector2:
    var course := clampi(track,0,2)
    var layout := posmod(variation,3)
    if solo:
        return SOLO_LINES[course][layout][index]
    # Keep online coordinates compatible with deployed clients and servers.
    return Vector2(ITEM_Z[index],ITEM_X[posmod(index+course+layout,ITEM_X.size())])

func nearest_available(at: Vector3, racer_id: int, max_distance: float = 28.0,
        continuing_merge := false) -> Dictionary:
    if not at.is_finite() or not is_finite(max_distance) or max_distance <= 0.0:
        return {}
    # Only four candidates for the HUD and local race guidance.
    # A collected client pickup stays hidden until reset.
    # A racer committed to the exterior bridge cannot reach main-road items
    # before the physical merge. Suppress misleading impossible pickup cues.
    var on_outer_bridge: bool = is_instance_valid(game.shortcut_route) and (
        str(game.shortcut_route.shortcut_hint(at,continuing_merge).get("mode","")) == "merge")
    for i in range(items.size()):
        var pickup: Node3D = items[i]
        if not is_instance_valid(pickup) or not pickup.visible or (
            used.has("%d:%d" % [i,racer_id])):
            continue
        if on_outer_bridge and pickup.position.z <= game.shortcut_route.ENTRY_Z and (
            pickup.position.z >= game.shortcut_route.EXIT_Z):
            continue
        var distance: float = at.z-pickup.position.z
        if distance < 0.0 or distance > max_distance:
            continue
        var side := "LEFT" if pickup.position.x < game.track_center_at(pickup.position.z) else "RIGHT"
        return {"index":i, "distance":distance, "side":side,
            "kind":kind_at(i,game.selected_track),
            "label":label_at(i,game.selected_track)}
    return {}

func pickup_marker_ahead(at: Vector3, velocity: Vector3, continuing_merge: bool) -> int:
    var forward := -velocity.z
    if forward < 5.0 or not velocity.is_finite() or not at.is_finite() or game.airtime.airborne:
        return -1
    var hint := nearest_available(at,game.player.racer_id,PACK_MARK_REACH,continuing_merge)
    var index := int(hint.get("index",-1))
    if index < 0 or (game.selected_track == 0 and index == 0 and not game.woodworks_opening_cleared(at.z)):
        return -1
    var target := items[index].global_position
    var distance: float = hint["distance"]
    var eta := distance/forward
    var aim := RaceFeedback.projected_lane_x(at.x,velocity.x,eta)
    return index if distance > PACK_MARK_MIN_DISTANCE and absf(aim-target.x) < 0.8+3.8*eta else -1

func pickup_marker_position(index: int) -> Vector3:
    if index < 0 or index >= items.size() or not is_instance_valid(items[index]) or not items[index].visible:
        return Vector3.INF
    var target := items[index].global_position
    return Vector3(target.x,game.height_at(target.z)+0.39,target.z)

func setup(owner: Node3D, track: int, variation: int) -> void:
    game = owner
    var finish := StandardMaterial3D.new()
    finish.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    finish.cull_mode = BaseMaterial3D.CULL_DISABLED
    finish.vertex_color_use_as_albedo = true
    finish.vertex_color_is_srgb = true
    for i in range(ITEM_Z.size()):
        var pickup := Node3D.new()
        pickup.name = "RarePickup_%02d" % i
        var effect_index := posmod(i+track,ITEM_KINDS.size())
        var shell := MeshInstance3D.new()
        shell.name = "EffectCrystal"
        shell.mesh = RARE_ART.build(effect_index,COLORS[effect_index])
        shell.material_override = finish
        shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        pickup.add_child(shell)
        pickup.position = placement_at(i,track,variation)
        # Readable identity from the approach, without changing hitbox size.
        # One billboard per rare collectible; no extra lights or shadows.
        var title := Label3D.new()
        title.name = "ImmediateEffectLabel"
        title.text = label_at(i,track)
        title.font_size = 34
        title.pixel_size = 0.010
        title.outline_size = 10
        title.modulate = COLORS[effect_index].lightened(0.27)
        title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        title.position = Vector3(0.0,1.00,0.0)
        pickup.add_child(title)
        add_child(pickup)
        items.append(pickup)
    _build_pulse_fx()
    activation_mesh = MeshInstance3D.new()
    activation_mesh.name = "ConfirmedPickupEffect"
    activation_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    activation_material = pulse_material.duplicate() as StandardMaterial3D
    activation_material.emission_enabled = false
    activation_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    activation_mesh.material_override = activation_material
    activation_mesh.hide()
    add_child(activation_mesh)

func _build_pulse_fx() -> void:
    # A single reusable unlit torus is enough for one local human's instant
    # rare item. No lights, shaders, particles, physics bodies or extra
    # audio channels; it is invisible unless a real pulse is confirmed.
    pulse_ring = MeshInstance3D.new()
    pulse_ring.name = "ConfirmedShockwaveVisual"
    var mesh := TorusMesh.new()
    mesh.inner_radius = 0.90
    mesh.outer_radius = 1.03
    mesh.rings = 24
    mesh.ring_segments = 6
    pulse_ring.mesh = mesh
    pulse_material = StandardMaterial3D.new()
    pulse_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    pulse_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    pulse_material.albedo_color = COLORS[2]
    pulse_material.emission_enabled = true
    pulse_material.emission = COLORS[2]
    pulse_material.emission_energy_multiplier = 0.72
    pulse_material.no_depth_test = false
    pulse_ring.material_override = pulse_material
    pulse_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    pulse_ring.visible = false
    add_child(pulse_ring)

func set_quality(quality: int) -> void:
    visual_quality = clampi(quality,0,2)
    if is_instance_valid(pulse_ring):
        pulse_ring.visible = visual_quality > 0 and pulse_remaining > 0.0
    if is_instance_valid(activation_mesh):
        activation_mesh.visible = visual_quality > 0 and activation_remaining > 0.0
        if activation_mesh.visible:
            _update_activation()

func _show_pulse(at: Vector3, hit_mask: int) -> void:
    # Triggered only after offline/server-authoritative human collection.
    # The client uses the validated dedicated-server notification instead.
    confirmed_pulses += 1
    pulse_remaining = PULSE_VISUAL_DURATION
    pulse_hit_mask = hit_mask
    if not is_instance_valid(pulse_ring):
        return
    pulse_ring.global_position = at+Vector3(0.0,-0.46,0.0)
    pulse_ring.scale = Vector3.ONE*0.36
    pulse_material.albedo_color = COLORS[2]
    set_quality(visual_quality)

func _present_pickup(kind: String, at: Vector3, hit_mask: int) -> void:
    if kind == "pulse":
        _show_pulse(at,hit_mask)
    else:
        activation_kind = kind
        activation_origin = at
        activation_remaining = ACTIVATION_DURATION
        activation_mesh.mesh = RARE_ART.activation(kind)
        set_quality(visual_quality)
        if kind == "spring":
            game.airtime.begin_super_jump()
    game.audio.item_pickup(kind)
    game.ui.show_item_pickup(kind)

func active_speed_item() -> int:
    if activation_remaining <= 0.0:
        return -1
    if activation_kind == "turbo" or activation_kind == "stabilizer":
        return ITEM_KINDS.find(activation_kind)
    return -1

func _update_activation() -> void:
    var progress := 1.0-activation_remaining/ACTIVATION_DURATION
    var anchor := activation_origin
    var drift := Vector3.ZERO
    var extent := Vector3.ONE
    var follows_player := active_speed_item() >= 0
    if follows_player and is_instance_valid(game.player) and game.player.global_position.is_finite():
        anchor = game.player.global_position
    match activation_kind:
        "turbo":
            drift.y = 0.03
            extent.z = lerpf(0.78,1.35,progress)
        "spring":
            drift.y = 0.05+1.25*progress
            extent.y = lerpf(0.70,1.20,progress)
        "stabilizer":
            drift.y = 0.17
            extent.x = lerpf(1.55,0.81,progress)
    activation_mesh.global_position = anchor+drift
    activation_mesh.scale = extent
    var tint: Color = COLORS[ITEM_KINDS.find(activation_kind)].lightened(0.22)
    tint.a = 0.94*(1.0-smoothstep(0.36,1.0,progress)) if follows_player else (
        0.94*pow(1.0-progress,1.6))
    activation_material.albedo_color = tint

func _process(delta: float) -> void:
    if not is_finite(delta) or delta <= 0.0:
        return
    if activation_remaining > 0.0:
        activation_remaining = maxf(0.0,activation_remaining-delta)
        if activation_remaining > 0.0 and visual_quality > 0:
            _update_activation()
        else:
            activation_mesh.hide()
    if pulse_remaining <= 0.0:
        return
    pulse_remaining = maxf(0.0,pulse_remaining-delta)
    if pulse_remaining == 0.0:
        pulse_hit_mask = 0
    if not is_instance_valid(pulse_ring):
        return
    if visual_quality == 0 or pulse_remaining <= 0.0:
        pulse_ring.visible = false
        return
    var progress: float = 1.0-pulse_remaining/PULSE_VISUAL_DURATION
    var radius: float = lerpf(0.36,PULSE_RANGE,progress)
    pulse_ring.scale = Vector3(radius,1.0,radius)
    var fade: Color = COLORS[2]
    fade.a = 0.88*pow(1.0-progress,1.4)
    pulse_material.albedo_color = fade

func clear_activation() -> void:
    pulse_remaining = 0.0
    pulse_hit_mask = 0
    activation_remaining = 0.0
    activation_kind = ""
    pulse_ring.hide()
    activation_mesh.hide()

static func pulse_impulse(offset: Vector3) -> Vector3:
    # Zero means no hit; also makes distance falloff deterministic enough
    # to validate independently of rendering and multiplayer state.
    if not offset.is_finite() or absf(offset.y) > PULSE_VERTICAL_LIMIT:
        return Vector3.ZERO
    var lateral := Vector2(offset.x,offset.z)
    var distance: float = lateral.length()
    # Godot stores Vector3 positions as 32-bit floats. A query at exactly
    # the advertised radius can round a few nanometres *inside* the edge;
    # reject that invisible remnant instead of giving an unfair micro-push.
    if distance < PULSE_MIN_DISTANCE or distance >= PULSE_RANGE-0.001:
        return Vector3.ZERO
    var intensity: float = 1.0-smoothstep(
        PULSE_MIN_DISTANCE,PULSE_RANGE,distance)
    var direction := Vector3(offset.x,0.0,offset.z)/distance
    return direction*(PULSE_HORIZONTAL_IMPULSE*intensity)+(
        Vector3.UP*PULSE_LIFT_IMPULSE*intensity)

func reset_round() -> void:
    clock = 0.0
    used.clear()
    confirmed_pulses = 0
    clear_activation()
    for i in range(items.size()):
        var item := items[i]
        item.position = placement_at(i,game.selected_track,game.built_variation,
            not game.net.is_active())
        item.rotation.y = 0.0
        item.visible = true

func _is_human(marble: RigidBody3D, net: Node) -> bool:
    if net.role == "server":
        return marble.network_controlled and net.joined_slots.values().has(marble.racer_id)
    return net.role == "offline" and marble.is_player

func tick(delta: float, racers: Array[RigidBody3D], net: Node) -> void:
    clock += delta
    eligible_collectors.clear()
    for marble in racers:
        if is_instance_valid(marble) and not marble.finished and (
            not marble.eliminated) and _is_human(marble,net):
            eligible_collectors.append(marble)
    for i in range(items.size()):
        var pickup := items[i]
        if not is_instance_valid(pickup):
            continue
        pickup.rotation.y = sin(clock*1.65+i)*0.52
        pickup.position.y = game.height_at(pickup.position.z)+1.05+sin(clock*2.5+i)*0.16
        for marble in eligible_collectors:
            var key := "%d:%d" % [i,marble.racer_id]
            if used.has(key):
                continue
            if marble.global_position.distance_squared_to(pickup.global_position) > PICKUP_RADIUS_SQUARED:
                continue
            used[key] = true
            var kind: String = kind_at(i,game.selected_track)
            var hit_mask := _activate(kind,marble,racers)
            if net.role == "server":
                net.notify_item_collected(marble.racer_id,i,kind,hit_mask)
            if net.role == "offline":
                pickup.visible = false
                _present_pickup(kind,marble.global_position,hit_mask)
            # Shared pickups remain visible in multiplayer: each human can
            # independently claim each one exactly once on the authority.
            break

func mark_local_pickup(index: int, hit_mask := 0) -> void:
    # Client display only: the dedicated server already applied the effect.
    if index < 0 or index >= items.size() or not is_instance_valid(items[index]) or not items[index].visible:
        return
    var pickup := items[index]
    pickup.hide()
    var at := pickup.global_position
    if is_instance_valid(game.player) and game.player.global_position.distance_squared_to(at) < 9.0:
        at = game.player.global_position
    else:
        at.y = game.height_at(at.z)+0.39
    _present_pickup(kind_at(index,game.selected_track),at,hit_mask)

func _activate(kind: String, racer: RigidBody3D, racers: Array[RigidBody3D]) -> int:
    var hit_mask := 0
    if kind == "turbo":
        racer.apply_central_impulse(Vector3(0.0,0.8,-9.5)*racer.mass)
    elif kind == "spring":
        racer.apply_central_impulse(Vector3(0.0,5.0,-3.4)*racer.mass)
    elif kind == "pulse":
        # Every close rival receives a bounded impulse proportional to its
        # actual distance, provided both spheres are on the same 3D deck.
        # No effects through raised shortcuts, on frozen/finished bodies
        # or outside the visible wave's exact horizontal radius.
        for opponent in racers:
            if opponent == racer or not is_instance_valid(opponent) or (
                opponent.finished or opponent.eliminated or opponent.freeze):
                continue
            var impulse: Vector3 = pulse_impulse(
                opponent.global_position-racer.global_position)
            if impulse == Vector3.ZERO:
                continue
            opponent.apply_central_impulse(impulse*opponent.mass)
            hit_mask |= 1 << opponent.racer_id
        racer.apply_central_impulse(Vector3(0.0,0.5,-2.4)*racer.mass)
    else:
        racer.linear_velocity.x *= 0.25
        racer.angular_velocity *= 0.35
        racer.apply_central_impulse(Vector3(0.0,0.35,-4.0)*racer.mass)
    return hit_mask
