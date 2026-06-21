extends SceneTree

func _initialize() -> void:
	var autoloads: Dictionary = _autoload_paths()
	var failed: Array[String] = []
	_scan("res://", failed, autoloads)
	for f in failed:
		printerr("PARSE_FAIL ", f)
	print("PARSE_CHECK_DONE failures=", failed.size())
	quit(0)

func _autoload_paths() -> Dictionary:
	var paths: Dictionary = {}
	for prop in ProjectSettings.get_property_list():
		var key: String = str(prop.get("name", ""))
		if not key.begins_with("autoload/"):
			continue
		var ref: String = str(ProjectSettings.get_setting(key)).trim_prefix("*")
		if ref.begins_with("uid://"):
			var id: int = ResourceUID.text_to_id(ref)
			if ResourceUID.has_id(id):
				ref = ResourceUID.get_id_path(id)
		paths[ref] = true
	return paths

func _scan(path: String, failed: Array[String], autoloads: Dictionary) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var full: String = path.path_join(name)
		if dir.current_is_dir():
			if full != "res://ci" and full != "res://addons":
				_scan(full, failed, autoloads)
		elif name.ends_with(".gd") and not autoloads.has(full):
			var res: Variant = load(full)
			if res == null or not (res is GDScript):
				failed.append(full)
			elif (res as GDScript).reload() != OK:
				failed.append(full)
		name = dir.get_next()
