extends Node
## Native integrations are optional during Godot headless CI. Production
## NEVER substitutes a timer, a UI click or a mock video for an earned SDK
## reward. Paid purchases are granted ONLY after backend Google Play receipt
## verification + idempotent consumption. No ad IDs or private keys in Git.
signal changed
const SKINS = preload("res://scripts/temporary_skins.gd")
const SETTINGS := "res://monetization_config.cfg"
const ADS_ROOT := "res://addons/admob/gdscript/src/api/"
const UMP_ROOT := "res://addons/admob/gdscript/src/ump/"
const BILLING_CLIENT := "res://addons/GodotGooglePlayBilling/BillingClient.gd"
var skins: Node
var rewarded_ad: Object
var rewarded_loader: Object
var rewarded_loading := false
var watching := false
var rewarded_unit := ""
var ump_consent_ready := false
var rewarded_consumed := false
var ads_initialized := false
var billing: Node
var billed_product_available := false
var displayed_price := "2,00 €"
var verify_url := ""
var verifying := false
var http: HTTPRequest
var receipt_token := ""
var info := "Premium cosmetics are not yet connected to Play services."
var consumed: Dictionary = {}
const CONSUMED_PATH := "user://marble_consumed_purchases.cfg"

func configure(lease_manager: Node) -> void:
    skins = lease_manager
    _read_config()
    _read_consumed()
    http = HTTPRequest.new()
    add_child(http)
    http.request_completed.connect(_verified_purchase_response)
    if not OS.has_feature("android"):
        info = "Google Play purchases and video ads require an Android build."
        return
    _init_ads()
    _init_billing()

func _read_config() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(SETTINGS) == OK:
        rewarded_unit = str(cfg.get_value("admob","rewarded_unit_id",""))
        verify_url = str(cfg.get_value("billing","verification_url",""))
    if not verify_url.begins_with("https://"):
        verify_url = ""

func _read_consumed() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(CONSUMED_PATH) == OK and cfg.has_section("used"):
        for key in cfg.get_section_keys("used"):
            consumed[key] = true

func _remember_token(token: String) -> void:
    var digest := token.sha256_text()
    consumed[digest] = true
    var cfg := ConfigFile.new()
    for key in consumed:
        cfg.set_value("used",str(key),true)
    cfg.save(CONSUMED_PATH)

func can_watch() -> bool:
    return ump_consent_ready and rewarded_ad != null and not watching and (
        rewarded_ad.has_method("can_show_ad") and rewarded_ad.can_show_ad())

func can_buy() -> bool:
    return billing != null and billing.is_ready() and (
        billed_product_available and not verifying and verify_url != "")

func _init_ads() -> void:
    if rewarded_unit == "" or not ResourceLoader.exists(
        ADS_ROOT+"RewardedAdLoader.gd") or not Engine.has_singleton(
        "PoingGodotAdMobRewardedAd") or not Engine.has_singleton(
        "PoingGodotAdMobUserMessagingPlatform") or not Engine.has_singleton(
        "PoingGodotAdMobConsentInformation"):
        info = "Rewarded ads require native AdMob, UMP consent and live ad ID."
        return
    if not ResourceLoader.exists(UMP_ROOT+"api/UserMessagingPlatform.gd") or (
        not ResourceLoader.exists(UMP_ROOT+"core/ConsentRequestParameters.gd")):
        info = "Google UMP privacy SDK is missing. No rewarded ads."
        return
    var consent_info_script: Script = load(UMP_ROOT+"api/ConsentInformation.gd")
    var request_script: Script = load(UMP_ROOT+"core/ConsentRequestParameters.gd")
    var consent_api: Script = load(UMP_ROOT+"api/UserMessagingPlatform.gd")
    var info_object: Object = consent_api.get("consent_information")
    # Request updated consent at every launch. Never display an ad or start
    # Google Mobile Ads from a stale, UNKNOWN or REQUIRED consent state.
    var on_consent_success := func() -> void:
        var state: int = int(info_object.get_consent_status())
        if state == 2:
            # ConsentStatus.REQUIRED: first display the real UMP consent form.
            var on_form_loaded := func(form: Object) -> void:
                var on_dismissed := func(_error: Variant) -> void:
                    _consent_complete(info_object)
                form.show(on_dismissed)
            var on_form_failed := func(_err: Variant) -> void:
                info = "Consent form unavailable; video reward disabled."
                changed.emit()
            consent_api.load_consent_form(on_form_loaded,on_form_failed)
        else:
            _consent_complete(info_object)
    var on_consent_failed := func(_err: Variant) -> void:
        info = "Ad privacy status unavailable; video reward disabled."
        changed.emit()
    info_object.update(request_script.new(),on_consent_success,on_consent_failed)

func _consent_complete(info_object: Object) -> void:
    var status: int = int(info_object.get_consent_status())
    # The plugin defines status 1=NOT_REQUIRED and 3=OBTAINED. Treat all
    # other states conservatively rather than targeting ads without consent.
    if status not in [1,3]:
        info = "Video ad unavailable under the current privacy choices."
        changed.emit()
        return
    ump_consent_ready = true
    if not ads_initialized:
        var mobile_ads_script: Script = load(ADS_ROOT+"MobileAds.gd")
        mobile_ads_script.call("initialize")
        ads_initialized = true
    _load_rewarded_ad()

