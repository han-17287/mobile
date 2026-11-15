extends Control
const ShipMap = preload("res://ShipMap.gd")
const TouchScroll = preload("res://TouchScroll.gd")
const TouchButton = preload("res://TouchButton.gd")
const Weapons = preload("res://Weapons.gd")
const Model = preload("res://State.gd")
const Arena = preload("res://Arena.gd")
const FONT = preload("res://assets/Korean.ttf")
const GREEN = Color("c1db8d")
var state = Model.new()
var stack: VBoxContainer
var page := "base"
var arena: Control
var confirm: ConfirmationDialog
var rng = RandomNumberGenerator.new()
var ship_previews: Array = []

func _ready():
	rng.randomize()
	for id in range(3): ship_previews.append(ShipMap.new(id,false))
	var t = Theme.new()
	t.default_font = FONT
	t.default_font_size = 15
	theme = t
	state.load_game()
	render()

func style(color: Color) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = Color("354448")
	s.set_border_width_all(1)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(14)
	return s

func label_line(value: String, size_px: int = 15, color: Color = Color("dfe7e1")):
	var label = Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	stack.add_child(label)

func button(value: String, action: Callable, enabled: bool = true, primary: bool = false):
	var b = TouchButton.new()
	b.text = value
	b.custom_minimum_size.y = 54
	b.disabled = not enabled
	b.add_theme_stylebox_override("normal", style(GREEN if primary else Color("1b282d")))
	b.add_theme_stylebox_override("hover", style(Color("9db97a") if primary else Color("304149")))
	b.add_theme_stylebox_override("pressed", style(Color("52745c")))
	b.add_theme_stylebox_override("disabled", style(Color("131e22")))
	b.add_theme_color_override("font_color", Color("15201b") if primary else Color("e1e8e1"))
	b.add_theme_color_override("font_hover_color", Color("15201b") if primary else Color.WHITE)
	b.pressed.connect(action)
	stack.add_child(b)
	return b

func render():
	arena = null
	for c in get_children():
		remove_child(c)
		c.queue_free()
	if state.raid:
		arena = Arena.new()
		arena.state = state
		arena.finished.connect(func(): page = "base"; call_deferred("render"))
		arena.return_to_base.connect(func(): page = "base"; call_deferred("render"))
		arena.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(arena)
		return
	var scroll = TouchScroll.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]: margin.add_theme_constant_override("margin_" + side, 24)
	for side in ["top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 30)
	scroll.add_child(margin)
	stack = VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 13)
	margin.add_child(stack)
	label_line("E X T R A C T I O N   L I N E     /     0 6", 12, GREEN)
	label_line({"base":"철수선","shop":"장비 보급","armory":"무기고","voyages":"챕터 선택"}.get(page,"철수선"), 38)
	label_line("%d CR    /    부품 %d    /    방호 LV.%d" % [state.credits, state.parts, state.upgrade], 14, GREEN)
	if page == "voyages":
		render_voyages()
		return
	if page == "armory":
		render_armory()
		return
	if page == "shop":
		render_shop()
		return
	var selected=ShipMap.DATA[state.selected_map]
	var art=Control.new()
	art.custom_minimum_size.y=185
	art.draw.connect(func():
		ShipMap.draw_ocean(art,art.size,Vector2.ZERO,0)
		ship_previews[state.selected_map].draw_deck(art,Vector2(76-950*0.095,12-100*0.095),0.095,0)
		art.draw_string(FONT,Vector2(145,48),selected.english,HORIZONTAL_ALIGNMENT_LEFT,-1,18,selected.color)
		art.draw_string(FONT,Vector2(145,80),selected.type+" · "+selected.name,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("e7e7db"))
		art.draw_string(FONT,Vector2(145,115),"승선 → 수색 → 철수",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("a2bdb9"))
		art.draw_string(FONT,Vector2(145,146),"CH.%02d / 구역 제압 + 보스" % (state.selected_map+1),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("a2bdb9"))
	)
	stack.add_child(art)
	label_line(state.message)
	label_line("장착  /  %s\n%s" % [Weapons.title(state.equipped.gun),Weapons.title(state.equipped.secondary)],14,GREEN)
	button("무기 선택 · 창고 · 분해 / 승급",func(): page="armory"; render())
	button("챕터 선택 · 범선 → 요트 → 크루즈",func(): page="voyages"; render())
	button("선택한 챕터 도전 →", launch, true, true)
	label_line("드래그 이동 · Q 무기 전환 · 특수 공격 버튼\n구역마다 3웨이브 → 무기 진화 → 보스 → 최종 철수", 14, Color("a8b7b6"))
	label_line("출격 보급  /  의약품 %d · %s" % [2 + state.reserve_meds, "강화 탄약" if state.booster else "기본 탄약"], 15, GREEN)
	button("의약품 +1 · 150 CR (%d/3)" % state.reserve_meds, func(): buy("med"), state.credits >= 150 and state.reserve_meds < 3)
	button("강화 탄약 · 피해 +20% · 200 CR", func(): buy("boost"), state.credits >= 200 and not state.booster)
	button("영구 방호 +15 HP · 600 CR + 부품 2", func(): buy("armor"), state.credits >= 600 and state.parts >= 2 and state.upgrade < 3)
	button("보석 · 뽑기권 장비 보급", func(): page = "shop"; render())
	label_line("출격 탄약 48 · 의약품 2개 무료 / 현장에서 탄약 보충\n사망: 장착 장비 유지 · 가방 속 모든 물건 손실", 12, Color("849998"))

