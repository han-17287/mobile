extends RefCounted
## Persistent base economy. Combat lives in Arena.gd.
const Weapons = preload("res://Weapons.gd")
const SAVE = "user://extraction_save.json"
var credits: int = 1200
var next_item_id: int = 6
var equipped: Dictionary = {"gun":Weapons.make("rifle",0,1),"secondary":Weapons.make("katana",0,2)}
var stash: Array = [Weapons.make("hammer",0,3),Weapons.make("bat",0,4),Weapons.make("shield",0,5)]
var gems: int = 0
var tickets: int = 3
var energies: Array = [0,0,0,0]
var valuables: int = 0
var selected_map: int = 0
var cleared_chapters: int = 0
var parts: int = 0
var upgrade: int = 0
var reserve_meds: int = 0
var booster: bool = false
var raid: bool = false
var run_data: Dictionary = {}
var message: String = "연안에서 세 척의 조난선 신호가 잡혔습니다.\n살아 돌아와야 전리품을 확보합니다."

func start() -> bool:
	if raid or not chapter_unlocked(selected_map): return false
	raid = true
	run_data = {"initial_meds": 2 + reserve_meds, "boosted": booster, "map_id":selected_map}
	reserve_meds = 0
	booster = false
	return true

func complete(success: bool, cargo: int, found_parts: int, kills: int, bag: Array = [], chapter_clear: bool = false):
	if not raid: return
	if success:
		valuables += maxi(0, cargo)
		stash.append_array(bag.duplicate(true))
		parts += maxi(0, found_parts)
		message = "철수 성공 · %d 처치\n판매용 물품 %d CR 상당 / 부품 +%d 확보" % [kills, cargo, found_parts]
		if chapter_clear:
			var mission_id=int(run_data.get("map_id",selected_map))
			if mission_id==cleared_chapters and chapter_unlocked(mission_id):
				cleared_chapters=mini(3,cleared_chapters+1)
				message="CHAPTER %02d CLEAR\n" % (mission_id+1)+message
				message+="\n다음 배가 해금됐습니다." if cleared_chapters<3 else "\n모든 챕터를 클리어했습니다. 다시 탐사할 수 있습니다."
			else: message="챕터 재클리어 · 물품 회수\n"+message
	else:
		message = "작전 실패 · %d 처치\n현장 전리품 손실. 기지 자산과 영구 개량은 유지됩니다." % kills
	raid = false
	run_data = {}
	save_game()

func buy(kind: String) -> bool:
	if raid: return false
	if kind == "armor" and upgrade < 3 and credits >= 600 and parts >= 2:
		credits -= 600
		parts -= 2
		upgrade += 1
		message = "방호 개량 완료. 최대 체력 +15."
	elif kind == "med" and credits >= 150 and reserve_meds < 3:
		credits -= 150
		reserve_meds += 1
		message = "다음 출격 의약품 +1."
	elif kind == "boost" and credits >= 200 and not booster:
		credits -= 200
		booster = true
		message = "다음 출격 강화 탄약 장착. 기본 사격 피해 +20%."
	else:
		return false
	save_game()
	return true

static func encode(value):
	if value is Vector2: return {"__vector2": [value.x, value.y]}
	if value is Dictionary:
		var out = {}
		for key in value: out[key] = encode(value[key])
		return out
	if value is Array:
		var out = []
		for item in value: out.append(encode(item))
		return out
	return value

static func decode(value):
	if value is Dictionary:
		if value.has("__vector2"):
			return Vector2(float(value["__vector2"][0]), float(value["__vector2"][1]))
		var out = {}
		for key in value: out[key] = decode(value[key])
		return out
	if value is Array:
		var out = []
		for item in value: out.append(decode(item))
		return out
	return value

func save_game():
	var data = {"version":5,"cleared_chapters":cleared_chapters,"equipped":equipped,"stash":stash,"next_item_id":next_item_id,"gems":gems,"tickets":tickets,"energies":energies,"valuables":valuables,"selected_map":selected_map,"credits":credits,"parts":parts,"upgrade":upgrade,"reserve_meds":reserve_meds,"booster":booster,"raid":raid,"run_data":encode(run_data),"message":message}
	var file = FileAccess.open(SAVE + ".tmp", FileAccess.WRITE)
	if not file: return
	file.store_string(JSON.stringify(data))
	file.close()
	DirAccess.rename_absolute(SAVE + ".tmp", SAVE)

