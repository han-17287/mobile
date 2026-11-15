extends ScrollContainer
## Explicit touch scrolling with mouse emulation disabled for combat multitouch.
var scroll_finger: int = -1
var start_point := Vector2.ZERO
var initial_scroll := 0
var touch_scrolling := false

func _input(event):
	if not is_visible_in_tree(): return
	if event is InputEventScreenTouch:
		if event.pressed and scroll_finger == -1 and get_global_rect().has_point(event.position):
			scroll_finger = event.index
			start_point = event.position
			initial_scroll = scroll_vertical
			touch_scrolling = false
		elif not event.pressed and event.index == scroll_finger:
			if touch_scrolling:
				cancel_buttons(self,scroll_finger)
				get_viewport().set_input_as_handled()
			scroll_finger = -1
			touch_scrolling = false
	elif event is InputEventScreenDrag and event.index == scroll_finger:
		var displacement = event.position.y-start_point.y
		if absf(displacement)>12 or touch_scrolling:
			touch_scrolling = true
			cancel_buttons(self,scroll_finger)
			scroll_vertical = initial_scroll-int(displacement)
			get_viewport().set_input_as_handled()

func cancel_buttons(parent: Node, index: int):
	for child in parent.get_children():
		if child is Button and child.get_script() == preload("res://TouchButton.gd"):
			if child.finger == index: child.finger = -1
		cancel_buttons(child,index)

func _notification(what):
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		scroll_finger = -1
		touch_scrolling = false
