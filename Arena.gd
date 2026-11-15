extends Control
## Real-time survivor arena. All gameplay motion uses world coordinates.
signal finished
signal return_to_base
const RunUpgrades = preload("res://RunUpgrades.gd")
const ShipMap = preload("res://ShipMap.gd")
const TouchScroll = preload("res://TouchScroll.gd")
const TouchButton = preload("res://TouchButton.gd")
const Weapons = preload("res://Weapons.gd")
const FONT = preload("res://assets/Korean.ttf")
const GREEN = Color("bedf90")
const WORLD = Vector2(1900, 1900)
const SKILLS = {
	"area": ["광역 증폭", "근접·충격파 범위 +18%", "AREA"],
	"power": ["고압 탄두", "탄환 피해 +8", "FIREPOWER"],
	"haste": ["급속 노리쇠", "사격 간격 15% 단축", "FIRE RATE"],
	"pierce": ["관통 탄심", "탄환이 적을 1명 더 관통", "PENETRATION"],
	"spread": ["분산 사격", "동시 발사 탄환 +1", "MULTISHOT"],
	"field": ["펄스 방벽", "주변 적에게 주기적 피해", "ELECTRIC FIELD"],
	"drone": ["호위 드론", "회전 드론 추가 · 접촉 피해", "ORBITAL DRONE"],
	"speed": ["경량 장구", "이동 속도 +12%", "MOBILITY"],
	"magnet": ["회수 장치", "자원 수집 반경 +40", "RECOVERY"],
}
const CHAPTER_TARGETS = [60,100]
const WAVE_MARKS = [[0,15,35],[0,25,60]]
const WAVE_SIZES = [[18,24,28],[28,40,48]]
var wave_started: Array = [0,0]
var wave_remaining: int = 0
var wave_clock: float = 0.0
var multikill: int = 0
var multikill_clock: float = 0.0
var evolution_flash: float = 0.0
const BOSS_NAMES = ["갑판장 · 검은 닻","경호대장 · 아이언 가드","선장 · 어비스"]
var chapter_kills: Array = [0,0]
var boss_started: bool = false
var boss_defeated: bool = false
var state
var ship
var caches: Array = []
var visited_zones: Array = []
var searching: int = -1
var search_progress: float = 0.0
var search_button: Button
var chart_button: Button
var zone_title: Label
var ammo: int = 48
var active_slot: String = "gun"
var bag: Array = []
var melee_clock: float = 0.0
var combo: int = 0
var combo_reset: float = 0.0
var second_hit: float = 0.0
var special_clock: float = 0.0
var special_time: float = 0.0
var special_tick: float = 0.0
var special_kind: String = ""
var special_direction: Vector2 = Vector2.UP
var charge_time: float = 0.0
var charging: bool = false
var charge_touch: int = -1
var swing_time: float = 0.0
var knock_velocity: Vector2 = Vector2.ZERO
var crates: Array = []
var extraction_requested: bool = false
var map_id: int = 0
var swap_button: Button
var special_button: Button
var charge_button: Button
var bag_button: Button
var extraction_button: Button
var weapon_label: Label
var player = Vector2(950, 1720)
var enemies: Array = []
var bullets: Array = []
var drops: Array = []
var effects: Array = []
var skills: Dictionary = {}
var offered: Array = []
var elapsed := 0.0
var hp := 100.0
var max_hp := 100.0
var xp := 0
var level := 1
var kills := 0
var cargo := 0
var parts := 0
var meds := 2
var boosted := false
var shot_clock := 0.0
var spawn_clock := 0.4
var pulse_clock := 0.0
var drone_clock := 0.0
var hit_clock := 0.0
var save_clock := 0.0
var extract_progress := 0.0
var elite_wave := 0
var next_id := 0
var facing := Vector2.UP
var rng = RandomNumberGenerator.new()
var paused := false
var ended := false
var aim_input := Vector2.ZERO
var touch_id := -1
var dragging := false
var stick_origin := Vector2.ZERO
var stick_tip := Vector2.ZERO
var overlay: Control
var health_label: Label
var time_label: Label
var loot_label: Label
var objective: Label
var health_bar: ProgressBar
var xp_bar: ProgressBar
var heal_button: Button
var pause_button: Button
var banner := "드래그로 이동 · 가까운 적을 자동 조준"
var banner_time := 6.0
var sounds: Dictionary = {}
var audio_players: Array = []
var audio_cursor := 0

func _ready():
	rng.randomize()
	map_id = state.selected_map
	ship = ShipMap.new(map_id)
	player = ship.spawn
	for pos in ship.ammo_points: crates.append({"p":pos,"used":false})
	for site in ship.cache_points: caches.append({"p":site.p,"name":site.name,"used":false})
	mouse_filter = Control.MOUSE_FILTER_STOP
	max_hp = 100.0 + state.upgrade * 15
	hp = max_hp
	meds = int(state.run_data.get("initial_meds", 2))
	boosted = state.run_data.get("boosted", false)
	if state.run_data.has("player"):
		restore(state.run_data)
		ship = ShipMap.new(map_id)
		if boss_started:
			chapter_kills=CHAPTER_TARGETS.duplicate()
			wave_started=[3,3]
		if not ship.walkable(player,17): player = ship.grid.get_point_position(ship.cell_at(player))
	build_hud()
	build_audio()
	if not offered.is_empty(): show_choices()
	update_hud()
	checkpoint()

func skill(key: String) -> int:
	return int(skills.get(key, 0))

func xp_needed() -> int:
	return 6 + (level - 1) * 3

func camera_center() -> Vector2:
	return Vector2(size.x * 0.5, size.y * 0.50)

func screen(world_pos: Vector2) -> Vector2:
	return world_pos - player + camera_center()

func clear_input():
	dragging = false
	touch_id = -1
	aim_input = Vector2.ZERO
	charging = false
	charge_time = 0
	charge_touch = -1

func _gui_input(event):
	if paused or ended: return
	if event is InputEventScreenTouch:
		if event.pressed and touch_id == -1:
			touch_id = event.index
			dragging = true
			stick_origin = event.position
			stick_tip = event.position
		elif event.index == touch_id and not event.pressed: clear_input()
	elif event is InputEventScreenDrag and event.index == touch_id:
		stick_tip = event.position
		aim_input = (stick_tip - stick_origin).limit_length(52) / 52
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if touch_id != -1: return
		if event.pressed:
			dragging = true
			stick_origin = event.position
			stick_tip = event.position
		else: clear_input()
	elif event is InputEventMouseMotion and dragging and touch_id == -1:
		stick_tip = event.position
		aim_input = (stick_tip - stick_origin).limit_length(52) / 52

func _unhandled_key_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if offered.is_empty(): toggle_pause()
		elif event.keycode == KEY_SPACE and not paused: use_special()
		elif event.keycode == KEY_Q: switch_weapon()
		elif event.keycode == KEY_E: heal()
		elif event.keycode == KEY_I: show_bag()
		elif event.keycode == KEY_F: begin_charge()
	if event is InputEventKey and not event.pressed and event.keycode == KEY_F: release_charge()

func _notification(what):
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		clear_input()
		if is_node_ready() and not paused and not ended: toggle_pause()
		if is_node_ready(): checkpoint()

func _process(delta):
	if not paused and not ended:
		var keyboard = Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)), float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
		var direction = aim_input if dragging else keyboard.limit_length(1)
		simulate(minf(delta, 0.05), direction)
	update_hud()
	queue_redraw()

