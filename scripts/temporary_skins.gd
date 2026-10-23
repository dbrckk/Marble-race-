extends Node
## Temporary, cosmetic-only skins. No speed, collision, cash or AI advantages.
## Unlocks are strictly through a completed native rewarded-ad callback or
## a server-verified Google Play consumable. No free button-to-reward path.
signal changed
const FREE_SECONDS := 4*60*60
const PAID_SECONDS := 6*60*60
const PRODUCT_ID := "random_skin_6h"
const SAVE_PATH := "user://marble_temporary_skin.cfg"
# Exactly ten equally likely options (10% each), every roll includes all ten.
# The previously active look MAY be rolled again, but its timer is replaced.
const SKINS := [
    {"name":"Nebula Sovereign","base":"#3326ad","accent":"#ee65f8","vein":"#9cf9ff","fx":"stardust"},
    {"name":"Solar Phoenix","base":"#ff7a24","accent":"#ffe16e","vein":"#ff327b","fx":"flame"},
    {"name":"Void Emperor","base":"#0c142d","accent":"#745cfa","vein":"#e2d5ff","fx":"aura"},
    {"name":"Aurora Prism","base":"#0fcba4","accent":"#81b6ff","vein":"#fdd3ff","fx":"ribbon"},
    {"name":"Glacial Crown","base":"#82ecff","accent":"#e7fcff","vein":"#348ec3","fx":"frost"},
    {"name":"Dragonfire Relic","base":"#a2263c","accent":"#ff8b41","vein":"#ffe89b","fx":"ember"},
    {"name":"Celestial Lotus","base":"#ffc0f4","accent":"#7d72ff","vein":"#ffffff","fx":"petals"},
    {"name":"Quantum Mirage","base":"#19d2da","accent":"#d9fc61","vein":"#ffeafc","fx":"spark"},
    {"name":"Obsidian Eclipse","base":"#121a21","accent":"#bbd1db","vein":"#f5c16c","fx":"smoke"},
    {"name":"Royal Stardust","base":"#f5cd6e","accent":"#813ac5","vein":"#ffffff","fx":"comet"}
]
var skin_id := -1
var source := ""
var ends_utc := 0
var last_seen_utc := 0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
    rng.randomize()
    _read()

static func format_time(seconds: int) -> String:
    var safe := maxi(0,seconds)
    return "%02d:%02d:%02d" % [safe/3600,(safe/60)%60,safe%60]

func _read() -> void:
    var settings := ConfigFile.new()
    if settings.load(SAVE_PATH) != OK:
        return
    skin_id = int(settings.get_value("lease","id",-1))
    ends_utc = int(settings.get_value("lease","until",0))
    source = str(settings.get_value("lease","source",""))
    last_seen_utc = int(settings.get_value("lease","seen",0))
    _refresh()

func _save() -> void:
    var settings := ConfigFile.new()
    settings.set_value("lease","id",skin_id)
    settings.set_value("lease","until",ends_utc)
    settings.set_value("lease","source",source)
    settings.set_value("lease","seen",last_seen_utc)
    var error: Error = settings.save(SAVE_PATH)
    if error != OK:
        push_warning("Temporary skin lease could not be saved")

func _refresh() -> void:
    var now := int(Time.get_unix_time_from_system())
    # No untrusted device-clock rollback can extend an expiring cosmetic lease.
    if now < last_seen_utc-90 or skin_id < 0 or skin_id >= SKINS.size() or (
        source not in ["ad","play"] or ends_utc <= now or
        ends_utc > now+(FREE_SECONDS if source == "ad" else PAID_SECONDS)+120):
        if skin_id >= 0:
            skin_id = -1
            ends_utc = 0
            source = ""
            last_seen_utc = now
            _save()
            changed.emit()
        return

func remaining() -> int:
    _refresh()
    if skin_id < 0:
        return 0
    return maxi(0,ends_utc-int(Time.get_unix_time_from_system()))

func active_id() -> int:
    return skin_id if remaining() > 0 else -1

func active_skin() -> Dictionary:
    var index := active_id()
    return SKINS[index] if index >= 0 else {}

func grant_from_confirmed_ad() -> bool:
    # Call only from the native SDK's on_user_earned_reward event.
    return _grant(FREE_SECONDS,"ad")

func grant_from_verified_purchase() -> bool:
    # Call only after backend purchase-token validation and idempotent
    # consumption. Never grant on click, pending purchase or billing launch.
    return _grant(PAID_SECONDS,"play")

func _grant(duration: int, origin: String) -> bool:
    if duration not in [FREE_SECONDS,PAID_SECONDS] or origin not in ["ad","play"]:
        return false
    var now := int(Time.get_unix_time_from_system())
    if now < last_seen_utc-90:
        return false
    skin_id = rng.randi_range(0,SKINS.size()-1)
    ends_utc = now+duration
    last_seen_utc = now
    source = origin
    _save()
    changed.emit()
    return true
