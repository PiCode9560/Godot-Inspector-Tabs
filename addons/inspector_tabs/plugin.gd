@tool
extends EditorPlugin

const INSPECTOR_TAB = preload("inspector_tabs.gd")
var plugin = INSPECTOR_TAB.new()

var settings = EditorInterface.get_editor_settings()
const EditorSettingsDescription = preload("editor_settings_description.gd")


func _enter_tree():
	_load_settings()
	add_inspector_plugin(plugin)
	plugin.start()


func _process(delta: float) -> void:
	plugin.process(delta)

func _exit_tree():
	settings.set(plugin.KEY_TAB_LAYOUT, null)
	settings.set(plugin.KEY_TAB_STYLE, null)
	settings.set(plugin.KEY_TAB_PROPERTY_MODE, null)
	settings.set(plugin.KEY_MERGE_ABSTRACT_CLASS_TABS, null)
	settings.set(plugin.KEY_TAB_CLIP_MODE, null)

	plugin.exit()
	remove_inspector_plugin(plugin)


func _load_settings() -> void:
	var config = ConfigFile.new()
	## Load data from a file.
	var err = config.load(EditorInterface.get_editor_paths().get_config_dir()+"/InspectorTabsPluginSettings.cfg")
	## If the file didn't load, ignore it.
	if err != OK:
		print("ERROR LOADING SETTINGS FILE")

	_load_setting(INSPECTOR_TAB.KEY_TAB_LAYOUT,
			"Place the tabs horizontally or vertically.",
			TYPE_INT,
			PROPERTY_HINT_ENUM,
			"Horizontal,Vertical",
			"tab layout",
			1,
			config,
			)

	_load_setting(INSPECTOR_TAB.KEY_TAB_STYLE,
			"Style for the tabs.",
			TYPE_INT,
			PROPERTY_HINT_ENUM,
			"Text Only,Icon Only,Text and Icon",
			"tab style",
			1,
			config,
			)

	_load_setting(INSPECTOR_TAB.KEY_TAB_PROPERTY_MODE,
			"The behavior of the tabs/how the properties is displayed. \n
[b]Tabbed[/b] will only display the category that is selected. \n
[b]Jump Scroll[/b] will display all of the categories, and clicking on the tabs will scroll to that category.",
			TYPE_INT,
			PROPERTY_HINT_ENUM,
			"Tabbed,Jump Scroll",
			"tab property mode",
			0,
			config,
			)

	_load_setting(INSPECTOR_TAB.KEY_MERGE_ABSTRACT_CLASS_TABS,
			"Put abstract class categories in its child class tab. so that it's easier to find.\n
For example, [b]PhysicsBody3D[/b] category will be in the [b]RigidBody3D[/b] tab.",
			TYPE_BOOL,
			PROPERTY_HINT_ENUM,
			"",
			"merge abstract class tabs",
			true,
			config,
			)

	_load_setting(INSPECTOR_TAB.KEY_TAB_CLIP_MODE,
			"How the tabs in the tab bar are clipped when they are overflowed.\n
[b]Scroll:[/b] A scroll bar will be shown when the tabs overflowed. \n
[b]Clip Text:[/b] If [b]Tab Style[/b] is set to [b]Text Only[/b] or [b]Text and Icon[/b], the text in the tab will be clipped when overflowed. \n
[b]Flow:[/b] The tabs will be moved to a new row when overflowed.",
			TYPE_INT,
			PROPERTY_HINT_ENUM,
			"Scroll,Clip Text,Flow",
			"tab clip mode",
			0,
			config,
			)



func _load_setting(setting_path:String, description:String, type:int, hint, hint_string:String, config_path:String, default_value, config:ConfigFile) -> void:
	settings.set(setting_path, config.get_value("Settings", config_path,default_value))

	var property_info = {
		"name": setting_path,
		"type": type,
		"hint": hint,
		"hint_string": hint_string,
	}
	settings.add_property_info(property_info)

	EditorSettingsDescription.set_editor_setting_desc(setting_path,description)
