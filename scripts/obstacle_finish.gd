extends Node3D
## Instanced toy obstacle detail for 100+ bumpers. All artwork is collision-free.
## Four batches rather than hundreds of extra MeshInstance3D draw calls.
const BUMPER_BRASS := Color("#f4d9a0")
var posts: Array[Dictionary] = []
var blocks: Array[Dictionary] = []
var post_count := 0
var block_count := 0

func register_post(location: Vector3, radius: float, height: float, pigment: Color) -> void:
    posts.append({"pos":location, "radius":radius, "height":height, "color":pigment})

func register_block(local_transform: Transform3D, size: Vector3, pigment: Color) -> void:
    blocks.append({"transform":local_transform, "size":size, "color":pigment})

func _make_batch(name_text: String, geometry: Mesh, count: int, metallic: float, roughness: float) -> MultiMesh:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color.WHITE
    mat.vertex_color_use_as_albedo = true
    mat.metallic = metallic
    mat.roughness = roughness
    geometry.material = mat
    var batch := MultiMesh.new()
    batch.transform_format = MultiMesh.TRANSFORM_3D
    batch.use_colors = true
    batch.mesh = geometry
    batch.instance_count = count
    var art := MultiMeshInstance3D.new()
    art.name = name_text
    art.multimesh = batch
    art.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(art)
    return batch

func rebuild() -> void:
    for child in get_children():
        child.queue_free()
    post_count = posts.size()
    block_count = blocks.size()
    if post_count > 0:
        _build_post_details()
    if block_count > 0:
        _build_block_details()

func _build_post_details() -> void:
    var rings := TorusMesh.new()
    rings.inner_radius = 0.94
    rings.outer_radius = 1.12
    rings.rings = 12
    rings.ring_segments = 7
    var batch_rings := _make_batch("PostChromeBands",rings,post_count*2,0.66,0.25)
    var disks := CylinderMesh.new()
    disks.top_radius = 0.80
    disks.bottom_radius = 0.80
    disks.height = 0.17
    disks.radial_segments = 18
    var batch_disks := _make_batch("PostColorInlays",disks,post_count,0.23,0.30)
    for i in range(post_count):
        var item: Dictionary = posts[i]
        var pos: Vector3 = item["pos"]
        var radius: float = item["radius"]
        var height: float = item["height"]
        var tint: Color = item["color"]
        var basis := Basis().scaled(Vector3.ONE * radius)
        var upper := Transform3D(basis,pos+Vector3.UP*(height*0.5-0.15))
        var lower := Transform3D(basis,pos-Vector3.UP*(height*0.5-0.13))
        batch_rings.set_instance_transform(i*2,upper)
        batch_rings.set_instance_color(i*2,BUMPER_BRASS)
        batch_rings.set_instance_transform(i*2+1,lower)
        batch_rings.set_instance_color(i*2+1,Color("#596774"))
        batch_disks.set_instance_transform(i,Transform3D(basis,pos+Vector3.UP*(height*0.5+0.01)))
        batch_disks.set_instance_color(i,tint.lightened(0.24))

func _build_block_details() -> void:
    var plate_mesh := BoxMesh.new()
    plate_mesh.size = Vector3.ONE
    var dark_mesh := BoxMesh.new()
    dark_mesh.size = Vector3.ONE
    var top := _make_batch("ObstacleInsetPlates",plate_mesh,block_count,0.17,0.35)
    var foot := _make_batch("ObstacleRubberFootings",dark_mesh,block_count,0.01,0.77)
    for i in range(block_count):
        var item: Dictionary = blocks[i]
        var holder: Transform3D = item["transform"]
        var size: Vector3 = item["size"]
        var tint: Color = item["color"]
        var top_scale := Basis().scaled(Vector3(size.x*0.79,0.043,size.z*0.72))
        var foot_scale := Basis().scaled(Vector3(size.x*0.92,0.13,size.z*0.90))
        top.set_instance_transform(i,holder * Transform3D(top_scale,Vector3(0,size.y*0.5+0.024,0)))
        foot.set_instance_transform(i,holder * Transform3D(foot_scale,Vector3(0,-size.y*0.48,0)))
        top.set_instance_color(i,tint.lightened(0.17))
        foot.set_instance_color(i,Color("#384047"))
