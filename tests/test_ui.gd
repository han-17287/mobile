extends SceneTree
const Model = preload("res://State.gd")
func _initialize(): call_deferred("run")
func run():
	DirAccess.remove_absolute(Model.SAVE)
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.page = "shop"
	game.render()
	game.show_purchase("현장 보급", 1200, "₩2,900")
	game.confirm.confirmed.emit()
	assert(game.state.gems == 1200 and game.state.credits == 1200)
	game.launch()
	var a = game.arena
	a.set_process(false)
	await process_frame
	assert(a.size == Vector2(480,900))
	var touch = InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = Vector2(100,700)
	a._gui_input(touch)
	var drag = InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(152,700)
	a._gui_input(drag)
	var old = a.player
	a.simulate(0.1, a.aim_input)
	assert(a.player.x > old.x)
	touch.pressed = false
	a._gui_input(touch)
	assert(not a.dragging and a.aim_input == Vector2.ZERO)
	# A visible target is automatically shot, killed, and drops a collectible.
	a.enemies = [{"p":a.player + Vector2(0,-65),"hp":1.0,"max_hp":30.0,"speed":0.0,"radius":15.0,"elite":false,"runner":false,"id":100}]
	a.bullets = []
	a.fire()
	assert(not a.bullets.is_empty())
	a.update_bullets(0.1)
	a.resolve_kills()
	assert(a.kills == 1 and a.drops.size() == 1)
	a.drops[0].p = a.player
	a.collect_drops(0.1)
	assert(a.cargo == 12 and a.xp == 2)
	a.xp = a.xp_needed()
	a.roll_choices()
	a.show_choices()
	assert(a.paused and a.offered.size() == 3)
	var chosen = a.offered[0]
	old = a.player
	a.simulate(1, Vector2.RIGHT)
	assert(a.player == old)
	a.choose_skill(chosen)
	assert(a.skill(chosen) == 1 and a.level == 2 and not a.paused)
	a.hp = 50
	a.heal()
	assert(a.hp == 90 and a.meds == 1)
	a.checkpoint()
	var saved = Model.new()
	saved.load_game()
	assert(saved.run_data.player == a.player and int(saved.run_data.meds) == 1)
	# Reload the full arena, not just its dictionary.
	game.state = saved
	game.render()
	a = game.arena
	a.set_process(false)
	assert(a.hp == 90 and a.skill(chosen) == 1 and a.kills == 1)
	a.toggle_pause()
	assert(a.paused)
	a.toggle_pause()
	assert(not a.paused)
	# Checkpoints require a deliberate request, then an uninterrupted hold.
	a.enemies=[]
	a.spawn_clock=100
	a.player=a.exits()[0]
	a.cargo=500
	a.parts=2
	var bank=game.state.credits
	a.simulate(1,Vector2.ZERO)
	assert(a.extract_progress==0 and not a.ended)
	a.request_extraction()
	a.simulate(1,Vector2.ZERO)
	a.player+=Vector2(100,0)
	a.simulate(0.1,Vector2.ZERO)
	assert(a.extract_progress==0 and not a.extraction_requested)
	a.player=a.exits()[0]
	a.request_extraction()
	for i in range(3): a.simulate(1,Vector2.ZERO)
	assert(a.ended and not game.state.raid and game.state.credits==bank and game.state.valuables==500)
	await process_frame
	game.launch()
	a = game.arena
	a.set_process(false)
	a.cargo = 999
	a.parts = 9
	a.hp = 1
	a.shot_clock = 100
	a.melee_clock = 100
	a.enemies = [{"p":a.player,"hp":1000.0,"max_hp":1000.0,"speed":0.0,"radius":15.0,"elite":false,"runner":false,"id":999}]
	bank = game.state.credits
	a.simulate(0.02, Vector2.ZERO)
	assert(a.ended and not game.state.raid and game.state.credits == bank)
	await process_frame
	DirAccess.remove_absolute(Model.SAVE)
	print("PASS: shop, touch movement/release, auto-fire, kills/loot, skill pause, healing, full resume, extraction gate/reset/payout, death")
	quit()
