extends SceneTree
const RACER = preload("res://scripts/marble.gd")
var stage: Node3D

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    stage=load("res://scenes/main.tscn").instantiate()
    root.add_child(stage)
    await process_frame
    stage.set_process(false)
    stage.set_physics_process(false)
    stage.career.unlocked=3
    assert(stage.set_track(0))
    for layout in range(3):
        stage.race_variation=layout
        stage.start_race("Grip Tape")
        stage.race_state="RACING"
        var player: RigidBody3D=stage.player
        var art: MeshInstance3D=stage.board.find_child("OpeningObstacleArt",true,false)
        var obstacle: StaticBody3D=art.get_parent().get_node("AntiEdgeBaffle_01_L")
        var item: Node3D=stage.race_items.items[0]
        for marble in stage.racers:
            marble.freeze=true
        for lane in [-1.65,0.0,1.65]:
            for tick in range(11):
                var z: float=art.entry_z+11.5-float(tick)*0.95
                player.global_position=Vector3(stage.track_center_at(z)+lane,stage.height_at(z)+0.52,z)
                player.linear_velocity=Vector3(0,0,-23)
                var blockers: Array[Vector3]=[]
                for i in range(39):
                    var marble: RigidBody3D=stage.racers[i]
                    var mz: float=z-1.05-float(i/5)*1.10
                    var mx: float=player.global_position.x+float(i%5-2)*1.24+sin(float(i/5)*1.7+float(tick)*0.47)*0.58
                    marble.global_position=Vector3(mx,stage.height_at(mz)+0.48,mz)
                    marble.linear_velocity=player.linear_velocity
                    blockers.append(marble.global_position)
                stage.race_moments.reset_round()
                for sample in range(5):
                    stage.race_moments.tick(0.12)
                for update in range(24):
                    stage._update_camera(1.0/60.0,update==0)
                var gaps_blocked := 0
                for gap: Vector2 in art.entry_gaps:
                    var at: Vector3 = art.to_global(Vector3((gap.x+gap.y)*0.5,0,art.entry_z+0.09))
                    at.y = stage.height_at(at.z)+0.08
                    gaps_blocked += int(_blocked(at,blockers))
                print("PACK ",layout," ",lane," ",tick," ",stage.race_moments.nearby_pack_count," ",_blocked(item.global_position,blockers)," ",_blocked(obstacle.global_position+Vector3.UP*0.30,blockers)," ",gaps_blocked," ",art.entry_gaps.size())
        for clearance in [0.0,0.8,1.6,2.4,3.2]:
            for tick in range(8):
                var z: float=art.entry_z+7.0-float(tick)*0.75
                player.global_position=Vector3(stage.track_center_at(z),stage.height_at(z)+0.52+clearance,z)
                player.linear_velocity=Vector3(0,0,-23)
                stage.airtime.airborne=clearance>0.0
                stage.airtime.flight_time=0.34
                stage.race_moments.reset_round()
                for update in range(24):
                    stage._update_camera(1.0/60.0,update==0)
                var landing_z := z-14.0
                var landing:=Vector3(stage.track_center_at(landing_z),stage.height_at(landing_z)+0.40,landing_z)
                var bounds:=root.get_visible_rect().size
                var landing_screen: Vector2=stage.camera.unproject_position(landing)/bounds
                var player_screen: Vector2=stage.camera.unproject_position(player.global_position)/bounds
                print("JUMP ",layout," ",clearance," ",tick," ",landing_screen.y," ",player_screen.y)
        stage.return_to_menu()
    stage.queue_free()
    await process_frame
    print("PROBE_PASS")
    quit()

func _blocked(target: Vector3,blockers: Array[Vector3]) -> bool:
    var origin: Vector3=stage.camera.global_position
    var direction:=target-origin
    for c in blockers:
        var t: float=direction.dot(c-origin)/direction.length_squared()
        if t>0.0 and t<1.0 and (origin+direction*t).distance_squared_to(c)<RACER.RADIUS*RACER.RADIUS:
            return true
    return false
