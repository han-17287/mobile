extends SceneTree
func _initialize(): call_deferred("run")
func touch(index, position, pressed):
	var event=InputEventScreenTouch.new()
	event.index=index
	event.position=position
	event.pressed=pressed
	root.push_input(event,true)
func run():
	DirAccess.remove_absolute("user://extraction_save.json")
	var game=load("res://Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.launch()
	var a=game.arena
	a.set_process(false)
	await process_frame
	touch(0,Vector2(70,700),true)
	var drag=InputEventScreenDrag.new()
	drag.index=0
	drag.position=Vector2(120,700)
	root.push_input(drag,true)
	assert(a.dragging and a.aim_input.x>0)
	var point=a.swap_button.get_global_rect().get_center()
	touch(1,point,true)
	touch(1,point,false)
	assert(a.active_slot=="secondary" and a.dragging)
	a.state.equipped.secondary=a.state.new_item("hammer",0)
	a.update_hud()
	point=a.charge_button.get_global_rect().get_center()
	touch(1,point,true)
	assert(a.charging and a.dragging)
	a.charge_time=1.6
	touch(1,point,false)
	assert(not a.charging and a.melee_clock>0 and a.dragging)
	touch(0,Vector2(120,700),false)
	assert(not a.dragging)
	point=a.pause_button.get_global_rect().get_center()
	touch(0,point,true)
	touch(0,point,false)
	assert(a.paused)
	# Touch must not activate combat controls behind the modal.
	point=a.swap_button.get_global_rect().get_center()
	touch(0,point,true)
	touch(0,point,false)
	assert(a.active_slot=="secondary" and a.paused)
	a.close_overlay()
	a.finish_run(false)
	await process_frame
	game.page="shop"
	game.render()
	game.show_purchase("보석",300,"₩2,900")
	await process_frame
	# Confirmation buttons use the same independent-touch implementation.
	var button=game.confirm.get_ok_button()
	var event=InputEventScreenTouch.new()
	event.index=0
	event.position=Vector2(5,5)
	event.pressed=true
	button._gui_input(event)
	event.position=button.get_global_rect().get_center()
	event.pressed=false
	button._input(event)
	assert(game.state.gems==300)
	DirAccess.remove_absolute("user://extraction_save.json")
	game.free()
	await process_frame
	print("PASS: GUI-dispatched multitouch movement + weapon switching + hammer hold/release, pause modal isolation, confirmation touch")
	quit()
