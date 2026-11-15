extends SceneTree
func _initialize(): call_deferred("run")
func capture(name: String):
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://previews/"+name)
func run():
	var game=load("res://Main.tscn").instantiate()
	root.add_child(game)
	game.page="voyages"
	game.render()
	await capture("chapters_locked.png")
	game.launch()
	var a=game.arena
	a.set_process(false)
	a.chapter_kills=[60,100]
	a.player=Vector2(950,570)
	a.elapsed=95
	a.kills=27
	a.hp=78
	a.cargo=640
	a.parts=4
	a.spawn_chapter_boss()
	var boss=a.chapter_boss()
	boss.p=Vector2(960,490)
	boss.hp=680
	boss.windup=0.7
	boss.attack_target=a.player+Vector2(-55,60)
	a.update_hud()
	a.queue_redraw()
	await capture("chapter_boss.png")
	boss.hp=0
	a.resolve_kills()
	a.player=a.exits()[-1]
	a.finish_run(true)
	await process_frame
	game.page="voyages"
	game.render()
	await capture("chapters_unlocked.png")
	game.free()
	await process_frame
	print("Rendered locked chapters, boss encounter, and next-chapter unlock")
	quit()
