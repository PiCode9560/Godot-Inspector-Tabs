extends EditorInspectorPlugin

const KEY_TAB_LAYOUT: StringName = &"inspector_tabs/tab_layout"
const KEY_TAB_STYLE: StringName  = &"inspector_tabs/tab_style"
const KEY_TAB_PROPERTY_MODE: StringName  = &"inspector_tabs/tab_property_mode"
const KEY_MERGE_ABSTRACT_CLASS_TABS: StringName  = &"inspector_tabs/merge_abstract_class_tabs"

enum TabStyles{
	TEXT_ONLY,
	ICON_ONLY,
	TEXT_AND_ICON,
}

enum TabPropertyModes{
	TABBED,
	JUMP_SCROLL,
}

var current_category:String = ""

var categories = [] # All categories/subclasses in the inspector
var tabs = [] # All tabs in the inspector

var categories_finish = false # Finish adding categories

var inspector_tab_bar:InspectorTabBar # Inspector Tabs
var base_control = EditorInterface.get_base_control()
var settings = EditorInterface.get_editor_settings()

## Container to place the inspector and the tab bar.
var inspector_container :BoxContainer

var tab_can_change = false # Stops the TabBar from changing tab

var vertical_mode:bool = true # Tab position
var vertical_tab_side = 1 # 0:left; 1:Right;
var tab_style:TabStyles
var property_mode:TabPropertyModes
var merge_abstract_class_tabs:bool

## path to the editor inspector list of properties
var property_container = EditorInterface.get_inspector().get_child(0).get_child(2)
## path to the inspector scroll bar
var property_scroll_bar:VScrollBar = EditorInterface.get_inspector().get_node("_v_scroll")
## Use to check if the loaded icon is an unknown icon
var UNKNOWN_ICON:Texture2D = EditorInterface.get_base_control().get_theme_icon("", "EditorIcons")
## The icon to use if the object icon is not found.
var fallback_icon : Texture2D = EditorInterface.get_base_control().get_theme_icon("Resource", "EditorIcons")

var is_filtering = false ## is the search bar in use

var current_parse_category:String = ""

var icon_cache : Dictionary

var inspector_dock = EditorInterface.get_base_control().find_child("Inspector",true,false)


func _can_handle(object):
	# We support all objects in this example.
	return true


# getting the category from the inspector
func _parse_category(object: Object, category: String) -> void:
	if category == "Atlas": return # Not sure what class this is. But it seems to break things.

	# reset the list if its the first category
	if categories_finish:
		parse_begin(object)

	if current_parse_category != "Node": # This line is needed because when selecting multiple nodes the refcounted class will be the last tab.
		current_parse_category = category


# Finished getting inspector categories
func _parse_end(object: Object) -> void:
	if current_parse_category != "Node" and current_parse_category != "RefCounted": return # False finish

	if current_parse_category == "RefCounted":
		fallback_icon = EditorInterface.get_base_control().get_theme_icon("ObjectDisabled", "EditorIcons")
	else:
		fallback_icon = EditorInterface.get_base_control().get_theme_icon("NodeDisabled", "EditorIcons")

	current_parse_category = ""

	for i in property_container.get_children():
		if i.get_class() == "EditorInspectorCategory":

			# Get Node Name
			var category = i.get("tooltip_text").split("|")
			if category.size() > 1:
				category = category[1]
			else:
				category = category[0]

			if category.split('"').size() > 1:
				category = category.split('"')[1]

			# Add it to the list of categories and tabs
			categories.append(category)
			if is_new_tab(category):
				tabs.append(category)

		elif categories.size() == 0:# If theres properties at the top of the inspector without its own category.
			# Add it to the list of categories and tabs
			var category = "Unknown"
			tabs.append(category)
			categories.append(category)
	categories_finish = true
	update_tabs() # load tab
	tab_can_change = true

	var tab = tabs.find(current_category)
	if tab == -1:
		_switch_tab(0)
		tab_selected(0)
		inspector_tab_bar.tab_bar.current_tab = 0
	else:
		_switch_tab(tab)
		inspector_tab_bar.tab_bar.current_tab = tab


