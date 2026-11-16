extends RigidBody3D
## Rigid-body racer with visually distinct procedurally marbled glass.
signal crossed_finish(racer)
signal fell_off(racer)

const SHADER = preload("res://shaders/marble.gdshader")
const AIPath = preload("res://scripts/ai_race_strategy.gd")
static var mesh_cache: Dictionary = {}
static var default_physics: PhysicsMaterial

static func get_sphere(high_detail: bool, quality: int) -> SphereMesh:
    var key := "%d-%d" % [int(high_detail),quality]
    if mesh_cache.has(key):
        return mesh_cache[key]
    var sphere := SphereMesh.new()
    sphere.radius = RADIUS
    sphere.height = RADIUS * 2.0
    if quality == 0:
        sphere.radial_segments = 22 if high_detail else 14
        sphere.rings = 10 if high_detail else 7
    elif quality == 2:
        sphere.radial_segments = 40 if high_detail else 28
        sphere.rings = 20 if high_detail else 14
    else:
        sphere.radial_segments = 32 if high_detail else 24
        sphere.rings = 16 if high_detail else 12
    mesh_cache[key] = sphere
    return sphere

func set_render_quality(quality: int) -> void:
    if is_instance_valid(mesh):
        mesh.mesh = get_sphere(is_player,quality)
        if is_instance_valid(glass_material):
            glass_material.set_shader_parameter("visual_quality",float(clampi(quality,0,2)))
const RADIUS := 0.39
const GLACIER_ACTIVE_SCAN := 0.10
const GLACIER_ABORT_TIME := 0.35
const GLACIER_MERGE_BRAKE_HOLD := 0.25
const GLACIER_MERGE_RECOVERY := 1.0
const PALETTE := [
    Color("#e98739"), Color("#46adb4"), Color("#e45d88"), Color("#a75ad0"),
    Color("#76bc64"), Color("#f1c353"), Color("#e76850"), Color("#468fdc"),
    Color("#e6e1e1"), Color("#bb6c50"), Color("#598c68"), Color("#384d9a")
]
const NAMES := [
    "Copper", "Turquoise", "Rosie", "Orchid", "Lucky Green", "Sunburst",
    "Ruby", "Blue Marble", "Snowfall", "Cinnamon", "Moss", "Midnight",
    "Tiger Eye", "Violet", "Lucky", "Poppy", "Spark", "Drift", "Mango",
    "Jasper", "Rainbow", "Atlas", "Comet", "Bolt", "Pebble", "Cobalt",
    "Swirl", "Mint", "Saffron", "Frost", "Plum", "Amber", "Quartz",
    "Bubble", "Blizzard", "Jade", "Nova", "Ripple", "Opal", "YOU"
]

var racer_id := 0
var course_owner: Node3D
var display_name := ""
var is_player := false
var network_controlled := false
var finished := false
var eliminated := false
var finish_time := 0.0
var previous_race_position := Vector3.ZERO
var perk := ""
var track_direction := -1.0
var mesh: MeshInstance3D
var collision: CollisionShape3D
var seed_value := 0.0
var target_sway := 0.0
var stuck_seconds := 0.0
var recovery_count := 0
var progress_anchor_z := 0.0
var progress_stall_seconds := 0.0
var boost_ring: MeshInstance3D
var glass_material: ShaderMaterial
var boost_glow := 0.0
var ai_lane_goal := 0.0
var ai_lane_timer := 0.0
var ai_traffic_timer := 0.0
var ai_traffic_goal := 0.0
var glacier_pass_remaining := 0.0
var glacier_pass_scan := 0.0
var glacier_leader: RigidBody3D
var glacier_waiting_to_pass := false
var glacier_resumed_pass := false
var glacier_abort_remaining := 0.0
var glacier_return_offset := 0.0
var glacier_cut_in_rider: RigidBody3D
var glacier_merge_brake_time := 0.0
var glacier_merge_recovery := 0.0
var glacier_merge_scan := 0.0
var glacier_merge_leader: RigidBody3D
var ai_traffic_offset := 0.0
var last_boosting := false

