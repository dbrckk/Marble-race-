extends SceneTree
## Real surface probes and deterministic flight/landing trajectories in all
## nine layouts. The feedback layer never edits marble velocity, positions,
## race rewards, purchases, network messages or collision geometry.
const AIR = preload("res://scripts/airtime_director.gd")
const FEEDBACK = preload("res://scripts/race_feedback.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    assert(AIR.landing_grade(0.10,0.8,18.0,2.0) == "")
    assert(AIR.landing_grade(0.5,0.04,18.0,2.0) == "")
    assert(AIR.landing_grade(0.5,0.8,1.0,2.0) == "")
    assert(AIR.landing_grade(0.5,0.8,18.0,2.0) == "PERFECT LANDING")
    assert(AIR.landing_grade(0.95,0.9,18.0,2.0) == "BIG AIR")
    assert(AIR.landing_grade(0.45,0.4,13.0,8.0) == "TOUCHDOWN")
    assert(AIR.landing_grade(NAN,0.9,18.0,2.0) == "")
    var start := Vector3(0.0,1.0,-60.0)
    var velocity := Vector3(0.0,1.8,-15.0)
    for mode in [0,1,2]:
        var base: Dictionary = FEEDBACK.camera_pose(
            start,velocity,0.0,mode,false,-1.0,false,0.0)
        var flight: Dictionary = FEEDBACK.camera_pose(
            start,velocity,0.0,mode,false,-1.0,false,1.0)
        if mode == 0:
            assert((flight["position"] as Vector3).y >
                (base["position"] as Vector3).y and
                (flight["focus"] as Vector3).y < (base["focus"] as Vector3).y and
                float(flight["fov"]) > float(base["fov"]),
                "True jumps should reveal more of the course in chase mode")
        else:
            assert(base == flight,
                "The user's alternate camera angles must not be changed")

    var stage = load("res://scenes/main.tscn").instantiate()
    root.add_child(stage)
    await process_frame
    stage.career.save_path = "user://qa_flight_career.cfg"
    stage.career.unlocked = 3
    stage.set_process(false)
    stage.set_physics_process(false)
    assert(stage.airtime != null and stage.airtime.ripple.multimesh.instance_count == 3)
    var checked := 0
    for biome in range(3):
        stage.return_to_menu()
        assert(stage.set_track(biome))
        for layout in range(3):
            stage.race_variation = layout
            stage.start_race("Grip Tape")
            stage.race_state = "RACING"
            assert(stage.built_variation == layout and stage.racers.size() == 40)
            var flight: Node3D = stage.airtime
            var player: RigidBody3D = stage.player
            player.freeze = false
            for marble in stage.racers:
                marble.freeze = true if marble != player else false
            for frame in range(4):
                await physics_frame
            _verify_jump_guides(stage)
            assert(flight.ignored_rids.size() == 40,
                "Physics probes must ignore all marbles, not mistake their tops for road")
            assert(not flight.probe_floor(player).is_empty())
            # Sample a real collision floor, not an invented deck height.
            var z: float = -15.0
            var x: float = stage.track_center_at(z)
            var ground_probe := Vector3(x,stage.height_at(z)+0.48,z)
            player.global_position = ground_probe
            var hit: Dictionary = flight.probe_floor(player)
            assert(hit.has("ground") and hit["touching"],
                "The real board must give a correct marble floor probe")
            # The physics probe is independent of video quality and uses
            # one static ray for the local human, never 40 raycasts per tick.
            for quality in range(3):
                stage.set_graphics_quality(quality)
                assert(flight.ripple.visible == (quality != 0))
                assert(flight.probe_floor(player)["touching"])
            stage.set_graphics_quality(1)
            flight.reset_round()
            var before: Vector3 = player.global_position
            var before_velocity: Vector3 = player.linear_velocity
            assert(flight.ignored_rids.size() == 40)
            var p := Vector3(x,stage.height_at(z)+0.40,z)
            # Prime on a real road. Then take off over 0.6 seconds and
            # land on a REAL ground hit below the player.
            assert(flight.sample_motion(0.05,true,0.0,p,
                Vector3(0,0,-13)).is_empty())
            var earned: Dictionary = {}
            for n in range(10):
                var dt := 0.06
                var height := 0.24+0.67*sin(float(n+1)/11.0*PI)
                var air_pos: Vector3 = p+Vector3(0.0,height,-float(n+1)*0.78)
                var speed_y: float = 3.0 if n < 5 else -3.0
                earned = flight.sample_motion(dt,false,height,air_pos,
                    Vector3(0,speed_y,-13))
                assert(earned.is_empty())
            earned = flight.sample_motion(0.06,true,0.0,
                p+Vector3(0.0,0.0,-8.2),Vector3(0,-3,-13))
            assert(earned.get("grade","") == "PERFECT LANDING" and
                float(earned["seconds"]) >= 0.38,
                "A true timed air arc must receive exactly one valid landing grade")
            assert(flight.landing_count == 1 and flight.perfect_landings == 1)
            assert(flight.sample_motion(0.06,true,0.0,
                p+Vector3(0,0,-9.0),Vector3(0,0,-13)).is_empty() and
                flight.landing_count == 1,
                "Continuous rolling must never farm additional landings")
            flight.clear_motion()
            flight._show_landing(earned)
            assert(stage.ui.race_moment_label.text.contains("PERFECT LANDING"))
            var contact_velocity := Vector3(0,0,-13)
            assert(flight.sample_control_contact(0.05,{"touching":false},before,contact_velocity) == 0)
            assert(flight.sample_control_contact(0.05,hit,before,Vector3(10,0,-13)) == 0,
                "A sideways skid has not stabilized the landing")
            player.linear_velocity = contact_velocity
            flight.tick_physics(0.05)
            assert(flight.control_weight() == 0.0 and flight.ripple_age[0] == 0.0)
            flight.tick_physics(0.05)
            assert(flight.control_weight() == 1.0 and flight.ripple_age[0] > 0.0)
            assert(flight.ripple_normal[0].is_equal_approx(hit["normal"]))
            player.linear_velocity = before_velocity
            flight.advance_visuals(0.77)
            assert(flight.ripple_age[0] == 0.0 and flight.control_weight() == 0.0)
            # Clear and arm again. A seam hop shorter than 0.125s must
            # produce zero false positives.
            flight.reset_round()
            flight.sample_motion(0.05,true,0.0,p,Vector3(0,0,-13))
            flight.sample_motion(0.05,false,0.04,p+Vector3(0,0.04,-0.6),
                Vector3(0,0.7,-13))
            flight.sample_motion(0.05,true,0.0,p+Vector3(0,0,-1.2),
                Vector3(0,0,-13))
            assert(flight.landing_count == 0)
            # A sudden network correction/teleport cancels any pending
            # airborne achievement, irrespective of vertical speed.
            flight.sample_motion(0.05,false,0.7,p+Vector3(0,0.7,-1.8),
                Vector3(0,2,-13))
            flight.sample_motion(0.05,false,1.1,p+Vector3(0,1.1,-2.4),
                Vector3(0,2,-13))
            assert(flight.sample_motion(0.05,true,0.0,
                p+Vector3(0,0,-48.0),Vector3(0,-2,-13)).is_empty())
            assert(flight.landing_count == 0 and not flight.airborne)
            # A visual callback must never change player racing physics,
            # and no paid item or career credit is awarded here.
            assert(player.global_position.is_equal_approx(before) and
                player.linear_velocity.is_equal_approx(before_velocity))
            assert(stage.race_items.used.is_empty() and
                stage.course_sculptures.earned_apex.is_empty())
            flight.reset_round()
            assert(flight.landing_count == 0 and
                flight.longest_airtime == 0.0 and
                flight.ignored_rids.size() == 40)
            if not _verify_bridge_surface(stage,flight,player,biome):
                quit(1)
                return
            if biome == 1 and not _verify_glacier_grip(stage,flight,player):
                quit(1)
                return
            if not _verify_bank_exit(stage,flight,player):
                quit(1)
                return
            stage.return_to_menu()
            assert(not stage.audio.bridge_rolling.playing and stage.audio.bridge_mix == 0.0)
            checked += 1
    assert(checked == 9)
    stage.queue_free()
    for i in range(4):
        await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(
        "user://qa_flight_career.cfg"))
    print("AIRTIME_PASS: nine real floor probes, safe jump and touchdown arcs, 40 marble exclusion, mobile pooled ripples and physics integrity")
    print("BRIDGE_SURFACE_PASS: nine real bridge floors, contact confirmation, airborne rejection, pooled ripples and reversible audio fades")
    print("GLACIER_GRIP_PASS: three real ice layouts, lateral slip, jump rejection and one grounded recovery cue")
    print("CONTROL_RETURN_PASS: nine real bank departures and two-sample touchdown recoveries with floor-aligned effects")
    print("JUMP_GUIDES_PASS: 30 ramps across nine layouts, one paint batch and lane-aware camera")
    quit(0)

