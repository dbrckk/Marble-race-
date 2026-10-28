extends Node
## Internet multiplayer transport: clients only connect to an HTTPS/WebSocket public server.
## The Godot headless process owns 40 RigidBody3D racers and is the sole RPC authority.
## Single active room per server process; deploy multiple instances for scale.
signal lobby_changed(message: String)
signal session_closed(message: String)

const MAX_PLAYERS := 4
const SLOT_FIRST := 39
const FRAME_PERIOD := 0.10
const INPUT_PERIOD := 0.07
const FLOATS_PER_RACER := 9
const ROOM_CODE_LENGTH := 6
const WAIT_FOR_PLAYERS := 6.0
const RESULTS_DURATION := 15.0
const CONNECT_TIMEOUT := 90.0
const JOIN_TIMEOUT := 18.0
const SNAPSHOT_TIMEOUT := 12.0
const PING_INTERVAL := 2.5
const MIN_PING_INTERVAL_MS := 800
const COMMAND_TIMEOUT_MS := 650 # Dead-man switch: stop stale steering/boost after packet loss.
const TRACK_COUNT := 3

var game: Node3D
var role := "offline" # offline | client | server
var match_running := false
var local_slot := SLOT_FIRST
var connected := false
var joined_slots: Dictionary = {} # peer ID -> racer index; only on server
var steer_by_slot: Dictionary = {}
var boost_by_slot: Dictionary = {}
var energy_by_slot: Dictionary = {}
var last_command_ms: Dictionary = {}
var desired_mode := "public"
var desired_code := ""
var room_mode := ""
var room_code := ""
var queue_seconds := 0.0
var results_seconds := 0.0
var completed_rounds := 0 # Advance the course after each completed online match.
var frame_clock := 0.0
var input_clock := 0.0
var last_frame_time := -1.0
var match_clock := 0.0
var _closing := false
var _rng := RandomNumberGenerator.new()
var _endpoint := ""
var _connect_elapsed := 0.0
var targets: Array[Transform3D] = []
var targets_received := false
var ping_ms := -1.0
var snapshot_age_seconds := 0.0
var _join_elapsed := 0.0
var _ping_elapsed := 0.0
var _ping_sequence := 0
var _pending_ping := -1
var _sent_ping_ms := 0
var _last_ping_by_peer: Dictionary = {}

func configure(owner: Node3D) -> void:
    game = owner
    name = "InternetSession"
    _rng.randomize()

func is_active() -> bool:
    return role != "offline"

func is_client() -> bool:
    return role == "client" and match_running

func is_host() -> bool:
    return role == "server" and match_running

func can_host_start() -> bool:
    # Dedicated server automatically starts a room after minimum attendance.
    return false

func online_url() -> String:
    var config := ConfigFile.new()
    if config.load("user://marble_settings.cfg") == OK:
        var setting := str(config.get_value("online","server","")).strip_edges()
        if setting != "":
            return setting
    if FileAccess.file_exists("res://config/online_server.txt"):
        return FileAccess.get_file_as_string("res://config/online_server.txt").strip_edges()
    return ""

func set_online_url(text_url: String) -> void:
    var cfg := ConfigFile.new()
    cfg.load("user://marble_settings.cfg")
    cfg.set_value("online","server",text_url.strip_edges())
    cfg.save("user://marble_settings.cfg")

