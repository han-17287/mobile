extends SceneTree
const Model = preload("res://State.gd")
const Arena = preload("res://Arena.gd")
func _initialize(): call_deferred("run")
func foe(a, distance=50.0, health=10000.0):
	return {"p":a.player+Vector2(0,-distance),"hp":health,"max_hp":health,"speed":0.0,"radius":15.0,"elite":false,"runner":false,"id":100,"air":0.0}
func select(a, kind):
	a.state.equipped.secondary = a.state.new_item(kind,0)
	a.active_slot="secondary"
	a.melee_clock=0
	a.special_time=0
	a.special_clock=0
	a.second_hit=0
	a.combo=0
	a.facing=Vector2.UP
	a.enemies=[foe(a)]
	a.bullets=[]
	a.knock_velocity=Vector2.ZERO
func run():
	var state=Model.new()
	state.start()
	var a=Arena.new()
	a.state=state
	a.size=Vector2(480,900)
	root.add_child(a)
	a.set_process(false)
	a.spawn_clock=1000
	a.player=Vector2(1100,1550)
	a.crates=[]
	a.enemies=[foe(a,80)]
	a.ammo=1
	a.fire()
	assert(a.ammo==0 and a.bullets.size()==1)
	a.fire()
	assert(a.bullets.size()==1)
	a.simulate(0.01,Vector2.ZERO)
	assert(a.active_slot=="secondary")
	a.drops=[{"p":a.player,"xp":0,"cash":0,"parts":0,"ammo":12,"gear":[]}]
	a.collect_drops(0.01)
	assert(a.ammo==12 and a.active_slot=="secondary")
	a.switch_weapon()
	assert(a.active_slot=="gun")
	select(a,"katana")
	for i in range(3):
		a.enemies[0].p=a.player+Vector2(0,-40)
		a.melee_attack()
	assert(is_equal_approx(a.enemies[0].hp,10000-25-25-45))
	a.bullets=[]
	a.use_special()
	assert(a.bullets.size()==1 and a.bullets[0].visual=="katana")
	a.use_special()
	assert(a.bullets.size()==1)
	select(a,"hammer")
	assert(a.movement_speed()<175)
	a.begin_charge()
	a.charge_time=1.6
	a.release_charge()
	assert(a.enemies[0].hp==9750 and a.melee_clock>0)
	var after=a.enemies[0].hp
	a.begin_charge()
	a.release_charge()
	assert(a.enemies[0].hp==after)
	a.enemies=[foe(a,50)]
	a.use_special()
	a.update_special(0.25)
	assert(a.enemies[0].hp<10000 and a.special_time>0)
	select(a,"bat")
	var pos=a.enemies[0].p
	a.melee_attack()
	assert(a.enemies[0].p.distance_to(pos)>100 and a.enemies[0].hp==9980)
	a.bullets=[]
	a.use_special()
	assert(a.bullets[0].visual=="bat" and a.bullets[0].damage==200)
	select(a,"shield")
	a.melee_attack()
	assert(a.second_hit>0)
	a.enemies[0].p=a.player+Vector2(0,-40)
	a.simulate(0.23,Vector2.ZERO)
	assert(a.enemies[0].hp==9956)
	a.enemies=[foe(a,10)]
	a.hp=100
	a.hit_clock=0
	a.melee_clock=5
	a.simulate(0.01,Vector2.ZERO)
	assert(is_equal_approx(a.hp,93.25))
	assert(is_equal_approx(a.knock_velocity.length(),105.0))
	a.hit_clock=0
	a.enemies=[foe(a,20)]
	a.use_special()
	a.simulate(0.02,Vector2.ZERO)
	assert(is_equal_approx(a.hp,93.25) and a.enemies[0].air>0)
	# Full persisted action state: active weapon, ammo, special timer and loot.
	a.bag=[state.new_item("hammer",2)]
	a.checkpoint()
	var restored=Model.new()
	restored.load_game()
	assert(restored.run_data.ammo==a.ammo and restored.run_data.active_slot==a.active_slot)
	assert(restored.run_data.special_time==a.special_time and restored.run_data.bag.size()==1)
	# A newly equipped item is protected; the old item in the bag is lost.
	a.special_time=0
	var old_uid=state.equipped.secondary.uid
	var new_uid=a.bag[0].uid
	a.equip_bag(0)
	assert(state.equipped.secondary.uid==new_uid and a.bag[0].uid==old_uid)
	a.finish_run(false)
	assert(state.equipped.secondary.uid==new_uid)
	for item in state.stash: assert(item.uid!=old_uid)
	assert(not state.raid and state.run_data.is_empty())
	a.free()
	DirAccess.remove_absolute(Model.SAVE)
	print("PASS: ammo/fallback/refill, katana combo/projectile, hammer charge/anti-spam/spin, bat knockback/ball, shield double hit/mitigation/knock resist/invulnerability/launch, persistence, equipped-vs-bag death")
	await create_timer(0.15).timeout
	quit()