func launch():
	state.start()
	state.save_game()
	render()

func buy(kind: String):
	state.buy(kind)
	render()

func show_purchase(product: String, amount: int, price: String):
	confirm = ConfirmationDialog.new()
	confirm.title = "테스트 지급 확인"
	confirm.dialog_text = "%s · 보석 %d\n예시 가격 %s\n실제 결제 없이 지급합니다." % [product, amount, price]
	confirm.ok_button_text = "무료 테스트 지급"
	confirm.cancel_button_text = "취소"
	confirm.get_ok_button().set_script(TouchButton)
	confirm.get_cancel_button().set_script(TouchButton)
	add_child(confirm)
	confirm.confirmed.connect(func(): state.gems += amount; state.save_game(); render())
	confirm.popup_centered(Vector2i(380, 210))

func _notification(what):
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if is_instance_valid(arena): arena.checkpoint()
		else: state.save_game()


func render_armory():
	label_line("장착한 장비는 사망해도 유지 · 가방 속 장비는 손실",12,GREEN)
	for slot in ["gun","secondary"]:
		var slot_id = slot
		var item = state.equipped[slot]
		label_line(Weapons.title(item),20,Weapons.COLORS[int(item.grade)])
		var preview = Control.new()
		preview.custom_minimum_size.y = 70
		preview.draw.connect(func(): Weapons.draw_icon(preview,Vector2(70,48),item.kind,Vector2(0.9,-0.4),1.7,Weapons.COLORS[int(item.grade)]))
		stack.add_child(preview)
		label_line(Weapons.TYPES[item.kind].description,13)
		var target = int(item.grade)+1
		if target <= 3:
			button("%s 승급 · 해당 등급 에너지 1 (%d 보유)" % [Weapons.GRADES[target],int(state.energies[target])],func(): state.promote(slot_id); render(),int(state.energies[target])>=1)
	label_line("등급 에너지  /  일반 %d · 희귀 %d · 영웅 %d · 전설 %d" % state.energies,12)
	label_line("창고 · 장비 %d개" % state.stash.size(),23,GREEN)
	button("판매용 물품 일괄 판매 · +%d CR" % state.valuables,func(): state.sell_valuables(); render(),state.valuables>0)
	for i in range(state.stash.size()):
		var index = i
		var item = state.stash[i]
		label_line(Weapons.title(item),17,Weapons.COLORS[int(item.grade)])
		label_line(Weapons.TYPES[item.kind].description,12)
		button("장착 ↔ 기존 장비는 창고로",func(): state.equip_stash(index); render())
		button("분해 → %s 에너지 1" % Weapons.GRADES[int(item.grade)],func(): confirm_inventory(index,false),int(item.grade)>0)
		button("판매 → %d CR" % Weapons.sell_value(item),func(): confirm_inventory(index,true))
	button("← 기지로",func(): page="base"; render())

