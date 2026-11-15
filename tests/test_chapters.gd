extends SceneTree
const Model=preload("res://State.gd")
const Arena=preload("res://Arena.gd")
func _initialize(): call_deferred("run")
func enemy_at(point: Vector2,id: int,hp: float=0) -> Dictionary:
	return {"p":point,"hp":hp,"max_hp":30.0,"speed":0.0,"radius":15.0,"elite":false,"runner":false,"id":id,"air":0.0}
func arena_for(state):
	var a=Arena.new()
	a.state=state
	a.size=Vector2(480,900)
	root.add_child(a)
	a.set_process(false)
	a.spawn_clock=999
	return a
func progress_to_boss(a):
	a.player=a.ship.spawn
	for i in range(Arena.CHAPTER_TARGETS[0]):
		a.enemies=[enemy_at(a.player,100+i)]
		a.resolve_kills()
	assert(a.chapter_kills[0]==Arena.CHAPTER_TARGETS[0])
	a.player=a.ship.grid.get_point_position(a.ship.cell_at(Vector2(950,950)))
	assert(a.zone()==1)
	for i in range(Arena.CHAPTER_TARGETS[1]):
		a.enemies=[enemy_at(a.player,200+i)]
		a.resolve_kills()
	assert(a.chapter_kills[1]==Arena.CHAPTER_TARGETS[1])
	a.player=a.ship.grid.get_point_position(a.ship.cell_at(Vector2(950,550)))
	a.drops=[]
	a.simulate(0.01,Vector2.ZERO)
	assert(a.boss_started and not a.chapter_boss().is_empty())
func run():
	var s=Model.new()
	assert(s.chapter_unlocked(0) and not s.chapter_unlocked(1) and not s.chapter_unlocked(2))
	assert(not s.select_chapter(1))
	s.selected_map=1
	assert(not s.start() and not s.raid)
	s.selected_map=0
	s.start()
	var a=arena_for(s)
	a.player=a.ship.cache_points[-1].p
	a.simulate(0.01,Vector2.ZERO)
	assert(not a.boss_started)
	# Loot extraction is explicitly not chapter completion.
	a.player=a.exits()[0]
	a.cargo=100
	a.finish_run(true)
	assert(s.cleared_chapters==0 and s.valuables==100)
	a.free()
	# Boss kill followed by an early exit still cannot unlock the next ship.
	s.start()
	a=arena_for(s)
	progress_to_boss(a)
	a.chapter_boss().hp=0
	a.resolve_kills()
	assert(a.boss_defeated)
	a.player=a.exits()[0]
	a.finish_run(true)
	assert(s.cleared_chapters==0)
	a.free()
	# A death after defeating the boss cannot unlock either.
	s.start()
	a=arena_for(s)
	progress_to_boss(a)
	a.chapter_boss().hp=0
	a.resolve_kills()
	a.player=a.exits()[-1]
	a.finish_run(false)
	assert(s.cleared_chapters==0)
	a.free()
	for id in range(3):
		assert(s.select_chapter(id) and s.start())
		a=arena_for(s)
		progress_to_boss(a)
		# Save during a telegraphed boss attack; reload full enemy state.
		var boss=a.chapter_boss()
		boss.attack_target=a.player
		boss.windup=0.6
		a.checkpoint()
		var restored=Model.new()
		restored.load_game()
		assert(restored.run_data.boss_started and restored.run_data.chapter_kills[1]==Arena.CHAPTER_TARGETS[1])
		a.free()
		s=restored
		a=arena_for(s)
		assert(is_equal_approx(a.chapter_boss().windup,0.6))
		# Telegraph damage and shield special invulnerability.
		a.hp=100
		a.hit_clock=0
		boss=a.chapter_boss()
		boss.p=a.player+Vector2(0,40)
		boss.attack_target=a.player
		boss.windup=0.01
		a.update_chapter_boss(boss,0.02)
		assert(a.hp==100-(25+id*5))
		a.hit_clock=0
		a.special_kind="shield"
		a.special_time=1
		boss.windup=0.01
		var health=a.hp
		a.update_chapter_boss(boss,0.02)
		assert(a.hp==health)
		a.special_time=0
		boss.hp=0
		a.resolve_kills()
		assert(a.boss_defeated)
		a.enemies=[]
		a.drops=[]
		a.player=a.exits()[-1]
		a.request_extraction()
		for j in range(3): a.simulate(1,Vector2.ZERO)
		assert(a.ended and s.cleared_chapters==id+1)
		a.finish_run(true)
		assert(s.cleared_chapters==id+1)
		a.free()
		var saved=Model.new()
		saved.load_game()
		assert(saved.cleared_chapters==id+1)
		s=saved
	# Replay does not skip chapters or erase completion.
	assert(s.select_chapter(0) and s.start())
	s.complete(true,0,0,0,[],true)
	assert(s.cleared_chapters==3)
	# Previous free-selection version: recover expedition items, reset only chapter locks.
	var legacy=Model.new()
	legacy.cleared_chapters=2
	legacy.selected_map=2
	legacy.start()
	legacy.run_data={"map_id":2,"bag":[legacy.new_item("hammer",2)],"cargo":321,"parts":4}
	legacy.save_game()
	var data=JSON.parse_string(FileAccess.get_file_as_string(Model.SAVE))
	data.version=4
	data.erase("cleared_chapters")
	var file=FileAccess.open(Model.SAVE,FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	var migrated=Model.new()
	migrated.load_game()
	assert(not migrated.raid and migrated.selected_map==0 and migrated.cleared_chapters==0)
	assert(migrated.stash.size()==4 and migrated.valuables==321 and migrated.parts==4)
	print("PASS: locked selection/start, stage objectives, middle-exit/death rejection, three sequential boss clears, final extraction, boss save/resume, telegraph damage/immunity, replay/idempotency")
	await create_timer(0.1).timeout
	quit()