# Start inspector loading
func parse_begin(object: Object) -> void:
	categories_finish = false
	categories.clear()
	tabs.clear()
	tab_can_change = false
	inspector_tab_bar.tab_bar.clear_tabs()


func process(delta) -> void:

	if EditorInterface.get_inspector().global_position.x < base_control.get_viewport().size.x/2 -EditorInterface.get_inspector().size.x/2:
		if vertical_tab_side != 1:
			vertical_tab_side = 1
			_update_tabbar()
	else:
		if vertical_tab_side != 0:
			vertical_tab_side = 0
			_update_tabbar()

	if inspector_tab_bar.tab_bar.tab_count != 0:
		if EditorInterface.get_inspector().get_edited_object() == null:
			inspector_tab_bar.tab_bar.clear_tabs()


## Start plugin
func start() -> void:
	property_scroll_bar.scrolling.connect(property_scrolling)

	var filter_bar = inspector_dock.find_children("","LineEdit",true,false).filter(func(line_edit:LineEdit): return line_edit.right_icon == EditorInterface.get_editor_theme().get_icon("Search","EditorIcons"))[0]
	filter_bar.text_changed.connect(_filter_text_changed)

	var inspector := EditorInterface.get_inspector()
	inspector_container = BoxContainer.new()
	inspector.get_parent().add_child(inspector_container)

	inspector_tab_bar = InspectorTabBar.new(vertical_mode)
	inspector_container.add_child(inspector_tab_bar)
	inspector_tab_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	inspector_tab_bar.tab_bar.tab_selected.connect(tab_selected)
	inspector_tab_bar.tab_bar.tab_changed.connect(_on_tab_changed)

	inspector.reparent(inspector_container)
	_update_tabbar()

	inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var settings = EditorInterface.get_editor_settings()
	tab_style = settings.get(KEY_TAB_STYLE)
	property_mode = settings.get(KEY_TAB_PROPERTY_MODE)
	merge_abstract_class_tabs = settings.get(KEY_MERGE_ABSTRACT_CLASS_TABS)
	settings.settings_changed.connect(settings_changed)

	var tab_pos = settings.get(KEY_TAB_LAYOUT)
	if tab_pos != null:
		if tab_pos == 0:
			change_vertical_mode(false)
		else:
			change_vertical_mode(true)


func exit() -> void:
	EditorInterface.get_inspector().reparent(inspector_container.get_parent())
	inspector_container.queue_free()
	inspector_tab_bar.queue_free()


# Is it not a custom class
func is_base_class(c_name:String) -> bool:
	if c_name.contains("."):return false
	for list in ProjectSettings.get_global_class_list():
		if list.class == c_name:
			return false
	return true


func get_script_icon(script_path:String) -> Texture2D:
	if !script_path.begins_with("res://"):
		script_path = "res://" + script_path

	var file := FileAccess.open(script_path, FileAccess.READ)
	if not file:
		return base_control.get_theme_icon("GDScript", "EditorIcons")
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.begins_with("@icon("):
			var start = line.find("\"") + 1
			var end = line.rfind("\"")
			if start > 0 and end > start:
				var img_path = line.substr(start, end - start)

				if !img_path.begins_with("res://"): ## If path is absolute
					img_path = script_path.substr(0, script_path.rfind("/")) + "/" + img_path

				var texture: Texture2D = load(img_path)
				var image = texture.get_image()
				image.resize(UNKNOWN_ICON.get_width(),UNKNOWN_ICON.get_height())
				return ImageTexture.create_from_image(image)

	return base_control.get_theme_icon("GDScript", "EditorIcons")