func simulate(dt: float, direction: Vector2):
	if paused or ended: return
	elapsed += dt
	evolution_flash=maxf(0,evolution_flash-dt)
	multikill_clock=maxf(0,multikill_clock-dt)
	if multikill_clock<=0: multikill=0
	tick_waves(dt)
	if not visited_zones.has(zone()):
		visited_zones.append(zone())
		banner = ShipMap.DATA[map_id].zones[zone()] + " 진입 / 위험도 " + str(zone()+1)
		banner_time = 4
	banner_time = maxf(0, banner_time - dt)
	hit_clock = maxf(0, hit_clock - dt)
	melee_clock = maxf(0, melee_clock - dt)
	special_clock = maxf(0, special_clock - dt)
	swing_time = maxf(0, swing_time - dt)
	combo_reset = maxf(0, combo_reset - dt)
	if combo_reset <= 0: combo = 0
	if charging and melee_clock <= 0: charge_time = minf(1.6, charge_time + dt)
	var movement = direction.limit_length(1) * movement_speed()
	if special_time > 0 and special_kind == "shield": movement = special_direction * 380
	player = move_with_walls(player, (movement + knock_velocity) * dt, 17)
	knock_velocity = knock_velocity.move_toward(Vector2.ZERO, 800 * dt)
	player = player.clamp(Vector2(30, 30), WORLD - Vector2(30, 30))
	if direction.length_squared() > 0.01: facing = direction.normalized()
	if zone()==2 and chapter_kills[0]>=CHAPTER_TARGETS[0] and chapter_kills[1]>=CHAPTER_TARGETS[1] and not boss_started:
		spawn_chapter_boss()
	spawn_clock -= dt
	if spawn_clock <= 0 and not boss_defeated:
		spawn_clock = 1.6 if zone()<2 else 0.9
		if enemies.size() < 120:
			spawn_enemy()
			if zone() >= 2 and not boss_started: spawn_enemy()
	if elapsed >= 90 * (elite_wave + 1) and not boss_defeated:
		elite_wave += 1
		spawn_enemy(true)
		banner = "중장갑 감염체 출현 · 처치 시 희귀 부품"
		banner_time = 4
	shot_clock -= dt
	if active_slot == "gun" and ammo <= 0:
		active_slot = "secondary"
		banner = "탄약 소진 · 보조무기로 전환 / 보급 상자 탐색"
		banner_time = 4
	if active_slot == "gun" and shot_clock <= 0 and not enemies.is_empty():
		fire()
		shot_clock = maxf(0.12, 0.42 * pow(0.85, skill("haste")))
	if active_slot == "secondary" and melee_clock <= 0 and not charging and special_time <= 0:
		melee_attack()
	if second_hit > 0:
		second_hit -= dt
		if second_hit <= 0 and active_slot == "secondary":
			strike(22,68,35,0.3)
			if evolved("shield"): strike(22,90,35,-1,true)
			if mastery("shield")>=2: area_damage(player,melee_reach(80),28+mastery("shield")*10,"pulse")
	update_special(dt)
	for enemy in enemies:
		var toward = player - enemy.p
		enemy.air = maxf(0, float(enemy.get("air",0)) - dt)
		if enemy.air > 0: continue
		if enemy.get("boss",false):
			update_chapter_boss(enemy,dt)
			if ended: return
			if float(enemy.get("windup",0))>0: continue
		var target = path_target(enemy.p, player)
		enemy.p = move_with_walls(enemy.p, (target-enemy.p).normalized() * enemy.speed * dt, enemy.radius)
		# Keep dense crowds from occupying precisely the same position.
		enemy.p = move_with_walls(enemy.p, Vector2(-toward.y, toward.x).normalized() * sin(float(enemy.id) * 2.3 + elapsed) * 13 * dt, enemy.radius)
		if (player-enemy.p).length() < enemy.radius + 13 and hit_clock <= 0:
			if special_time > 0 and special_kind == "shield": continue
			var shielded = active_slot == "secondary" and secondary_kind() == "shield"
			hp -= (19 if enemy.elite else 9) * (0.75 if shielded else 1.0)
			knock_velocity = (player-enemy.p).normalized() * 150 * (0.70 if shielded else 1.0)
			play_sound("hurt")
			hit_clock = 0.65
			extract_progress = 0
			search_progress = 0
			effects.append({"p":player,"t":0.25,"max":0.25,"kind":"hurt"})
			if hp <= 0:
				finish_run(false)
				return
	update_bullets(dt)
	pulse_clock -= dt
	if skill("field") > 0 and pulse_clock <= 0:
		pulse_clock = 0.8
		var radius = 60 + skill("field") * 12
		effects.append({"p":player,"t":0.35,"max":0.35,"kind":"pulse","radius":radius})
		for enemy in enemies:
			if player.distance_to(enemy.p) <= radius + enemy.radius and clear_shot(player,enemy.p): enemy.hp -= 11 + skill("field") * 8
	drone_clock -= dt
	if skill("drone") > 0 and drone_clock <= 0:
		drone_clock = 0.23
		for i in range(skill("drone")):
			var drone_pos = player + Vector2.from_angle(elapsed * 2.6 + TAU * i / skill("drone")) * 83
			for enemy in enemies:
				if drone_pos.distance_to(enemy.p) < enemy.radius + 17 and clear_shot(drone_pos,enemy.p): enemy.hp -= 25
	resolve_kills()
	collect_drops(dt)
	while effects.size()>180: effects.pop_front()
	for i in range(effects.size() - 1, -1, -1):
		effects[i].t -= dt
		if effects[i].t <= 0: effects.remove_at(i)
	for crate in crates:
		if not crate.used and player.distance_to(crate.p) < 45 and clear_shot(player,crate.p):
			crate.used = true
			ammo += 24
			banner = "탄약 상자 +24 / 총 전환은 직접 선택"
			banner_time = 3
			checkpoint()
	if searching >= 0:
		if searching >= caches.size() or caches[searching].used or player.distance_to(caches[searching].p)>65 or not clear_shot(player,caches[searching].p):
			searching = -1
			search_progress = 0
		else:
			search_progress += dt
			if search_progress >= 1.6: finish_search()
	if extraction_requested and at_checkpoint() and special_time <= 0:
		extract_progress += dt
		if extract_progress >= 3:
			finish_run(true)
			return
	else:
		extract_progress = 0
		extraction_requested = false
	if xp >= xp_needed() and offered.is_empty():
		roll_choices()
		show_choices()
	save_clock += dt
	if save_clock >= 5:
		save_clock = 0
		checkpoint()

func spawn_enemy(elite: bool = false):
	if enemies.size() >= 120: return
	var candidates=[]
	for cell in ship.free_cells:
		var candidate=ship.grid.get_point_position(cell)
		var distance=candidate.distance_to(player)
		if distance>350 and distance<780: candidates.append(candidate)
	if candidates.is_empty(): return
	var p=candidates[rng.randi_range(0,candidates.size()-1)]
	var runner = not elite and rng.randf() < 0.20
	var health = (32 + zone() * 22 + elapsed * 0.04) * (8 if elite else 0.7 if runner else 1.0)
	enemies.append({"p":p,"hp":health,"max_hp":health,"speed":45.0 if elite else 110.0 if runner else 62.0 + minf(28, elapsed * 0.1),"radius":24.0 if elite else 11.0 if runner else 15.0,"elite":elite,"runner":runner,"id":next_id,"air":0.0})
	next_id += 1

func fire():
	if ammo <= 0 or enemies.is_empty() or bullets.size()>=260: return
	var target = nearest_enemy(560)
	if target.is_empty(): return
	ammo -= 1
	play_sound("shot")
	facing = (target.p - player).normalized()
	var count = 1 + skill("spread") + mastery("rifle") + (2 if evolved("rifle") else 0)
	for i in range(count):
		var direction = facing.rotated((i - (count - 1) / 2.0) * 0.14)
		bullets.append({"p":player + direction * 20,"v":direction * 600,"ttl":0.95,"damage":(64 + 8 * skill("power")) * (1+mastery("rifle")*0.15) * Weapons.scale(state.equipped.gun) * (1.2 if boosted else 1.0),"hits":[],"remaining":1 + skill("pierce") + (1 if mastery("rifle")>=2 else 0),"ricochet":2 if evolved("rifle") else 1 if mastery("rifle")>=3 else 0,"blast":90.0 if evolved("rifle") else 58.0 if mastery("rifle")>=4 else 0.0})
	effects.append({"p":player + facing * 24,"t":0.08,"max":0.08,"kind":"muzzle"})

