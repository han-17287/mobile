extends SceneTree
const Model = preload("res://State.gd")
func _initialize():
	var s = Model.new()
	assert(s.buy("med"))
	assert(s.credits == 1050 and s.reserve_meds == 1)
	assert(s.buy("boost"))
	assert(not s.buy("boost"))
	s.start()
	assert(s.raid and s.run_data.initial_meds == 3 and s.run_data.boosted)
	assert(s.reserve_meds == 0 and not s.booster)
	assert(not s.buy("med"))
	var before = s.credits
	s.complete(true, 200, 2, 18)
	assert(s.credits == before and s.valuables == 200 and s.parts == 2)
	s.complete(true, 200, 2, 18)
	assert(s.credits == before and s.valuables == 200 and s.parts == 2)
	s.sell_valuables()
	assert(s.credits == before+200 and s.valuables==0)
	assert(s.buy("armor") and s.upgrade == 1)
	s.start()
	before = s.credits
	s.complete(false, 900, 12, 20)
	assert(s.credits == before and s.parts == 0 and s.upgrade == 1)
	s.start()
	s.run_data = {"player":Vector2(500, 600),"enemies":[{"p":Vector2(12,34),"hp":27.0}],"skills":{"power":2},"offered":["power","haste","field"]}
	s.save_game()
	var other = Model.new()
	other.load_game()
	assert(other.raid and other.run_data.player == Vector2(500,600))
	assert(other.run_data.enemies[0].p == Vector2(12,34))
	assert(other.run_data.offered == s.run_data.offered)
	# Legacy save migration preserves bank and upgrades, discards incompatible combat.
	var f = FileAccess.open(Model.SAVE, FileAccess.WRITE)
	f.store_string('{"credits":987,"parts":4,"upgrade":2,"raid":true,"depth":5}')
	f.close()
	other = Model.new()
	other.load_game()
	assert(other.credits == 987 and other.upgrade == 2 and not other.raid)
	var craft=Model.new()
	craft.stash.append(craft.new_item("hammer",1))
	var kind=craft.equipped.secondary.kind
	assert(craft.dismantle(craft.stash.size()-1) and craft.energies[1]==1)
	assert(craft.promote("secondary") and craft.equipped.secondary.kind==kind and craft.equipped.secondary.grade==1)
	assert(not craft.promote("secondary"))
	var random=RandomNumberGenerator.new()
	random.seed=100
	assert(craft.draw_equipment(false,random).is_empty())
	assert(not craft.draw_equipment(true,random).is_empty() and craft.tickets==2)
	craft.gems=100
	assert(not craft.draw_equipment(false,random).is_empty() and craft.gems==0)
	var old_uid=craft.equipped.secondary.uid
	assert(craft.equip_stash(0))
	assert(craft.stash[0].uid==old_uid)
	# v3 land expedition migrates safely, including carried gear and unsold salvage.
	var legacy=Model.new()
	legacy.cleared_chapters=1
	legacy.selected_map=1
	legacy.start()
	legacy.run_data={"bag":[legacy.new_item("hammer",2)],"cargo":321,"parts":4}
	legacy.save_game()
	var data=JSON.parse_string(FileAccess.get_file_as_string(Model.SAVE))
	data.version=3
	var legacy_file=FileAccess.open(Model.SAVE,FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(data))
	legacy_file.close()
	var migrated=Model.new()
	migrated.load_game()
	assert(not migrated.raid and migrated.stash.size()==4 and migrated.valuables==321 and migrated.parts==4)
	migrated.cleared_chapters=2
	migrated.selected_map=2
	migrated.save_game()
	var cruise=Model.new()
	cruise.load_game()
	assert(cruise.selected_map==2)
	DirAccess.remove_absolute(Model.SAVE)
	print("PASS: supply costs/limits, one-shot consumption, settlement idempotency, death, armor, vector snapshot, legacy migration")
	quit()
