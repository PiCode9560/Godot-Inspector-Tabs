# Godot Inspector Tabs
Godot add-on for spliting the inspector property classes into its own tabs. So that its shorter and require less scrolling.
There's also a jump-scroll option that didn't hide the properties in different tabs.

Vertical layout           |  Horizontal layout
:-------------------------:|:-------------------------:
![](https://github.com/user-attachments/assets/fc5455d2-c48d-4e1f-b51f-4c09e2d4eb83)  |  ![](https://github.com/user-attachments/assets/e2849982-a57f-46d6-bcfa-c38676032b9d)

# Features
- An option for horizontal/vertical tab layout. (Can be changed in the `editor_settings/inspector_tabs/tab_layout`. Make sure advanced settings is on)
- An option to add/remove text and icon on the tabs. (Can be changed in the `editor_settings/inspector_tabs/tab_style`)
- A Jump-scroll option that didn't hide the properties in different tabs. (Can be changed in the `editor_settings/inspector_tabs/tab_property_mode`)
- An option to put abstract class into its child tab instead of its own. so that its easier to find. (Can be changed in the `editor_settings/inspector_tabs/merge_abstract_class_tabs`)
- The built-in property filter will search for properties on all tabs.
- Settings is synced to all projects.
- Support custom script classes and GDExtension classes.
- Favorite property will be shown in all tabs.

# Installing
You can install it from the [Asset store](https://store.godotengine.org/asset/picode/inspector-tabs/) or [Asset library](https://godotengine.org/asset-library/asset/3951).

You can also install it manually:
- Download the files.
- Place the addon folder into your the root of your project.
- In the project, go to `project_settings/plugins` and enable the plugin.