func connect_server(raw_url: String, mode: String = "public", invite_code: String = "") -> String:
    if is_active() or game.race_state != "MENU":
        return "Return to main menu and disconnect first"
    var address := raw_url.strip_edges()
    var normalized_mode := mode.strip_edges().to_lower()
    if normalized_mode not in ["public","private_create","private_join"]:
        return "Invalid matchmaking mode"
    if not (address.begins_with("wss://") or _local_ws_allowed(address)):
        return "Use a secure wss:// public server URL"
    if address.length() > 250 or address.contains(" ") or address.contains("@") or address.contains("#"):
        return "Invalid server address"
    if address == "wss://" or address.ends_with("://"):
        return "Enter the full server hostname"
    var room := invite_code.strip_edges().to_upper()
    if normalized_mode == "private_join" and not _valid_room_code(room):
        return "Enter a six-character invite code"
    var socket := WebSocketMultiplayerPeer.new()
    var status := socket.create_client(address)
    if status != OK:
        return "WebSocket connection error %d" % status
    desired_mode = normalized_mode
    desired_code = room
    _endpoint = address
    _connect_elapsed = 0.0
    _join_elapsed = 0.0
    _ping_elapsed = 0.0
    _pending_ping = -1
    ping_ms = -1.0
    snapshot_age_seconds = 0.0
    role = "client"
    connected = false
    local_slot = -1
    targets.clear()
    targets_received = false
    _register_signals()
    multiplayer.multiplayer_peer = socket
    lobby_changed.emit("CONNECTING TO SERVER... FREE HOSTS MAY TAKE UP TO 90s TO WAKE")
    return ""

func _local_ws_allowed(address: String) -> bool:
    return address.begins_with("ws://127.0.0.1:") or address.begins_with("ws://localhost:")

func _valid_room_code(room: String) -> bool:
    if room.length() != ROOM_CODE_LENGTH:
        return false
    for character in room:
        if not ("A" <= character and character <= "Z") and not ("0" <= character and character <= "9"):
            return false
    return true

func start_dedicated(port: int = 8080) -> Error:
    if is_active():
        return ERR_ALREADY_IN_USE
    var socket := WebSocketMultiplayerPeer.new()
    var status: Error = socket.create_server(port,"0.0.0.0")
    if status != OK:
        return status
    role = "server"
    connected = true
    room_code = ""
    room_mode = ""
    local_slot = SLOT_FIRST
    _register_signals()
    multiplayer.multiplayer_peer = socket
    lobby_changed.emit("Dedicated authoritative WebSocket server listening on %d" % port)
    return OK

func _register_signals() -> void:
    if not multiplayer.peer_connected.is_connected(_peer_connected):
        multiplayer.peer_connected.connect(_peer_connected)
    if not multiplayer.peer_disconnected.is_connected(_peer_disconnected):
        multiplayer.peer_disconnected.connect(_peer_disconnected)
    if not multiplayer.connected_to_server.is_connected(_server_connected):
        multiplayer.connected_to_server.connect(_server_connected)
    if not multiplayer.connection_failed.is_connected(_connection_failed):
        multiplayer.connection_failed.connect(_connection_failed)
    if not multiplayer.server_disconnected.is_connected(_server_disconnected):
        multiplayer.server_disconnected.connect(_server_disconnected)

func _server_connected() -> void:
    if role == "client":
        connected = true
        _join_elapsed = 0.0
        _request_join.rpc_id(1,desired_mode,desired_code)
        lobby_changed.emit("SERVER CONNECTED. REQUESTING ROOM...")

func _connection_failed() -> void:
    if role == "client":
        leave_room("Cannot reach the online server")

func _server_disconnected() -> void:
    if role == "client":
        leave_room("Internet server disconnected")

func _peer_connected(_id: int) -> void:
    pass # Authority registers players only after a validated room request.

func _peer_disconnected(id: int) -> void:
    if role != "server" or not joined_slots.has(id):
        return
    var slot: int = int(joined_slots[id])
    joined_slots.erase(id)
    steer_by_slot.erase(slot)
    boost_by_slot.erase(slot)
    energy_by_slot.erase(slot)
    last_command_ms.erase(id)
    _last_ping_by_peer.erase(id)
    if match_running and slot < game.racers.size():
        game.racers[slot].network_controlled = false
        game.racers[slot].is_player = false # AI resumes even for server's camera slot 39.
    if joined_slots.is_empty():
        _reset_room()
    elif not match_running and results_seconds <= 0.0:
        _broadcast_lobby_status()