func _load_rewarded_ad() -> void:
    if rewarded_loading or not ump_consent_ready or rewarded_unit == "":
        return
    rewarded_ad = null
    if is_instance_valid(rewarded_loader):
        rewarded_loader = null
    var loader_script: Script = load(ADS_ROOT+"RewardedAdLoader.gd")
    var callback_script: Script = load(ADS_ROOT+"listeners/RewardedAdLoadCallback.gd")
    var request_script: Script = load(ADS_ROOT+"core/AdRequest.gd")
    rewarded_loader = loader_script.new()
    var callback: Object = callback_script.new()
    callback.set("on_ad_loaded",func(ad: Object) -> void:
        rewarded_loading = false
        rewarded_ad = ad
        info = "Rewarded skin video ready."
        changed.emit())
    callback.set("on_ad_failed_to_load",func(_err: Variant) -> void:
        rewarded_loading = false
        rewarded_ad = null
        info = "No rewarded video available. Try again later."
        changed.emit())
    rewarded_loading = true
    rewarded_loader.load(rewarded_unit,request_script.new(),callback)

func _ad_closed() -> void:
    # A short video, early dismissal and completed rewarded video all need
    # a fresh loaded ad to support repeated four-hour rerolls.
    watching = false
    if is_instance_valid(rewarded_ad):
        rewarded_ad.destroy()
    rewarded_ad = null
    rewarded_consumed = false
    if ump_consent_ready:
        _load_rewarded_ad()
    changed.emit()

func watch() -> bool:
    if not can_watch():
        return false
    watching = true
    rewarded_consumed = false
    var listener_script: Script = load(
        ADS_ROOT+"listeners/OnUserEarnedRewardListener.gd")
    var listener: Object = listener_script.new()
    listener.set("on_user_earned_reward",func(_reward: Variant) -> void:
        if not watching or rewarded_consumed or not is_instance_valid(skins):
            return
        # The only grant is the actual SDK reward callback, never the ad
        # opening, impression, early dismissal or load-complete callback.
        rewarded_consumed = true
        skins.grant_from_confirmed_ad()
        info = "4-hour skin activated. Previous skin replaced."
        changed.emit())
    var fullscreen: Object = rewarded_ad.get("full_screen_content_callback")
    fullscreen.set("on_ad_dismissed_full_screen_content",func() -> void:
        _ad_closed())
    fullscreen.set("on_ad_failed_to_show_full_screen_content",func(_error: Variant) -> void:
        info = "Video could not play. No new skin was awarded."
        _ad_closed())
    rewarded_ad.show(listener)
    return true

func _init_billing() -> void:
    if not ResourceLoader.exists(BILLING_CLIENT) or not Engine.has_singleton(
        "GodotGooglePlayBilling"):
        return
    var script: Script = load(BILLING_CLIENT)
    billing = script.new()
    add_child(billing)
    billing.connected.connect(_billing_connected)
    billing.query_product_details_response.connect(_billing_details)
    billing.on_purchase_updated.connect(_billing_purchases)
    billing.query_purchases_response.connect(_billing_purchases)
    billing.start_connection()

func _billing_connected() -> void:
    billing.query_product_details(PackedStringArray([SKINS.PRODUCT_ID]),0)
    billing.query_purchases(0)

func _billing_details(response: Dictionary) -> void:
    billed_product_available = false
    if int(response.get("response_code",-1)) != 0:
        return
    for product in response.get("product_details",[]):
        if str(product.get("product_id",product.get("productId",""))) == SKINS.PRODUCT_ID:
            billed_product_available = true
            # Price is ultimately taken from the Google Play purchase sheet.
            var offer: Dictionary = product.get("one_time_purchase_offer_details",{})
            displayed_price = str(offer.get("formatted_price","2,00 €"))
    changed.emit()

func buy() -> bool:
    if not can_buy():
        return false
    var result: Dictionary = billing.purchase(SKINS.PRODUCT_ID)
    return int(result.get("response_code",-1)) == 0

func _billing_purchases(result: Dictionary) -> void:
    if int(result.get("response_code",-1)) != 0 or verify_url == "" or verifying:
        return
    for purchase in result.get("purchases",[]):
        # PENDING state is NEVER rewarded, nor is a wrong product/package.
        if int(purchase.get("purchase_state",0)) != 1 or not (
            SKINS.PRODUCT_ID in purchase.get("product_ids",[])) or str(
            purchase.get("package_name","")) != "com.dbrckk.marble_race":
            continue
        var token := str(purchase.get("purchase_token",""))
        if token.length() < 12 or consumed.has(token.sha256_text()):
            continue
        _request_validation(token)
        break

func _request_validation(token: String) -> void:
    if verify_url == "" or verifying or token == "":
        return
    receipt_token = token
    verifying = true
    changed.emit()
    # The server must call the Google Play Developer API, reject refunded /
    # previously consumed tokens, and atomically consume this consumable.
    # Only HTTPS JSON with ok, consumed, matching product and token_sha256 grants a skin.
    var payload := JSON.stringify({"product_id":SKINS.PRODUCT_ID,
        "package_name":"com.dbrckk.marble_race","purchase_token":token})
    var err := http.request(verify_url,[
        "Content-Type: application/json"],HTTPClient.METHOD_POST,payload)
    if err != OK:
        verifying = false
        receipt_token = ""
        info = "Purchase verification unavailable. No reward was granted."
        changed.emit()

func _verified_purchase_response(_result: int, status: int,
        _headers: PackedStringArray, body: PackedByteArray) -> void:
    var token := receipt_token
    receipt_token = ""
    verifying = false
    var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
    if status == 200 and parsed is Dictionary and bool(parsed.get("ok",false)) and (
        bool(parsed.get("consumed",false))) and (
        str(parsed.get("product_id","")) == SKINS.PRODUCT_ID) and (
        str(parsed.get("token_sha256","")) == token.sha256_text()) and (
        token != "" and not consumed.has(token.sha256_text())):
        _remember_token(token)
        skins.grant_from_verified_purchase()
        info = "6-hour skin activated. Previous skin replaced."
    else:
        info = "Google Play payment not verified. No skin awarded."
    changed.emit()