func update_bullets(dt: float):
	for i in range(bullets.size() - 1, -1, -1):
		var b = bullets[i]
		var old: Vector2 = b.p
		b.p += b.v * dt
		b.ttl -= dt
		if not clear_shot(old, b.p):
			bullets.remove_at(i)
			continue
		for enemy in enemies:
			if enemy.hp <= 0 or b.hits.has(enemy.id): continue
			var nearest = Geometry2D.get_closest_point_to_segment(enemy.p, old, b.p)
			if nearest.distance_to(enemy.p) < enemy.radius + 3:
				enemy.hp -= b.damage
				b.hits.append(enemy.id)
				b.remaining -= 1
				if float(b.get("blast",0))>0: area_damage(enemy.p,float(b.blast),b.damage*0.45,"blast")
				if int(b.get("ricochet",0))>0:
					var target=chain_target(enemy.p,b.hits)
					if not target.is_empty():
						b.p=enemy.p
						b.v=(target.p-enemy.p).normalized()*b.v.length()
						b.ricochet-=1
						b.remaining=maxi(1,int(b.remaining))
						b.ttl=maxf(b.ttl,0.5)
						break
				effects.append({"p":enemy.p,"t":0.16,"max":0.16,"kind":"hit"})
				if b.remaining <= 0: break
		if b.ttl <= 0 or b.remaining <= 0: bullets.remove_at(i)

func resolve_kills():
	for i in range(enemies.size() - 1, -1, -1):
		var enemy = enemies[i]
		if enemy.hp > 0: continue
		kills += 1
		multikill+=1
		multikill_clock=1.8
		var progress_zone=zone()
		if enemy.get("boss",false):
			boss_defeated=true
			banner="최종 보스 격파! 마지막 철수 지점에서 챕터를 완료하십시오."
			banner_time=6
		elif progress_zone<2 and (progress_zone==0 or chapter_kills[0]>=CHAPTER_TARGETS[0]):
			chapter_kills[progress_zone]=mini(CHAPTER_TARGETS[progress_zone],int(chapter_kills[progress_zone])+1)
		var rare = enemy.elite or kills % 18 == 0
		drops.append({"p":enemy.p,"xp":12 if enemy.elite else 2,"cash":(100 if enemy.elite else 12) * (zone()+1),"parts":2 if enemy.elite else 1 if rare else 0,"ammo":12 if kills%5==0 else 6 if rng.randf()<0.25 else 0,"gear":[]})
		if enemy.get("boss",false):
			drops[-1].cash += 500
			drops[-1].parts += 3
			drops[-1].ammo += 24
		if rng.randf() < (0.08 if enemy.elite else [0.01,0.02,0.035][zone()]):
			var kinds = Weapons.TYPES.keys()
			var grade_roll = rng.randf()
			var grade = 0 if grade_roll < (0.85 - zone()*0.2) else 1 if grade_roll < 0.96-zone()*0.06 else 2 if grade_roll < 0.998-zone()*0.004 else 3
			drops[-1].gear.append(state.new_item(kinds[rng.randi_range(0,kinds.size()-1)],grade))
		effects.append({"p":enemy.p,"t":0.45,"max":0.45,"kind":"kill"})
		enemies.remove_at(i)
	# Bound idle-session drop cost while preserving all rewards.
	while drops.size() > 200:
		var last = drops.pop_back()
		drops[0].xp += last.xp
		drops[0].cash += last.cash
		drops[0].parts += last.parts
		drops[0]["ammo"] = drops[0].get("ammo",0) + last.get("ammo",0)
		drops[0]["gear"] = drops[0].get("gear",[]) + last.get("gear",[])

func collect_drops(dt: float):
	for i in range(drops.size() - 1, -1, -1):
		var drop = drops[i]
		var distance = player.distance_to(drop.p)
		if distance < 110 + skill("magnet") * 40 and clear_shot(player,drop.p):
			drop.p = drop.p.move_toward(player, 310 * dt)
		if player.distance_to(drop.p) < 18:
			play_sound("pickup")
			xp += int(drop.xp)
			cargo += int(drop.cash)
			parts += int(drop.parts)
			ammo += int(drop.get("ammo",0))
			for item in drop.get("gear",[]):
				bag.append(item)
				banner = "장비 발견: " + Weapons.title(item)
				banner_time = 4
			drops.remove_at(i)

func roll_choices():
	var pool=[]
	for key in SKILLS:
		if skill(key)<5: pool.append(key)
	offered=[]
	var kinds=["rifle",secondary_kind()]
	# A weapon or its prerequisite is always available: no dead-end evolution luck.
	for kind in kinds:
		if RunUpgrades.ready(skills,kind): offered.append("evolve_"+kind)
		elif mastery(kind)<4: offered.append("weapon_"+kind)
		elif not evolved(kind) and not offered.has(RunUpgrades.support(kind)):
			offered.append(RunUpgrades.support(kind))
	for key in offered: pool.erase(key)
	while offered.size()<3 and not pool.is_empty():
		var index=rng.randi_range(0,pool.size()-1)
		offered.append(pool[index])
		pool.remove_at(index)
	if offered.is_empty():
		xp-=xp_needed()
		level+=1
		hp=minf(max_hp,hp+20)

func upgrade_description(key: String) -> Array:
	return SKILLS[key] if SKILLS.has(key) else RunUpgrades.description(key,skills)

func choose_skill(key: String):
	if not offered.has(key) or ended: return
	if key.begins_with("evolve_") and not RunUpgrades.ready(skills,key.trim_prefix("evolve_")): return
	var desc=upgrade_description(key)
	xp-=xp_needed()
	level+=1
	play_sound("upgrade")
	skills[key]=skill(key)+1
	offered=[]
	ammo+=8
	hp=minf(max_hp,hp+8)
	banner="%s · LV.%d / 탄약 +8" % [desc[0],skill(key)]
	if key.begins_with("evolve_"):
		evolution_flash=1.2
		banner="진화 완료 · "+desc[0]
		effects.append({"p":player,"t":0.8,"max":0.8,"kind":"pulse","radius":180})
	banner_time=4
	close_overlay()
	checkpoint()

func heal():
	if paused or ended or meds <= 0 or hp >= max_hp: return
	meds -= 1
	hp = minf(max_hp, hp + 40)
	effects.append({"p":player,"t":0.5,"max":0.5,"kind":"heal"})
	checkpoint()

func finish_run(success: bool):
	if ended: return
	ended = true
	clear_input()
	state.complete(success, cargo, parts, kills, bag, success and boss_defeated and at_final_checkpoint())
	finished.emit()

func snapshot() -> Dictionary:
	var data = {}
	for key in ["player","enemies","bullets","drops","skills","offered","elapsed","hp","max_hp","xp","level","kills","cargo","parts","meds","boosted","shot_clock","spawn_clock","pulse_clock","drone_clock","hit_clock","extract_progress","elite_wave","next_id","facing","ammo","active_slot","bag","melee_clock","combo","combo_reset","second_hit","special_clock","special_time","special_tick","special_kind","special_direction","swing_time","knock_velocity","crates","extraction_requested","map_id","caches","visited_zones","searching","search_progress","chapter_kills","boss_started","boss_defeated","wave_started","wave_remaining","wave_clock"]:
		data[key] = get(key)
	data["rng_state"] = str(rng.state)
	return data.duplicate(true)

func restore(data: Dictionary):
	for key in ["player","enemies","bullets","drops","skills","offered","elapsed","hp","max_hp","xp","level","kills","cargo","parts","meds","boosted","shot_clock","spawn_clock","pulse_clock","drone_clock","hit_clock","extract_progress","elite_wave","next_id","facing","ammo","active_slot","bag","melee_clock","combo","combo_reset","second_hit","special_clock","special_time","special_tick","special_kind","special_direction","swing_time","knock_velocity","crates","extraction_requested","map_id","caches","visited_zones","searching","search_progress","chapter_kills","boss_started","boss_defeated","wave_started","wave_remaining","wave_clock"]:
		if data.has(key): set(key, data[key])
	if data.has("rng_state"): rng.state = int(data.rng_state)

func checkpoint():
	if not state or ended or not state.raid: return
	state.run_data = snapshot()
	state.save_game()

func make_label(parent: Node, text: String, px: int, color: Color = Color("e2e8df")) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", px)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func box(color: Color) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(5)
	s.set_content_margin_all(0)
	return s

