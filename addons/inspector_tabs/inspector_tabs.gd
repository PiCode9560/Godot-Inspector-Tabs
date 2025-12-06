extends EditorInspectorPlugin

const KEY_TAB_LAYOUT = "inspector_tabs/tab_layout"
const KEY_TAB_STYLE = "inspector_tabs/tab_style"
const KEY_TAB_PROPERTY_MODE = "inspector_tabs/tab_property_mode"
const KEY_MERGE_ABSTRACT_CLASS_TABS = "inspector_tabs/merge_abstract_class_tabs"
const KEY_TAB_CLIP_MODE = "inspector_tabs/tab_clip_mode"

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

var tab_bar:InspectorTabBar # Inspector Tabs
var base_control = EditorInterface.get_base_control()
var settings = EditorInterface.get_editor_settings()


var tab_can_change = false # Stops the TabBar from changing tab

var vertical_mode:bool = true # Tab position
var vertical_tab_side = 1 # 0:left; 1:Right;
var tab_style:TabStyles
var property_mode:TabPropertyModes
var merge_abstract_class_tabs:bool
var tab_clip_mode:InspectorTabBar.ClipMode

## path to the editor inspector list of properties
var property_container = EditorInterface.get_inspector().get_child(0).get_child(2)
## path to the editor inspector favorite list.
var favorite_container = EditorInterface.get_inspector().get_child(0).get_child(1)
## path to the editor inspector "viewer" area. (camera viewer or skeleton3D bone tree)
var viewer_container = EditorInterface.get_inspector().get_child(0).get_child(0)
## path to the inspector scroll bar
var property_scroll_bar:VScrollBar = EditorInterface.get_inspector().get_node("_v_scroll")
## Use to check if the loaded icon is an unknown icon
var UNKNOWN_ICON:Texture2D = EditorInterface.get_base_control().get_theme_icon("", "EditorIcons")

var is_filtering = false ## is the search bar in use

var current_parse_category:String = ""

var icon_cache : Dictionary

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
	if current_parse_category != "Node": return # False finish
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
		tab_clicked(0)
		tab_selected(0)
		tab_bar.current_tab = 0
	else:
		tab_clicked(tab)
		tab_bar.current_tab = tab

	tab_resized()

# Start inspector loading
func parse_begin(object: Object) -> void:
	categories_finish = false
	categories.clear()
	tabs.clear()
	tab_can_change = false
	tab_bar.clear_tabs()

func process(delta) -> void:
	# Reposition UI
	if vertical_mode:
		tab_bar.size.y = 0
		tab_bar.size.x = EditorInterface.get_inspector().size.y
		if vertical_tab_side == 0:#Left side
			tab_bar.global_position = EditorInterface.get_inspector().global_position+Vector2(0,tab_bar.size.x)
			tab_bar.rotation = -PI/2
			property_container.custom_minimum_size.x = property_container.get_parent_area_size().x - tab_bar.size.y - 5
			favorite_container.custom_minimum_size.x = favorite_container.get_parent_area_size().x - tab_bar.size.y - 5
			viewer_container.custom_minimum_size.x = favorite_container.get_parent_area_size().x - tab_bar.size.y - 5
			property_container.position.x = tab_bar.size.y + 5
			favorite_container.position.x = tab_bar.size.y + 5
			viewer_container.position.x = tab_bar.size.y + 5
		else:#Right side
			tab_bar.global_position = EditorInterface.get_inspector().global_position+Vector2(favorite_container.get_parent_area_size().x+tab_bar.size.y/2,0)
			if property_scroll_bar.visible:
				property_scroll_bar.position.x = property_container.get_parent_area_size().x - tab_bar.size.y+property_scroll_bar.size.x/2
				tab_bar.global_position.x += property_scroll_bar.size.x
			tab_bar.rotation = PI/2
			property_container.custom_minimum_size.x = property_container.get_parent_area_size().x - tab_bar.size.y - 5
			favorite_container.custom_minimum_size.x = favorite_container.get_parent_area_size().x - tab_bar.size.y - 5
			viewer_container.custom_minimum_size.x = favorite_container.get_parent_area_size().x - tab_bar.size.y - 5
			property_container.position.x = 0
			favorite_container.position.x = 0
			viewer_container.position.x = 0

	if EditorInterface.get_inspector().global_position.x < base_control.get_viewport().size.x/2 -EditorInterface.get_inspector().size.x/2:
		if vertical_tab_side != 1:
			vertical_tab_side = 1
			change_vertical_mode()
	else:
		if vertical_tab_side != 0:
			vertical_tab_side = 0
			change_vertical_mode()

	if tab_bar.tab_count != 0:
		if EditorInterface.get_inspector().get_edited_object() == null:
			tab_bar.clear_tabs()