## Distinct reward-only glass palettes with zero physics or networking changes.
## Original COPPER appearance remains the default for old saves.
const PLAYER_STYLE_BASE := [
    Color("#f29b48"), Color("#70d1ed"), Color("#ffe08e"),
    Color("#bd87f3"), Color("#e9f8fb")]
const PLAYER_STYLE_ACCENT := [
    Color("#542b1d"), Color("#164f77"), Color("#bb6028"),
    Color("#392467"), Color("#f58dce")]
const PLAYER_STYLE_VEIN := [
    Color("#fff0d0"), Color("#e9ffff"), Color("#fff1bd"),
    Color("#f4caff"), Color("#89ebec")]

func apply_player_style(style: int) -> void:
    if not is_player or not is_instance_valid(glass_material):
        return
    var chosen: int = clampi(style,0,PLAYER_STYLE_BASE.size()-1)
    glass_material.set_shader_parameter("base_color",PLAYER_STYLE_BASE[chosen])
    glass_material.set_shader_parameter("accent_color",PLAYER_STYLE_ACCENT[chosen])
    glass_material.set_shader_parameter("vein_color",PLAYER_STYLE_VEIN[chosen])
    glass_material.set_shader_parameter("stripe_scale",0.80+float(chosen)*0.19)
    glass_material.set_shader_parameter("pattern_seed",
        seed_value+float(chosen)*2.83)

func setup(index: int, player: bool, base_position: Vector3, chosen_perk: String = "") -> void:
    racer_id = index
    is_player = player
    display_name = "YOU" if player else NAMES[index % (NAMES.size() - 1)]
    perk = chosen_perk if player else ""
    seed_value = float(index) * 2.317
    name = "Marble_%02d" % index
    position = base_position
    previous_race_position = base_position
    progress_anchor_z = base_position.z
    mass = 0.73
    gravity_scale = 1.0
    linear_damp = 0.20
    angular_damp = 0.16
    continuous_cd = true
    can_sleep = false
    contact_monitor = false
    if default_physics == null:
        default_physics = PhysicsMaterial.new()
        default_physics.friction = 0.72
        default_physics.bounce = 0.19
    physics_material_override = default_physics.duplicate() if is_player else default_physics

    if perk == "Lead Core":
        mass = 1.65
    elif perk == "Grip Tape":
        physics_material_override.friction = 1.28
    elif perk == "Bounce Back":
        physics_material_override.bounce = 0.80
    elif perk == "Aerodynamic":
        linear_damp = 0.045

    mesh = MeshInstance3D.new()
    mesh.name = "ArtGlass"
    mesh.mesh = get_sphere(is_player,1)
    var material = ShaderMaterial.new()
    material.shader = SHADER
    var base: Color = PALETTE[index % PALETTE.size()]
    var accent: Color = PALETTE[(index * 7 + 5) % PALETTE.size()]
    if player:
        base = Color("#f29b48")
        accent = Color("#542b1d")
    material.set_shader_parameter("base_color", base)
    material.set_shader_parameter("accent_color", accent)
    material.set_shader_parameter("vein_color", Color(0.98, 0.94, 0.82) if index % 3 == 0 else Color(0.75, 0.92, 0.93))
    material.set_shader_parameter("pattern_seed", seed_value)
    material.set_shader_parameter("stripe_scale", 0.3 + float(index % 7) * 0.29)
    glass_material = material
    material.set_shader_parameter("visual_quality",1.0)
    mesh.material_override = material
    # One cheap blended contact-shadow batch already grounds all marbles.
    # Rendering individual moving shadow maps here costs a second geometry pass.
    mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mesh)

    if is_player:
        boost_ring = MeshInstance3D.new()
        boost_ring.name = "TurboHalo"
        var halo = TorusMesh.new()
        halo.inner_radius = 0.44
        halo.outer_radius = 0.48
        halo.rings = 28
        halo.ring_segments = 7
        boost_ring.mesh = halo
        boost_ring.rotation.x = 0.15
        var ring_material = StandardMaterial3D.new()
        ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        ring_material.albedo_color = Color(0.49,0.93,1.0,0.65)
        ring_material.emission_enabled = true
        ring_material.emission = Color("#6ff1f9")
        ring_material.emission_energy_multiplier = 1.9
        boost_ring.material_override = ring_material
        boost_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        boost_ring.visible = false
        add_child(boost_ring)

    collision = CollisionShape3D.new()
    collision.name = "SphereCollision"
    var shape = SphereShape3D.new()
    shape.radius = RADIUS
    collision.shape = shape
    add_child(collision)

