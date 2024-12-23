class_name LevelBrowser
extends FileDialog

const ADMIN_LEVELS_FOLDER := "admin_levels"

func _ready() -> void:
	var admin_levels_dir: String
	if OS.has_feature("editor"):
		admin_levels_dir = "res://%s" % ADMIN_LEVELS_FOLDER
		access = FileDialog.ACCESS_RESOURCES
		print("Editor, using resource access")
	else:
		admin_levels_dir = "user://%s" % ADMIN_LEVELS_FOLDER
		access = FileDialog.ACCESS_USERDATA
		print("Non-editor, using user access data")
	
	var err := DirAccess.make_dir_recursive_absolute(admin_levels_dir)
	if err:
		printerr("Error making admin levels directory %s: error code %d" % [admin_levels_dir, err])
	
	if OS.has_feature("editor"):
		title = ProjectSettings.globalize_path(admin_levels_dir)
		print("Editor, using path %s" % title)
	else:
		title = OS.get_user_data_dir().path_join(admin_levels_dir.lstrip("user://"))
		print("Non-editor, using path %s" % title)

	
	root_subfolder = admin_levels_dir