func make_button(parent: Node, text: String, callback: Callable) -> Button:
	var b = TouchButton.new()
	b.text = text
	b.custom_minimum_size.y = 52
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_stylebox_override("normal", box(Color("263b3b")))
	b.add_theme_stylebox_override("hover", box(Color("36554c")))
	b.add_theme_stylebox_override("pressed", box(Color("60805b")))
	b.add_theme_stylebox_override("disabled", box(Color("1c282b")))
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func build_hud():
	var top = Panel.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 150
	top.add_theme_stylebox_override("panel", box(Color(0.035, 0.065, 0.075, 0.95)))
	add_child(top)
	var brand = make_label(top, "철수선 / " + ShipMap.DATA[map_id].english, 14, GREEN)
	brand.position = Vector2(20, 15)
	chart_button = make_button(top,"해도",show_chart)
	chart_button.position=Vector2(335,17)
	chart_button.size=Vector2(62,52)
	time_label = make_label(top, "00:00", 24)
	time_label.position = Vector2(20, 38)
	health_label = make_label(top, "", 13)
	health_label.position = Vector2(128, 49)
	pause_button = make_button(top, "Ⅱ", toggle_pause)
	pause_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	pause_button.offset_left = -70
	pause_button.offset_right = -20
	pause_button.offset_top = 17
	pause_button.offset_bottom = 69
	health_bar = ProgressBar.new()
	health_bar.show_percentage = false
	health_bar.position = Vector2(20, 79)
	health_bar.size = Vector2(size.x - 40, 7)
	health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_bar.add_theme_stylebox_override("fill", box(GREEN))
	health_bar.add_theme_stylebox_override("background", box(Color("263a3c")))
	top.add_child(health_bar)
	xp_bar = ProgressBar.new()
	xp_bar.show_percentage = false
	xp_bar.position = Vector2(20, 90)
	xp_bar.size = Vector2(size.x - 40, 4)
	xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_bar.add_theme_stylebox_override("fill", box(Color("72b8ce")))
	xp_bar.add_theme_stylebox_override("background", box(Color("263a3c")))
	top.add_child(xp_bar)
	loot_label = make_label(top, "", 12, Color("d1ba8b"))
	loot_label.position = Vector2(20, 105)
	objective = make_label(top, "", 12, GREEN)
	objective.position = Vector2(20, 126)
	heal_button = combat_button("회복", heal, Vector2(-126,-76), Vector2(106,50))
	swap_button = combat_button("전환", switch_weapon, Vector2(-248,-76), Vector2(112,50))
	special_button = combat_button("특수", use_special, Vector2(-140,-142), Vector2(120,56))
	charge_button = combat_button("차지", func(): pass, Vector2(-248,-142), Vector2(98,56))
	charge_button.button_down.connect(begin_charge)
	charge_button.button_up.connect(release_charge)
	bag_button = make_button(top,"가방",show_bag)
	bag_button.position = Vector2(335,105)
	bag_button.size = Vector2(125,38)
	bag_button.custom_minimum_size.y = 38
	weapon_label = make_label(self,"",13,GREEN)
	weapon_label.position = Vector2(20,151)
	search_button = combat_button("수색",request_search,Vector2(-200,-211),Vector2(180,52))
	extraction_button = combat_button("철수 요청",request_extraction,Vector2(-200,-211),Vector2(180,52))

func combat_button(text: String, callback: Callable, offset: Vector2, dimensions: Vector2) -> Button:
	var result = make_button(self,text,callback)
	result.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	result.offset_left = offset.x
	result.offset_top = offset.y
	result.offset_right = offset.x + dimensions.x
	result.offset_bottom = offset.y + dimensions.y
	return result

func update_hud():
	if not is_instance_valid(time_label): return
	time_label.text = "%02d:%02d" % [int(elapsed) / 60, int(elapsed) % 60]
	health_label.text = "HP %d / %d   ·   LV.%d" % [maxi(0, int(hp)), int(max_hp), level]
	health_bar.max_value = max_hp
	health_bar.value = hp
	xp_bar.max_value = xp_needed()
	xp_bar.value = xp
	loot_label.text = "%d 처치 · 가방 %d CR · 부품 %d" % [kills,cargo,parts]
	objective.text = "CH.%02d · " % (map_id+1) + chapter_objective()
	heal_button.text = "회복 [%d]" % meds
	heal_button.disabled = paused or ended or meds <= 0 or hp >= max_hp
	var kind = secondary_kind()
	weapon_label.text = "%s  /  탄약 %d  /  %s" % [run_weapon_title(state.equipped[active_slot].kind),ammo,"이번 판 강화"]
	swap_button.text = "보조무기 Q" if active_slot == "gun" else "총 [%d] Q" % ammo
	swap_button.disabled = paused or ended or special_time > 0
	special_button.text = (Weapons.TYPES[kind].special + " %.1f" % special_clock) if special_clock > 0 else Weapons.TYPES[kind].special
	special_button.disabled = paused or ended or active_slot != "secondary" or special_clock > 0
	charge_button.visible = active_slot == "secondary" and kind == "hammer"
	charge_button.text = "차지 %d%%" % int(charge_time/1.6*100) if charging else "차지 (홀드)"
	charge_button.disabled = paused or ended or special_time > 0
	extraction_button.visible = at_checkpoint() and not paused
	extraction_button.text = "철수 %.1f / 3 · 취소" % extract_progress if extraction_requested else "최종 철수 · 클리어" if boss_defeated and at_final_checkpoint() else "중간 철수 · 해금 없음"
	bag_button.disabled = paused or ended or special_time > 0
	chart_button.disabled = paused or ended
	search_button.visible = nearby_cache()>=0 and not at_checkpoint() and not paused
	search_button.text = "수색 %.1f / 1.6" % search_progress if searching>=0 else "보관함 수색"

func open_overlay() -> VBoxContainer:
	clear_input()
	paused = true
	charging = false
	charge_time = 0
	searching = -1
	search_progress = 0
	if is_instance_valid(overlay):
		remove_child(overlay)
		overlay.queue_free()
	overlay = ColorRect.new()
	overlay.color = Color(0.02, 0.04, 0.05, 0.96)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var column = VBoxContainer.new()
	column.custom_minimum_size.x = minf(400, size.x - 40)
	column.add_theme_constant_override("separation", 17)
	center.add_child(column)
	return column

func close_overlay():
	if is_instance_valid(overlay):
		remove_child(overlay)
		overlay.queue_free()
	overlay = null
	paused = false
	clear_input()

func show_choices():
	if offered.is_empty(): return
	var column = open_overlay()
	make_label(column, "FIELD UPGRADE  /  LV.%d" % (level + 1), 13, GREEN)
	make_label(column, "이번 판의 화력을 선택하라", 23)
	make_label(column, "선택하는 동안 전투가 멈춥니다.", 13, Color("8fa9a7"))
	for key in offered:
		var desc = upgrade_description(key)
		var tag="진화" if key.begins_with("evolve_") else "LV.%d" % (skill(key)+1)
		var b = make_button(column, "%s   %s\n%s" % [desc[0],tag,desc[1]],func(): choose_skill(key))
		if key.begins_with("evolve_"): b.add_theme_stylebox_override("normal",box(Color("756035")))
		b.custom_minimum_size.y = 98
	make_label(column, "무기 강화 IV + 증폭 II → 진화\n소총: 분산 사격 / 보조무기: 광역 증폭\n매 선택 탄약 +8 · 회복 +8 / 이번 판에만 적용", 12, Color("8fa9a7"))
	checkpoint()

func toggle_pause():
	if ended or not offered.is_empty(): return
	if paused:
		close_overlay()
		return
	var column = open_overlay()
	make_label(column, "통신 대기", 30, GREEN)
	make_label(column, "작전이 일시 정지되었습니다.\n진행 상황은 자동 저장됩니다.", 15)
	make_button(column, "작전 계속", toggle_pause)
	make_button(column, "작전 포기…", show_abandon)
	checkpoint()

func show_abandon():
	var column = open_overlay()
	make_label(column, "작전을 포기합니까?", 24)
	make_label(column, "가방 속 물건을 전부 잃습니다.\n현재 장착 장비와 기지 자산은 유지됩니다.", 15)
	make_button(column, "계속 생존하기", close_overlay)
	make_button(column, "포기하고 기지로", func(): finish_run(false))