func wants_shortcut() -> bool:
    # About one in seven bot rivals per course, with a different set in
    # each biome. Never select a local or remotely controlled human racer.
    if is_player or network_controlled or not is_instance_valid(course_owner):
        return false
    # Opponents rotate on rematches; track layout and AI stay deterministic.
    return (racer_id*7+course_owner.selected_track*11+course_owner.built_variation*5)%13 < 2

static func recovery_side(relative_x: float, attempts: int) -> float:
    # A failed inward escape may push directly into a slalom post forever.
    # Alternate the exit edge on subsequent attempts while within the safe
    # shoulder. At the actual outer rail always steer IN to avoid a fall.
    if absf(relative_x) <= 1.0:
        return 1.0 if attempts % 2 == 0 else -1.0
    if absf(relative_x) > 2.4 and absf(relative_x) < 5.45 and attempts % 2 == 1:
        return signf(relative_x)
    return -signf(relative_x)

# Natural steering release: a moderate amount of counter-drift keeps touch
# controls predictable without braking forward speed or cancelling actual
# collisions. Glacier retains more lateral slide; active inputs keep the
# original full steering authority on both server and local humans.
static func human_steering_force(axis: float, speed_z: float,
        sideways_speed: float, biome: int) -> float:
    if not is_finite(axis) or not is_finite(speed_z) or (
        not is_finite(sideways_speed)):
        return 0.0
    var input: float = clampf(axis,-1.0,1.0)
    var forward: float = absf(speed_z)
    var direct: float = input*lerpf(18.5,26.0,clampf(forward/18.0,0.0,1.0))
    var release: float = 1.0-clampf(absf(input)/0.16,0.0,1.0)
    var coast_grip: float = [0.42,0.22,0.36][clampi(biome,0,2)]
    return direct-clampf(sideways_speed,-10.0,10.0)*coast_grip*release

