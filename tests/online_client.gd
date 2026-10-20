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

func _initialize() -> void:
    for argument in OS.get_cmdline_user_args():
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
    while Time.get_ticks_msec() - started < 40000:
        await process_frame
        if game.net.room_code != "" and not invite_printed:
            invite_printed = true
            print("ONLINE_INVITE_CODE ",game.net.room_code)
        if game.net.match_running and not began:
            began = true
            assert(game.net.local_slot >= 36 and game.net.local_slot <= 39,
                "Server must assign a playable marble")
            assert(game.player != null and game.player.racer_id == game.net.local_slot,
                "Camera must follow assigned online marble")
            assert(game.racers.size() == 40,"Online session must show all 40 physical marbles")
            for marble in game.racers:
                assert(marble.freeze,"Client must not run duplicate physics")
            print("ONLINE_CLIENT_MATCH_STARTED slot=%d" % game.net.local_slot)
        if began and game.race_state == "RACING":
            game.change_steer(0.76)
            game.change_boost(true)
            steering_sent = true
        if began and game.net.targets_received and game.net.last_frame_time > 0.0:
            snapped = true
        if snapped and steering_sent and game.race_time > 1.0:
            print("ONLINE_CLIENT_PASS slot=%d 40_racers=true snapshots=true controls=true server_time=%.2f" % [
                game.net.local_slot,game.race_time])
            game.net.leave_room()
            game.queue_free()
            quit(0)
            return
    push_error("ONLINE_CLIENT_TIMEOUT connected=%s begun=%s snapped=%s role=%s" % [
        str(game.net.connected),str(began),str(snapped),game.net.role])
    game.net.leave_room()
    game.queue_free()
    quit(4)