func _draw():
	var bounds = Rect2(Vector2.ZERO, size)
	ShipMap.draw_ocean(self,size,player,elapsed)
	var offset = camera_center() - player
	ship.draw_deck(self,offset,1.0,elapsed)
	for site in caches:
		var p=screen(site.p)
		var color=Color("76644a") if site.used else Color("d9b871")
		draw_rect(Rect2(p-Vector2(22,15)+Vector2(3,5),Vector2(44,30)),Color(0,0,0,0.3))
		draw_rect(Rect2(p-Vector2(22,15),Vector2(44,30)),Color("3b4646"))
		draw_rect(Rect2(p-Vector2(22,15),Vector2(44,30)),color,false,2)
		draw_line(p-Vector2(22,2),p+Vector2(22,-2),color,2)
		draw_rect(Rect2(p-Vector2(4,4),Vector2(8,10)),color)
		if not site.used: draw_string(FONT,p+Vector2(-24,-24),"SALVAGE",HORIZONTAL_ALIGNMENT_LEFT,-1,10,color)
		if searching>=0 and caches[searching].p==site.p:
			draw_arc(p,35,-PI/2,-PI/2+TAU*search_progress/1.6,32,GREEN,3,true)
	for point in exits():
		var p = screen(point)
		draw_circle(p,60,Color(0.65,0.85,0.6,0.07))
		draw_arc(p,60,0,TAU,48,GREEN,2,true)
		draw_string(FONT,p+Vector2(-42,-70),("FINAL / 최종" if point==ship.exit_points[-1] else "EVAC / 철수"),HORIZONTAL_ALIGNMENT_LEFT,-1,12,GREEN)
		draw_line(p-Vector2(20,0),p+Vector2(20,0),GREEN,3)
		draw_line(p-Vector2(0,20),p+Vector2(0,20),GREEN,3)
		if player.distance_to(point)<60 and extraction_requested:
			draw_arc(p,66,-PI/2,-PI/2+TAU*extract_progress/3,48,GREEN,5,true)
	for crate in crates:
		if crate.used: continue
		var p = screen(crate.p)
		draw_rect(Rect2(p-Vector2(16,12),Vector2(32,24)),Color("817448"))
		draw_rect(Rect2(p-Vector2(16,12),Vector2(32,24)),Color("e5ca7d"),false,2)
		for j in range(3): draw_line(p+Vector2(-8+j*8,-7),p+Vector2(-8+j*8,7),Color("efe0ad"),3)
		draw_string(FONT,p+Vector2(-24,-21),"AMMO",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("e5ca7d"))
	for drop in drops:
		var p = screen(drop.p)
		if not bounds.grow(10).has_point(p): continue
		var c = Color("b9a1ec") if not drop.get("gear",[]).is_empty() else Color("e4ba73") if drop.get("ammo",0) > 0 or drop.parts > 0 else Color("7ccbd0")
		draw_circle(p, 10, Color(c, 0.12))
		draw_colored_polygon(PackedVector2Array([p + Vector2(0,-5), p + Vector2(4,0), p + Vector2(0,5), p + Vector2(-4,0)]), c)
	for enemy in enemies:
		var p = screen(enemy.p)
		p.y -= sin(float(enemy.get("air",0))*PI)*35
		if not bounds.grow(40).has_point(p): continue
		var r: float = enemy.radius
		var c = Color("b37c5c") if enemy.elite else Color("987c72") if enemy.runner else Color("77817a")
		var direction = (player - enemy.p).normalized()
		var side = direction.orthogonal()
		draw_circle(p + Vector2(3, 6), r + 2, Color(0,0,0,0.3))
		draw_line(p - side * r * 0.8, p + direction * r * 0.9 - side * (r + 2), c.darkened(0.25), 5)
		draw_line(p + side * r * 0.8, p + direction * r * 0.9 + side * (r + 2), c.darkened(0.25), 5)
		draw_circle(p, r * 0.8, c.darkened(0.25))
		draw_circle(p + direction * r * 0.35, r * 0.5, c)
		draw_line(p + direction * r * 0.75 - side * 4, p + direction * r * 0.75 + side * 4, Color("dfaa83"), 2)
		if enemy.elite:
			draw_arc(p, r + 4, 0, TAU, 16, Color("c99b6a"), 2)
		if enemy.hp < enemy.max_hp:
			draw_rect(Rect2(p + Vector2(-r, -r - 9), Vector2(r * 2, 3)), Color("342d2c"))
			draw_rect(Rect2(p + Vector2(-r, -r - 9), Vector2(r * 2 * maxf(0, enemy.hp / enemy.max_hp), 3)), Color("c99b6a"))
	for b in bullets:
		var p = screen(b.p)
		draw_line(p - b.v.normalized() * 15, p, Color("f1da9b"), 3, true)
		if b.get("visual","") == "katana":
			draw_line(p-b.v.normalized().orthogonal()*26,p+b.v.normalized().orthogonal()*26,Color("9ee4ea"),4,true)
		elif b.get("visual","") == "bat":
			draw_circle(p,7,Color("fff1d2"))
			draw_arc(p,5,0,PI,12,Color("b76c55"),1)
		else: draw_circle(p, 2, Color("fff7dd"))
	var center = camera_center()
	if skill("field") > 0:
		draw_arc(center, 60 + skill("field") * 12, 0, TAU, 64, Color(0.5,0.8,0.85,0.22), 1)
	for i in range(skill("drone")):
		var p = center + Vector2.from_angle(elapsed * 2.6 + TAU * i / skill("drone")) * 83
		draw_line(p - Vector2(9,9), p + Vector2(9,9), Color("9bafb1"), 3)
		draw_line(p - Vector2(9,-9), p + Vector2(9,-9), Color("9bafb1"), 3)
		draw_circle(p, 5, Color("7bbcd1"))
	draw_operator(center)
	if active_slot == "secondary" and swing_time > 0:
		var angle = facing.angle()
		draw_arc(center,melee_reach(Weapons.TYPES[secondary_kind()].reach)*0.85,angle-1.2,angle+1.2,24,Color(0.8,0.9,0.95,swing_time/0.24),4,true)
	if charging:
		draw_arc(center,43,-PI/2,-PI/2+TAU*charge_time/1.6,40,Color("e2b96b"),5,true)
	if special_time > 0:
		if special_kind == "hammer":
			draw_arc(center,melee_reach(106),elapsed*14,elapsed*14+4.4,32,Color("d1b884"),7,true)
		elif special_kind == "shield":
			draw_arc(center,38,0,TAU,40,Color("89cce8"),4,true)
	for effect in effects:
		var p = screen(effect.p)
		var alpha: float = effect.t / effect.max
		var color = Color("c6d9ac")
		var radius = 10.0 + (1 - alpha) * 24
		match effect.kind:
			"blast":
				color=Color("ffd587")
				radius=effect.radius*(1-alpha)
			"pulse":
				color = Color("83c6d1")
				radius = effect.radius * (1 - alpha)
			"hurt": color = Color("d78572")
			"muzzle":
				color = Color("fff0ad")
				radius = 6
			"kill": color = Color("8a8c70")
			"heal": color = GREEN
			"hit":
				color = Color("f0d19a")
				radius = 5 + (1 - alpha) * 8
		color.a = alpha
		draw_arc(p, radius, 0, TAU, 24, color, 2, true)
	if evolution_flash>0:
		draw_rect(Rect2(Vector2.ZERO,size),Color(0.95,0.78,0.35,minf(0.22,evolution_flash*0.18)))
	if multikill>=3 and multikill_clock>0:
		draw_string(FONT,Vector2(24,250),"%d KILL CHAIN" % multikill,HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("f2ce82"))
	var closest_exit = ship.exit_points[-1] if boss_defeated else nearest_checkpoint()
	if player.distance_to(closest_exit)>95:
		var toward = (closest_exit-player).normalized()
		var arrow = center+toward*145
		draw_colored_polygon(PackedVector2Array([arrow+toward*12,arrow-toward*7+toward.orthogonal()*7,arrow-toward*7-toward.orthogonal()*7]),GREEN)
		draw_string(FONT,arrow+Vector2(-20,-20),("최종 철수 %dm" if boss_defeated else "철수 %dm") % int(player.distance_to(closest_exit)/10),HORIZONTAL_ALIGNMENT_LEFT,-1,12,GREEN)
	if banner_time > 0 and chapter_boss().is_empty():
		draw_rect(Rect2(20, 177, size.x - 40, 34), Color(0.04,0.09,0.1,0.85))
		draw_string(FONT, Vector2(30, 200), banner, HORIZONTAL_ALIGNMENT_LEFT, size.x - 60, 13, GREEN)
	var boss=chapter_boss()
	if not boss.is_empty():
		var bp=screen(boss.p)
		draw_arc(bp,32,0,TAU,40,Color("e6a078"),3,true)
		if float(boss.get("windup",0))>0:
			var target=screen(boss.attack_target)
			var warning_alpha=0.13+0.12*(1-boss.windup)
			draw_circle(target,110,Color(0.92,0.25,0.15,warning_alpha))
			draw_arc(target,110,0,TAU,64,Color("ed996f"),3,true)
			draw_line(target-Vector2(15,0),target+Vector2(15,0),Color("ed996f"),2)
			draw_line(target-Vector2(0,15),target+Vector2(0,15),Color("ed996f"),2)
		draw_rect(Rect2(20,178,size.x-40,43),Color(0.05,0.025,0.02,0.95))
		draw_string(FONT,Vector2(30,196),"FINAL BOSS / "+BOSS_NAMES[map_id],HORIZONTAL_ALIGNMENT_LEFT,size.x-60,13,Color("edb18a"))
		draw_rect(Rect2(30,205,size.x-60,6),Color("4d3430"))
		draw_rect(Rect2(30,205,(size.x-60)*maxf(0,boss.hp/boss.max_hp),6),Color("e09f72"))
	# Compact radar exposes escape position and approaching swarms.
	var radar = Vector2(size.x - 72, size.y - 280)
	draw_rect(Rect2(radar - Vector2(46,46), Vector2(92,92)), Color(0.02,0.05,0.06,0.82))
	draw_rect(Rect2(radar - Vector2(46,46), Vector2(92,92)), Color("45615d"), false, 1)
	var mini_hull=PackedVector2Array()
	for p in ship.hull: mini_hull.append(radar-Vector2(42,42)+p/WORLD*84)
	draw_colored_polygon(mini_hull,Color("52625e"))
	draw_circle(radar - Vector2(42,42) + player / WORLD * 84, 3, GREEN)
	for point in exits(): draw_circle(radar - Vector2(42,42) + point / WORLD * 84,3,GREEN)
	for wall in walls(): draw_rect(Rect2(radar-Vector2(42,42)+wall.position/WORLD*84,wall.size/WORLD*84),Color("6c7567"))
	for enemy in enemies:
		draw_circle(radar - Vector2(42,42) + enemy.p / WORLD * 84, 1.2, Color("b47d67"))
	if dragging:
		draw_circle(stick_origin, 52, Color(0.5,0.65,0.6,0.10))
		draw_arc(stick_origin, 52, 0, TAU, 48, Color(0.7,0.8,0.7,0.35), 2)
		draw_circle(stick_origin + aim_input * 52, 19, Color(0.7,0.85,0.65,0.4))
	else:
		var p = Vector2(74, size.y - 83)
		draw_arc(p, 35, 0, TAU, 40, Color("435953"), 1)
		draw_circle(p, 12, Color("344a43"))
		draw_string(FONT, Vector2(120, size.y - 60), "드래그 이동", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("7a918a"))