func _make_code() -> String:
    var chars := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    var code := ""
    for i in range(ROOM_CODE_LENGTH):
        code += chars[_rng.randi_range(0,chars.length()-1)]
    return code

@rpc("any_peer","call_remote","reliable")
func _request_join(mode: String, code: String) -> void:
    if role != "server":
        return
    var peer_id := multiplayer.get_remote_sender_id()
    if peer_id <= 1 or joined_slots.has(peer_id):
        return
    if joined_slots.size() >= MAX_PLAYERS or match_running or results_seconds > 0.0:
        _reject_join.rpc_id(peer_id,"Room full or race already running")
        return
    if mode not in ["public","private_create","private_join"]:
        _reject_join.rpc_id(peer_id,"Unsupported mode")
        return
    if room_mode == "":
        if mode == "private_join":
            _reject_join.rpc_id(peer_id,"No private room with this code")
            return
        room_mode = "private" if mode == "private_create" else "public"
        room_code = _make_code() if room_mode == "private" else ""
    elif room_mode == "private":
        if mode != "private_join" or code != room_code:
            _reject_join.rpc_id(peer_id,"Private code incorrect or room unavailable")
            return
    elif mode != "public":
        _reject_join.rpc_id(peer_id,"A public race is waiting; try Quick Match")
        return

    var used: Array = joined_slots.values()
    var slot := SLOT_FIRST
    while slot in used and slot >= SLOT_FIRST - MAX_PLAYERS + 1:
        slot -= 1
    if slot < SLOT_FIRST-MAX_PLAYERS+1:
        _reject_join.rpc_id(peer_id,"Lobby full")
        return
    joined_slots[peer_id] = slot
    steer_by_slot[slot] = 0.0
    boost_by_slot[slot] = false
    energy_by_slot[slot] = 1.0
    last_command_ms[peer_id] = 0
    queue_seconds = 0.0 if joined_slots.size() < 2 else queue_seconds
    _accepted.rpc_id(peer_id,slot,room_mode,room_code,completed_rounds % TRACK_COUNT)
    _broadcast_lobby_status()

@rpc("authority","call_remote","reliable")
func _accepted(slot: int, visibility: String, code: String, track: int) -> void:
    if role != "client":
        return
    local_slot = clampi(slot,SLOT_FIRST-MAX_PLAYERS+1,SLOT_FIRST)
    _join_elapsed = 0.0
    _ping_elapsed = PING_INTERVAL # probe immediately after room acceptance
    room_mode = visibility
    room_code = code
    game.selected_track = clampi(track,0,2)
    lobby_changed.emit(("PRIVATE ROOM: %s   |   " % code) if code != "" else "PUBLIC MATCH FOUND")

@rpc("authority","call_remote","reliable")
func _reject_join(message: String) -> void:
    if role == "client":
        leave_room(message)

func _can_send(peer_id: int) -> bool:
    if not multiplayer.get_peers().has(peer_id):
        return false
    var socket := multiplayer.multiplayer_peer as WebSocketMultiplayerPeer
    if socket == null:
        return false
    var peer := socket.get_peer(peer_id)
    return peer != null and peer.get_ready_state() == WebSocketPeer.STATE_OPEN

func _broadcast_lobby_status() -> void:
    if role != "server":
        return
    var count: int = joined_slots.size()
    var message := "%d / 4 ONLINE PLAYERS. " % count
    message += "STARTING SOON..." if count >= 2 else "WAITING FOR ANOTHER PLAYER..."
    if room_mode == "private":
        message = "PRIVATE CODE %s   |   %s" % [room_code,message]
    lobby_changed.emit(message)
    for peer_id in joined_slots.keys():
        if _can_send(int(peer_id)):
            _lobby_state.rpc_id(int(peer_id),message,count)