func _verify_jump_guides(stage: Node3D) -> void:
    var guide: Node3D = stage.jump_guides
    var expected := 2 if stage.selected_track == 0 else 4
    assert(guide.baked and guide.windows.size() == expected and guide.ramps.size() == expected)
    assert(guide.get_child_count() == 1 and guide.paint.multimesh.instance_count == 20*expected)
    for window in guide.windows:
        var lip: Vector3 = window["lip"]
        var landing: Vector3 = window["landing"]
        var bridge: bool = window["bridge"]
        assert(lip.z > landing.z and landing.z > stage.FINISH_Z)
        var origin := lip+Vector3(0.0,0.39,5.0)
        var velocity := Vector3(0.0,0.0,-13.0)
        var hint: Dictionary = guide.preview(origin,velocity,bridge,false)
        assert(not hint.is_empty() and hint["landing"] == landing)
        assert(guide.preview(origin,velocity,not bridge,false).is_empty())
        assert(guide.preview(origin+Vector3.RIGHT*3.0,velocity,bridge,false).is_empty())
        assert(guide.preview(origin,-velocity,bridge,false).is_empty())
        assert(guide.preview(landing+Vector3(0.0,1.0,-2.0),velocity,bridge,true).is_empty())
        for mode in range(3):
            var base: Dictionary = FEEDBACK.camera_pose(origin,velocity,origin.x,mode,false,-1.0)
            var framed: Dictionary = FEEDBACK.camera_pose(origin,velocity,origin.x,mode,false,-1.0,
                false,0.0,0.0,0.0,hint)
            if mode == 0:
                var lift: float = framed["position"].y-base["position"].y
                assert(lift > 0.0 and lift < 0.65 and framed["fov"] == base["fov"])
            else:
                assert(framed == base)

