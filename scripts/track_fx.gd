extends Node3D
## Decorative geometry only. One MultiMesh for hundreds of track rivets.
## No extra rigid bodies or expensive realtime shadow maps.
const GOLD := Color("#d9b67b")
const TRACK_LENGTH := 18
var beacons: Array[Node3D] = []
var pulsing_materials: Array[StandardMaterial3D] = []
var clock := 0.0

func _ready() -> void:
    _rivet_instancing()
    _road_markings()
    _waypoint_lanterns()

func _rivet_instancing() -> void:
    var material=StandardMaterial3D.new()
    material.albedo_color=Color("#b6a59b")
    material.metallic=0.73
    material.roughness=0.29
    material.vertex_color_use_as_albedo=true
    var mesh=SphereMesh.new()
    mesh.radius=0.090
    mesh.height=0.047
    mesh.radial_segments=8
    mesh.rings=3
    mesh.material=material
    var positions: Array[Vector3]=[]
    for section in range(TRACK_LENGTH):
        for unit in range(6):
            var z = 8.0-section*12.0+(unit-2.5)*1.87
            for side in [-1.0,1.0]:
                # Along the colorful outer rails.
                positions.append(Vector3(side*6.85, z*0.085+1.245,z))
            if unit%2==0:
                positions.append(Vector3(-6.15,z*0.085+0.032,z))
                positions.append(Vector3(6.15,z*0.085+0.032,z))
    var mm=MultiMesh.new()
    mm.transform_format=MultiMesh.TRANSFORM_3D
    mm.use_colors=true
    mm.mesh=mesh
    mm.instance_count=positions.size()
    for i in range(positions.size()):
        mm.set_instance_transform(i,Transform3D(Basis(),positions[i]))
        mm.set_instance_color(i,Color("#f9deaa") if i%7==0 else Color("#9f9da3"))
    var node=MultiMeshInstance3D.new()
    node.name="GoldFastenersInstanced"
    node.multimesh=mm
    node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(node)

func _thin_line(location: Vector3, size: Vector3, color: Color, emission := 0.0, angle := 0.0) -> void:
    var node=MeshInstance3D.new()
    var geo=BoxMesh.new()
    geo.size=size
    node.mesh=geo
    node.position=location
    node.rotation.y=angle
    var mat=StandardMaterial3D.new()
    mat.albedo_color=color
    mat.roughness=0.45
    if emission>0:
        mat.emission_enabled=true
        mat.emission=color
        mat.emission_energy_multiplier=emission
    node.material_override=mat
    node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(node)

func _road_markings() -> void:
    # Real-world toy car/slot-race markings: directional speed chevrons and lane markers.
    for section in range(1,TRACK_LENGTH-1):
        if section%2==0:
            continue
        var z=8.0-section*12.0
        for stripe in range(4):
            var zz=z+(stripe-1.5)*2.1
            for side in [-1.0,1.0]:
                var base_x=side*3.35
                var color=Color("#eed89a") if section%4==1 else Color("#a7d8c5")
                _thin_line(Vector3(base_x-0.43,zz*.085+0.07,zz),Vector3(0.74,0.018,0.12),
                    color,0.05,-0.70)
                _thin_line(Vector3(base_x+0.43,zz*.085+0.07,zz),Vector3(0.74,0.018,0.12),
                    color,0.05,0.70)
        # lane-side marker reflectors
        for side in [-1.0,1.0]:
            var x=side*5.67
            for j in range(3):
                var zz=z+(j-1)*3.3
                _thin_line(Vector3(x,zz*.085+0.045,zz),
                    Vector3(0.20,0.018,0.64),Color("#f5e3b0"),0.20)

func _waypoint_lanterns() -> void:
    # Metallic brass-ringed checkpoint light, glowing but not adding per-pixel light sources.
    for n in range(3):
        var z = 8.0-[4,9,14][n]*12.0
        for side in [-1.0,1.0]:
            var pole_x=side*6.28
            var y=z*.085+4.7
            var m=StandardMaterial3D.new()
            var col=Color("#f5c26e") if n%2==0 else Color("#9feadc")
            m.albedo_color=col
            m.emission_enabled=true
            m.emission=col
            m.emission_energy_multiplier=1.0
            m.metallic=0.18
            m.roughness=0.25
            var bulb=MeshInstance3D.new()
            bulb.name="CheckpointBeacon_%d" % n
            var sphere=SphereMesh.new()
            sphere.radius=0.25
            sphere.height=0.50
            sphere.radial_segments=14
            sphere.rings=6
            bulb.mesh=sphere
            bulb.material_override=m
            bulb.position=Vector3(pole_x,y,z)
            bulb.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            add_child(bulb)
            beacons.append(bulb)
            pulsing_materials.append(m)

func _process(delta: float) -> void:
    clock+=delta
    for idx in range(pulsing_materials.size()):
        var wave=0.45+0.45*sin(clock*3.2+idx*0.95)
        pulsing_materials[idx].emission_energy_multiplier=0.6+wave*1.0
        beacons[idx].scale=Vector3.ONE*(0.88+wave*0.15)
