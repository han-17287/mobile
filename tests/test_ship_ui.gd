extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var game=load("res://Main.tscn").instantiate()
	root.add_child(game)
	game.page="voyages"
	game.render()
	await process_frame
	var choice
	for child in game.stack.get_children():
		if child is Button and child.text.contains("크루즈"): choice=child
	assert(choice!=null and choice.disabled)
	game.state.cleared_chapters=2
	game.render()
	for child in game.stack.get_children():
		if child is Button and child.text.contains("크루즈"): choice=child
	assert(not choice.disabled)
	choice.pressed.emit()
	assert(game.page=="base" and game.state.selected_map==2)
	game.launch()
	var arena=game.arena
	arena.set_process(false)
	assert(arena.ship.id==2 and arena.caches.size()==3)
	arena.show_chart()
	var time=arena.elapsed
	arena.simulate(1.0,Vector2.UP)
	assert(arena.paused and arena.elapsed==time)
	arena.close_overlay()
	assert(not arena.paused)
	# Magnetic pickup cannot pull items through a cabin partition.
	arena.player=Vector2(900,850)
	arena.drops=[{"p":Vector2(830,850),"xp":1,"cash":12,"parts":0}]
	arena.skills={"magnet":5}
	var origin=arena.drops[0].p
	arena.collect_drops(0.1)
	assert(arena.drops[0].p==origin)
	game.free()
	await process_frame
	print("PASS: ship selection/launch, chart pause/resume, loot cannot be pulled through walls")
	quit()
