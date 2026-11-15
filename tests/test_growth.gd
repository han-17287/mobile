extends SceneTree
const Model=preload("res://State.gd")
const Arena=preload("res://Arena.gd")
func _initialize(): call_deferred("run")
func foe(a,p: Vector2,id: int,hp: float=5000) -> Dictionary:
	return {"p":p,"hp":hp,"max_hp":hp,"speed":0.0,"radius":15.0,"elite":false,"runner":false,"id":id,"air":0.0}
func run():
	var state=Model.new()
	state.start()
	var a=Arena.new()
	a.state=state
	a.size=Vector2(480,900)
	root.add_child(a)
	a.set_process(false)
	a.player=Vector2(1100,1550)
	a.spawn_clock=1000
	# Fresh run: no persistent/equipment upgrade leakage.
	assert(a.skills.is_empty() and a.level==1 and a.wave_started==[0,0])
	a.tick_waves(0.01)
	assert(a.wave_started[0]==1 and a.wave_remaining==17)
	a.chapter_kills[0]=15
	a.tick_waves(0.01)
	assert(a.wave_started[0]==2)
	a.chapter_kills[0]=35
	a.tick_waves(0.01)
	assert(a.wave_started[0]==3)
	# XP choices are earned, pause the action, grant ammunition and run-only stats.
	for rank in range(4):
		a.xp=a.xp_needed()
		a.roll_choices()
		assert(a.offered.has("weapon_rifle"))
		a.show_choices()
		assert(a.paused)
		var bullets_before=a.ammo
		a.choose_skill("weapon_rifle")
		assert(a.mastery("rifle")==rank+1 and a.ammo==bullets_before+8 and not a.paused)
	for rank in range(2):
		a.xp=a.xp_needed()
		a.roll_choices()
		assert(a.offered.has("spread"))
		a.choose_skill("spread")
	a.xp=a.xp_needed()
	a.roll_choices()
	assert(a.offered.has("evolve_rifle"))
	a.choose_skill("evolve_rifle")
	assert(a.evolved("rifle"))
	a.roll_choices()
	assert(not a.offered.has("evolve_rifle"))
	a.offered=[]
	a.enemies=[foe(a,a.player+Vector2(0,-90),100)]
	a.bullets=[]
	var ammo=a.ammo
	a.fire()
	assert(a.bullets.size()==9 and a.ammo==ammo-1)
	assert(a.bullets[0].blast==90 and a.bullets[0].ricochet==2)
	# A hit can hurt a group and redirect toward an unhit target; no wall penetration.
	a.enemies=[foe(a,a.player+Vector2(0,-65),200),foe(a,a.player+Vector2(35,-65),201)]
	a.bullets=[{"p":a.player,"v":Vector2(0,-600),"ttl":1.0,"damage":100.0,"hits":[],"remaining":1,"blast":90.0,"ricochet":1}]
	a.update_bullets(0.1)
	assert(a.enemies[0].hp<4900 and a.enemies[1].hp<5000)
	assert(a.bullets.size()==1 and a.bullets[0].ricochet==0)
	# All four secondaries change their actual attacks when upgraded/evolved.
	for kind in ["katana","hammer","bat","shield"]:
		state.equipped.secondary=state.new_item(kind,0)
		a.skills={"weapon_"+kind:4,"area":2,"evolve_"+kind:1}
		a.active_slot="secondary"
		a.combo=2
		a.facing=Vector2.UP
		a.enemies=[foe(a,a.player+Vector2(0,-60),300),foe(a,a.player+Vector2(40,-60),301)]
		a.bullets=[]
		assert(a.melee_reach(80)>200)
		a.melee_attack()
		if kind=="katana" or kind=="bat": assert(a.bullets.size()==3)
		if kind=="hammer": assert(a.enemies[0].hp<4800 and a.effects.size()>0)
		a.special_clock=0
		a.special_time=0
		a.use_special()
		if kind=="bat": assert(a.bullets.size()==8 and a.bullets[-1].blast==75)
		if kind=="shield": assert(a.special_time>0 and a.special_clock<15)
	# Guaranteed five-kill ammo and doubled XP; one pickup is collected only once.
	a.enemies=[]
	a.kills=4
	a.enemies=[foe(a,a.player,999,0)]
	a.drops=[]
	a.resolve_kills()
	assert(a.drops[0].ammo==12 and a.drops[0].xp==2)
	ammo=a.ammo
	a.collect_drops(0.1)
	assert(a.ammo==ammo+12 and a.drops.is_empty())
	a.collect_drops(0.1)
	assert(a.ammo==ammo+12)
	# Evolution and wave progress resume exactly, but reset on the next sortie.
	a.checkpoint()
	var restored=Model.new()
	restored.load_game()
	a.free()
	a=Arena.new()
	a.state=restored
	a.size=Vector2(480,900)
	root.add_child(a)
	a.set_process(false)
	assert(a.evolved("shield") and a.wave_started[0]==3)
	a.finish_run(false)
	a.free()
	restored.start()
	a=Arena.new()
	a.state=restored
	a.size=Vector2(480,900)
	root.add_child(a)
	a.set_process(false)
	assert(a.skills.is_empty() and a.level==1 and a.wave_started==[0,0])
	a.free()
	print("PASS: three waves, earned upgrades, guaranteed evolution prerequisites, ammo economy, explosive ricochet, four secondary evolutions, pickup idempotency, resume and fresh-run reset")
	await create_timer(0.1).timeout
	quit()
