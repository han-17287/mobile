extends Button
## Native GUI hit testing plus independent fingers: move with one thumb,
## activate/hold a combat button with another. Mouse remains supported on desktop.
var finger := -1
func _gui_input(event):
	if event is InputEventScreenTouch and event.pressed and not disabled and finger == -1:
		finger = event.index
		button_down.emit()
		accept_event()

func _input(event):
	if event is InputEventScreenTouch and not event.pressed and event.index == finger:
		finger = -1
		get_viewport().set_input_as_handled()
		button_up.emit()
		if not disabled and is_visible_in_tree() and get_global_rect().has_point(event.position): pressed.emit()

func _notification(what):
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		finger = -1