## Start plugin
func start() -> void:
	property_scroll_bar.scrolling.connect(property_scrolling)
	var filter_bar = EditorInterface.get_inspector().get_parent().get_child(2).get_child(0)
	filter_bar.text_changed.connect(_filter_text_changed)

	var settings = EditorInterface.get_editor_settings()
	tab_style = settings.get("inspector_tabs/tab_style")
	property_mode = settings.get("inspector_tabs/tab_property_mode")
	merge_abstract_class_tabs = settings.get("inspector_tabs/merge_abstract_class_tabs")
	tab_clip_mode = settings.get(KEY_TAB_CLIP_MODE)
	settings.settings_changed.connect(settings_changed)

	var tab_pos = settings.get("inspector_tabs/tab_layout")
	if tab_pos != null:
		if tab_pos == 0:
			change_vertical_mode(false)
		else:
			change_vertical_mode(true)

func exit() -> void:
	property_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	favorite_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewer_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	property_container.custom_minimum_size.x = 0
	favorite_container.custom_minimum_size.x = 0
	viewer_container.custom_minimum_size.x = 0

	tab_bar.queue_free()

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
	tab_bar.clear_tabs()
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
				tab_bar.add_tab(tab_name,null)
			TabStyles.ICON_ONLY:
				tab_bar.add_tab("",load_icon)
			TabStyles.TEXT_AND_ICON:
				tab_bar.add_tab(tab_name,load_icon)

		tab_bar.set_tab_tooltip(tab_bar.tab_count-1,tab_name)

func tab_clicked(tab: int) -> void:
	if is_filtering: return
	if property_mode == TabPropertyModes.TABBED: # Tabbed
		var category_idx = -1
		var tab_idx = -1

		# Show nececary properties
		for i in property_container.get_children():
			if i.get_class() == "EditorInspectorCategory":
				category_idx += 1
				if is_new_tab(categories[category_idx]):
					tab_idx += 1

			elif tab_idx == -1: # If theres properties at the top of the inspector without its own category.
				category_idx += 1
				if is_new_tab(categories[category_idx]):
					tab_idx += 1
			if tab_idx != tab:
				i.visible = false
			else:
				i.visible = true
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
		tab_clicked(tab_bar.current_tab)


func tab_selected(tab):
	if tab_can_change:
		current_category = tabs[tab]

func tab_resized():
	if not vertical_mode:
		if tabs.size() != 0:
			pass
			#print_debug("FIX max_tab_width")
			#tab_bar.max_tab_width = tab_bar.get_parent().get_rect().size.x/tabs.size()



# Change position mode
func change_vertical_mode(mode:bool = vertical_mode):
	vertical_mode = mode
	if tab_bar:
		tab_bar.queue_free()
	vertical_mode = vertical_mode

	tab_bar = InspectorTabBar.new(tab_clip_mode, vertical_mode, vertical_tab_side == 0)
	tab_bar.custom_minimum_size = Vector2(10,10)
	tab_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	#tab_bar.clip_tabs = true
	tab_bar.rotation = PI/2
	tab_bar.mouse_filter =Control.MOUSE_FILTER_PASS

	#panel.anchor_right = 1
	#panel.anchor_bottom = 1

	var inspector = EditorInterface.get_inspector().get_parent()

	tab_bar.tab_clicked.connect(tab_clicked)

	if not vertical_mode:
		inspector.add_child(tab_bar)
		inspector.move_child(tab_bar,3)

	update_tabs()

	if vertical_mode:
		EditorInterface.get_inspector().add_child(tab_bar)
		property_container.size_flags_horizontal = Control.SIZE_SHRINK_END
		favorite_container.size_flags_horizontal = Control.SIZE_SHRINK_END
		viewer_container.size_flags_horizontal = Control.SIZE_SHRINK_END
		tab_bar.top_level = true
		if vertical_tab_side == 0:
			tab_bar.layout_direction =Control.LAYOUT_DIRECTION_LTR
			(tab_bar._tab_container as HBoxContainer).layout_direction = Control.LAYOUT_DIRECTION_RTL
		else:
			tab_bar.layout_direction =Control.LAYOUT_DIRECTION_RTL
			(tab_bar._tab_container as HBoxContainer).layout_direction = Control.LAYOUT_DIRECTION_LTR
	else:
		property_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		favorite_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		viewer_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		property_container.custom_minimum_size.x = 0
		favorite_container.custom_minimum_size.x = 0
		viewer_container.custom_minimum_size.x = 0
	tab_bar.resized.connect(tab_resized)
	tab_bar.tab_selected.connect(tab_selected)
	tab_resized()


