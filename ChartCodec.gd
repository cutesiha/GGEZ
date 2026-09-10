class_name ChartCodec
extends RefCounted

const SUPPORTED_NOTE_TYPES: Array[String] = ["tap", "hold", "rapid", "slur"]


static func load_chart(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _failure("Chart file was not found: %s" % path)

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure("Chart file could not be opened: %s" % path)
	var source: String = file.get_as_text()

	var json: JSON = JSON.new()
	var parse_result: int = json.parse(source)
	if parse_result != OK:
		return _failure("JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()])

	if typeof(json.data) != TYPE_DICTIONARY:
		return _failure("Chart root must be an object.")
	var chart: Dictionary = json.data
	var validation_error: String = validate_chart(chart)
	if not validation_error.is_empty():
		return _failure(validation_error)
	return {"ok": true, "chart": chart}


static func validate_chart(chart: Dictionary) -> String:
	var required_chart_fields: Array[String] = ["formatVersion", "songId", "audioPath", "bpm", "offset", "laneCount", "sections", "notes"]
	var missing_error: String = _missing_field_error(chart, required_chart_fields, "chart")
	if not missing_error.is_empty():
		return missing_error

	if not _is_integer(chart["formatVersion"]) or int(chart["formatVersion"]) != 1:
		return "chart.formatVersion must be the integer 1."
	if typeof(chart["songId"]) != TYPE_STRING or String(chart["songId"]).is_empty():
		return "chart.songId must be a non-empty string."
	if not _is_number(chart["bpm"]) or float(chart["bpm"]) <= 0.0:
		return "chart.bpm must be greater than zero."
	if not _is_number(chart["offset"]):
		return "chart.offset must be numeric."
	if not _is_integer(chart["laneCount"]) or int(chart["laneCount"]) != 4:
		return "chart.laneCount must be the integer 4."

	var audio_path: String = String(chart["audioPath"])
	if not audio_path.begins_with("res://audio/") or audio_path.get_extension().to_lower() != "wav":
		return "chart.audioPath must point to a WAV file under res://audio/."
	if not ResourceLoader.exists(audio_path):
		return "chart.audioPath does not exist: %s" % audio_path

	if typeof(chart["sections"]) != TYPE_ARRAY:
		return "chart.sections must be an array."
	for index in range(chart["sections"].size()):
		var section_value: Variant = chart["sections"][index]
		if typeof(section_value) != TYPE_DICTIONARY:
			return "sections[%d] must be an object." % index
		var section: Dictionary = section_value
		var section_error: String = _validate_section(section, index)
		if not section_error.is_empty():
			return section_error

	if chart.has("phases"):
		if typeof(chart["phases"]) != TYPE_ARRAY:
			return "chart.phases must be an array."
		for index in range(chart["phases"].size()):
			var phase_value: Variant = chart["phases"][index]
			if typeof(phase_value) != TYPE_DICTIONARY:
				return "phases[%d] must be an object." % index
			var phase: Dictionary = phase_value
			var phase_error: String = _validate_phase(phase, index)
			if not phase_error.is_empty():
				return phase_error

	if typeof(chart["notes"]) != TYPE_ARRAY:
		return "chart.notes must be an array."
	for index in range(chart["notes"].size()):
		var note_value: Variant = chart["notes"][index]
		if typeof(note_value) != TYPE_DICTIONARY:
			return "notes[%d] must be an object." % index
		var note: Dictionary = note_value
		var note_error: String = _validate_note(note, index)
		if not note_error.is_empty():
			return note_error

	return ""


static func _validate_section(section: Dictionary, index: int) -> String:
	var required_section_fields: Array[String] = ["id", "type", "startTime", "endTime"]
	var missing_error: String = _missing_field_error(section, required_section_fields, "sections[%d]" % index)
	if not missing_error.is_empty():
		return missing_error
	if typeof(section["id"]) != TYPE_STRING or String(section["id"]).is_empty():
		return "sections[%d].id must be a non-empty string." % index
	if typeof(section["type"]) != TYPE_STRING or not ["opponent", "player", "ensemble"].has(String(section["type"])):
		return "sections[%d].type must be opponent, player, or ensemble." % index
	if not _is_number(section["startTime"]) or float(section["startTime"]) < 0.0:
		return "sections[%d].startTime must be zero or greater." % index
	if not _is_number(section["endTime"]) or float(section["endTime"]) <= float(section["startTime"]):
		return "sections[%d].endTime must be greater than startTime." % index
	return ""


static func _validate_phase(phase: Dictionary, index: int) -> String:
	var required_phase_fields: Array[String] = ["id", "type", "start", "end"]
	var missing_error: String = _missing_field_error(phase, required_phase_fields, "phases[%d]" % index)
	if not missing_error.is_empty():
		return missing_error
	if typeof(phase["id"]) != TYPE_STRING or String(phase["id"]).is_empty():
		return "phases[%d].id must be a non-empty string." % index
	if typeof(phase["type"]) != TYPE_STRING or not ["break", "normal", "highlight"].has(String(phase["type"])):
		return "phases[%d].type must be break, normal, or highlight." % index
	if not _is_number(phase["start"]) or float(phase["start"]) < 0.0:
		return "phases[%d].start must be zero or greater." % index
	if not _is_number(phase["end"]) or float(phase["end"]) <= float(phase["start"]):
		return "phases[%d].end must be greater than start." % index
	return ""


static func _validate_note(note: Dictionary, index: int) -> String:
	var required_note_fields: Array[String] = ["time", "lane", "side", "type", "duration", "pitch", "mash", "connectNext"]
	var missing_error: String = _missing_field_error(note, required_note_fields, "notes[%d]" % index)
	if not missing_error.is_empty():
		return missing_error
	if not _is_number(note["time"]) or float(note["time"]) < 0.0:
		return "notes[%d].time must be zero or greater." % index
	if not _is_integer(note["lane"]) or int(note["lane"]) < 0 or int(note["lane"]) > 3:
		return "notes[%d].lane must be an integer from 0 to 3." % index
	if typeof(note["side"]) != TYPE_STRING or not ["opponent", "player"].has(String(note["side"])):
		return "notes[%d].side must be opponent or player." % index

	var note_type: String = String(note["type"])
	if not SUPPORTED_NOTE_TYPES.has(note_type):
		return "notes[%d].type is unsupported: %s" % [index, note_type]
	if not _is_number(note["duration"]) or float(note["duration"]) < 0.0:
		return "notes[%d].duration must be zero or greater." % index
	if not _is_integer(note["pitch"]) or int(note["pitch"]) < 0 or int(note["pitch"]) > 5:
		return "notes[%d].pitch must be an integer from 0 to 5." % index
	if not _is_integer(note["mash"]) or int(note["mash"]) < 0:
		return "notes[%d].mash must be a non-negative integer." % index
	if typeof(note["connectNext"]) != TYPE_BOOL:
		return "notes[%d].connectNext must be a boolean." % index

	if note_type == "hold" and float(note["duration"]) <= 0.0:
		return "notes[%d].duration must be greater than zero for hold notes." % index
	if note_type == "rapid":
		if float(note["duration"]) <= 0.0:
			return "notes[%d].duration must be greater than zero for rapid notes." % index
		if int(note["mash"]) < 1:
			return "notes[%d].mash must be at least 1 for rapid notes." % index
	return ""


static func _missing_field_error(data: Dictionary, fields: Array[String], context: String) -> String:
	for field in fields:
		if not data.has(field):
			return "%s is missing required field '%s'." % [context, field]
	return ""


static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


static func _is_integer(value: Variant) -> bool:
	return _is_number(value) and float(value) == floor(float(value))


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