func drive(delta: float, elapsed: float, steering: float, boosting: bool) -> void:
    if finished or eliminated or sleeping:
        return
    if is_player:
        boost_glow = move_toward(boost_glow,1.0 if boosting else 0.0,delta*4.4)
        if is_instance_valid(glass_material):
            glass_material.set_shader_parameter("boost_strength",boost_glow)
        if is_instance_valid(boost_ring):
            boost_ring.visible = boost_glow > 0.02
            boost_ring.rotation.y += delta*7.0*maxf(0.2,boost_glow)
            boost_ring.scale = Vector3.ONE*(0.92+0.11*sin(elapsed*12.0))
    # Downhill assistance counteracts stalls without prescribing a trajectory.
    var drive_force := 12.5
    if perk == "Aerodynamic":
        drive_force *= 1.22
    if (is_player or network_controlled) and boosting:
        drive_force += 8.0
    var side_force := 0.0
    var following_bypass := false
    if is_player or network_controlled:
        # Steering retains authority at high speed, without making tiny inputs twitchy.
        side_force = human_steering_force(steering,linear_velocity.z,
            linear_velocity.x,course_owner.selected_track if (
                is_instance_valid(course_owner)) else 0)
    else:
        # Predictable seeded weave prevents the AI from blindly hugging one rail.
        # Other marbles still interact solely through physical collisions.
        ai_lane_timer -= delta
        if ai_lane_timer <= 0.0:
            ai_lane_timer = 1.5 + float(racer_id % 5) * 0.37
            var phase: float = elapsed * 0.37 + seed_value * 2.1
            ai_lane_goal = sin(phase) * (2.0 + float(racer_id % 4) * 0.5)
        # Look ahead into the next bend: AI follows the physical winding road,
        # rather than steering towards the old straight-world X=0.
        var center_ahead: float = course_owner.track_center_at(position.z-5.0) if is_instance_valid(course_owner) else 0.0
        var lane_error: float = ai_lane_goal + center_ahead - position.x
        side_force = clampf(lane_error*1.0 - linear_velocity.x*0.18,-4.5,4.5)
        # A small, deterministic field of rivals takes the optional road.
        # AI must physically steer through its fork: no teleports, and the
        # server remains the sole source of racing physics.
        if wants_shortcut() and is_instance_valid(course_owner.shortcut_route):
            var road: Node3D = course_owner.shortcut_route
            var entered: bool = road.entered.has(racer_id)
            if AIPath.pursue_bypass(position.z,entered,
                road.ENTRY_Z,road.EXIT_Z,road.ENTRY_WINDOW):
                var aim_x: float = AIPath.bypass_target_x(road,position.z)
                side_force = AIPath.bypass_steering(aim_x,position.x,
                    linear_velocity.x,course_owner.selected_track == 1)
                following_bypass = true
        if not following_bypass and is_instance_valid(course_owner):
            # Safety-first line selection: specialist shortcuts always keep
            # their previously verified physics, while ordinary marbles only
            # attempt an overtake from the central open part of the road.
            # General passing yields to hazards. Glacier's return has a
            # dedicated passing line wholly beyond its shutter's sweep.
            var traffic_center: float = course_owner.track_center_at(position.z)
            var next_hazard: Dictionary = course_owner.upcoming_hazard(position.z)
            var hazard_near: bool = not next_hazard.is_empty() and (
                float(next_hazard.get("distance",999.0)) < 3.5)
            # Keep start-grid collisions, both route portals, jumps and
            # their AI approach entirely unchanged. Tactical side choices
            # belong in the run home where a passing duel matters most.
            var traffic_safe: bool = position.z < -108.0 and (
                not wants_shortcut()) and (
                absf(position.x-traffic_center) < 2.15) and (
                absf(ai_lane_goal) < 1.9) and not hazard_near
            if traffic_safe:
                # Staggered 2.5-3 Hz scans; no physics simulation or network
                # traffic added. Blend rather than snapping between lines.
                ai_traffic_timer -= delta
                if ai_traffic_timer <= 0.0:
                    ai_traffic_timer = AIPath.TRAFFIC_SCAN_PERIOD+(
                        float(racer_id%4)*0.05)
                    ai_traffic_goal = AIPath.traffic_lane(self,
                        course_owner.racers,center_ahead,ai_lane_goal,
                        AIPath.temperament(racer_id,
                            course_owner.selected_track,
                            course_owner.built_variation))
                ai_traffic_offset = move_toward(ai_traffic_offset,
                    ai_traffic_goal,delta*4.5)
                side_force = clampf((
                    center_ahead+ai_traffic_offset-position.x)*1.0-(
                    linear_velocity.x*0.18),-4.5,4.5)
            else:
                # Preserve the proven original control whenever a marble is
                # already near a railing, a kinetic hazard or a shortcut.
                ai_traffic_timer = 0.0
                ai_traffic_goal = ai_lane_goal
                ai_traffic_offset = ai_lane_goal
            # Biome tactics matter on all rematches: some bots seek a
            # physical boost, cautious drivers avoid ice and everyone reads
            # the Forge vent's arrival phase. Existing moving-gate avoidance
            # still has final priority. Never apply this to human steering,
            # or to specialists currently on their exterior physical road.
            var planned_offset: float = ai_traffic_offset if traffic_safe else ai_lane_goal
            if is_instance_valid(course_owner.course_mechanics):
                var zone_offset: float = AIPath.biome_zone_safe_lane(
                    course_owner.course_mechanics,position.z,
                    linear_velocity.z,planned_offset,
                    AIPath.temperament(racer_id,course_owner.selected_track,
                        course_owner.built_variation))
                if absf(zone_offset-planned_offset) > 0.10:
                    side_force = clampf((
                        center_ahead+zone_offset-position.x)*2.2-
                        linear_velocity.x*0.48,-8.5,8.5)
                    planned_offset = zone_offset
            # The physical timed-gate collider overrides a lucrative boost
            # or tempting drift when both appear in the same approach.
            if is_instance_valid(course_owner.race_director):
                var safe_offset: float = AIPath.timed_gate_safe_lane(
                    course_owner.race_director,position.z,
                    linear_velocity.z,elapsed,planned_offset)
                if absf(safe_offset-planned_offset) > 0.10:
                    side_force = clampf((
                        center_ahead+safe_offset-position.x)*2.25-
                        linear_velocity.x*0.55,-9.5,9.5)
            var glacier_lane := _glacier_return_pass(delta,traffic_center)
            var glacier_passing := glacier_pass_remaining > 0.0 and glacier_lane != INF
            if glacier_lane != INF:
                if not glacier_passing:
                    glacier_lane = AIPath.timed_gate_safe_lane(course_owner.race_director,
                        position.z,linear_velocity.z,elapsed,glacier_lane)
                var lateral_error := traffic_center+glacier_lane-position.x
                if glacier_passing:
                    side_force = clampf(lateral_error*13.0-linear_velocity.x*4.2,-19.0,19.0)
                else:
                    side_force = clampf(lateral_error*22.0-linear_velocity.x*6.0,-26.0,26.0)
            var return_x := traffic_center+glacier_return_offset if glacier_abort_remaining > 0.0 else INF
            drive_force = _glacier_follow_force(drive_force,glacier_passing,return_x)
            if glacier_abort_remaining > 0.0 and is_instance_valid(glacier_cut_in_rider):
                # Even a partly alongside bot must yield longitudinal space
                # while the other marble still has inward momentum.
                var rider_speed := -glacier_cut_in_rider.linear_velocity.z
                var gap := position.z-glacier_cut_in_rider.position.z
                var safe_speed := maxf(1.0,rider_speed+minf(0.0,(gap-1.65)*3.0))
                drive_force = minf(drive_force,maxf(-35.0,(safe_speed+linear_velocity.z)*10.0))
            drive_force = _glacier_merge_force(delta,drive_force)
            side_force += AIPath.baffle_dodge(position,traffic_center)
        elif following_bypass:
            # Real shortcut steering retains full priority over crowd
            # strategy, especially at Glacier's narrow entry portal.
            ai_traffic_timer = 0.0
            ai_traffic_goal = ai_lane_goal
            ai_traffic_offset = ai_lane_goal
    # Progress watchdog: collisions sometimes wedge a sphere with nonzero angular
    # velocity, fooling speed-based stall detection. Measure net forward progress.
    progress_stall_seconds += delta
    if progress_stall_seconds >= 2.0:
        if position.z > progress_anchor_z - 0.7:
            stuck_seconds += 1.35
        else:
            recovery_count = maxi(0,recovery_count-1)
        progress_anchor_z = position.z
        progress_stall_seconds = 0.0
    # Real physics recovery: give a marble a small nudge if trapped against a
    # rail/post for >2 sec. No teleportation, no fake position interpolation.
    # Let a marble keep its chosen outside lane instead of forcing it back.
    var center_now: float = course_owner.recovery_center_at(position) if is_instance_valid(course_owner) else 0.0
    var relative_x: float = position.x-center_now
    var wall_proximity := clampf((absf(relative_x)-4.70)/1.05,0.0,1.0)
    if following_bypass and AIPath.inside_shortcut_gate(
        course_owner.shortcut_route,position):
        # A selected AI specialist may steer through the REAL open gate.
        # Previously the 31N recovery force cancelled its 18N steering.
        # Never relax the wall on ordinary racers or human input.
        wall_proximity = 0.0
    side_force += -signf(relative_x) * 31.0 * wall_proximity
    if linear_velocity.length() < 0.65 or (absf(linear_velocity.z) < 0.30 and absf(relative_x) > 3.5):
        stuck_seconds += delta
    else:
        stuck_seconds = maxf(0.0,stuck_seconds - delta*3.0)
    if stuck_seconds > 1.65:
        var side_direction: float = recovery_side(relative_x,recovery_count)
        var effort := minf(2.8,1.0+float(recovery_count)*0.35)
        var impulse := Vector3(side_direction*3.6*effort,1.4*effort,-6.5*effort)
        if recovery_count >= 2 and not network_controlled and (
            not is_player or absf(steering) < 0.22) and is_instance_valid(course_owner) and (
            course_owner.net.role == "offline" and
            position.z < course_owner.FINAL_OBSTACLE_Z+course_owner.SEGMENT_LENGTH+2.0 and
            position.z > course_owner.CHECKPOINT_Z[-1]):
            # Release the contact with the front face before trying another
            # forward recovery between the final modules' posts and ramps.
            # Alternate sides near the center; keep the usual rail protection.
            var escape_side := side_direction
            if absf(relative_x) < 3.2:
                escape_side = -1.0 if recovery_count%2 == 0 else 1.0
            impulse = Vector3(escape_side*6.2,4.4,7.2)
        elif recovery_count >= 3 and is_player and absf(steering) < 0.22 and not network_controlled and (
            is_instance_valid(course_owner) and course_owner.selected_track > 0 and
            not course_owner.net.is_active() and absf(relative_x) > 2.4):
            # Repeated forward kicks can pin a marble against a rail and baffle.
            # Forge's staggered blocks also need a brief backward release.
            var release_z := 4.0 if course_owner.selected_track == 2 else 0.0
            var lift := 5.8 if course_owner.selected_track == 2 else 2.1
            impulse = Vector3(-signf(relative_x)*6.3,lift,release_z)
            if course_owner.selected_track == 2 and recovery_count >= 5 and recovery_count%2 == 1:
                # A slalom block can also stop an immediate inward nudge.
                # Back up along the edge on alternating attempts to clear it.
                impulse = Vector3(-signf(relative_x)*1.3,4.2,8.5)
        apply_central_impulse(impulse*mass)
        stuck_seconds = 0.0
        recovery_count += 1
    apply_central_force(Vector3(side_force, 0.0, -drive_force) * mass)
    if linear_velocity.length() > 24.0:
        linear_velocity = linear_velocity.limit_length(24.0)
    if position.y < -55.0 or absf(relative_x) > 26.0:
        eliminated = true
        fell_off.emit(self)