func settings_changed() -> void:
	var tab_pos = settings.get("inspector_tabs/tab_layout")
	if tab_pos != null:
		if tab_pos == 0:
			if vertical_mode != false:
				change_vertical_mode(false)
		else:
			if vertical_mode != true:
				change_vertical_mode(true)
	var style = settings.get("inspector_tabs/tab_style")
	if style != null:
		if tab_style != style:
			tab_style = style
	var prop_mode = settings.get("inspector_tabs/tab_property_mode")
	if prop_mode != null:
		if property_mode != prop_mode:
			property_mode = prop_mode
	var merge_class = settings.get("inspector_tabs/merge_abstract_class_tabs")
	if merge_class != null:
		if merge_abstract_class_tabs != merge_class:
			merge_abstract_class_tabs = merge_class
	var clip_mode = settings.get(KEY_TAB_CLIP_MODE)
	if clip_mode != null:
		if tab_clip_mode != clip_mode:
			tab_clip_mode = clip_mode
			change_vertical_mode()


	if tab_pos != null and style != null and prop_mode != null and merge_class != null and clip_mode != null:

		#Save settings
		var config = ConfigFile.new()
		# Store some values.
		config.set_value("Settings", "tab layout", tab_pos)
		config.set_value("Settings", "tab style", style)
		config.set_value("Settings", "tab property mode", prop_mode)
		config.set_value("Settings", "merge abstract class tabs", merge_abstract_class_tabs)
		config.set_value("Settings", "tab clip mode", clip_mode)

		# Save it to a file (overwrite if already exists).
		var err = config.save(EditorInterface.get_editor_paths().get_config_dir()+"/InspectorTabsPluginSettings.cfg")
		if err != OK:
			print("Error saving inspector tab settings: ",error_string(err))

func property_scrolling():
	if property_mode != TabPropertyModes.JUMP_SCROLL or tab_bar.tab_count == 0 or is_filtering:return
	var category_idx = -1
	var tab_idx = -1
	var category_y = - INF
	if property_scroll_bar.value <= 1:
		tab_bar.current_tab = 0
		return
	for i in property_container.get_children():
		if i.get_class() == "EditorInspectorCategory":
			var list_size_y =  EditorInterface.get_inspector().get_children().filter(func(node:Node):return node is VBoxContainer)[0].size.y
			if (i.position.y+property_container.position.y-EditorInterface.get_inspector().size.y/3) <= property_scroll_bar.value/property_scroll_bar.max_value*list_size_y:
				category_y = property_container.position.y
			else:
				tab_bar.current_tab = max(tab_idx,0)
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
		load_icon = get_script_icon(tab) ## Get script custom icon or the GDScript icon
	elif ClassDB.class_exists(tab):
		if ClassDB.class_get_api_type(tab) == ClassDB.APIType.API_EXTENSION:
			load_icon = get_extension_class_icon(tab)  ## Get GDExtension node icon
		else:
			load_icon = base_control.get_theme_icon(tab, "EditorIcons") ## Get editor node icon
	else:
		load_icon = get_script_class_icon(tab) ## Get script class icon

	if load_icon == UNKNOWN_ICON:
		load_icon = base_control.get_theme_icon("NodeDisabled", "EditorIcons")

	return load_icon


func find_custom_class_name(_script:GDScript) -> String:
	var _name : String = ""
	if _script.get_base_script():
		_name = _script.get_base_script().get_global_name()
		for class_info in ProjectSettings.get_global_class_list():
			if class_info["class"] == _name:
				if ResourceLoader.exists(class_info["icon"]) == false:
					return find_custom_class_name(load(class_info["path"]))
	else:
		var _node = _script.new() as Node
		_name = _node.get_class()
		_node.free()
	return _name


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

class InspectorTabBar extends MarginContainer:
	signal tab_clicked(tab : int)
	signal tab_selected(tab : int)

	var _buttons : Array[Button] = []
	var _tab_container : Container

	var current_tab:int = 0:
		set(v):
			if current_tab != v:
				current_tab = v
				_update_buttons()

	var tab_count:int = 0

	enum ClipMode {
		SCROLL,
		CLIP_TEXT,
		FLOW
	}

	func _init(mode:ClipMode, vertical:bool, on_left_side:bool) -> void:
		self.name = "InspectorTabBar"

		var panel = Panel.new()
		add_child(panel)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW

		var add_scroll_container := func():
			_tab_container = HBoxContainer.new()
			_tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var scroll_container := InspectorScrollContainer.new(vertical)
			panel.add_child(scroll_container)
			scroll_container.add_child(_tab_container)
			scroll_container.minimum_size_changed.connect(func(): panel.custom_minimum_size.y = scroll_container.size.y)
			scroll_container.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)


		match mode:
			ClipMode.FLOW:
				_tab_container = FlowContainer.new()
				panel.add_child(_tab_container)
				_tab_container.minimum_size_changed.connect(func(): panel.custom_minimum_size.y = _tab_container.get_minimum_size().y)
			ClipMode.SCROLL:
				add_scroll_container.call()
			ClipMode.CLIP_TEXT:
				add_scroll_container.call()

		_tab_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL


	func _tab_clicked(tab: int) -> void:
		current_tab = tab
		tab_clicked.emit(tab)
		_update_buttons()
	func _update_buttons():
		for i in _buttons.size():
			if i != current_tab:
				_buttons[i].button_pressed = false
			else:
				_buttons[i].button_pressed = true

	func clear_tabs() -> void:
		for button in _buttons:
			button.queue_free()
		_buttons.clear()
		tab_count = 0

	func add_tab(title:String, icon:Texture2D) -> void:
		#print("ADD T")
		var button := Button.new()
		button.toggle_mode = true
		_tab_container.add_child(button)
		button.pressed.connect(_tab_clicked.bind(_buttons.size()))
		_buttons.append(button)
		button.text = title
		button.icon = icon
		tab_count += 1
		#printerr("add_tab() not implemented")

	func set_tab_tooltip(tab_idx:int, tooltip:String) -> void:
		_buttons[tab_idx].tooltip_text = tooltip

