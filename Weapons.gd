extends RefCounted
## Shared data for weapon identity, grades, combat and inventory UI.
const GRADES = ["일반", "희귀", "영웅", "전설"]
const COLORS = [Color("c2cac6"), Color("78b9d4"), Color("b79bdb"), Color("e2bb72")]
const TYPES = {
	"rifle": {"name":"AR-17 소총", "slot":"gun", "damage":64.0, "interval":0.42, "reach":560.0, "speed":1.0, "knock":12.0, "special":"", "cooldown":0.0, "description":"강한 자동 사격 · 탄약 필요 / 맵에서 보충"},
	"katana": {"name":"카타나", "slot":"secondary", "damage":25.0, "interval":0.42, "reach":83.0, "speed":1.0, "knock":16.0, "special":"검기", "cooldown":7.0, "description":"3연속 베기 · 마지막 타격 강화 / 관통 검기"},
	"hammer": {"name":"망치", "slot":"secondary", "damage":88.0, "interval":1.35, "reach":88.0, "speed":0.78, "knock":55.0, "special":"휠윈드", "cooldown":12.0, "description":"느린 강타 · 길게 눌러 차지 / 회전 광역 공격"},
	"bat": {"name":"방망이", "slot":"secondary", "damage":20.0, "interval":0.68, "reach":87.0, "speed":1.0, "knock":115.0, "special":"홈~런!", "cooldown":9.0, "description":"낮은 피해 · 강한 밀치기 / 고속 야구공 발사"},
	"shield": {"name":"방패", "slot":"secondary", "damage":22.0, "interval":1.05, "reach":68.0, "speed":0.82, "knock":35.0, "special":"불도저!", "cooldown":15.0, "description":"2연타 · 피해 25% 감소 · 넉백 30% 저항\n특수: 2초 무적 돌진 · 적 띄우기"},
}

static func make(kind: String, grade: int, uid: int) -> Dictionary:
	return {"kind":kind,"grade":clampi(grade,0,3),"uid":uid}

static func title(item: Dictionary) -> String:
	return "%s · %s" % [GRADES[int(item.grade)], TYPES[item.kind].name]

static func scale(item: Dictionary) -> float:
	return 1.0 + int(item.grade) * 0.3

static func sell_value(item: Dictionary) -> int:
	return [100, 240, 600, 1500][int(item.grade)]

static func draw_icon(canvas: CanvasItem, p: Vector2, kind: String, direction: Vector2, scale_px: float = 1.0, tint: Color = Color("c7d2ce")):
	var f = direction.normalized()
	var s = f.orthogonal()
	match kind:
		"rifle":
			canvas.draw_line(p - f * 9 * scale_px, p + f * 27 * scale_px, Color("111d23"), 8 * scale_px, true)
			canvas.draw_line(p, p + f * 18 * scale_px, tint.darkened(0.25), 5 * scale_px, true)
			canvas.draw_line(p + f * 17 * scale_px, p + f * 31 * scale_px, tint, 2 * scale_px, true)
			canvas.draw_line(p - f * 3 * scale_px, p - f * 3 * scale_px + s * 9 * scale_px, Color("485b61"), 4 * scale_px, true)
		"katana":
			canvas.draw_line(p - f * 10 * scale_px, p, Color("675f4e"), 5 * scale_px, true)
			canvas.draw_line(p - s * 6 * scale_px, p + s * 6 * scale_px, Color("cfb783"), 3 * scale_px, true)
			canvas.draw_colored_polygon(PackedVector2Array([p-s*2*scale_px,p+f*39*scale_px+s*3*scale_px,p+f*30*scale_px+s*6*scale_px,p+s*3*scale_px]), tint)
		"hammer":
			canvas.draw_line(p - f * 15 * scale_px, p + f * 24 * scale_px, Color("8b7860"), 5 * scale_px, true)
			canvas.draw_colored_polygon(PackedVector2Array([p+f*15*scale_px-s*14*scale_px,p+f*31*scale_px-s*14*scale_px,p+f*31*scale_px+s*14*scale_px,p+f*15*scale_px+s*14*scale_px]), tint.darkened(0.25))
			canvas.draw_line(p+f*31*scale_px-s*14*scale_px,p+f*31*scale_px+s*14*scale_px,tint,3*scale_px,true)
		"bat":
			canvas.draw_line(p - f * 13 * scale_px, p + f * 10 * scale_px, Color("9d8664"), 4 * scale_px, true)
			canvas.draw_line(p + f * 7 * scale_px, p + f * 34 * scale_px, tint, 9 * scale_px, true)
			canvas.draw_circle(p + f * 34 * scale_px, 4.5 * scale_px, tint)
		"shield":
			canvas.draw_colored_polygon(PackedVector2Array([p-f*8*scale_px-s*18*scale_px,p+f*12*scale_px-s*15*scale_px,p+f*18*scale_px,p+f*12*scale_px+s*15*scale_px,p-f*8*scale_px+s*18*scale_px]), Color("425764"))
			canvas.draw_line(p+f*10*scale_px-s*12*scale_px,p+f*10*scale_px+s*12*scale_px,tint,3*scale_px,true)
			canvas.draw_line(p-f*4*scale_px-s*9*scale_px,p-f*4*scale_px+s*9*scale_px,Color("151f26"),4*scale_px,true)
