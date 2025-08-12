@tool
extends EditorPlugin

const INSPECTOR_TAB = preload("inspector_tabs.gd")
var plugin = INSPECTOR_TAB.new()

var settings = EditorInterface.get_editor_settings()

func _enter_tree():
	load_settings()
	add_inspector_plugin(plugin)
	plugin.start()

func load_settings():
	var config = ConfigFile.new()
	## Load data from a file.
	var err = config.load(EditorInterface.get_editor_paths().get_config_dir()+"/InspectorTabsPluginSettings.cfg")
	## If the file didn't load, ignore it.
	if err != OK:
		print("ERROR LOADING SETTINGS FILE")

	settings.set("inspector_tabs/tab_layout", config.get_value("Settings", "tab layout",1))

	var property_info = {
		"name": "inspector_tabs/tab_layout",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Horizontal,Vertical",
	}
	settings.add_property_info(property_info)

	settings.set("inspector_tabs/tab_style", config.get_value("Settings", "tab style",1))

	property_info = {
		"name": "inspector_tabs/tab_style",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Text Only,Icon Only,Text and Icon",
	}
	settings.add_property_info(property_info)

	settings.set("inspector_tabs/tab_property_mode", config.get_value("Settings", "tab property mode",0))

	property_info = {
		"name": "inspector_tabs/tab_property_mode",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Tabbed,Jump Scroll",
	}
	settings.add_property_info(property_info)

	settings.set("inspector_tabs/merge_abstract_class_tabs", config.get_value("Settings", "merge abstract class tabs",true))

	property_info = {
		"name": "inspector_tabs/merge_abstract_class_tabs",
		"type": TYPE_BOOL,
	}
	settings.add_property_info(property_info)

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