func confirm_inventory(index: int, sell: bool):
	if index < 0 or index >= state.stash.size(): return
	confirm = ConfirmationDialog.new()
	confirm.title = "판매 확인" if sell else "분해 확인"
	confirm.dialog_text = Weapons.title(state.stash[index])+"\n"+("판매하면 원본 장비가 사라집니다." if sell else "분해하면 원본 장비가 사라집니다.")
	confirm.ok_button_text = "판매" if sell else "분해"
	confirm.cancel_button_text = "취소"
	confirm.get_ok_button().set_script(TouchButton)
	confirm.get_cancel_button().set_script(TouchButton)
	add_child(confirm)
	confirm.confirmed.connect(func():
		if sell: state.sell_item(index)
		else: state.dismantle(index)
		render())
	confirm.popup_centered(Vector2i(380,210))

func render_shop():
	label_line("보석 %d  /  뽑기권 %d" % [state.gems,state.tickets],23,GREEN)
	label_line("장비 1개 확정 · 모든 무기 종류 동일 확률\n일반 70% / 희귀 24% / 영웅 5% / 전설 1%",14)
	label_line(state.message,15)
	button("뽑기권 1장 사용",func(): state.draw_equipment(true,rng); render(),state.tickets>0,true)
	button("보석 100개 사용",func(): state.draw_equipment(false,rng); render(),state.gems>=100)
	label_line("보석 구매 테스트 · 실제 청구 없음",20,GREEN)
	label_line("보석은 희귀 재화입니다. 아래는 결제 연동 전의 무료 테스트 지급이며 가격은 기획 예시입니다.",13)
	for item in [["보석 보급",300,"₩2,900"],["보석 보급",700,"₩5,900"]]:
		button("보석 %d · %s (테스트)" % [item[1],item[2]],func(): show_purchase(item[0],item[1],item[2]))
	button("무기고에서 획득 장비 확인",func(): page="armory"; render())
	button("← 기지로",func(): page="base"; render())


func render_voyages():
	label_line("앞 챕터를 끝까지 클리어하면 다음 배가 열립니다.\n구역 제압 → 최종 보스 → 마지막 철수 지점\n중간 철수는 물품만 회수합니다.",14)
	for id in range(3):
		var index=id
		var data=ShipMap.DATA[id]
		var chosen=state.selected_map==id
		var unlocked=state.chapter_unlocked(id)
		var status="완료" if id<state.cleared_chapters else "도전 가능" if unlocked else "잠김 · CH.%02d 클리어 필요" % id
		var card=button("CH.%02d  %s / %s\n%s" % [id+1,data.type,data.name,status],func(): state.select_chapter(index); page="base"; render(),unlocked)
		card.custom_minimum_size.y=170
		card.add_theme_font_size_override("font_size",14)
		card.alignment=HORIZONTAL_ALIGNMENT_LEFT
		for mode in ["normal","hover","pressed","disabled"]:
			var skin=style(Color("101c21") if not unlocked else Color("1e383f") if chosen else Color("15272e"))
			skin.content_margin_left=120
			if chosen: skin.border_color=data.color
			card.add_theme_stylebox_override(mode,skin)
		var sketch=Control.new()
		sketch.mouse_filter=Control.MOUSE_FILTER_IGNORE
		sketch.size=Vector2(110,170)
		sketch.draw.connect(func(): ship_previews[index].draw_deck(sketch,Vector2(55-950*0.085,12-100*0.085),0.085,0))
		if not unlocked: sketch.modulate=Color(0.4,0.4,0.4,1)
		card.add_child(sketch)
		label_line(data.route,12,data.color)
	button("← 기지로",func(): page="base"; render())
