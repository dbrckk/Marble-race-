extends RefCounted
## Portable, human-initiated solo progress transfer using Android's clipboard.
## No account, cloud connection, Android storage permission or executable
## deserialization. The SHA-256 digest detects corrupted copy/paste, not fraud.
const PREFIX := "MARBLE-CAREER-V1"
const MAX_CONFIG_BYTES := 16384
const MAX_CODE_LENGTH := 24000

static func export_career(career: RefCounted) -> Dictionary:
    if not is_instance_valid(career):
        return {"ok":false,"error":"No career to export."}
    if career.save() != OK:
        return {"ok":false,"error":"Could not save current career."}
    if not FileAccess.file_exists(career.save_path):
        return {"ok":false,"error":"Career file unavailable."}
    var bytes: PackedByteArray = FileAccess.get_file_as_bytes(career.save_path)
    if bytes.is_empty() or bytes.size() > MAX_CONFIG_BYTES:
        return {"ok":false,"error":"Career file exceeds safe backup size."}
    var content: String = bytes.get_string_from_utf8()
    var candidate: Dictionary = _validate_config(content)
    if not bool(candidate["ok"]):
        return candidate
    var code: String = "%s.%s.%s" % [
        PREFIX,content.sha256_text(),Marshalls.raw_to_base64(bytes)]
    return {"ok":true,"code":code,"length":code.length(),
        "starts":candidate["starts"],"finishes":candidate["finishes"],
        "mastery":candidate["mastery"],"league":candidate["league"]}

static func preview_previous_career(career: RefCounted) -> Dictionary:
    if not is_instance_valid(career):
        return {"ok":false,"error":"No career to recover."}
    var path: String = career.save_path+".before_import"
    if not FileAccess.file_exists(path):
        return {"ok":false,"error":"No previous import to undo."}
    var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
    if bytes.is_empty() or bytes.size() > MAX_CONFIG_BYTES:
        return {"ok":false,"error":"Previous career copy is invalid."}
    var content: String = bytes.get_string_from_utf8()
    if content.to_utf8_buffer() != bytes:
        return {"ok":false,"error":"Previous career copy has invalid text."}
    var checked: Dictionary = _validate_config(content)
    if not bool(checked["ok"]):
        return checked
    checked["code"] = "%s.%s.%s" % [
        PREFIX,content.sha256_text(),Marshalls.raw_to_base64(bytes)]
    return checked

static func preview_code(raw_code: String) -> Dictionary:
    var code: String = raw_code.strip_edges()
    if code.length() == 0 or code.length() > MAX_CODE_LENGTH:
        return {"ok":false,"error":"Paste a valid Marble Race career backup."}
    var chunks: PackedStringArray = code.split(".",false)
    if chunks.size() != 3 or chunks[0] != PREFIX or (
        chunks[1].length() != 64 or chunks[2].length() == 0):
        return {"ok":false,"error":"This backup code has an unknown format."}
    var bytes: PackedByteArray = Marshalls.base64_to_raw(chunks[2])
    if bytes.is_empty() or bytes.size() > MAX_CONFIG_BYTES:
        return {"ok":false,"error":"The backup data is incomplete or too large."}
    var content: String = bytes.get_string_from_utf8()
    if content.to_utf8_buffer() != bytes or (
        content.sha256_text() != chunks[1]):
        return {"ok":false,"error":"Checksum mismatch. Copy the entire code again."}
    var checked: Dictionary = _validate_config(content)
    if not bool(checked["ok"]):
        return checked
    checked["content"] = content
    return checked