# add tabs
func update_tabs() -> void:
	inspector_tab_bar.tab_bar.clear_tabs()
	for tab:String in tabs:
		## Get an icon for the tab.
		var load_icon = get_tab_icon(tab)
		var tab_name = tab.split("/")[-1]

		if vertical_mode:
			# Rotate the image for the vertical tab
			if vertical_tab_side == 0:
				var rotated_image = load_icon.get_image().duplicate()
				rotated_image.rotate_90(CLOCKWISE)
				load_icon = ImageTexture.create_from_image(rotated_image)
			else:
				var rotated_image = load_icon.get_image().duplicate()
				rotated_image.rotate_90(COUNTERCLOCKWISE)
				load_icon = ImageTexture.create_from_image(rotated_image)

		match tab_style:
			TabStyles.TEXT_ONLY:
				inspector_tab_bar.tab_bar.add_tab(tab_name,null)
			TabStyles.ICON_ONLY:
				inspector_tab_bar.tab_bar.add_tab("",load_icon)
			TabStyles.TEXT_AND_ICON:
				inspector_tab_bar.tab_bar.add_tab(tab_name,load_icon)

		inspector_tab_bar.tab_bar.set_tab_tooltip(inspector_tab_bar.tab_bar.tab_count-1,tab_name)


func _on_tab_changed(tab: int) -> void:
	_update_inspector()


func _switch_tab(tab: int) -> void:
	inspector_tab_bar.tab_bar.current_tab = tab


func _update_inspector() -> void:
	if is_filtering: return

	var tab := inspector_tab_bar.tab_bar.current_tab
	if property_mode == TabPropertyModes.TABBED: # Tabbed
		var category_idx = -1
		var tab_idx = -1

		# Show nececary properties
		for child in property_container.get_children():
			if child.get_class() == "EditorInspectorCategory":
				category_idx += 1
				if is_new_tab(categories[category_idx]):
					tab_idx += 1

			elif tab_idx == -1: # If theres properties at the top of the inspector without its own category.
				category_idx += 1
				if is_new_tab(categories[category_idx]):
					tab_idx += 1
			if tab_idx != tab:
				child.visible = false
			else:
				child.visible = true

	elif property_mode == TabPropertyModes.JUMP_SCROLL: # Jump Scroll
		var category_idx = -1
		var tab_idx = -1

		# Show nececary properties
		for i in property_container.get_children():
			if i.get_class() == "EditorInspectorCategory":
				category_idx += 1
				if is_new_tab(categories[category_idx]):
					tab_idx += 1
				if tab_idx == tab:
					var list_size_y =  EditorInterface.get_inspector().get_children().filter(func(node:Node):return node is VBoxContainer)[0].size.y
					property_scroll_bar.value = (i.position.y+property_container.position.y)/list_size_y*property_scroll_bar.max_value
					break
			elif tab_idx == -1 and tab == 0: # If theres properties at the top of the inspector without its own category.
				property_scroll_bar.value = 0
				break

func is_new_tab(category:String) -> bool:
	if merge_abstract_class_tabs:
		if ClassDB.class_exists(category) and not ClassDB.can_instantiate(category):
			if categories[0] == category:
				return true
			return false
	return true


# Is searching
func _filter_text_changed(text:String):
	if text != "":
		for i in property_container.get_children():
			i.visible = true
		is_filtering = true
	else:
		is_filtering = false
		_switch_tab(inspector_tab_bar.tab_bar.current_tab)


func tab_selected(tab):
	if tab_can_change:
		current_category = tabs[tab]

# Change position mode
func change_vertical_mode(mode:bool):
	vertical_mode = mode
	_update_tabbar()

func _update_tabbar() -> void:
	if inspector_tab_bar.get_index() != vertical_tab_side:
		inspector_container.move_child(inspector_tab_bar,vertical_tab_side)

	if not vertical_mode:
		inspector_container.move_child(inspector_tab_bar,0)

	inspector_container.vertical = !vertical_mode

	inspector_tab_bar.change_vertical_mode(vertical_mode)
	inspector_tab_bar.change_vertical_side(vertical_tab_side)

	update_tabs()


