extends SceneTree
func _initialize(): call_deferred("run")
func capture(file: String):
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://previews/"+file)
func run():
	var game=load("res://Main.tscn").instantiate()
	root.add_child(game)
	await capture("base.png")
	game.page="voyages"
	game.render()
	await capture("ships_selection.png")
	for id in range(3):
		game.state.raid=false
		game.state.run_data={}
		game.state.cleared_chapters=id
		game.state.selected_map=id
		game.launch()
		var a=game.arena
		a.set_process(false)
		a.rng.seed=44+id
		a.player=[Vector2(740,920),Vector2(780,1120),Vector2(950,1000)][id]
		a.elapsed=35
		a.hp=82
		a.kills=12
		a.cargo=260
		a.active_slot="secondary"
		a.facing=Vector2.UP
		a.enemies=[]
		for i in range(7):
			a.spawn_enemy()
			var target=a.player+Vector2.from_angle(i*2.1)*(110+i*17)
			a.enemies[-1].p=a.ship.grid.get_point_position(a.ship.cell_at(target))
		a.banner_time=0
		a.update_hud()
		a.queue_redraw()
		await capture(["sailship.png","yacht.png","cruise.png"][id])
		a.show_chart()
		await capture(["sailship_chart.png","yacht_chart.png","cruise_chart.png"][id])
		a.close_overlay()
	game.free()
	await process_frame
	print("Rendered three ships, tactical charts, ship selection and base")
	quit()