func load_game():
	if not FileAccess.file_exists(SAVE): return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	if not data is Dictionary: return
	credits = maxi(0, int(data.get("credits", 1200)))
	parts = maxi(0, int(data.get("parts", 0)))
	upgrade = clampi(int(data.get("upgrade", 0)), 0, 3)
	reserve_meds = clampi(int(data.get("reserve_meds", 0)), 0, 3)
	booster = data.get("booster", false) == true
	message = str(data.get("message", message))
	# Turn-based saves keep their bank but do not resume an incompatible mission.
	if int(data.get("version", 1)) >= 2:
		raid = data.get("raid", false) == true
		var restored = decode(data.get("run_data", {}))
		run_data = restored if restored is Dictionary else {}
		if int(data.get("version", 1)) < 3:
			raid = false
			run_data = {}
			message = "무기 탐사 버전으로 갱신했습니다. 기지 자산은 유지됩니다."
	else:
		raid = false
		message = "액션 버전으로 갱신했습니다. 기지 자산은 유지됩니다."

	if int(data.get("version", 1)) >= 3:
		equipped = data.get("equipped", equipped)
		stash = data.get("stash", stash)
		next_item_id = int(data.get("next_item_id",6))
		gems = maxi(0,int(data.get("gems",0)))
		tickets = maxi(0,int(data.get("tickets",3)))
		energies = data.get("energies",[0,0,0,0])
		valuables = maxi(0,int(data.get("valuables",0)))
		selected_map = clampi(int(data.get("selected_map",0)),0,2)

	if int(data.get("version",1)) == 3 and raid:
		stash.append_array(run_data.get("bag",[]))
		valuables += maxi(0,int(run_data.get("cargo",0)))
		parts += maxi(0,int(run_data.get("parts",0)))
		raid=false
		run_data={}
		message="선박 탐사 업데이트. 이전 작전의 장착 장비·가방 물품은 기지에 보관했습니다."

	cleared_chapters=clampi(int(data.get("cleared_chapters",0)),0,3) if int(data.get("version",1))>=5 else 0
	if int(data.get("version",1))==4 and raid:
		stash.append_array(run_data.get("bag",[]))
		valuables+=maxi(0,int(run_data.get("cargo",0)))
		parts+=maxi(0,int(run_data.get("parts",0)))
		raid=false
		run_data={}
		message="챕터 업데이트: 이전 탐사 물품을 기지에 보관했습니다. 범선부터 공략하십시오."
	if not chapter_unlocked(selected_map): selected_map=mini(cleared_chapters,2)
	if equipped.gun.uid==equipped.secondary.uid:
		equipped.gun.uid=next_item_id
		next_item_id+=1

func chapter_unlocked(id: int) -> bool:
	return id>=0 and id<3 and id<=cleared_chapters

func select_chapter(id: int) -> bool:
	if raid or not chapter_unlocked(id): return false
	selected_map=id
	save_game()
	return true

func new_item(kind: String, grade: int) -> Dictionary:
	var item = Weapons.make(kind,grade,next_item_id)
	next_item_id += 1
	return item

func equip_stash(index: int) -> bool:
	if raid or index < 0 or index >= stash.size(): return false
	var item = stash[index]
	var slot = Weapons.TYPES[item.kind].slot
	stash[index] = equipped[slot]
	equipped[slot] = item
	save_game()
	return true

func dismantle(index: int) -> bool:
	if raid or index < 0 or index >= stash.size(): return false
	var item = stash[index]
	if int(item.grade) == 0: return false
	energies[int(item.grade)] += 1
	stash.remove_at(index)
	message = "%s 에너지 +1. 원본 장비가 분해됐습니다." % Weapons.GRADES[int(item.grade)]
	save_game()
	return true

func promote(slot: String) -> bool:
	if raid or not equipped.has(slot): return false
	var target = int(equipped[slot].grade) + 1
	if target > 3 or int(energies[target]) < 1: return false
	energies[target] -= 1
	equipped[slot].grade = target
	message = "%s 승급 완료." % Weapons.title(equipped[slot])
	save_game()
	return true

func sell_item(index: int) -> bool:
	if raid or index < 0 or index >= stash.size(): return false
	credits += Weapons.sell_value(stash[index])
	stash.remove_at(index)
	save_game()
	return true

func sell_valuables():
	if raid: return
	credits += valuables
	valuables = 0
	save_game()

func draw_equipment(use_ticket: bool, rng: RandomNumberGenerator) -> Dictionary:
	if raid: return {}
	if use_ticket:
		if tickets < 1: return {}
		tickets -= 1
	else:
		if gems < 100: return {}
		gems -= 100
	var roll = rng.randf()
	var grade = 0 if roll < 0.70 else 1 if roll < 0.94 else 2 if roll < 0.99 else 3
	var kinds = Weapons.TYPES.keys()
	var item = new_item(kinds[rng.randi_range(0,kinds.size()-1)],grade)
	stash.append(item)
	message = "장비 획득: " + Weapons.title(item)
	save_game()
	return item