func _verify_bridge_surface(stage: Node3D, flight: Node3D, player: RigidBody3D,
        biome: int) -> bool:
    var road_z := -46.0
    var road := Vector3(stage.track_center_at(road_z),stage.height_at(road_z)+0.41,road_z)
    player.global_position = road
    var road_hit: Dictionary = flight.probe_floor(player)
    assert(road_hit.get("touching",false) and not road_hit["bridge"])
    var bridge: Vector3 = stage.shortcut_route.point_at(-64.0)+Vector3.UP*0.67
    player.global_position = bridge
    var bridge_hit: Dictionary = flight.probe_floor(player)
    assert(bridge_hit.get("touching",false) and bridge_hit["bridge"])
    var over_bridge := bridge+Vector3.UP*0.75
    player.global_position = over_bridge
    var airborne_hit: Dictionary = flight.probe_floor(player)
    assert(airborne_hit.get("bridge",false) and not airborne_hit["touching"])
    assert(flight.sample_rolling_surface(road_hit,road) == 0)
    assert(flight.sample_rolling_surface(road_hit,road) == 0)
    assert(flight.sample_rolling_surface(bridge_hit,bridge) == 0)
    assert(flight.sample_rolling_surface(airborne_hit,over_bridge) == 0)
    assert(flight.sample_rolling_surface(bridge_hit,bridge) == 0)
    assert(flight.sample_rolling_surface(bridge_hit,bridge) == 1)
    assert(flight.bridge_grounded)

    var sound: Node3D = stage.audio
    player.global_position = bridge
    player.linear_velocity = Vector3(0,0,-13)
    sound.set_bridge_surface(true,true)
    sound._update_rolling(0.11)
    assert(is_equal_approx(sound.bridge_mix,0.5))
    sound._update_rolling(0.11)
    assert(is_equal_approx(sound.bridge_mix,1.0) and sound.bridge_rolling.playing)
    assert(sound.bridge_rolling.stream == sound.BRIDGE_ROLLS[biome])
    assert(sound.bridge_rolling.stream.loop)
    assert(sound.bridge_rolling.volume_db > sound.rolling.volume_db)
    sound._update_rolling(0.8)
    assert(flight.sample_rolling_surface(airborne_hit,over_bridge) == 0)
    assert(not flight.bridge_grounded and flight.rolling_surface == AIR.Surface.BRIDGE)
    var grounded_volume: float = sound.bridge_rolling.volume_db
    sound.set_bridge_surface(true,false)
    sound._update_rolling(0.2)
    assert(sound.bridge_rolling.volume_db < grounded_volume-6.0)
    assert(flight.sample_rolling_surface(bridge_hit,bridge) == 0)
    assert(flight.sample_rolling_surface(road_hit,road) == 0)
    assert(flight.sample_rolling_surface(road_hit,road) == -1)
    sound.set_bridge_surface(false,false)
    sound._update_rolling(0.11)
    assert(is_equal_approx(sound.bridge_mix,0.5))
    sound._update_rolling(0.11)
    assert(is_zero_approx(sound.bridge_mix) and not sound.bridge_rolling.playing)
    assert(player.linear_velocity.is_equal_approx(Vector3(0,0,-13)))

    flight._emit_ripple(bridge_hit["ground"],"",1)
    assert(flight.ripple_transition[0] == 1)
    assert(is_equal_approx(flight.ripple_age[0],AIR.BRIDGE_PULSE_LIFETIME))
    flight.advance_visuals(AIR.BRIDGE_PULSE_LIFETIME+0.01)
    assert(is_zero_approx(flight.ripple_age[0]))
    flight.clear_motion()
    assert(flight.sample_rolling_surface(bridge_hit,bridge) == 0)
    assert(flight.sample_rolling_surface(bridge_hit,bridge) == 0,
        "A racer placed directly on a bridge needs no entry pulse")
    return true