func build_audio():
	# Original synthesized effects; no third-party audio assets.
	var noise = RandomNumberGenerator.new()
	noise.seed = 123
	for kind in ["shot", "hurt", "pickup", "upgrade"]:
		var duration = 0.07 if kind == "shot" else 0.16 if kind == "hurt" else 0.045 if kind == "pickup" else 0.25
		var frequency = 120.0 if kind == "shot" else 75.0 if kind == "hurt" else 880.0 if kind == "pickup" else 520.0
		var count = int(22050 * duration)
		var data = PackedByteArray()
		data.resize(count * 2)
		for i in range(count):
			var t = float(i) / 22050
			var envelope = pow(1.0 - float(i) / count, 2)
			var wave = sin(TAU * frequency * t * (1 + t * 2))
			if kind == "shot" or kind == "hurt": wave = wave * 0.35 + noise.randf_range(-1,1) * 0.65
			data.encode_s16(i * 2, int(wave * envelope * 10000))
		var stream = AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = 22050
		stream.data = data
		sounds[kind] = stream
	for i in range(6):
		var audio = AudioStreamPlayer.new()
		audio.volume_db = -12
		add_child(audio)
		audio_players.append(audio)

func play_sound(kind: String):
	if audio_players.is_empty(): return
	var audio = audio_players[audio_cursor % audio_players.size()]
	audio_cursor += 1
	audio.stream = sounds[kind]
	audio.play()

func secondary_kind() -> String:
	return state.equipped.secondary.kind

func movement_speed() -> float:
	var factor = Weapons.TYPES[secondary_kind()].speed if active_slot == "secondary" else 1.0
	return (175 + 21 * skill("speed")) * factor * (0.45 if charging else 1.0)

func switch_weapon():
	if paused or ended or special_time > 0: return
	if active_slot == "secondary" and ammo <= 0:
		banner = "탄약 없음 · 보급 상자를 찾으십시오"
		banner_time = 3
		return
	active_slot = "secondary" if active_slot == "gun" else "gun"
	charging = false
	charge_time = 0
	second_hit = 0
	combo = 0
	checkpoint()

func nearest_enemy(reach: float) -> Dictionary:
	var chosen: Dictionary = {}
	var best = reach * reach
	for enemy in enemies:
		var distance = player.distance_squared_to(enemy.p)
		if enemy.hp > 0 and distance <= best and clear_shot(player,enemy.p):
			best = distance
			chosen = enemy
	return chosen

func melee_attack():
	var data = Weapons.TYPES[secondary_kind()]
	var target = nearest_enemy(melee_reach(data.reach) + 15)
	if target.is_empty(): return
	facing = (target.p-player).normalized()
	combo = (combo % 3) + 1
	combo_reset = 1.6
	var damage = data.damage
	if secondary_kind() == "katana" and combo == 3: damage *= 1.8
	strike(damage, data.reach, data.knock, 0.05)
	weapon_followup()
	melee_clock = data.interval * pow(0.90,skill("haste")) * (0.65 if evolved(secondary_kind()) else 1.0)
	if secondary_kind() == "shield": second_hit = 0.22

func strike(damage: float, reach: float, knock: float, dot_limit: float, radial: bool = false, launch: bool = false):
	swing_time = 0.24
	play_sound("hurt")
	reach=melee_reach(reach)
	knock*=1+mastery(secondary_kind())*0.15
	for enemy in enemies:
		var diff = enemy.p-player
		if diff.length() > reach + enemy.radius or not clear_shot(player,enemy.p): continue
		if not radial and diff.normalized().dot(facing) < dot_limit: continue
		enemy.hp -= (damage + skill("power") * 3) * (1+mastery(secondary_kind())*0.2) * Weapons.scale(state.equipped.secondary)
		enemy.p = move_with_walls(enemy.p, diff.normalized() * knock, enemy.radius)
		if launch: enemy.air = 1.0
		if secondary_kind()=="bat" and mastery("bat")>=2:
			for other in enemies:
				if other.id!=enemy.id and other.hp>0 and enemy.p.distance_to(other.p)<enemy.radius+other.radius+22 and clear_shot(enemy.p,other.p):
					other.hp-=damage*(0.6 if not evolved("bat") else 1.2)
					effects.append({"p":other.p,"t":0.2,"max":0.2,"kind":"hit"})
		effects.append({"p":enemy.p,"t":0.22,"max":0.22,"kind":"hit"})