static func restore_career(career: RefCounted, raw_code: String) -> Dictionary:
    var checked: Dictionary = preview_code(raw_code)
    if not bool(checked["ok"]):
        return checked
    if not is_instance_valid(career):
        return {"ok":false,"error":"No career to restore."}
    var temporary: String = career.save_path+".importing"
    var old_copy: String = career.save_path+".before_import"
    var file := FileAccess.open(temporary,FileAccess.WRITE)
    if file == null:
        return {"ok":false,"error":"Could not prepare restored data."}
    file.store_string(str(checked["content"]))
    file.flush()
    file.close()
    # Keep one on-device rollback copy in case the user imports an old code.
    # Do not damage the live career file until the replacement is validated.
    if FileAccess.file_exists(career.save_path):
        var existing: PackedByteArray = FileAccess.get_file_as_bytes(career.save_path)
        if existing.size() <= MAX_CONFIG_BYTES:
            var backup := FileAccess.open(old_copy,FileAccess.WRITE)
            if backup == null:
                DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
                return {"ok":false,"error":"Could not preserve the previous save."}
            backup.store_buffer(existing)
            backup.flush()
            backup.close()
    var result: Error = DirAccess.rename_absolute(
        ProjectSettings.globalize_path(temporary),
        ProjectSettings.globalize_path(career.save_path))
    if result != OK:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
        return {"ok":false,"error":"Android refused to replace the career save."}
    career.load_save()
    return {"ok":true,"starts":career.starts,"finishes":career.finishes,
        "mastery":career.mastery_count(),"league":career.league_points}

static func _validate_config(content: String) -> Dictionary:
    var config := ConfigFile.new()
    if config.parse(content) != OK or not config.has_section("career"):
        return {"ok":false,"error":"Invalid or unsupported career data."}
    # Only data from our validated career format is portable. Reject obvious
    # corruption before replacing the installed save; the Career class still
    # performs its own strict clamping on load.
    for key in ["starts","finishes","victories","podiums"]:
        if not config.has_section_key("career",key):
            return {"ok":false,"error":"The career backup is missing fields."}
        var number: Variant = config.get_value("career",key)
        if typeof(number) != TYPE_INT or number < 0 or number > 1000000:
            return {"ok":false,"error":"Career totals are out of range."}
    var starts: int = int(config.get_value("career","starts"))
    var finishes: int = int(config.get_value("career","finishes"))
    var victories: int = int(config.get_value("career","victories"))
    var podiums: int = int(config.get_value("career","podiums"))
    if finishes > starts or victories > finishes or podiums > finishes:
        return {"ok":false,"error":"Impossible career totals."}
    var mastery_count := 0
    for index in range(3):
        var place: Variant = config.get_value("career","best_%d" % index,0)
        var stars: Variant = config.get_value("career","stars_%d" % index,0)
        var best_time: Variant = config.get_value("career","time_%d" % index,0.0)
        if typeof(place) != TYPE_INT or place < 0 or place > 40 or (
            typeof(stars) != TYPE_INT or stars < 0 or stars > 3):
            return {"ok":false,"error":"Invalid circuit medal or position."}
        if typeof(best_time) not in [TYPE_INT,TYPE_FLOAT] or (
            not is_finite(float(best_time)) or best_time < 0 or best_time > 600):
            return {"ok":false,"error":"Invalid lap time in backup."}
        var mask: Variant = config.get_value("mastery","flags_%d" % index,0)
        if typeof(mask) != TYPE_INT or mask < 0 or mask > 7:
            return {"ok":false,"error":"Invalid mastery stamp in backup."}
        mastery_count += int(bool(mask & 1))+int(bool(mask & 2))+int(bool(mask & 4))
        for sector in range(4):
            var split: Variant = config.get_value("sectors",
                "best_%d_%d" % [index,sector],0.0)
            if typeof(split) not in [TYPE_INT,TYPE_FLOAT] or (
                not is_finite(float(split)) or split < 0 or split >= 600.0):
                return {"ok":false,"error":"Invalid sector split in backup."}
        for section in ["runs","passes","shortcuts"]:
            var stat: Variant = config.get_value("league",
                "%s_%d" % [section,index],0)
            if typeof(stat) != TYPE_INT or stat < 0 or stat > 1000000:
                return {"ok":false,"error":"Invalid league history in backup."}
    var league: Variant = config.get_value("league","score",0)
    var style: Variant = config.get_value("mastery","style",0)
    if typeof(league) != TYPE_INT or league < 0 or league > 2000000:
        return {"ok":false,"error":"Invalid league rank in backup."}
    if typeof(style) != TYPE_INT or style < 0 or style >= 5:
        return {"ok":false,"error":"Invalid cosmetic selection in backup."}
    return {"ok":true,"starts":starts,"finishes":finishes,
        "mastery":mastery_count,"league":int(league)}