func _verify_glacier_grip(stage: Node3D, flight: Node3D, player: RigidBody3D) -> bool:
    flight.reset_round()
    var zone: Node3D = stage.course_mechanics.zones[0]
    var slab := zone.get_node("LowFrictionIce") as StaticBody3D
    var shape: BoxShape3D = slab.get_child(0).shape
    var ice_point := slab.to_global(Vector3.UP*shape.size.y*0.5)+Vector3.UP*AIR.RADIUS
    player.global_position = ice_point
    var ice_hit: Dictionary = flight.probe_floor(player)
    assert(ice_hit.get("ice",false) and ice_hit.get("touching",false),
        "Use a real grounded Glacier slab for all layouts")
    var slope: float = stage.track_center_at(ice_point.z+0.5)-stage.track_center_at(ice_point.z-0.5)
    player.linear_velocity = Vector3(-13.0*slope,0,-13.0)
    flight.tick_physics(0.05)
    assert(not flight.ice_touching,"One sample is too brief to confirm ice")
    flight.tick_physics(0.05)
    assert(flight.ice_touching and flight.ice_skid < 0.01,
        "Following the ice lane is not a lateral skid")
    player.linear_velocity.x += 3.6
    flight.tick_physics(0.05)
    assert(flight.ice_skid > 0.9 and flight.ice_slide_seen)
    var sound: Node3D = stage.audio
    sound.set_ice_feedback(true,true,flight.ice_skid)
    sound._process(0.12)
    assert(sound.bridge_rolling.stream == sound.BRIDGE_ROLLS[1] and sound.bridge_rolling.playing)
    assert(sound.ice_skid_mix > 0.55)

    player.global_position = ice_point+Vector3.UP*0.75
    flight.tick_physics(0.05)
    assert(not flight.ice_touching and flight.glacier_grip == AIR.Grip.ICE)
    assert(not flight.ripple_transition.has(AIR.GRIP_RETURN))
    var dry_z := ice_point.z
    var main: float = stage.track_center_at(dry_z)
    var lane_side := signf(ice_point.x-main)
    player.global_position = Vector3(main+lane_side*0.65,stage.height_at(dry_z)+0.41,dry_z)
    var dry_hit: Dictionary = flight.probe_floor(player)
    assert(dry_hit.get("touching",false) and not dry_hit.get("ice",false))
    var next_voice: int = sound.current_channel
    var velocity: Vector3 = player.linear_velocity
    flight.tick_physics(0.05)
    assert(sound.current_channel == next_voice,"Require a second solid contact before announcing grip")
    flight.tick_physics(0.05)
    assert(flight.glacier_grip == AIR.Grip.DRY and flight.ice_skid == 0.0)
    assert(flight.ripple_transition.has(AIR.GRIP_RETURN) and sound.channels[next_voice].stream == sound.WOOD_HITS[1])
    next_voice = sound.current_channel
    flight.tick_physics(0.05)
    assert(sound.current_channel == next_voice and player.linear_velocity == velocity)
    sound.set_ice_feedback(false,false,0.0)
    sound._update_rolling(0.22)
    assert(not sound.bridge_rolling.playing)
    return true

