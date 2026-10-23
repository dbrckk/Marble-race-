extends SceneTree
## V1 Play Store freemium contract: ten visually distinct equal-probability
## temporary skins, replacement instead of stacking, 4h ad/6h IAP, expiry,
## no click-to-reward or unverified native Google Play purchase.
const LEASE = preload("res://scripts/temporary_skins.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    assert(LEASE.SKINS.size() == 10,"Exactly ten exclusive random skins")
    var names := {}
    var fx := {}
    for def in LEASE.SKINS:
        var key := str(def["name"])
        assert(not names.has(key),"Ten skins must have distinct names")
        names[key] = true
        fx[str(def["fx"])] = true
        assert(Color(str(def["base"])).a > 0.99)
        assert(Color(str(def["accent"])).a > 0.99)
        assert(Color(str(def["vein"])).a > 0.99)
    assert(fx.size() >= 8,"Distinct premium particles cannot be recolours only")
    assert(LEASE.FREE_SECONDS == 14400 and LEASE.PAID_SECONDS == 21600)
    assert(LEASE.PRODUCT_ID == "random_skin_6h")
    assert(LEASE.format_time(14400) == "04:00:00" and
        LEASE.format_time(21600) == "06:00:00")
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.set_process(false)
    game.set_physics_process(false)
    game.career.save_path = "user://qa_freemium_career.cfg"
    var manager: Node = game.skins
    manager.skin_id = -1
    manager.ends_utc = 0
    manager.last_seen_utc = 0
    manager.source = ""
    manager.rng.seed = 73401
    assert(manager.active_id() == -1)
    assert(not game.monetization.can_watch() and not game.monetization.can_buy(),
        "Without native SDK and verified server, both paid options must fail CLOSED")
    assert(not game.monetization.watch() and not game.monetization.buy(),
        "Pressing an unconfigured store button must never create a skin")
    # Poing AdMob v5 loads RewardedAd objects without a can_show_ad()
    # method. Availability comes from its successful SDK load callback.
    var ad_stub := RefCounted.new()
    game.monetization.rewarded_ad = ad_stub
    game.monetization.ump_consent_ready = false
    assert(not game.monetization.can_watch(),
        "Without UMP privacy consent no rewarded video may start")
    game.monetization.ump_consent_ready = true
    game.monetization.rewarded_loading = true
    assert(not game.monetization.can_watch(),
        "A still-loading rewarded video cannot be displayed")
    game.monetization.rewarded_loading = false
    assert(game.monetization.can_watch(),
        "Poing v5 AdMob's loaded reward is ready without nonexistent can_show_ad")
    game.monetization.watching = true
    assert(not game.monetization.can_watch(),
        "A second video cannot start while the first is on screen")
    game.monetization.watching = false
    game.monetization.ump_consent_ready = false
    game.monetization.rewarded_ad = null
    ad_stub = null
    assert(manager.active_id() == -1)
    # If network drops between real payment and backend verification, keep
    # the private Play token across relaunch and prevent double purchases.
    var bridge = game.monetization
    var pending_qa := "qa_purchase_token_for_recovery_184723"
    assert(bridge._hold_pending(pending_qa))
    assert(bridge.pending_token == pending_qa)
    assert(not bridge._hold_pending("different_paid_purchase_token_24178"),
        "Never overwrite the first unverified purchase with a second token")
    bridge.pending_token = ""
    bridge._read_pending()
    assert(bridge.pending_token == pending_qa,
        "App relaunch must recover an unverified genuine Play receipt")
    bridge.receipt_token = pending_qa
    bridge._verified_purchase_response(1,503,PackedStringArray(),
        "{}".to_utf8_buffer())
    assert(bridge.pending_token == pending_qa and bridge.retry_remaining > 0.0,
        "A server outage cannot silently discard a paid purchase")
    assert(not bridge.can_buy(),
        "An unverified purchase must block accidental repeat billing")
    assert(manager.active_id() == -1,
        "Network error cannot mint a cosmetic reward")
    bridge._clear_pending()
    assert(bridge.pending_token == "")
    assert(not FileAccess.file_exists(bridge.PENDING_PATH))
    # A backend-generated identity + absolute expiry must be used without
    # client-side rerolling, even if a verified response is repeated.
    var issued_at := int(Time.get_unix_time_from_system())
    var server_expires: int = issued_at+LEASE.PAID_SECONDS-35
    assert(not manager.grant_from_verified_entitlement(-1,server_expires) and
        not manager.grant_from_verified_entitlement(10,server_expires) and
        not manager.grant_from_verified_entitlement(3,issued_at-1) and
        not manager.grant_from_verified_entitlement(3,
            issued_at+LEASE.PAID_SECONDS+200),
        "An invalid, expired or overlong server-paid lease must be rejected")
    assert(bridge._hold_pending(pending_qa))
    bridge.receipt_token = pending_qa
    var verified_response := JSON.stringify({"ok":true,"consumed":true,
        "product_id":LEASE.PRODUCT_ID,
        "token_sha256":pending_qa.sha256_text(),"skin_id":7,
        "expires_utc":server_expires})
    bridge._verified_purchase_response(0,200,PackedStringArray(),
        verified_response.to_utf8_buffer())
    assert(manager.active_id() == 7 and manager.ends_utc == server_expires and
        manager.source == "play",
        "A validated purchase must apply the immutable server-selected skin")
    assert(bridge.pending_token == "" and
        not FileAccess.file_exists(bridge.PENDING_PATH),
        "Successful entitlement must resolve the saved purchase")
    assert(bridge.consumed.has(pending_qa.sha256_text()),
        "A redeemed product token is locally protected from repeat credit")
    assert(manager.grant_from_verified_entitlement(7,server_expires) and
        manager.ends_utc == server_expires,
        "Replayed backend receipt cannot extend six hours or reroll")
    manager.skin_id = -1
    manager.ends_utc = 0
    manager.source = ""
    manager.last_seen_utc = 0
    manager._save()
    manager.changed.emit()
    # Google Play Billing 3.3 returns an ARRAY of one-time purchase offers,
    # not the old singular object. Show real localized prices only.
    bridge._billing_details({"response_code":0,"product_details":[{
        "product_id":LEASE.PRODUCT_ID,
        "one_time_purchase_offer_details_list":[{
            "formatted_price":"2,00 €","price_currency_code":"EUR",
            "purchase_option_id":"regular_offer"}]}]})
    assert(bridge.billed_product_available and
        bridge.displayed_price == "2,00 €" and
        bridge.purchase_option_id == "regular_offer",
        "The purchase button must read a real localized Play Billing 3.3 offer")
    assert(not bridge.can_buy(),
        "An offline mock offer cannot make a missing native billing SDK purchasable")
    bridge._billing_details({"response_code":0,"product_details":[{
        "product_id":LEASE.PRODUCT_ID,
        "one_time_purchase_offer_details_list":null}]})
    assert(not bridge.billed_product_available and
        bridge.displayed_price == "—",
        "No offer must disable purchases rather than invent a two-euro price")
    game.ui.show_skin_shop()
    assert(game.ui.skin_shop_layer.visible)
    assert(game.ui.skin_shop_layer.find_children(
        "ExclusiveSkin_*","Label",true,false).size() == 10)
    assert(game.ui.skin_ad_button.disabled and
        game.ui.skin_purchase_button.disabled,
        "No payment or ad option may promise a reward it cannot confirm")
    assert(game.ui.skin_shop_status.text == "No exclusive skin active")
    assert(game.ui.skin_shop_layer.find_child("TenSkinCatalogueScroll",
        true,false) is ScrollContainer)
    assert(manager._grant(LEASE.FREE_SECONDS,"ad"))
    assert(manager.remaining() <= 14400 and manager.remaining() >= 14398)
    assert(manager.source == "ad")
    assert(game.player.glass_material.get_shader_parameter("skin_radiance") == 1.0)
    assert(int(game.player.glass_material.get_shader_parameter("skin_signature")) ==
        manager.active_id())
    assert(game.trail.color_ramp is Gradient,
        "Premium skins must visibly change particle age, not simply recolour glass")
    for key in ["flame","frost","smoke","petals","comet"]:
        var skin := -1
        for index in range(LEASE.SKINS.size()):
            if str(LEASE.SKINS[index]["fx"]) == key:
                skin = index
                break
        assert(skin >= 0)
        manager.skin_id = skin
        game._refresh_premium_skin()
        assert(game.trail.color_ramp is Gradient)
        var sphere: SphereMesh = game.trail.mesh as SphereMesh
        if key == "smoke":
            assert(sphere.radius > 0.11 and game.trail.gravity.y > 0.0,
                "Premium smoke must behave like larger rising puffs")
        if key == "frost":
            assert(sphere.radius > 0.07 and game.trail.gravity.y < 0.0,
                "Frost should use cool falling flakes, not the flame effect")
    var first: int = manager.active_id()
    var old_until: int = manager.ends_utc
    assert(manager._grant(LEASE.PAID_SECONDS,"play"))
    assert(manager.remaining() >= 21598 and manager.remaining() <= 21600,
        "Paid purchase REPLACES prior ad period, does not add six hours")
    assert(manager.ends_utc >= old_until+7195 and manager.source == "play")
    assert(manager.skin_id >= 0 and manager.skin_id < 10)
    assert(int(game.player.glass_material.get_shader_parameter("skin_signature")) ==
        manager.active_id(),"New skin must apply instantly to the living marble")
    assert(game.ui.skin_shop_status.text.contains("remaining"))
    assert(game.ui.skin_shop_status.text.contains(
        str(LEASE.SKINS[manager.active_id()]["name"])))
    # The same skin may be selected twice; this is truthfully disclosed as
    # 10% per skin in the shop rather than falsely promising a new identity.
    var roll_counts := PackedInt32Array()
    roll_counts.resize(10)
    for n in range(1200):
        assert(manager._grant(LEASE.FREE_SECONDS,"ad"))
        roll_counts[manager.skin_id] += 1
    for count in roll_counts:
        assert(count >= 80 and count <= 160,
            "The advertised ten-way draw must be approximately uniform")
    assert(manager.source == "ad" and manager.remaining() <= 14400)
    # A lapsed, saved cosmetic cannot survive Android app resume.
    manager.ends_utc = int(Time.get_unix_time_from_system())-1
    assert(manager.remaining() == 0 and manager.active_id() == -1)
    assert(game.player.glass_material.get_shader_parameter("skin_radiance") == 0.0)
    assert(game.trail.color_ramp == null and
        absf((game.trail.mesh as SphereMesh).radius-0.053) < 0.001,
        "Skin expiry must restore the ordinary player trail with no premium remnants")
    # An invalid/rolled-back clock cannot prolong a skin indefinitely.
    manager.last_seen_utc = int(Time.get_unix_time_from_system())+200
    assert(not manager._grant(LEASE.FREE_SECONDS,"ad"))
    manager.last_seen_utc = 0
    manager.skin_id = -1
    manager.ends_utc = 0
    manager.source = ""
    manager._save()
    game.ui.show_menu()
    game.queue_free()
    for i in range(3):
        await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(
        "user://qa_freemium_career.cfg"))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(LEASE.SAVE_PATH))
    # The scene was queued for deletion above; never dereference its
    # monetization child after process_frame frees the live Node.
    DirAccess.remove_absolute(ProjectSettings.globalize_path(
        "user://marble_consumed_purchases.cfg"))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(
        "user://marble_pending_play_purchase.cfg"))
    print("FREEMIUM_SKINS_PASS: 10 skins, 10% rolls, 4h/6h, nonstacking, persistence, expiry, cosmetic-only, fail-closed IAP and ads")
    quit(0)