func _glacier_return_pass(delta: float, center_x: float) -> float:
    if course_owner.selected_track != 1 or not is_instance_valid(course_owner.race_director) or (
        not is_instance_valid(course_owner.shortcut_route)):
        return INF
    var director: Node3D = course_owner.race_director
    var gate: int = director.GLACIER_RETURN_GATE
    var distance: float = position.z-director.event_z(gate)
    if position.z > course_owner.shortcut_route.EXIT_Z-0.5 or distance < -5.0 or distance > 12.0:
        glacier_pass_remaining = 0.0
        glacier_pass_scan = 0.0
        glacier_leader = null
        glacier_waiting_to_pass = false
        glacier_resumed_pass = false
        glacier_abort_remaining = 0.0
        glacier_cut_in_rider = null
        return INF
    glacier_abort_remaining = maxf(0.0,glacier_abort_remaining-delta)
    glacier_pass_remaining = maxf(0.0,glacier_pass_remaining-delta)
    glacier_pass_scan -= delta
    var side: float = director.side_at(gate)
    var passing := glacier_pass_remaining > 0.0
    var merge_recovery := glacier_merge_recovery > 0.0
    if passing and (distance >= -1.25 or glacier_resumed_pass):
        var entries: Dictionary = course_owner.shortcut_route.entered
        if not entries.is_empty():
            var cut_in := AIPath.glacier_pass_cut_in(self,course_owner.racers,entries,
                center_x-side*AIPath.GLACIER_PASS_OFFSET)
            if is_instance_valid(cut_in):
                glacier_cut_in_rider = cut_in
                glacier_abort_remaining = GLACIER_ABORT_TIME
                glacier_pass_scan = 0.0
    elif glacier_abort_remaining <= 0.0:
        glacier_cut_in_rider = null
    if glacier_pass_scan <= 0.0 and absf(position.x-center_x) <= 2.7:
        glacier_pass_scan = AIPath.TRAFFIC_SCAN_PERIOD+float(racer_id%4)*0.05
        if passing:
            glacier_pass_scan = GLACIER_ACTIVE_SCAN
        elif glacier_waiting_to_pass or glacier_abort_remaining > 0.0 or merge_recovery:
            glacier_pass_scan = 0.14
        var within_pass_window := distance >= -1.25 or (passing and glacier_resumed_pass)
        # Reacquire traffic across the return path as soon as a pass aborts.
        if passing and within_pass_window and not AIPath.glacier_return_pass_is_clear(
                self,course_owner.racers,glacier_leader,center_x,side,true,false):
            glacier_abort_remaining = GLACIER_ABORT_TIME
        var return_x := center_x+glacier_return_offset if glacier_abort_remaining > 0.0 else INF
        var next_leader := AIPath.glacier_return_leader(self,course_owner.racers,return_x)
        if next_leader != glacier_leader:
            glacier_waiting_to_pass = false
        glacier_leader = next_leader
        if not within_pass_window or glacier_abort_remaining > 0.0:
            glacier_pass_remaining = 0.0
            glacier_resumed_pass = false
        elif passing:
            if glacier_resumed_pass:
                # Hold the open lane through the shutter while the move is safe.
                glacier_pass_remaining = maxf(glacier_pass_remaining,0.20)
        else:
            # Carry the controller's intent from the merge into the shutter
            # only when the same bridge traffic is still in front.
            var following_bridge_rider: bool = merge_recovery and is_instance_valid(glacier_leader) and (
                glacier_leader.is_player or glacier_leader.network_controlled) and (
                course_owner.shortcut_route.entered.has(glacier_leader.racer_id))
            var resuming := (glacier_waiting_to_pass or following_bridge_rider) and distance >= 2.0
            if AIPath.glacier_return_pass_is_clear(
                    self,course_owner.racers,glacier_leader,center_x,side,false,resuming):
                glacier_resumed_pass = resuming
                glacier_waiting_to_pass = false
                glacier_return_offset = position.x-center_x
                glacier_pass_remaining = 0.85
                glacier_pass_scan = GLACIER_ACTIVE_SCAN
    if glacier_abort_remaining > 0.0:
        return glacier_return_offset
    return -side*AIPath.GLACIER_PASS_OFFSET if glacier_pass_remaining > 0.0 and (
        distance >= -1.25 or glacier_resumed_pass) else INF

