extends RefCounted
## Local-player cosmetics only. This class never touches the marble's
## RigidBody3D mass, impulses, friction, velocity or online authority.
const SKINS = preload("res://scripts/temporary_skins.gd")
const RACER = preload("res://scripts/marble.gd")

static func apply(game: Node3D) -> void:
    if not is_instance_valid(game.player) or not is_instance_valid(game.player.glass_material):
        return
    var marble: RigidBody3D = game.player
    var material: ShaderMaterial = marble.glass_material
    var index: int = game.skins.active_id() if is_instance_valid(game.skins) else -1
    material.set_shader_parameter("skin_radiance",0.0)
    material.set_shader_parameter("skin_signature",0.0)
    if index < 0:
        marble.apply_player_style(game.career.selected_style)
        if is_instance_valid(game.trail):
            game.trail.lifetime = 0.52
            game.trail.spread = 20.0
            game.trail.gravity = Vector3(0.0,-0.12,0.0)
            game.trail.color_ramp = null
            var default_mesh: SphereMesh = game.trail.mesh as SphereMesh
            if default_mesh != null:
                default_mesh.radius = 0.053
                default_mesh.height = 0.105
        return
    var definition: Dictionary = SKINS.SKINS[index]
    var base := Color(str(definition["base"]))
    var accent := Color(str(definition["accent"]))
    var vein := Color(str(definition["vein"]))
    material.set_shader_parameter("base_color",base)
    material.set_shader_parameter("accent_color",accent)
    material.set_shader_parameter("vein_color",vein)
    material.set_shader_parameter("pattern_seed",marble.seed_value+float(index)*4.73)
    material.set_shader_parameter("stripe_scale",1.10+float(index%4)*0.53)
    material.set_shader_parameter("skin_radiance",1.0)
    material.set_shader_parameter("skin_signature",float(index))
    if is_instance_valid(game.trail):
        var category := str(definition["fx"])
        # Existing CPUParticles3D, no extra particle system for the ten
        # different exclusive trails, smoke, embers, frost and stardust.
        game.trail.lifetime = 0.92 if category in [
            "smoke","ribbon","comet"] else 0.60
        game.trail.spread = 54.0 if category in [
            "smoke","petals","frost"] else 16.0
        game.trail.gravity = Vector3(0.0,
            0.55 if category in ["smoke","ember","flame"] else -0.12,0.0)
        game.trail.color = accent
        var puff: SphereMesh = game.trail.mesh as SphereMesh
        if puff != null:
            puff.radius = 0.115 if category == "smoke" else (
                0.079 if category in ["frost","petals","ribbon"] else 0.053)
            puff.height = puff.radius*2.0
        # Each specialty family has a different luminous age profile.
        # One 1D 32-pixel gradient feeds the EXISTING mobile particle system,
        # avoiding ten simultaneous emitters, sprite textures or shadow pass.
        var palette := Gradient.new()
        palette.offsets = PackedFloat32Array([0.0,0.32,1.0])
        var core: Color = Color.WHITE
        var tip: Color = Color.WHITE
        if category == "smoke":
            core = Color(0.75,0.83,0.97,0.44)
            tip = Color(0.47,0.53,0.72,0.22)
        elif category in ["flame","ember"]:
            core = Color(1.0,0.95,0.63,0.92)
            tip = Color(1.0,0.30,0.13,0.40)
        elif category == "frost":
            core = Color(0.94,1.0,1.0,0.93)
            tip = Color(0.32,0.78,1.0,0.42)
        elif category == "petals":
            core = Color(1.0,0.73,0.96,0.86)
            tip = Color(0.75,0.56,1.0,0.40)
        else:
            core = Color(1.0,1.0,1.0,0.93)
            tip = Color(0.72,0.88,1.0,0.42)
        palette.colors = PackedColorArray([core,tip,
            Color(tip.r,tip.g,tip.b,0.0)])
        var ramp := GradientTexture1D.new()
        ramp.width = 32
        ramp.gradient = palette
        game.trail.color_ramp = ramp

static func trail_tint(game: Node3D, boosting: bool) -> Color:
    if not is_instance_valid(game.skins) or game.skins.active_id() < 0:
        return Color("#91f5fd") if boosting else (
            RACER.PLAYER_STYLE_BASE[game.career.selected_style]
            if not game.net.is_active() else Color("#eeb65e"))
    var definition: Dictionary = game.skins.active_skin()
    var accent := Color(str(definition["accent"]))
    var vein := Color(str(definition["vein"]))
    var mixed: Color = accent.lerp(vein,0.38 if boosting else 0.10)
    mixed.a = 0.76 if boosting else 0.63
    return mixed
