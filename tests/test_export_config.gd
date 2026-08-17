extends GutTest
## Pins the Android export scaffolding (spec 7.1 export row, spec 8 MVP line).
## The preset is config only: building the AAB needs the Android SDK, which
## lives outside this repo's test loop.


func _load_presets() -> ConfigFile:
	var cfg := ConfigFile.new()
	assert_eq(cfg.load("res://export_presets.cfg"), OK, "export_presets.cfg must exist and parse")
	return cfg


func test_android_preset_is_a_gradle_aab_for_arm64() -> void:
	var cfg := _load_presets()
	assert_eq(String(cfg.get_value("preset.0", "platform", "")), "Android")
	assert_true(bool(cfg.get_value("preset.0.options", "gradle_build/use_gradle_build", false)))
	assert_eq(int(cfg.get_value("preset.0.options", "gradle_build/export_format", -1)), 1, "1 = AAB")
	assert_true(bool(cfg.get_value("preset.0.options", "architectures/arm64-v8a", false)))
	assert_false(bool(cfg.get_value("preset.0.options", "architectures/armeabi-v7a", true)))

func test_export_excludes_dev_only_directories() -> void:
	var cfg := _load_presets()
	var exclude := String(cfg.get_value("preset.0", "exclude_filter", ""))
	assert_string_contains(exclude, "addons/gut/*")
	assert_string_contains(exclude, "tests/*")

func test_post_notifications_permission_is_declared() -> void:
	var cfg := _load_presets()
	assert_true(bool(cfg.get_value("preset.0.options", "permissions/post_notifications", false)),
		"spec 5: Android 13+ runtime permission needs the manifest entry")

func test_project_icon_is_configured_and_present() -> void:
	assert_eq(String(ProjectSettings.get_setting("application/config/icon", "")), "res://icon.svg")
	assert_true(FileAccess.file_exists("res://icon.svg"))

func test_project_is_locked_to_portrait() -> void:
	assert_eq(int(ProjectSettings.get_setting("display/window/handheld/orientation", 0)), 1,
		"spec: portrait only")
