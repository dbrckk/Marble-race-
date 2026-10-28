extends SceneTree
## Three genuinely different original soundtrack masters, not the same
## backing OGG slowed down or sped up. All share the authentic 112 BPM
## drum grid and have bounded Android memory/decoder/voice costs.
const AUDIO = preload("res://scripts/audio.gd")
const NOTE_SR := 22050
const NOTE_BPM := 112
const BARS := 12

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    assert(AUDIO.THEME_SCORES.size() == 3)
    assert(AUDIO.THEME_TITLES.size() == 3)
    var fingerprints: Dictionary = {}
    var max_total_bytes := 0
    for index in range(3):
        var resource: AudioStream = AUDIO.THEME_SCORES[index]
        assert(resource is AudioStreamWAV,
            "Every world needs an original, offline playable PCM score")
        var track := resource as AudioStreamWAV
        print("BIOME_PCM_DEBUG track=",index,
            " sample_rate=",track.mix_rate," format=",track.format,
            " expected_format=",AudioStreamWAV.FORMAT_16_BITS,
            " payload_bytes=",track.data.size(),
            " length=",track.get_length())
        assert(track.mix_rate == NOTE_SR and
            track.format == AudioStreamWAV.FORMAT_16_BITS)
        assert(absf(track.get_length()-float(BARS*4)*60.0/float(NOTE_BPM)) < 0.02,
            "Twelve original bars must align with the adaptive 112 BPM rhythm")
        assert(track.data.size() > 900000 and track.data.size() < 1200000,
            "Scores should fill the music loop without bloating the Android APK")
        max_total_bytes += track.data.size()
        var fingerprint: int = 0
        for pos in range(0,track.data.size(),101):
            fingerprint = posmod(fingerprint*31+int(track.data[pos]),1000000007)
        assert(not fingerprints.has(fingerprint),
            "The same audio master must never be reused across biomes")
        fingerprints[fingerprint] = true
    assert(max_total_bytes < 3500000,"Three offline soundtracks should cost under 3.5 MB PCM")

    var stage = load("res://scenes/main.tscn").instantiate()
    root.add_child(stage)
    await process_frame
    stage.career.save_path = "user://qa_original_music_career.cfg"
    stage.career.unlocked = 3
    stage.set_process(false)
    stage.set_physics_process(false)
    assert(stage.audio.channels.size() == 10 and
        stage.audio.spatial_channels.size() == 7,
        "New soundtracks must reuse the original fixed SFX pools")
    for index in range(3):
        assert(stage.set_track(index))
        var player: AudioStreamPlayer = stage.audio.music
        var score: AudioStreamWAV = AUDIO.THEME_SCORES[index]
        assert(stage.audio.track_theme == index and player.stream == score)
        assert(score.loop_mode == AudioStreamWAV.LOOP_FORWARD and
            score.loop_begin == 0 and
            score.loop_end == score.data.size()/2,
            "Seamless original score loop must play to the true sample boundary")
        assert(is_equal_approx(player.pitch_scale,1.0) and
            is_equal_approx(stage.audio.percussion.pitch_scale,1.0),
            "Both independently composed melodies and their drum stems must be in sync")
        if index > 0:
            assert(stage.audio.music_fade < 0.01 and
                stage.audio.music_previous.stream == AUDIO.THEME_SCORES[index-1],
                "Track selection must preserve the old score until a clean crossfade")
        stage.audio._process(0.48)
        assert(stage.audio.music_fade > 0.5,
            "A low-overhead equal-power crossfade must progress")
        stage.audio._process(0.48)
        assert(stage.audio.music_fade == 1.0 and
            not stage.audio.music_previous.playing,
            "A finished transition cannot leave redundant audio voices playing")
        stage.start_race("Grip Tape")
        assert(stage.audio.race_active and
            stage.audio.music.stream == score,
            "The race uses its own world score rather than the shared menu loop")
        assert(stage.racers.size() == 40)
        stage.return_to_menu()
        assert(not stage.audio.race_active,
            "Rematches and menus must reset only audio energy, not track identity")
    stage.queue_free()
    for n in range(4):
        await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(
        "user://qa_original_music_career.cfg"))
    print("BIOME_SCORES_PASS: three original 12-bar masters, 112 BPM alignment, sub-3.5 MB PCM, seamless looping, crossfades and 40 marbles")
    quit(0)