@rpc("authority","call_remote","reliable")
func _lobby_state(message: String, _count: int) -> void:
    if role == "client":
        lobby_changed.emit(message)

# Reply only to accepted players. Bound probing to avoid amplification by spam.
@rpc("any_peer","call_remote","unreliable",2)
func _probe_latency(sequence: int) -> void:
    if role != "server":
        return
    var sender: int = multiplayer.get_remote_sender_id()
    if not joined_slots.has(sender):
        return
    var now: int = Time.get_ticks_msec()
    if now - int(_last_ping_by_peer.get(sender,-MIN_PING_INTERVAL_MS)) < MIN_PING_INTERVAL_MS:
        return
    _last_ping_by_peer[sender] = now
    if _can_send(sender):
        _latency_reply.rpc_id(sender,sequence)

@rpc("authority","call_remote","unreliable",2)
func _latency_reply(sequence: int) -> void:
    if role != "client" or sequence != _pending_ping or _sent_ping_ms <= 0:
        return
    var measured: int = Time.get_ticks_msec() - _sent_ping_ms
    if measured < 0 or measured > 120000:
        return
    ping_ms = float(measured) if ping_ms < 0.0 else lerpf(ping_ms,float(measured),0.35)
    _pending_ping = -1

func quality_text() -> String:
    if role != "client" or not connected:
        return ""
    if local_slot < SLOT_FIRST-MAX_PLAYERS+1:
        return "CONNECTING"
    if match_running and snapshot_age_seconds >= 4.0:
        return "NETWORK STALLED"
    if ping_ms < 0.0:
        return "CHECKING PING"
    if ping_ms >= 280.0:
        return "%d ms · SLOW" % int(ping_ms)
    if ping_ms >= 130.0:
        return "%d ms · FAIR" % int(ping_ms)
    return "%d ms · GOOD" % int(ping_ms)

func _process(delta: float) -> void:
    if role == "server":
        if match_running:
            frame_clock += delta
            if frame_clock >= FRAME_PERIOD and game.race_state in ["RACING","RESULTS"]:
                frame_clock = 0.0
                _broadcast_snapshot()
        elif results_seconds > 0.0:
            results_seconds -= delta
            if results_seconds <= 0.0:
                if joined_slots.size() >= 2:
                    _launch_match()
                else:
                    game.return_to_menu()
                    _broadcast_lobby_status()
        elif joined_slots.size() >= 2:
            queue_seconds += delta
            if queue_seconds >= WAIT_FOR_PLAYERS or joined_slots.size() == MAX_PLAYERS:
                _launch_match()
        else:
            queue_seconds = 0.0
    elif role == "client":
        if not connected:
            _connect_elapsed += delta
            if _connect_elapsed >= CONNECT_TIMEOUT:
                leave_room("Connection timed out. Check the server address and Internet access.")
        elif local_slot < SLOT_FIRST-MAX_PLAYERS+1:
            _join_elapsed += delta
            if _join_elapsed >= JOIN_TIMEOUT:
                leave_room("The server did not admit you to a room. Retry matchmaking.")
        else:
            _ping_elapsed += delta
            if _ping_elapsed >= PING_INTERVAL:
                _ping_elapsed = 0.0
                _ping_sequence += 1
                _pending_ping = _ping_sequence
                _sent_ping_ms = Time.get_ticks_msec()
                _probe_latency.rpc_id(1,_ping_sequence)
            if match_running:
                snapshot_age_seconds += delta
                if snapshot_age_seconds >= SNAPSHOT_TIMEOUT:
                    leave_room("Connection to the race was lost. Try another match.")
                    return
                input_clock += delta
                if input_clock >= INPUT_PERIOD and game.race_state == "RACING":
                    input_clock = 0.0
                    _send_controls.rpc_id(1,game.steer_target,game.boosting)
                if targets_received and game.racers.size() == targets.size():
                    var amount := clampf(delta*12.0,0.0,1.0)
                    for i in range(targets.size()):
                        var racer: RigidBody3D = game.racers[i]
                        racer.global_position = racer.global_position.lerp(targets[i].origin,amount)
                        racer.quaternion = racer.quaternion.slerp(targets[i].basis.get_rotation_quaternion(),amount)