class InspectorScrollContainer extends Control:

	const PAGE_DIVISOR = 8

	var _scroll_bar : ScrollBar
	var _child : Control

	var reverse := false

	func _init(reverse:bool) -> void:
		self.reverse = reverse
		#var vbox := VBoxContainer.new()
		#vbox.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		#add_child(vbox)
		#vbox.minimum_size_changed.connect(func(): custom_minimum_size.y = vbox.get_minimum_size().y)
		#vbox.clip_contents = false
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

		#vbox.add_child(_tab_container)


		_scroll_bar = HScrollBar.new()
		add_child(_scroll_bar)
		_scroll_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_scroll_bar.set_anchors_and_offsets_preset.call_deferred(Control.PRESET_BOTTOM_WIDE)
		_scroll_bar.owner = self
		_scroll_bar.scrolling.connect(_on_scroll_bar_scrolling)
		resized.connect(_update_scroll_bar)
		if reverse:
			_scroll_bar.scale.x = -1
		#_scroll_bar.

		custom_minimum_size.y = _scroll_bar.get_minimum_size().y
		child_entered_tree.connect(_on_child_entered_tree)

	func _on_child_entered_tree(node: Node) -> void:
		if _child: return
		if node != _scroll_bar:
			if node is Control:
				_child = node
				node.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
				node.minimum_size_changed.connect(func():
					_update_scroll_bar())
				custom_minimum_size.y = _scroll_bar.get_minimum_size().y + node.get_minimum_size().y
		#panel.resized.connect(func():
			#scroll_bar.page = panel.size.x;
			#scroll_bar.custom_minimum_size.x = panel.size.x)

	func _update_scroll_bar() -> void:
		if _child:
			_scroll_bar.max_value = _child.get_minimum_size().x
			custom_minimum_size.y = _scroll_bar.get_minimum_size().y + _child.get_minimum_size().y;

		_scroll_bar.page = size.x;
		#_scroll_bar.custom_minimum_size.x = size.x
		_scroll_bar.scrolling.emit()

		if _scroll_bar.page == _scroll_bar.max_value:
			_scroll_bar.visible = false
			if _child:
				custom_minimum_size.y = _child.get_minimum_size().y;
		else:
			_scroll_bar.visible = true
			if _child:
				custom_minimum_size.y = _scroll_bar.get_minimum_size().y + _child.get_minimum_size().y;
		_scroll_bar.position.y = size.y - _scroll_bar.size.y

		if reverse:
			_scroll_bar.position.x = size.x

	func _on_scroll_bar_scrolling() -> void:
		if _child:
			if not reverse:
				_child.position.x = -_scroll_bar.value
			else:
				_child.position.x = size.x + _scroll_bar.value - _child.size.x

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			if event.button_index == MouseButton.MOUSE_BUTTON_WHEEL_DOWN and event.is_pressed():
				# Taken from godot source code.
				var change : float = ( _scroll_bar.page / PAGE_DIVISOR if (_scroll_bar.page != 0.0) else (_scroll_bar.max_value - _scroll_bar.min_value) / 16.0) * event.factor;
				_scroll_bar.value += max(change,_scroll_bar.step)
				_scroll_bar.scrolling.emit()
			if event.button_index == MouseButton.MOUSE_BUTTON_WHEEL_UP and event.is_pressed():
				# Taken from godot source code.
				var change : float = ( _scroll_bar.page / PAGE_DIVISOR if (_scroll_bar.page != 0.0) else (_scroll_bar.max_value - _scroll_bar.min_value) / 16.0) * event.factor;
				_scroll_bar.value -= max(change,_scroll_bar.step)
				_scroll_bar.scrolling.emit()