func settings_changed() -> void:
	var tab_pos = settings.get(KEY_TAB_LAYOUT)
	if tab_pos != null:
		if tab_pos == 0:
			if vertical_mode != false:
				change_vertical_mode(false)
		else:
			if vertical_mode != true:
				change_vertical_mode(true)
	var style = settings.get(KEY_TAB_STYLE)
	if style != null:
		if tab_style != style:
			tab_style = style
	var prop_mode = settings.get(KEY_TAB_PROPERTY_MODE)
	if prop_mode != null:
		if property_mode != prop_mode:
			property_mode = prop_mode
	var merge_class = settings.get(KEY_MERGE_ABSTRACT_CLASS_TABS)
	if merge_class != null:
		if merge_abstract_class_tabs != merge_class:
			merge_abstract_class_tabs = merge_class

	if tab_pos != null and style != null and prop_mode != null and merge_class != null:

		#Save settings
		var config = ConfigFile.new()
		# Store some values.
		config.set_value("Settings", "tab layout", tab_pos)
		config.set_value("Settings", "tab style", style)
		config.set_value("Settings", "tab property mode", prop_mode)
		config.set_value("Settings", "merge abstract class tabs", merge_abstract_class_tabs)

		# Save it to a file (overwrite if already exists).
		var err = config.save(EditorInterface.get_editor_paths().get_config_dir()+"/InspectorTabsPluginSettings.cfg")
		if err != OK:
			print("Error saving inspector tab settings: ",error_string(err))

	_update_tabbar()

func property_scrolling():
	if property_mode != TabPropertyModes.JUMP_SCROLL or inspector_tab_bar.tab_bar.tab_count == 0 or is_filtering:return
	var category_idx = -1
	var tab_idx = -1
	var category_y = - INF
	if property_scroll_bar.value <= 1:
		inspector_tab_bar.tab_bar.current_tab = 0
		return
	for i in property_container.get_children():
		if i.get_class() == "EditorInspectorCategory":
			var list_size_y =  EditorInterface.get_inspector().get_children().filter(func(node:Node):return node is VBoxContainer)[0].size.y
			if (i.position.y+property_container.position.y-EditorInterface.get_inspector().size.y/3) <= property_scroll_bar.value/property_scroll_bar.max_value*list_size_y:
				category_y = property_container.position.y
			else:
				inspector_tab_bar.tab_bar.current_tab = max(tab_idx,0)
				break
			category_idx += 1
			if is_new_tab(categories[category_idx]):
				tab_idx += 1
		elif tab_idx == -1: # If theres properties at the top of the inspector without its own category.
			category_idx += 1
			tab_idx += 1

func get_tab_icon(tab) -> Texture2D:
	var load_icon : Texture2D

	if tab.ends_with(".gd"):
		## Get script custom icon or the GDScript icon
		load_icon = get_script_icon(tab)

	elif tab == "Resource" or tab == "RefCounted":
		load_icon = EditorInterface.get_base_control().get_theme_icon("Object", "EditorIcons")

	elif ClassDB.class_exists(tab):
		if ClassDB.class_get_api_type(tab) == ClassDB.APIType.API_EXTENSION:
			## Get GDExtension node icon
			load_icon = get_extension_class_icon(tab)
		else:
			## Get editor node icon
			load_icon = base_control.get_theme_icon(tab, "EditorIcons")

	else:
		## Get script custom class icon
		load_icon = get_script_class_icon(tab)

	if load_icon == UNKNOWN_ICON:
		load_icon = fallback_icon

	return load_icon

## Find an ancestor class that have an icon.
func find_custom_class_name(_script:Script) -> String:
	if _script.get_base_script():
		## Get the parent script class.
		var _name := _script.get_base_script().get_global_name()
		for class_info in ProjectSettings.get_global_class_list():
			if class_info["class"] == _name:
				if ResourceLoader.exists(class_info["icon"]) == false:
					return find_custom_class_name(load(class_info["path"]))
	else:
		## Get script base class. (Get the built-in godot class)
		var _name = _script.get_global_name()
		for class_info in ProjectSettings.get_global_class_list():
			if class_info["class"] == _name:
				return class_info["base"]

	return ""


