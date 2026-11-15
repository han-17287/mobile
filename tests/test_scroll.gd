extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var game=load("res://Main.tscn").instantiate()
	root.add_child(game)
	game.page="armory"
	game.render()
	await process_frame
	var scroll=game.get_child(0)
	var press=InputEventScreenTouch.new()
	press.index=0
	press.position=Vector2(300,700)
	press.pressed=true
	root.push_input(press,true)
	for i in range(10):
		var drag=InputEventScreenDrag.new()
		drag.index=0
		drag.position=Vector2(300,700-i*30)
		drag.relative=Vector2(0,-30)
		root.push_input(drag,true)
		await process_frame
	press.pressed=false
	root.push_input(press,true)
	print("scroll after touch drag=",scroll.scroll_vertical)
	assert(scroll.scroll_vertical>0)
	assert(game.state.equipped.secondary.kind=="katana")
	print("PASS: touch scrolling over controls does not activate them")
	game.free()
	quit()