func _launch_match() -> void:
    if role != "server" or joined_slots.size() < 2 or match_running:
        return
    # All clients receive this index in _begin_round before spawning racers.
    # Do not depend on local career unlocks: public rooms allow all courses.
    game.selected_track = completed_rounds % TRACK_COUNT
    match_running = true
    queue_seconds = 0.0
    results_seconds = 0.0
    frame_clock = 0.0
    var slots := PackedInt32Array()
    for slot in joined_slots.values():
        slots.append(int(slot))
        energy_by_slot[int(slot)] = 1.0
        boost_by_slot[int(slot)] = false
        steer_by_slot[int(slot)] = 0.0
    # Server sets up physics first; Godot RPC needs matching scene paths.
    for peer_id in joined_slots.keys():
        if _can_send(int(peer_id)):
            _begin_round.rpc_id(int(peer_id),game.selected_track,game.race_variation,slots)
    _begin_round(game.selected_track,game.race_variation,slots)
    lobby_changed.emit("ONLINE MATCH STARTED")

@rpc("authority","call_remote","reliable")
func _begin_round(track: int, variant: int, slots: PackedInt32Array) -> void:
    if role not in ["client","server"]:
        return
    match_running = true
    game.selected_track = clampi(track,0,2)
    game.race_variation = clampi(variant,0,2)
    last_frame_time = -1.0
    snapshot_age_seconds = 0.0
    targets.clear()
    targets_received = false
    game.start_race("Grip Tape")
    if role == "server":
        for slot in slots:
            game.racers[slot].network_controlled = true
    else:
        for racer in game.racers:
            racer.freeze = true
            racer.collision_layer = 0
            racer.collision_mask = 0

func all_participants_finished() -> bool:
    if role != "server" or not match_running:
        return false
    if joined_slots.is_empty():
        return true
    for slot in joined_slots.values():
        var index: int = int(slot)
        if index < 0 or index >= game.racers.size():
            continue
        var racer: RigidBody3D = game.racers[index]
        if not racer.finished and not racer.eliminated:
            return false
    return true

@rpc("any_peer","call_remote","unreliable_ordered",0)
func _send_controls(axis: float, turbo: bool) -> void:
    if role != "server" or not match_running or not is_finite(axis):
        return
    var peer_id := multiplayer.get_remote_sender_id()
    if not joined_slots.has(peer_id):
        return
    var slot: int = int(joined_slots[peer_id])
    var now: int = Time.get_ticks_msec()
    if now - int(last_command_ms.get(peer_id,0)) < 20:
        return # 50 Hz upper bound, no client-selected racer ID.
    last_command_ms[peer_id] = now
    steer_by_slot[slot] = clampf(axis,-1.0,1.0)
    boost_by_slot[slot] = turbo and float(energy_by_slot.get(slot,0.0)) >= 0.025

func input_for_slot(slot: int) -> Vector2:
    if role != "server" or not joined_slots.values().has(slot):
        return Vector2.ZERO
    return Vector2(float(steer_by_slot.get(slot,0.0)),
        1.0 if bool(boost_by_slot.get(slot,false)) and float(energy_by_slot.get(slot,0.0)) > 0.025 else 0.0)

