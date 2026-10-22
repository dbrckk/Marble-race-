extends SceneTree
## Real-world pre-race schematic and phone usability regression.
## The map is informational only, while the bottom race buttons stay fixed.
const MAP = preload("res://scripts/course_briefing.gd")
const PATH = preload("res://scripts/track_path.gd")
const ROUTE = preload("res://scripts/shortcut_route.gd")
const DIRECTOR = preload("res://scripts/race_director.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.career.save_path = "user://qa_course_briefing.cfg"
    game.career.unlocked = 3
    game.ui.show_perks()
    await process_frame
    var overview: Control = game.ui.course_briefing
    var scroll: ScrollContainer = game.ui.perk_scroll
    var footer: Control = game.ui.start_button.get_parent()
    assert(overview != null and overview.name == "PhysicalCourseBriefingMap")
    assert(scroll != null and scroll.name == "PerkSelectionScroll")
    assert(scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO)
    assert(scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED)
    assert(overview.mouse_filter == Control.MOUSE_FILTER_IGNORE,
        "Track map must not block mobile scrolling and taps")
    assert(footer.name == "FixedPerkActions")
    assert(not scroll.is_ancestor_of(game.ui.start_button),
        "START RACE must stay visible even if descriptions overflow")
    assert(not scroll.is_ancestor_of(footer.get_child(0)),
        "BACK must remain reachable even while the perk list scrolls")
    assert(game.ui.select_buttons.size() == 6)
    assert(game.ui.start_button.disabled,
        "A first-time player must choose a valid perk before starting")
    assert(game.ui.start_button.is_visible_in_tree())
    assert(overview.custom_minimum_size.y >= 120.0)
    var panel_end: float = game.ui.perk_panel.get_global_rect().end.y
    var button_bottom: float = game.ui.start_button.get_global_rect().end.y
    assert(button_bottom <= panel_end+1.0 and button_bottom > 0.0,
        "The pinned start action must not be clipped outside the card")
    var track_colors := []
    for track in range(3):
        assert(game.set_track(track))
        game.ui.show_perks()
        await process_frame
        assert(overview.course == track and overview.variation == game.race_variation)
        assert(overview.describe().contains(
            "RIGHT SHORTCUT" if ROUTE.side_for(track) > 0 else "LEFT SHORTCUT"))
        track_colors.append(MAP.TRACK_COLORS[track])
        var physical: Node3D = game.shortcut_route
        for z in [-49.0,-63.0,-80.0,-103.0]:
            var location: Vector3 = physical.point_at(z)
            assert(overview.shortcut_point(z).distance_to(
                overview.project(z,location.x)) < 0.01,
                "The briefing branch must project real shortcut geometry")
        for i in range(DIRECTOR.EVENT_Z.size()):
            assert(overview.hazard_side_at(i) == game.race_director.side_at(i),
                "First course preview must use the real timed hazard side")
            var marker: Vector2 = overview.project(DIRECTOR.EVENT_Z[i],
                PATH.center_at(DIRECTOR.EVENT_Z[i],track)+(
                float(overview.hazard_side_at(i))*3.22))
            assert(marker.is_finite())
            assert(marker.x > 20.0 and marker.x < overview.size.x-10.0)
        assert(overview.project(12.0,0.0).x <
            overview.project(-185.0,0.0).x,
            "Course overview should show forward progress left to right")
        game.ui._choose_perk("Grip Tape")
        assert(not game.ui.start_button.disabled,
            "Touch selection must make the always-visible START button active")
        # The race_variation is the NEXT attempt, while built_variation may
        # show a previous session's course. The map must forecast correctly.
        for next_variant in range(3):
            game.race_variation = next_variant
            game.ui.show_perks()
            assert(overview.variation == next_variant)
            assert(game.ui.course_strategy_label.text.contains(
                "LAYOUT %d / 3" % (next_variant+1)),
                "The player should know which physical rematch layout comes next")
            game.start_race("Grip Tape")
            assert(game.built_variation == next_variant)
            for i in range(DIRECTOR.EVENT_Z.size()):
                assert(MAP.hazard_side(track,next_variant,i) ==
                    game.race_director.side_at(i),
                    "Previewed hazard placement must match its built rematch")
            game.return_to_menu()
        assert(game.ui.start_button.visible)
    assert(track_colors[0] != track_colors[1] and
        track_colors[1] != track_colors[2],
        "Each physical landscape needs its own course card colors")
    assert(MAP.hazard_side(0,0,-1) == 0)
    assert(MAP.hazard_side(0,0,99) == 0)
    assert(MAP.hazard_side(0,0,0) != MAP.hazard_side(0,1,0),
        "The upcoming obstacle side must rotate for rematches")
    game.return_to_menu()
    game.queue_free()
    for i in range(4):
        await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(
        "user://qa_course_briefing.cfg"))
    print("COURSE_BRIEFING_PASS: real road map, 3x3 rematches, fixed phone actions and touch safety")
    quit()