func _glacier_merge_force(delta: float, drive_force: float) -> float:
    var route: Node3D = course_owner.shortcut_route
    if course_owner.selected_track != 1 or not is_instance_valid(route):
        return drive_force
    var past_exit: float = route.EXIT_Z-position.z
    if past_exit < -0.5 or past_exit > 16.0 or route.entered.is_empty() or route.entered.has(racer_id):
        glacier_merge_brake_time = 0.0
        glacier_merge_recovery = 0.0
        glacier_merge_scan = 0.0
        glacier_merge_leader = null
        return drive_force
    glacier_merge_brake_time = maxf(0.0,glacier_merge_brake_time-delta)
    var limited := AIPath.glacier_merge_drive(self,course_owner.racers,route,drive_force)
    glacier_merge_recovery = maxf(0.0,glacier_merge_recovery-delta)
    if limited < 0.0 and limited < drive_force:
        glacier_merge_recovery = GLACIER_MERGE_RECOVERY
    glacier_merge_scan -= delta
    if glacier_merge_scan <= 0.0:
        glacier_merge_scan = GLACIER_ACTIVE_SCAN
        glacier_merge_leader = AIPath.glacier_return_leader(self,course_owner.racers)
    var ahead := glacier_merge_leader
    if is_instance_valid(ahead) and ahead.glacier_merge_brake_time > 0.0 and (
            AIPath.glacier_leader_in_line(self,ahead)):
        limited = _glacier_stopping_force(limited,ahead,false)
    if limited < 0.0 and limited < drive_force:
        glacier_merge_brake_time = GLACIER_MERGE_BRAKE_HOLD
    return limited