func _physics_process(delta: float) -> void:
    if role != "server" or not match_running or game.race_state != "RACING":
        return
    # A dropped/disconnected client must not steer indefinitely on the server.
    # Watch the last *accepted* command rather than the WebSocket connection state.
    var now := Time.get_ticks_msec()
    for peer_id in joined_slots.keys():
        var joined_slot: int = int(joined_slots[peer_id])
        if now - int(last_command_ms.get(peer_id, 0)) > COMMAND_TIMEOUT_MS:
            steer_by_slot[joined_slot] = 0.0
            boost_by_slot[joined_slot] = false
    for slot in energy_by_slot.keys():
        var e: float = float(energy_by_slot[slot])
        if bool(boost_by_slot.get(slot,false)):
            e = maxf(0.0,e-delta*0.26)
        else:
            e = minf(1.0,e+delta*0.08)
        energy_by_slot[slot] = e
        if e < 0.025:
            boost_by_slot[slot] = false

func _broadcast_snapshot() -> void:
    if not match_running or game.racers.size() != 40:
        return
    var floats := PackedFloat32Array()
    for marble in game.racers:
        var quat: Quaternion = marble.quaternion
        floats.append_array(PackedFloat32Array([
            marble.global_position.x,marble.global_position.y,marble.global_position.z,
            quat.x,quat.y,quat.z,quat.w,
            1.0 if marble.finished else (-1.0 if marble.eliminated else 0.0),
            marble.finish_time
        ]))
    var energies := PackedFloat32Array()
    for slot in range(36,40):
        energies.append(float(energy_by_slot.get(slot,1.0)))
    for peer_id in joined_slots.keys():
        if _can_send(int(peer_id)):
            _receive_snapshot.rpc_id(int(peer_id),floats,game.race_time,energies)

@rpc("authority","call_remote","unreliable_ordered",1)
func _receive_snapshot(floats: PackedFloat32Array, timestamp: float, energies: PackedFloat32Array) -> void:
    if role != "client" or not match_running or game.racers.size() != 40:
        return
    if floats.size() != 40*FLOATS_PER_RACER or not is_finite(timestamp) or timestamp <= last_frame_time:
        return
    last_frame_time = timestamp
    snapshot_age_seconds = 0.0
    game.race_time = timestamp
    if targets.size() != 40:
        targets.resize(40)
    for i in range(40):
        var j := i*FLOATS_PER_RACER
        var xyz := Vector3(floats[j],floats[j+1],floats[j+2])
        if not xyz.is_finite():
            return
        var quat := Quaternion(floats[j+3],floats[j+4],floats[j+5],floats[j+6])
        if not quat.is_normalized():
            quat = Quaternion.IDENTITY
        targets[i] = Transform3D(Basis(quat),xyz)
        var marble: RigidBody3D = game.racers[i]
        if not targets_received:
            marble.global_position = xyz
            marble.quaternion = quat
        marble.finished = floats[j+7] > 0.5
        marble.eliminated = floats[j+7] < -0.5
        marble.finish_time = maxf(0.0,floats[j+8])
    targets_received = true
    if local_slot >= 36 and local_slot <= 39 and energies.size() == 4:
        game.boost_energy = clampf(energies[local_slot-36],0.0,1.0)

func notify_course_event(slot: int, kind: String) -> void:
    if role != "server" or not match_running or kind not in ["speed","ice","vent","shortcut","jump",
            "near_miss","near_miss_precision","near_miss_chain","apex",
            "bridge_gate_1","bridge_gate_2","bridge_perfect"]:
        return
    for peer_id in joined_slots.keys():
        if int(joined_slots[peer_id]) == slot and _can_send(int(peer_id)):
            _course_event_notice.rpc_id(int(peer_id),kind)
            return