func use_special():
	if paused or ended or active_slot != "secondary" or special_clock > 0 or special_time > 0: return
	charging = false
	charge_time = 0
	var kind = secondary_kind()
	var target = nearest_enemy(560)
	if not target.is_empty(): facing = (target.p-player).normalized()
	special_direction = facing
	special_kind = kind
	special_clock = Weapons.TYPES[kind].cooldown * (0.65 if evolved(kind) else 0.85 if mastery(kind)>=3 else 1.0)
	match kind:
		"katana", "bat":
			var count=5 if evolved(kind) else 3 if mastery(kind)>=4 else 1
			for i in range(count):
				emit_weapon_projectile(kind,facing.rotated((i-(count-1)/2.0)*0.20),1.0)
			play_sound("shot")
		"hammer":
			special_time = 2.6
			special_tick = 0
		"shield":
			special_time = 2.0
			special_tick = 0
	banner = Weapons.TYPES[kind].special + "!"
	banner_time = 2
	checkpoint()

func update_special(dt: float):
	if special_time <= 0: return
	special_time = maxf(0, special_time-dt)
	special_tick -= dt
	if special_tick > 0: return
	special_tick = 0.24
	if special_kind == "hammer":
		strike(32,112,12,-1,true)
	elif special_kind == "shield":
		facing = special_direction
		strike(38,67,55,-0.2,false,true)

func begin_charge():
	if paused or ended or active_slot != "secondary" or secondary_kind() != "hammer" or special_time > 0: return
	charging = true
	charge_time = 0

func release_charge():
	if not charging: return
	charging = false
	if paused or ended or melee_clock > 0:
		charge_time = 0
		return
	var target = nearest_enemy(140)
	if not target.is_empty(): facing = (target.p-player).normalized()
	var power = clampf(charge_time/1.6,0,1)
	strike(60+power*190,90+power*55,60+power*55,-0.4,true)
	effects.append({"p":player,"t":0.4,"max":0.4,"kind":"pulse","radius":melee_reach(90+power*55)})
	charge_time = 0
	melee_clock = 1.35
	checkpoint()

func zone() -> int:
	return 2 if player.y < 700 else 1 if player.y < 1200 else 0

func exits() -> Array:
	return ship.exit_points

func nearest_checkpoint() -> Vector2:
	var result: Vector2 = exits()[0]
	for point in exits():
		if player.distance_squared_to(point) < player.distance_squared_to(result): result = point
	return result

func at_checkpoint() -> bool:
	return player.distance_to(nearest_checkpoint()) < 60 and clear_shot(player,nearest_checkpoint())

func request_extraction():
	if paused or ended or not at_checkpoint() or special_time > 0: return
	extraction_requested = not extraction_requested
	extract_progress = 0
	checkpoint()

func walls() -> Array:
	return ship.barriers

func move_with_walls(origin: Vector2, delta: Vector2, radius: float) -> Vector2:
	var pos=origin
	var steps=maxi(1,ceili(delta.length()/10.0))
	var step=delta/steps
	for i in range(steps):
		for axis in [0,1]:
			var next=pos
			next[axis]+=step[axis]
			if ship.walkable(next,radius): pos=next
	return pos

func clear_shot(from: Vector2,to: Vector2) -> bool:
	return ship.segment_clear(from,to)

func path_target(from: Vector2,to: Vector2) -> Vector2:
	if ship.segment_clear(from,to,26): return to
	return ship.route_target(from,to)

func show_bag():
	if ended or not offered.is_empty() or special_time > 0: return
	var column = open_overlay()
	make_label(column, "현장 가방", 28, GREEN)
	make_label(column, "장착한 장비만 사망 후 유지됩니다.\n교체한 기존 장비는 가방으로 이동합니다.", 13)
	make_label(column, "판매 물품 %d CR 상당 · 부품 %d" % [cargo,parts], 14)
	make_label(column, "장착: %s\n%s" % [Weapons.title(state.equipped.gun),Weapons.title(state.equipped.secondary)], 14)
	var scroll = TouchScroll.new()
	scroll.custom_minimum_size.y = 265
	column.add_child(scroll)
	var items = VBoxContainer.new()
	items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items.add_theme_constant_override("separation",8)
	scroll.add_child(items)
	if bag.is_empty(): make_label(items,"획득한 장비가 없습니다.",15)
	for i in range(bag.size()):
		var index = i
		make_button(items, Weapons.title(bag[i])+" → 장착", func(): equip_bag(index))
	make_button(column,"전투로 돌아가기",close_overlay)

func equip_bag(index: int):
	if index < 0 or index >= bag.size() or not offered.is_empty() or special_time > 0: return
	var item = bag[index]
	var slot = Weapons.TYPES[item.kind].slot
	bag[index] = state.equipped[slot]
	state.equipped[slot] = item
	second_hit = 0
	combo = 0
	checkpoint()
	show_bag()


func draw_operator(center: Vector2):
	var f = facing
	var side = facing.orthogonal()
	var walking = aim_input.length() > 0.05 or Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_D)
	var stride = sin(elapsed*14)*5 if walking else 0.0
	var armor_color = Color("435866") if hit_clock <= 0 else Color("a87969")
	draw_set_transform(center,0,Vector2(1,0.7))
	draw_circle(Vector2(3,12),25,Color(0,0,0,0.4))
	draw_set_transform(Vector2.ZERO)
	# Boots, legs, rucksack, plated torso, orange shoulder mark and respirator.
	for sign_value in [-1,1]:
		var hip = center + side*sign_value*8-f*6
		var boot = center+side*sign_value*10-f*(23+stride*sign_value)
		draw_line(hip,boot,Color("2a3b48"),9,true)
		draw_line(boot-f*4,boot+f*5,Color("131e27"),10,true)
	draw_line(center-f*10-side*10,center-f*10+side*10,Color("92806a"),17,true)
	draw_line(center-side*13,center+side*13,armor_color,18,true)
	draw_line(center-f*5,center+f*8,Color("647783"),13,true)
	draw_line(center-side*15-f*3,center-side*15+f*5,Color("cf8c55"),5,true)
	for sign_value in [-1,1]:
		draw_line(center+side*sign_value*14,center+side*sign_value*15+f*12,armor_color.lightened(0.1),7,true)
		draw_circle(center+side*sign_value*15+f*12,4,Color("b3aa92"))
	draw_circle(center+f*5,11,Color("7e8c86"))
	draw_line(center+f*11-side*7,center+f*11+side*7,Color("152b35"),5,true)
	draw_line(center+f*10-side*5,center+f*10+side*5,Color("82b2bd"),1,true)
	draw_circle(center+f*15,5,Color("34414a"))
	for sign_value in [-1,1]: draw_circle(center+f*13+side*sign_value*5,3,Color("b1b09a"))
	var kind = state.equipped[active_slot].kind
	var weapon_direction = f.rotated(sin(swing_time/0.24*PI)*0.9 if active_slot == "secondary" else 0)
	Weapons.draw_icon(self,center+side*16+f*8,kind,weapon_direction,1.0,Weapons.COLORS[int(state.equipped[active_slot].grade)])
	draw_arc(center,32,0,TAU,40,Color(0.74,0.87,0.56,0.25),1)


func _exit_tree():
	for audio in audio_players:
		if is_instance_valid(audio): audio.stop()


func nearby_cache() -> int:
	for i in range(caches.size()):
		if not caches[i].used and player.distance_to(caches[i].p)<65 and clear_shot(player,caches[i].p): return i
	return -1

func request_search():
	if paused or ended or special_time>0: return
	var index=nearby_cache()
	if index<0: return
	searching=index
	search_progress=0
	extraction_requested=false

func finish_search():
	if searching<0 or caches[searching].used: return
	var site=caches[searching]
	site.used=true
	var depth=zone()
	var value=120*(depth+1)+rng.randi_range(0,80)
	cargo+=value
	parts+=1+depth
	if rng.randf()<[0.06,0.10,0.16][depth]:
		var kinds=Weapons.TYPES.keys()
		var grade=1 if depth<2 else 2
		bag.append(state.new_item(kinds[rng.randi_range(0,kinds.size()-1)],grade))
		banner="장비 발견! 가방에서 확인하십시오."
	else: banner="%s · 물품 %d CR 상당 / 부품 +%d" % [site.name,value,1+depth]
	banner_time=4
	searching=-1
	search_progress=0
	play_sound("pickup")
	checkpoint()

