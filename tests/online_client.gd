extends SceneTree
## Two independent Godot client processes connect to the same dedicated server.
## Run with -- --url=ws://127.0.0.1:8080 --mode=public [--code=XXXXXX].
const SCENE = preload("res://scenes/main.tscn")
var game: Node3D
var url := "ws://127.0.0.1:8080"
var mode := "public"
var code := ""
var began := false
var snapped := false
var steering_sent := false
var invite_printed := false
var glacier_mode := false
var glacier_cut_in_sent := false
var bridge_mode := false
var bridge_entry_seen := false
var bridge_exit_seen := false

func _initialize() -> void:
    for argument in OS.get_cmdline_user_args():
        if argument == "--glacier-cut-in":
            glacier_mode = true
        if argument == "--bridge-feedback":
            bridge_mode = true
        if argument.begins_with("--url="):
            url = argument.trim_prefix("--url=")
        if argument.begins_with("--mode="):
            mode = argument.trim_prefix("--mode=")
        if argument.begins_with("--code="):
            code = argument.trim_prefix("--code=")
    call_deferred("_verify")

func _verify() -> void:
    game = SCENE.instantiate()
    root.add_child(game)
    await process_frame
    var error: String = game.net.connect_server(url,mode,code)
    if error != "":
        push_error("ONLINE_CLIENT_CONNECT_FAILED %s" % error)
        quit(3)
        return
    var started: int = Time.get_ticks_msec()
    var deadline := 30000 if glacier_mode else 125000
    var assigned_slot := -1
    while Time.get_ticks_msec() - started < deadline:
        await process_frame
        if game.net.room_code != "" and not invite_printed:
            invite_printed = true
            print("ONLINE_INVITE_CODE ",game.net.room_code)
        if game.net.match_running and not began:
            began = true
            assigned_slot = game.net.local_slot
            assert(game.net.local_slot >= 36 and game.net.local_slot <= 39,
                "Server must assign a playable marble")
            assert(game.player != null and game.player.racer_id == game.net.local_slot,
                "Camera must follow assigned online marble")
            assert(game.racers.size() == 40,"Online session must show all 40 physical marbles")
            var hud: CanvasLayer = game.ui
            assert(hud.opening_grid.is_visible_in_tree() and
                hud.remaining_label.text == "%s  •  LAYOUT %d / 3" % [game.track_title(),game.built_variation+1],
                "The received round must open on the correct circuit and layout preview")
            assert(hud.opening_grid_gaps == game.opening_obstacle_art.entry_gaps)
            for marble in game.racers:
                assert(marble.freeze,"Client must not run duplicate physics")
            print("ONLINE_CLIENT_MATCH_STARTED slot=%d" % game.net.local_slot)
        if glacier_mode:
            if began and not game.net.connected:
                var passed := snapped and (assigned_slot != 39 or glacier_cut_in_sent)
                if passed:
                    print("GLACIER_ONLINE_CLIENT_PASS slot=",assigned_slot)
                game.queue_free()
                quit(0 if passed else 5)
                return
            if began and game.race_state == "RACING" and game.net.targets_received:
                snapped = true
                _steer_glacier_rider()
            continue
        if began and game.race_state == "RACING":
            game.change_steer(0.76)
            game.change_boost(true)
            steering_sent = true
            if bridge_mode:
                _observe_bridge_feedback()
        if began and game.net.targets_received and game.net.last_frame_time > 0.0:
            snapped = true
        if snapped and steering_sent and game.net.ping_ms >= 0.0 and game.race_time > 1.0 and (
                not bridge_mode or bridge_exit_seen):
            if bridge_mode:
                print("ONLINE_BRIDGE_FEEDBACK_PASS slot=",assigned_slot)
            print("ONLINE_CLIENT_PASS slot=%d 40_racers=true snapshots=true controls=true ping_ms=%d server_time=%.2f" % [
                game.net.local_slot,int(game.net.ping_ms),game.race_time])
            game.net.leave_room()
            game.queue_free()
            quit(0)
            return
    push_error("ONLINE_CLIENT_TIMEOUT connected=%s begun=%s snapped=%s bridge_entry=%s bridge_exit=%s role=%s" % [
        str(game.net.connected),str(began),str(snapped),str(bridge_entry_seen),
        str(bridge_exit_seen),game.net.role])
    game.net.leave_room()
    game.queue_free()
    quit(4)

func _observe_bridge_feedback() -> void:
    var flight: Node3D = game.airtime
    var sound: Node3D = game.audio
    if flight.ripple_transition.has(1) and flight.bridge_grounded and sound.bridge_rolling.playing:
        assert(game.player.freeze and game.player.linear_velocity == Vector3.ZERO,
            "Server-driven bridge presentation must not move the frozen replica")
        assert(flight.landing_count == 0)
        bridge_entry_seen = true
    if bridge_entry_seen and flight.ripple_transition.has(-1) and not sound.bridge_rolling.playing:
        bridge_exit_seen = true

func _steer_glacier_rider() -> void:
    if game.net.local_slot != 39:
        return
    var director: Node3D = game.race_director
    var gate: int = director.GLACIER_RETURN_GATE
    var gate_z: float = director.event_z(gate)
    var seen: Vector3 = game.net.targets[game.net.local_slot].origin
    if seen.z >= gate_z+11.0 or seen.z < gate_z-3.5:
        game.change_steer(0.0)
        return
    glacier_cut_in_sent = glacier_cut_in_sent or seen.z < gate_z+7.5
    var lane: float = -director.side_at(gate)*(1.7 if glacier_cut_in_sent else 3.45)
    var center: float = game.track_center_at(seen.z)
    game.change_steer(clampf((center+lane-seen.x)*0.7,-0.8,0.8))