func _verify_bank_exit(stage: Node3D, flight: Node3D, player: RigidBody3D) -> bool:
    flight.reset_round()
    var bank_point: Vector3
    var dry_point: Vector3
    var exit_z := NAN
    for i in range(1,stage.course_sculptures.banks.size(),2):
        var bank: StaticBody3D = stage.course_sculptures.banks[i]
        bank_point = bank.to_global(Vector3.UP*0.055)+Vector3.UP*AIR.RADIUS
        player.global_position = bank_point
        var bank_hit: Dictionary = flight.probe_floor(player)
        if not bank_hit.get("touching",false) or not is_finite(bank_hit.get("bank_exit",NAN)):
            continue
        var candidate_exit: float = bank_hit["bank_exit"]
        var z := candidate_exit-0.72
        dry_point = Vector3(bank_point.x,stage.height_at(z)+0.43,z)
        player.global_position = dry_point
        var dry_hit: Dictionary = flight.probe_floor(player)
        if dry_hit.get("touching",false) and not is_finite(dry_hit.get("bank_exit",NAN)) and (
                flight._is_main_road(dry_hit["ground"])):
            exit_z = candidate_exit
            break
    assert(is_finite(exit_z),"Find a measurable bank and real downstream floor")
    player.global_position = bank_point
    player.linear_velocity = Vector3(0,0,-13)
    flight.tick_physics(0.05)
    flight.tick_physics(0.05)
    assert(is_equal_approx(flight.pending_bank_exit,exit_z) and flight.control_weight() == 0.0)
    player.global_position = bank_point+Vector3.UP*0.75
    flight.tick_physics(0.05)
    assert(flight.control_weight() == 0.0,"Leaving the bank in the air cannot confirm grip")
    player.global_position = dry_point
    flight.tick_physics(0.05)
    assert(flight.control_weight() == 0.0)
    flight.tick_physics(0.05)
    assert(flight.control_weight() == 1.0 and flight.ripple_transition.has(AIR.BANK_EXIT))
    assert(is_nan(flight.pending_bank_exit) and flight.landing_count == 0)
    flight.advance_visuals(0.15)
    var remaining: float = flight.control_weight()
    flight.tick_physics(0.05)
    assert(remaining < 1.0 and flight.control_weight() == remaining,
        "The same bank cannot replay its exit cue")
    assert(player.global_position.is_equal_approx(dry_point) and player.linear_velocity == Vector3(0,0,-13))
    var sound: Node3D = stage.audio
    for frame in range(45):
        sound._process(0.10)
    var open_wind: float = sound.air.volume_db
    var steady_roll: float = sound.rolling.volume_db
    sound.set_control_recovery(remaining)
    for frame in range(3):
        sound._process(0.05)
    assert(sound.air.volume_db < open_wind-2.0 and sound.rolling.volume_db > steady_roll+1.0)
    return true
