extends SceneTree
func _initialize(): call_deferred("run")
func capture(path: String):
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run():
	var game=load("res://Main.tscn").instantiate()
	root.add_child(game)
	game.launch()
	var a=game.arena
	a.set_process(false)
	a.player=Vector2(950,1050)
	a.spawn_clock=999
	a.rng.seed=18
	a.skills={"weapon_rifle":4,"spread":2}
	a.level=7
	a.xp=a.xp_needed()
	a.roll_choices()
	a.show_choices()
	await capture("res://previews/growth_choice.png")
	a.choose_skill("evolve_rifle")
	a.skills.merge({"field":2,"drone":2,"haste":2,"power":2},true)
	a.level=14
	a.xp=0
	a.elapsed=125
	a.kills=135
	a.chapter_kills=[60,75]
	a.wave_started=[3,2]
	a.wave_remaining=0
	a.wave_clock=999
	a.cargo=2200
	a.enemies=[]
	for i in range(65):
		a.spawn_enemy()
		var candidate=a.player+Vector2.from_angle(i*2.4)*(120+i*3)
		a.enemies[-1].p=a.ship.grid.get_point_position(a.ship.cell_at(candidate))
		a.enemies[-1].hp=120
		a.enemies[-1].max_hp=120
	a.banner="탄막 폭풍 · 진화 완료"
	a.banner_time=4
	DirAccess.make_dir_recursive_absolute("user://growth_frames")
	for i in range(45):
		if a.paused: a.choose_skill(a.offered[0])
		a.simulate(1.0/15,Vector2.ZERO)
		a.update_hud()
		a.queue_redraw()
		await capture("user://growth_frames/%03d.png" % i)
		if i==18: await capture("res://previews/growth_combat.png")
	print("Animation frames: ",ProjectSettings.globalize_path("user://growth_frames"))
	game.free()
	await process_frame
	quit()
