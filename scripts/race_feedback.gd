extends RefCounted
## Deterministic arcade camera and collision-feedback math.
## Lightweight, allocation-free calculations in gameplay: no raycasts,
## post-processing or extra physics, suitable for 40 marbles on Android.
const FOLLOW_MIN := 3.4
const FOLLOW_MAX := 8.0
const FOV_MIN := 63.0
const FOV_MAX := 78.0
# Camera sightline must remain above actual physical crests, even on the
# higher-relief Glacier and Forge circuits. Never move a marble or collider.
const TERRAIN_LOOK_CLEARANCE := 0.95
const CAMERA_GROUND_CLEARANCE := 3.8

static func terrain_safe_focus(focus: Vector3, floor_height: float) -> Vector3:
    if not is_finite(floor_height):
        return focus
    return Vector3(focus.x,maxf(focus.y,
        floor_height+TERRAIN_LOOK_CLEARANCE),focus.z)

static func terrain_safe_camera(position: Vector3, floor_height: float) -> Vector3:
    if not is_finite(floor_height):
        return position
    return Vector3(position.x,maxf(position.y,
        floor_height+CAMERA_GROUND_CLEARANCE),position.z)

static func smooth_factor(delta: float, rate: float) -> float:
    # Frame-rate-independent, avoiding abrupt jumps when Android goes
    # from 60 fps to 30 fps in a crowded hazard section.
    return 1.0-exp(-clampf(delta,0.0,0.12)*rate)

static func camera_pose(position: Vector3, velocity: Vector3,
    center_ahead_x: float, camera_mode: int, boosting: bool,
    hazard_distance: float, close_duel: bool = false) -> Dictionary:
    var planar_speed: float = Vector2(velocity.x,velocity.z).length()
    var pace: float = clampf((planar_speed-3.0)/19.0,0.0,1.0)
    # A compact preview pulls the camera up and back before a near-side
    # obstacle, without hiding the marble or exaggerating the speed.
    var risk: float = 0.0
    if hazard_distance >= 0.0 and hazard_distance <= 18.0:
        risk = clampf((18.0-hazard_distance)/14.0,0.0,1.0)
    var bend: float = clampf(center_ahead_x-position.x,-2.4,2.4)
    var lead: float = clampf(-velocity.z*0.23,0.0,4.2)
    var focus: Vector3
    var desired: Vector3
    match camera_mode:
        1:
            desired = position+Vector3(bend*0.16,12.5+pace*1.5,18.0+pace*1.8)
            focus = position+Vector3(bend*0.46,0.0,-8.0-lead*0.48)
        2:
            desired = position+Vector3(bend*0.20,19.0+pace*1.0,2.5)
            focus = position+Vector3(bend*0.38,0.0,-3.5-lead*0.36)
        _:
            desired = position+Vector3(
                bend*0.30,6.6+pace*0.75+risk*1.0,11.6+pace*1.6+risk*1.0)
            focus = position+Vector3(
                bend*0.72+clampf(velocity.x*0.10,-0.7,0.7),
                0.25,-5.6-lead*0.70)
    # A verified sustained duel gets slightly more framing room to see
    # the competing sphere. Only camera mode 0 changes; overhead/manual
    # modes retain their exact original framing and human control.
    var duel_lift: float = 0.0
    if close_duel and camera_mode == 0:
        var intensity: float = clampf((planar_speed-7.0)/13.0,0.0,1.0)
        duel_lift = 0.9*intensity
        desired += Vector3(0.0,duel_lift,1.3*intensity)
        focus += Vector3(0.0,0.0,0.65*intensity)
    var fov: float = clampf(
        64.0+pace*9.0+(3.1 if boosting else 0.0)+risk*1.4+
        duel_lift*2.1,
        FOV_MIN,FOV_MAX)
    return {"position":desired,"focus":focus,"fov":fov,"pace":pace,"risk":risk}

# Camera-only lean reveals genuine fast lateral corrections and the
# shape of the real winding ground. Never changes collision, input, velocity
# or the two alternative user-selected camera angles. <2.6 degrees on Android.
const CAMERA_ROLL_LIMIT := 0.045

static func camera_roll(lateral_speed: float, forward_speed: float,
        bend_delta: float, camera_mode: int) -> float:
    if camera_mode != 0 or not is_finite(lateral_speed) or (
        not is_finite(forward_speed) or not is_finite(bend_delta)):
        return 0.0
    var pace: float = clampf((forward_speed-3.0)/14.0,0.0,1.0)
    var lean: float = lateral_speed*0.0025 + bend_delta*0.0050
    return -clampf(lean*pace,-CAMERA_ROLL_LIMIT,CAMERA_ROLL_LIMIT)

static func collision_kind(other: Node) -> String:
    if other is RigidBody3D:
        return "glass"
    if other is AnimatableBody3D:
        return "mechanism"
    var label: String = other.name if is_instance_valid(other) else ""
    if label.begins_with("ToyPeg") or label.begins_with("AntiEdgeBaffle") or (
        label.begins_with("Chicane_") or label.begins_with("SlalomBlock_") or
        label.begins_with("GatePost_") or label.begins_with("BypassGuard_") or
        label.begins_with("PinballKicker_")):
        return "bumper"
    # Track planks, jump ramps, bridges and seam floors are rolling
    # surfaces; contact against them is not automatically a heavy hit.
    return "surface"

static func impact_intensity(velocity: Vector3, other: Node) -> float:
    var kind: String = collision_kind(other)
    if kind == "surface":
        # Play a landing thump only after actual downward velocity, never
        # on each ground contact while rolling at high horizontal speed.
        return clampf((-velocity.y-3.0)/10.0,0.0,1.0)
    var speed: float = velocity.length()
    if kind == "glass" and other is RigidBody3D:
        speed = (velocity-(other as RigidBody3D).linear_velocity).length()
    elif kind == "mechanism":
        speed += 1.3
    return clampf((speed-2.7)/14.0,0.0,1.0)

static func shake_strength(intensity: float) -> float:
    return clampf(intensity*0.105,0.0,0.105)

static func feedback_interval(intensity: float) -> float:
    return lerpf(0.19,0.09,clampf(intensity,0.0,1.0))