@rpc("authority","call_remote","reliable")
func _course_event_notice(kind: String) -> void:
    if role != "client" or not match_running or game.race_state != "RACING":
        return
    if kind not in ["speed","ice","vent","shortcut","jump",
            "near_miss","near_miss_precision","near_miss_chain","apex",
            "bridge_gate_1","bridge_gate_2","bridge_perfect"]:
        return
    game.audio.course_event(kind)
    game.ui.show_course_event(kind)
    if kind == "apex" and is_instance_valid(game.course_sculptures) and (
            is_instance_valid(game.player)):
        # The signed server event drives only art; it never grants client
        # velocity, score or trusted in-game progression.
        game.course_sculptures.flash_local_apex(game.player.global_position.z)
    if kind.begins_with("near_miss") and is_instance_valid(game.race_director) and (
        is_instance_valid(game.player)):
        # Draw only a validated server-awarded local skill event; online
        # clients never calculate impulses, streaks or trusted rewards.
        game.race_director.flash_local_near_miss(
            game.player.global_position.z,1.0 if kind != "near_miss" else 0.40)

func notify_item_collected(slot: int, pickup_id: int, kind: String) -> void:
    # Triggered only by the authoritative human-only pickup detector.
    if role != "server" or not match_running:
        return
    if pickup_id < 0 or pickup_id >= 4 or kind not in ["turbo","spring","pulse","stabilizer"]:
        return
    for peer_id in joined_slots.keys():
        if int(joined_slots[peer_id]) == slot and _can_send(int(peer_id)):
            _rare_item_notice.rpc_id(int(peer_id),pickup_id,kind)
            return

@rpc("authority","call_remote","reliable")
func _rare_item_notice(pickup_id: int, kind: String) -> void:
    if role != "client" or not match_running or game.race_state != "RACING":
        return
    if pickup_id < 0 or pickup_id >= 4 or kind not in ["turbo","spring","pulse","stabilizer"]:
        return
    if is_instance_valid(game.race_items):
        game.race_items.mark_local_pickup(pickup_id)
    game.audio.item_pickup(kind)
    game.ui.show_item_pickup(kind)

func on_host_finish() -> void:
    if role != "server" or not match_running:
        return
    var finish_times := PackedFloat32Array()
    for marble in game.racers:
        finish_times.append(marble.finish_time if marble.finished else -1.0)
    for peer_id in joined_slots.keys():
        if _can_send(int(peer_id)):
            _show_results.rpc_id(int(peer_id),finish_times,game.race_time)
    match_running = false
    completed_rounds += 1
    results_seconds = RESULTS_DURATION

@rpc("authority","call_remote","reliable")
func _show_results(finish_times: PackedFloat32Array, elapsed: float) -> void:
    if role != "client" or not match_running or finish_times.size() != 40:
        return
    for i in range(40):
        var marble: RigidBody3D = game.racers[i]
        marble.finished = finish_times[i] >= 0.0
        marble.finish_time = maxf(0.0,finish_times[i])
    game.race_time = elapsed
    match_running = false
    game._end_race()

func _reset_room() -> void:
    match_running = false
    results_seconds = 0.0
    queue_seconds = 0.0
    joined_slots.clear()
    completed_rounds = 0
    steer_by_slot.clear()
    boost_by_slot.clear()
    energy_by_slot.clear()
    room_mode = ""
    room_code = ""
    if is_instance_valid(game) and game.race_state != "MENU":
        game.return_to_menu()

func leave_room(message: String = "") -> void:
    if _closing:
        return
    _closing = true
    var was_server := role == "server"
    match_running = false
    connected = false
    _connect_elapsed = 0.0
    _join_elapsed = 0.0
    _ping_elapsed = 0.0
    _pending_ping = -1
    _sent_ping_ms = 0
    ping_ms = -1.0
    snapshot_age_seconds = 0.0
    _last_ping_by_peer.clear()
    targets.clear()
    targets_received = false
    if multiplayer.multiplayer_peer != null:
        multiplayer.multiplayer_peer.close()
        multiplayer.multiplayer_peer = null
    role = "offline"
    local_slot = SLOT_FIRST
    if was_server:
        _reset_room()
    room_code = ""
    room_mode = ""
    _closing = false
    if is_instance_valid(game) and game.race_state != "MENU":
        game.return_to_menu()
    session_closed.emit(message)