func _glacier_follow_force(drive_force: float, passing: bool, return_x: float) -> float:
    if not is_instance_valid(glacier_leader) or (
        not AIPath.glacier_leader_in_line(self,glacier_leader,return_x)):
        return drive_force
    var limited := _glacier_stopping_force(drive_force,glacier_leader,passing)
    if not passing and limited < 0.0:
        glacier_waiting_to_pass = true
    return limited


func _glacier_stopping_force(drive_force: float, leader: RigidBody3D, passing: bool) -> float:
    var gap := position.z-leader.position.z
    var speed := -linear_velocity.z
    var leader_speed := maxf(0.0,-leader.linear_velocity.z)
    # Preserve room for both bodies and let a confirmed pass develop while
    # it still has time to get alongside.
    var clear_gap := maxf(0.0,gap-1.35)
    if passing and clear_gap > (speed-leader_speed)*0.22:
        return drive_force
    var stopping_budget := 2.0*19.0*clear_gap
    var safe_speed := leader_speed+sqrt(stopping_budget) if passing else (
        sqrt(leader_speed*leader_speed+stopping_budget))
    safe_speed = maxf(1.0,safe_speed)
    return minf(drive_force,maxf(-64.0,(safe_speed-speed)*10.0))


func teleport_to_start(new_position: Vector3) -> void:
    freeze = true
    global_position = new_position
    previous_race_position = position
    linear_velocity = Vector3.ZERO
    angular_velocity = Vector3.ZERO
    finished = false
    eliminated = false
    collision_layer = 1
    collision_mask = 1
    finish_time = 0.0
    stuck_seconds = 0.0
    recovery_count = 0
    progress_anchor_z = new_position.z
    progress_stall_seconds = 0.0
    ai_lane_timer = 0.0
    ai_lane_goal = 0.0
    ai_traffic_timer = 0.0
    ai_traffic_goal = 0.0
    ai_traffic_offset = 0.0
    glacier_pass_remaining = 0.0
    glacier_pass_scan = 0.0
    glacier_leader = null
    glacier_waiting_to_pass = false
    glacier_resumed_pass = false
    glacier_abort_remaining = 0.0
    glacier_return_offset = 0.0
    glacier_cut_in_rider = null
    glacier_merge_brake_time = 0.0
    glacier_merge_recovery = 0.0
    glacier_merge_scan = 0.0
    glacier_merge_leader = null
    network_controlled = false
    freeze = false
