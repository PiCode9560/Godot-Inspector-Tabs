@tool
extends EditorPlugin

const INSPECTOR_TAB = preload("inspector_tabs.gd")
var plugin = INSPECTOR_TAB.new()

var settings = EditorInterface.get_editor_settings()

func _enter_tree():
	_load_settings()
	add_inspector_plugin(plugin)
	plugin.start()

## TODO:Move this to the inspector.gd.
func _process(delta: float) -> void:
	# Reposition UI
	if plugin.vertical_mode:
		plugin.tab_bar.size.x = EditorInterface.get_inspector().size.y
		if plugin.vertical_tab_side == 0:#Left side
			plugin.tab_bar.global_position = EditorInterface.get_inspector().global_position+Vector2(0,plugin.tab_bar.size.x)
			plugin.tab_bar.rotation = -PI/2
			plugin.property_container.custom_minimum_size.x = plugin.property_container.get_parent_area_size().x - plugin.tab_bar.size.y - 5
			plugin.favorite_container.custom_minimum_size.x = plugin.favorite_container.get_parent_area_size().x - plugin.tab_bar.size.y - 5
			plugin.viewer_container.custom_minimum_size.x = plugin.favorite_container.get_parent_area_size().x - plugin.tab_bar.size.y - 5
			plugin.property_container.position.x = plugin.tab_bar.size.y + 5
			plugin.favorite_container.position.x = plugin.tab_bar.size.y + 5
			plugin.viewer_container.position.x = plugin.tab_bar.size.y + 5
		else:#Right side
			plugin.tab_bar.global_position = EditorInterface.get_inspector().global_position+Vector2(plugin.favorite_container.get_parent_area_size().x+plugin.tab_bar.size.y/2,0)
			if plugin.property_scroll_bar.visible:
				plugin.property_scroll_bar.position.x = plugin.property_container.get_parent_area_size().x - plugin.tab_bar.size.y+plugin.property_scroll_bar.size.x/2
				plugin.tab_bar.global_position.x += plugin.property_scroll_bar.size.x
			plugin.tab_bar.rotation = PI/2
			plugin.property_container.custom_minimum_size.x = plugin.property_container.get_parent_area_size().x - plugin.tab_bar.size.y - 5
			plugin.favorite_container.custom_minimum_size.x = plugin.favorite_container.get_parent_area_size().x - plugin.tab_bar.size.y - 5
			plugin.viewer_container.custom_minimum_size.x = plugin.favorite_container.get_parent_area_size().x - plugin.tab_bar.size.y - 5
			plugin.property_container.position.x = 0
			plugin.favorite_container.position.x = 0
			plugin.viewer_container.position.x = 0

	if EditorInterface.get_inspector().global_position.x < get_viewport().size.x/2 -EditorInterface.get_inspector().size.x/2:
		if plugin.vertical_tab_side != 1:
			plugin.vertical_tab_side = 1
			plugin.change_vertical_mode()
	else:
		if plugin.vertical_tab_side != 0:
			plugin.vertical_tab_side = 0
			plugin.change_vertical_mode()

	if plugin.tab_bar.tab_count != 0:
		if EditorInterface.get_inspector().get_edited_object() == null:
			plugin.tab_bar.clear_tabs()


func _exit_tree():
	settings.set("inspector_tabs/tab_layout", null)
	settings.set("inspector_tabs/tab_style", null)
	settings.set("inspector_tabs/tab_property_mode", null)
	settings.set("inspector_tabs/merge_abstract_class_tabs", null)

	## TODO: move these to the inspector.gd??
	plugin.property_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plugin.favorite_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plugin.viewer_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plugin.property_container.custom_minimum_size.x = 0
	plugin.favorite_container.custom_minimum_size.x = 0
	plugin.viewer_container.custom_minimum_size.x = 0

	remove_inspector_plugin(plugin)
	plugin.tab_bar.queue_free()

func _load_settings() -> void:
	var config = ConfigFile.new()
	## Load data from a file.
	var err = config.load(EditorInterface.get_editor_paths().get_config_dir()+"/InspectorTabsPluginSettings.cfg")
	## If the file didn't load, ignore it.
	if err != OK:
		print("ERROR LOADING SETTINGS FILE")

	_load_setting(INSPECTOR_TAB.KEY_TAB_LAYOUT,
			TYPE_INT,
			PROPERTY_HINT_ENUM,
			"Horizontal,Vertical",
			"tab layout",
			1,
			config,
			)

	_load_setting(INSPECTOR_TAB.KEY_TAB_STYLE,
			TYPE_INT,
			PROPERTY_HINT_ENUM,
			"Text Only,Icon Only,Text and Icon",
			"tab style",
			1,
			config,
			)

	_load_setting(INSPECTOR_TAB.KEY_TAB_PROPERTY_MODE,
			TYPE_INT,
			PROPERTY_HINT_ENUM,
			"Tabbed,Jump Scroll",
			"tab property mode",
			0,
			config,
			)

	_load_setting(INSPECTOR_TAB.KEY_MERGE_ABSTRACT_CLASS_TABS,
			TYPE_BOOL,
			PROPERTY_HINT_ENUM,
			"",
			"merge abstract class tabs",
			true,
			config,
			)




func _load_setting(setting_path:String, type:int, hint, hint_string:String, config_path:String, default_value, config:ConfigFile) -> void:
	settings.set(setting_path, config.get_value("Settings", config_path,default_value))

	var property_info = {
		"name": setting_path,
		"type": type,
		"hint": hint,
		"hint_string": hint_string,
	}
	settings.add_property_info(property_info)
