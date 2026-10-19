extends SceneTree
const Career = preload("res://scripts/career.gd")
func _initialize() -> void:
    call_deferred("_verify")
func _verify() -> void:
    var c = Career.new()
    c.save_path="user://test_marble_career.cfg"
    c.starts=1
    assert(c.unlocked == 1)
    assert(not c.is_unlocked(1))
    var r: Dictionary = c.complete(0,9,90.0,true)
    assert(r["unlocked"] and c.unlocked == 2,"Bronze should unlock track 2")
    c.starts += 1
    r=c.complete(1,7,104.0,true)
    assert(r["unlocked"] and c.unlocked == 3,"Silver should unlock track 3")
    c.starts+=1
    r=c.complete(2,1,110.0,true)
    assert(c.stars[2] == 3 and c.victories == 1,"Gold not recorded")
    var restored=Career.new()
    restored.save_path = "user://test_marble_career.cfg"
    restored.load_save()
    assert(restored.unlocked == 3 and restored.track_best[0] == 9 and restored.track_best[1] == 7)
    assert(restored.victories == 1)
    print("CAREER_PASS: persisted medals, completion gate, unlocks, best positions")
    var root_dir=DirAccess.open("user://")
    if root_dir: root_dir.remove("test_marble_career.cfg")
    quit(0)
