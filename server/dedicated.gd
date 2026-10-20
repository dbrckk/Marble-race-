extends SceneTree
## Dedicated headless server, never hosted on a player's phone.
const GAME_SCENE = preload("res://scenes/main.tscn")
var match_scene: Node3D

func _initialize() -> void:
    call_deferred("_boot")

func _boot() -> void:
    match_scene = GAME_SCENE.instantiate()
    root.add_child(match_scene)
    await process_frame
    var port := 8080
    var env := OS.get_environment("PORT")
    if env.is_valid_int():
        port = int(env)
    port = clampi(port,1024,65535)
    var status: Error = match_scene.net.start_dedicated(port)
    if status != OK:
        push_error("WORLD_SERVER_FAILED %d" % status)
        quit(2)
        return
    print("WORLD_SERVER_READY port=%d rooms=1 max_players=4 protocol=websocket" % port)