func show_chart():
	if ended or not offered.is_empty(): return
	var column=open_overlay()
	make_label(column,ShipMap.DATA[map_id].type+" · "+ShipMap.DATA[map_id].name,26,GREEN)
	make_label(column,"노랑: 현재 위치  /  녹색: 철수  /  금색: 보관함",12)
	var chart=Control.new()
	chart.custom_minimum_size=Vector2(380,450)
	chart.draw.connect(func():
		ShipMap.draw_ocean(chart,chart.size,Vector2.ZERO,0)
		var zoom=0.245
		var origin=Vector2(chart.size.x/2-950*zoom,12-100*zoom)
		ship.draw_deck(chart,origin,zoom,0)
		for point in exits():
			chart.draw_circle(origin+point*zoom,6,GREEN)
			if point==ship.exit_points[-1]: chart.draw_string(FONT,origin+point*zoom+Vector2(9,4),"최종",HORIZONTAL_ALIGNMENT_LEFT,-1,11,GREEN)
		for site in caches:
			if not site.used: chart.draw_rect(Rect2(origin+site.p*zoom-Vector2(3,3),Vector2(6,6)),Color("e5c481"))
		chart.draw_circle(origin+player*zoom,5,Color("fff1a8"))
		chart.draw_arc(origin+player*zoom,9,0,TAU,24,Color("fff1a8"),2)
	)
	column.add_child(chart)
	make_label(column,chapter_objective(),13,GREEN)
	make_label(column,ShipMap.DATA[map_id].route,13)
	make_button(column,"탐사 계속",close_overlay)


func chapter_objective() -> String:
	if chapter_kills[0]<CHAPTER_TARGETS[0]: return "선미 WAVE %d/3 · %d/60 처치" % [maxi(1,int(wave_started[0])),chapter_kills[0]]
	if chapter_kills[1]<CHAPTER_TARGETS[1]: return "갑판 WAVE %d/3 · %d/100 처치" % [maxi(1,int(wave_started[1])),chapter_kills[1]]
	if boss_defeated: return "보스 격파 · 마지막 철수 지점으로"
	if boss_started: return "최종 보스 처치"
	return "3구역 진입 · 최종 보스와 대결"

func at_final_checkpoint() -> bool:
	var point: Vector2=ship.exit_points[-1]
	return player.distance_to(point)<60 and clear_shot(player,point)

func chapter_boss() -> Dictionary:
	for enemy in enemies:
		if enemy.get("boss",false): return enemy
	return {}

func spawn_chapter_boss():
	if boss_started or boss_defeated: return
	var candidates=[]
	for cell in ship.free_cells:
		var point=ship.grid.get_point_position(cell)
		if point.y<700 and point.distance_to(player)>120 and point.distance_to(player)<500: candidates.append(point)
	if candidates.is_empty(): return
	var point=candidates[rng.randi_range(0,candidates.size()-1)]
	var health=2000.0+map_id*700.0
	enemies.append({"p":point,"hp":health,"max_hp":health,"speed":58.0+map_id*5,"radius":24.0,"elite":true,"runner":false,"boss":true,"id":next_id,"air":0.0,"attack_clock":2.5,"windup":0.0,"attack_target":point})
	next_id+=1
	boss_started=true
	banner="최종 보스: "+BOSS_NAMES[map_id]
	banner_time=5
	checkpoint()

func update_chapter_boss(enemy: Dictionary,dt: float):
	if enemy.hp<=0: return
	if float(enemy.get("windup",0))>0:
		enemy.windup=maxf(0,enemy.windup-dt)
		if enemy.windup<=0:
			var target: Vector2=enemy.attack_target
			effects.append({"p":target,"t":0.45,"max":0.45,"kind":"pulse","radius":110})
			if player.distance_to(target)<110 and clear_shot(enemy.p,player) and hit_clock<=0 and not (special_kind=="shield" and special_time>0):
				var reduction=0.75 if active_slot=="secondary" and secondary_kind()=="shield" else 1.0
				hp-=(25+map_id*5)*reduction
				hit_clock=0.65
				extract_progress=0
				search_progress=0
				play_sound("hurt")
				if hp<=0: finish_run(false)
			enemy.attack_clock=3.5
	else:
		enemy.attack_clock=float(enemy.get("attack_clock",2.5))-dt
		if enemy.attack_clock<=0 and enemy.p.distance_to(player)<420 and clear_shot(enemy.p,player):
			enemy.attack_target=player
			enemy.windup=1.0


func mastery(kind: String) -> int:
	return RunUpgrades.rank(skills,kind)

func evolved(kind: String) -> bool:
	return RunUpgrades.evolved(skills,kind)

func melee_reach(base: float) -> float:
	return (base+mastery(secondary_kind())*15)*(1+skill("area")*0.18)*(1.25 if evolved(secondary_kind()) else 1.0)

func area_damage(origin: Vector2,radius: float,damage: float,visual: String):
	for enemy in enemies:
		if enemy.hp>0 and origin.distance_to(enemy.p)<=radius+enemy.radius and clear_shot(origin,enemy.p): enemy.hp-=damage
	effects.append({"p":origin,"t":0.35,"max":0.35,"kind":visual,"radius":radius})

func chain_target(origin: Vector2,already_hit: Array) -> Dictionary:
	var chosen: Dictionary={}
	var best=260.0*260.0
	for enemy in enemies:
		var distance=origin.distance_squared_to(enemy.p)
		if enemy.hp>0 and not already_hit.has(enemy.id) and distance<best and clear_shot(origin,enemy.p):
			chosen=enemy
			best=distance
	return chosen

func emit_weapon_projectile(kind: String,direction: Vector2,power: float):
	if bullets.size()>=260: return
	bullets.append({"p":player+direction*25,"v":direction*(780 if kind=="bat" else 440),"ttl":1.2,"damage":(200 if kind=="bat" else 115)*power*Weapons.scale(state.equipped.secondary)*(1+mastery(kind)*0.15),"remaining":5 if kind=="bat" else 12,"hits":[],"visual":kind,"ricochet":3 if kind=="bat" and mastery(kind)>=3 else 0,"blast":75.0 if kind=="bat" and evolved(kind) else 0.0})

func weapon_followup():
	var kind=secondary_kind()
	if kind=="katana" and (mastery(kind)>=3 or (mastery(kind)>=2 and combo==3)):
		var count=3 if evolved(kind) else 1
		for i in range(count): emit_weapon_projectile(kind,facing.rotated((i-(count-1)/2.0)*0.32),0.65)
	elif kind=="hammer" and mastery(kind)>=2:
		area_damage(player,melee_reach(100),32+mastery(kind)*12,"pulse")
		if evolved(kind):
			for i in [-1,1]:
				var origin=player+facing.rotated(i*0.5)*110
				if clear_shot(player,origin): area_damage(origin,120,75,"pulse")
	elif kind=="bat" and evolved(kind) and combo==3:
		for i in [-1,0,1]: emit_weapon_projectile(kind,facing.rotated(i*0.25),0.6)

func tick_waves(dt: float):
	if boss_defeated: return
	var stage=zone()
	if stage<2 and (stage==0 or chapter_kills[0]>=CHAPTER_TARGETS[0]):
		var wave=int(wave_started[stage])
		if wave<3 and chapter_kills[stage]>=WAVE_MARKS[stage][wave]:
			wave_started[stage]=wave+1
			wave_remaining+=WAVE_SIZES[stage][wave]
			banner="WAVE %d / 3 · 적 무리 접근" % (wave+1)
			banner_time=3
	wave_clock-=dt
	if wave_remaining>0 and wave_clock<=0 and enemies.size()<120:
		var before=enemies.size()
		spawn_enemy()
		if enemies.size()>before: wave_remaining-=1
		wave_clock=0.24 if stage==0 else 0.18


func run_weapon_title(kind: String) -> String:
	if evolved(kind): return RunUpgrades.EVOLUTIONS[kind]+" [진화]"
	return RunUpgrades.NAMES[kind]+(" +%d" % mastery(kind) if mastery(kind)>0 else "")