func get_script_class_icon(tab) -> Texture2D:
	if icon_cache.has(tab):
		return icon_cache.get(tab)

	for class_info in ProjectSettings.get_global_class_list():
		if class_info["class"] == tab:
			if ResourceLoader.exists(class_info["icon"]) == false:
				var cls_name = find_custom_class_name(load(class_info["path"]))
				return get_tab_icon(cls_name)


			var texture: Texture2D = ResourceLoader.load(class_info["icon"])
			var image = texture.get_image()
			image.resize(UNKNOWN_ICON.get_width(),UNKNOWN_ICON.get_height())

			var icon = ImageTexture.create_from_image(image)
			icon_cache = {tab:icon}
			return icon

	## Icon for @export_category()
	if vertical_mode:
		return base_control.get_theme_icon("ArrowUp", "EditorIcons")
	return base_control.get_theme_icon("ArrowLeft", "EditorIcons")


func get_extension_class_icon(tab) -> Texture2D:
	if icon_cache.has(tab):
		return icon_cache.get(tab)

	for i in GDExtensionManager.get_loaded_extensions():
		var cfg = load_gdextension_config(i)
		var icons = cfg.get("icons")
		if icons:
			var path = icons.get(tab, "")
			if ResourceLoader.exists(path):
				var texture: Texture2D = ResourceLoader.load(path)
				var image = texture.get_image()
				image.resize(UNKNOWN_ICON.get_width(),UNKNOWN_ICON.get_height())

				var icon = ImageTexture.create_from_image(image)
				icon_cache = {tab : icon}
				return icon

	return base_control.get_theme_icon("NodeDisabled", "EditorIcons")


func load_gdextension_config(path: String) -> Dictionary:
	var config = ConfigFile.new()
	var err = config.load(path)
	if err != OK:
		print("Failed to load .gdextension file:", path)
		return {}

	var data = {}
	for section in config.get_sections():
		data[section] = {}
		for key in config.get_section_keys(section):
			data[section][key] = config.get_value(section, key)

	return data


class InspectorTabBar extends Control:
	var tab_bar:TabBar
	var _panel: Panel

	var vertical_mode := false
	var vertical_side := 1 ## 0:left; 1:Right;

	func _init(vertical: bool) -> void:
		vertical_mode = vertical
		self.name = "InspectorTabBar"

		_panel = Panel.new()
		add_child(_panel)
		_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		_panel.clip_contents = true
		_panel.owner = self

		tab_bar = TabBar.new()
		_panel.add_child(tab_bar)
		tab_bar.owner = self

		tab_bar.minimum_size_changed.connect(_on_tabbar_minimum_size_changed)
		resized.connect(_on_resized)
		_update_tabbar()

	func _update_tabbar() -> void:
		if vertical_mode:
			if vertical_side == 0:
				tab_bar.rotation = -PI/2
				tab_bar.size = Vector2(size.y, size.x)
				tab_bar.layout_direction = Control.LAYOUT_DIRECTION_RTL
				tab_bar.position = Vector2(0, size.y)
			elif vertical_side == 1:

				tab_bar.rotation = PI/2
				tab_bar.size = Vector2(size.y, size.x)
				tab_bar.layout_direction = Control.LAYOUT_DIRECTION_LTR
				tab_bar.position = Vector2(size.x, 0)

		else:
			tab_bar.layout_direction = Control.LAYOUT_DIRECTION_INHERITED
			tab_bar.position = Vector2.ZERO
			tab_bar.rotation = 0
			tab_bar.size = Vector2(size.x, size.y)
		_update_minimum_size()

	func _on_tabbar_minimum_size_changed() -> void:
		_update_tabbar()

	func _on_resized() -> void:
		_update_tabbar()

	func _update_minimum_size() -> void:
		if vertical_mode:
			custom_minimum_size = Vector2(tab_bar.get_minimum_size().y,tab_bar.get_minimum_size().x)
		else:
			custom_minimum_size = Vector2(tab_bar.get_minimum_size().x,tab_bar.get_minimum_size().y)

	func change_vertical_mode(vertical: bool) -> void:
		vertical_mode = vertical
		_update_tabbar()

	func change_vertical_side(side: int) -> void:
		vertical_side = side
		_update_tabbar()
