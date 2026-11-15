extends SceneTree
const Model = preload("res://State.gd")
const Arena = preload("res://Arena.gd")
func _initialize(): call_deferred("run")
func run():
	var state = Model.new()
	state.start()
	var a = Arena.new()
	a.state = state
	a.size = Vector2(480,900)
	root.add_child(a)
	a.set_process(false)
	a.rng.seed = 42
	# A three-minute simulation exercises escalating crowds, all skill effects,
	# elite waves, pickups and snapshots without making a balance claim.
	a.hp = 100000
	a.max_hp = 100000
	a.skills = {"power":2,"haste":2,"pierce":2,"spread":2,"field":2,"drone":2,"speed":2,"magnet":2}
	for i in range(10800):
		if a.paused:
			assert(not a.offered.is_empty())
			a.choose_skill(a.offered[0])
		var heading = Vector2.from_angle(i / 180.0)
		a.simulate(1.0/60, heading)
		assert(not a.ended)
		assert(a.enemies.size() <= 121 and a.drops.size() <= 200)
	assert(a.kills > 50 and (a.elite_wave >= 1 or a.boss_defeated) and a.level > 2)
	print("PASS: 180s simulation; kills=",a.kills," level=",a.level," elite waves=",a.elite_wave," enemies=",a.enemies.size())
	DirAccess.remove_absolute(Model.SAVE)
	a.free()
	await create_timer(0.15).timeout
	quit()
