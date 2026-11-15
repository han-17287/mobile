extends RefCounted
## Authored ship decks share one source of truth for rendering, collision and routing.
const FONT = preload("res://assets/Korean.ttf")
const GRID_SIZE = 40
const DATA = [
	{"name":"검은 돛", "type":"범선", "english":"BLACK SAIL", "description":"포대 갑판 · 화물창 · 선장실", "route":"돛대 사이 좁은 길과 측면 포대를 돌아 선장실로", "color":Color("d9b278"), "floor":Color("75513a"), "zones":["후갑판","포대·화물 갑판","선장실·선수"]},
	{"name":"오로라", "type":"호화 요트", "english":"AURORA", "description":"선미 비치클럽 · 수영장 · VIP 라운지", "route":"수영장 양옆으로 갈라지는 길과 실내 라운지", "color":Color("8cdbd1"), "floor":Color("b4a18a"), "zones":["비치클럽","수영장·선데크","VIP 라운지"]},
	{"name":"메리디언", "type":"크루즈", "english":"MERIDIAN", "description":"탑승 홀 · 객실 복도 · 카지노·브리지", "route":"객실을 수색하고 긴 복도를 지나 중앙 홀로", "color":Color("dda4b0"), "floor":Color("586572"), "zones":["탑승 홀","객실 복도","카지노·브리지"]}
]
var id: int
var hull: PackedVector2Array
var barriers: Array = []
var props: Array = []
var floors: Array = []
var labels: Array = []
var ammo_points: Array = []
var cache_points: Array = []
var exit_points: Array = []
var spawn = Vector2(950,1700)
var grid = AStarGrid2D.new()
var free_cells: Array = []
var flow: Dictionary = {}
var flow_goal = Vector2i(-1,-1)
var wall_color = Color("ded8c7")

func _init(ship_id: int = 0, navigation: bool = true):
	id = clampi(ship_id,0,2)
	hull = PackedVector2Array([Vector2(950,100),Vector2(1180,230),Vector2(1330,430),Vector2(1390,740),Vector2(1390,1510),Vector2(1300,1780),Vector2(600,1780),Vector2(510,1510),Vector2(510,740),Vector2(570,430),Vector2(720,230)])
	if id == 2:
		hull=PackedVector2Array([Vector2(750,150),Vector2(1150,150),Vector2(1350,330),Vector2(1430,600),Vector2(1430,1570),Vector2(1330,1800),Vector2(570,1800),Vector2(470,1570),Vector2(470,600),Vector2(550,330)])
	if id == 0: build_sail()
	elif id == 1: build_yacht()
	else: build_cruise()
	if navigation: build_navigation()

func add_prop(kind: String, rect: Rect2, solid: bool = true):
	props.append({"kind":kind,"rect":rect})
	if solid: barriers.append(rect)

func wall(rect: Rect2):
	barriers.append(rect)
	props.append({"kind":"wall","rect":rect})

func room(rect: Rect2, door_side: String, door_center: float, color: Color):
	floors.append({"rect":rect,"color":color})
	var x=rect.position.x
	var y=rect.position.y
	var w=rect.size.x
	var h=rect.size.y
	var half=75.0
	for side in ["top","bottom","left","right"]:
		if side == "top" or side == "bottom":
			var sy=y if side=="top" else y+h-16
			if door_side==side:
				wall(Rect2(x,sy,door_center-half-x,16))
				wall(Rect2(door_center+half,sy,x+w-door_center-half,16))
			else: wall(Rect2(x,sy,w,16))
		else:
			var sx=x if side=="left" else x+w-16
			if door_side==side:
				wall(Rect2(sx,y,16,door_center-half-y))
				wall(Rect2(sx,door_center+half,16,y+h-door_center-half))
			else: wall(Rect2(sx,y,16,h))

func build_sail():
	wall_color=Color("aa8155")
	floors.append({"rect":Rect2(630,1420,640,315),"color":Color("896044")})
	room(Rect2(650,330,600,310),"bottom",950,Color("4a4034"))
	add_prop("chart",Rect2(840,365,220,90))
	add_prop("helm",Rect2(915,1500,70,70))
	for y in [810,1210]:
		add_prop("mast",Rect2(915,y,70,70))
		add_prop("rope",Rect2(850,y+45,36,36),false)
		add_prop("rope",Rect2(1020,y-20,36,36),false)
	for y in [760,1010,1260]:
		add_prop("cannon",Rect2(560,y,95,60))
		add_prop("cannon",Rect2(1245,y,95,60))
	for rect in [Rect2(740,1000,120,100),Rect2(1050,1040,120,100),Rect2(740,1350,100,90),Rect2(1080,740,100,90)]: add_prop("cargo",rect)
	add_prop("hatch",Rect2(850,900,200,60),false)
	add_prop("sail",Rect2(950,720,10,370),false)
	labels=[{"p":Vector2(950,1630),"name":"QUARTERDECK"},{"p":Vector2(950,1160),"name":"GUN DECK"},{"p":Vector2(950,550),"name":"CAPTAIN'S QUARTERS"}]
	exit_points=[Vector2(1190,1620),Vector2(700,910),Vector2(1180,700)]
	ammo_points=[Vector2(1030,1670),Vector2(700,1190),Vector2(1190,950),Vector2(1100,580)]
	cache_points=[{"p":Vector2(1160,1330),"name":"화물 보관함"},{"p":Vector2(730,820),"name":"포수의 상자"},{"p":Vector2(750,430),"name":"선장의 금고"}]

func build_yacht():
	wall_color=Color("e8e5d8")
	floors.append({"rect":Rect2(640,1510,620,230),"color":Color("c2ac8e")})
	room(Rect2(650,330,600,430),"bottom",950,Color("e1d8c4"))
	add_prop("pool",Rect2(820,900,260,350))
	for y in [920,1070,1220]:
		add_prop("lounger",Rect2(660,y,70,105))
		add_prop("lounger",Rect2(1170,y,70,105))
	add_prop("bar",Rect2(720,410,130,80))
	add_prop("sofa",Rect2(1050,400,110,65))
	add_prop("sofa",Rect2(1050,590,110,65))
	add_prop("table",Rect2(1020,495,110,65))
	add_prop("sofa",Rect2(700,1510,130,65))
	add_prop("sofa",Rect2(1070,1510,130,65))
	for p in [Vector2(600,800),Vector2(1250,800),Vector2(700,1380),Vector2(1180,1380)]: add_prop("plant",Rect2(p,Vector2(45,45)))
	add_prop("helipad",Rect2(840,1300,220,180),false)
	labels=[{"p":Vector2(950,1680),"name":"BEACH CLUB"},{"p":Vector2(950,850),"name":"SUN DECK"},{"p":Vector2(950,685),"name":"AURORA / PRIVATE LOUNGE"}]
	exit_points=[Vector2(1190,1670),Vector2(590,1330),Vector2(1300,720)]
	ammo_points=[Vector2(870,1650),Vector2(760,1270),Vector2(1140,820),Vector2(750,650)]
	cache_points=[{"p":Vector2(1250,1450),"name":"게스트 보관함"},{"p":Vector2(1290,1040),"name":"풀사이드 보관함"},{"p":Vector2(760,550),"name":"VIP 금고"}]

func build_cruise():
	wall_color=Color("becbd0")
	floors.append({"rect":Rect2(870,740,160,760),"color":Color("763f50")})
	for row in range(2):
		var y=800+row*310
		room(Rect2(630,y,240,260),"right",y+130,Color("817e78"))
		room(Rect2(1030,y,240,260),"left",y+130,Color("817e78"))
		add_prop("bed",Rect2(660,y+35,90,140))
		add_prop("bed",Rect2(1150,y+35,90,140))
		add_prop("table",Rect2(770,y+185,55,40))
		add_prop("table",Rect2(1075,y+185,55,40))
	floors.append({"rect":Rect2(650,390,600,340),"color":Color("4a354d")})
	for p in [Vector2(710,460),Vector2(1050,460),Vector2(710,630),Vector2(1050,630)]: add_prop("casino",Rect2(p,Vector2(140,75)))
	add_prop("reception",Rect2(810,1510,280,80))
	add_prop("piano",Rect2(650,1550,100,90))
	add_prop("sofa",Rect2(1180,1530,95,60))
	add_prop("bridge",Rect2(800,270,300,60))
	for y in [850,1210,1500]:
		add_prop("lifeboat",Rect2(522,y,65,140))
		add_prop("lifeboat",Rect2(1313,y,65,140))
	labels=[{"p":Vector2(950,1660),"name":"GRAND ATRIUM"},{"p":Vector2(950,1460),"name":"STATEROOMS / DECK 08"},{"p":Vector2(950,410),"name":"MERIDIAN CASINO"}]
	exit_points=[Vector2(1190,1670),Vector2(950,1080),Vector2(1270,570)]
	ammo_points=[Vector2(800,1650),Vector2(950,1420),Vector2(800,940),Vector2(950,740),Vector2(1200,370)]
	cache_points=[{"p":Vector2(780,1260),"name":"객실 802 금고"},{"p":Vector2(1110,950),"name":"객실 805 금고"},{"p":Vector2(950,550),"name":"카지노 정산함"}]

func walkable(p: Vector2, radius: float = 0) -> bool:
	if not Geometry2D.is_point_in_polygon(p,hull): return false
	if radius > 0:
		for d in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
			if not Geometry2D.is_point_in_polygon(p+d*radius,hull): return false
	for rect in barriers:
		if rect.grow(radius).has_point(p): return false
	return true

func build_navigation():
	grid.region=Rect2i(0,0,48,48)
	grid.cell_size=Vector2(40,40)
	grid.offset=Vector2(20,20)
	grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	for y in range(48):
		for x in range(48):
			var cell=Vector2i(x,y)
			var allowed=walkable(grid.get_point_position(cell),28)
			grid.set_point_solid(cell,not allowed)
			if allowed: free_cells.append(cell)

	# Only spawn/routable cells connected to the boarding point are retained.
	rebuild_flow(spawn)
	var connected=[]
	for cell in free_cells:
		if flow.has(cell): connected.append(cell)
		else: grid.set_point_solid(cell,true)
	free_cells=connected

func cell_at(p: Vector2) -> Vector2i:
	var candidate=Vector2i(floori(p.x/40),floori(p.y/40))
	if grid.is_in_boundsv(candidate) and not grid.is_point_solid(candidate): return candidate
	var best=Vector2i(free_cells[0])
	var distance=INF
	for cell in free_cells:
		var d=grid.get_point_position(cell).distance_squared_to(p)
		if d<distance: distance=d; best=cell
	return best

func rebuild_flow(target: Vector2):
	var goal=cell_at(target)
	if goal==flow_goal: return
	flow_goal=goal
	flow={goal:goal}
	var queue: Array=[goal]
	var index=0
	while index<queue.size():
		var current: Vector2i=queue[index]
		index+=1
		for delta in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next=current+delta
			if grid.is_in_boundsv(next) and not grid.is_point_solid(next) and not flow.has(next):
				flow[next]=current
				queue.append(next)

func route_target(from: Vector2, target: Vector2) -> Vector2:
	rebuild_flow(target)
	var cell=cell_at(from)
	if cell==flow_goal: return target
	if not flow.has(cell): return grid.get_point_position(cell)
	var next=grid.get_point_position(flow[cell])
	return next if segment_clear(from,next,26) else grid.get_point_position(cell)

func segment_clear(from: Vector2,to: Vector2,radius: float=0) -> bool:
	# The hull is convex: a segment between valid endpoints stays aboard.
	if not walkable(from,radius) or not walkable(to,radius): return false
	var segment_bounds=Rect2(from,Vector2.ZERO).expand(to).grow(radius+1)
	for obstacle in barriers:
		if not segment_bounds.intersects(obstacle): continue
		var rect=obstacle.grow(radius)
		var corners=[rect.position,rect.position+Vector2(rect.size.x,0),rect.end,rect.position+Vector2(0,rect.size.y)]
		for i in range(4):
			if Geometry2D.segment_intersects_segment(from,to,corners[i],corners[(i+1)%4])!=null: return false
	return true

func deck_span(y: float) -> Vector2:
	var cuts=[]
	for i in range(hull.size()):
		var a=hull[i]
		var b=hull[(i+1)%hull.size()]
		if (a.y<=y and b.y>y) or (b.y<=y and a.y>y): cuts.append(lerpf(a.x,b.x,(y-a.y)/(b.y-a.y)))
	cuts.sort()
	return Vector2(cuts[0],cuts[-1]) if cuts.size()>=2 else Vector2.ZERO

func rect_art(canvas: CanvasItem,rect: Rect2,color: Color,border: Color=Color.TRANSPARENT):
	canvas.draw_rect(Rect2(rect.position+Vector2(5,7),rect.size),Color(0,0,0,0.23))
	canvas.draw_rect(rect,color)
	if border.a>0: canvas.draw_rect(rect,border,false,2)
	canvas.draw_line(rect.position,rect.position+Vector2(rect.size.x,0),color.lightened(0.22),2)

func draw_deck(canvas: CanvasItem,origin: Vector2,zoom: float,time: float):
	canvas.draw_set_transform(origin,0,Vector2(zoom,zoom))
	var shadow=PackedVector2Array()
	for p in hull: shadow.append(p+Vector2(18,24))
	canvas.draw_colored_polygon(shadow,Color(0,0.015,0.025,0.4))
	var edge=PackedVector2Array(hull)
	edge.append(hull[0])
	canvas.draw_polyline(edge,Color(0.32,0.61,0.66,0.2+sin(time)*0.05),28,true)
	canvas.draw_colored_polygon(hull,DATA[id].floor)
	canvas.draw_polyline(edge,Color("2b2421") if id==0 else Color("d8dedb"),16,true)
	canvas.draw_polyline(edge,Color("a78356") if id==0 else Color("edf2e9"),4,true)
	if id==0:
		canvas.draw_line(Vector2(950,180),Vector2(950,35),Color("b68a53"),11,true)
		canvas.draw_line(Vector2(820,215),Vector2(950,35),Color("bfad81"),2,true)
		canvas.draw_line(Vector2(1080,215),Vector2(950,35),Color("bfad81"),2,true)
	# Plank courses are trimmed against the convex hull, including the pointed bow.
	for y in range(120,1775,24):
		var span=deck_span(y)
		if span==Vector2.ZERO: continue
		canvas.draw_line(Vector2(span.x+12,y),Vector2(span.y-12,y),DATA[id].floor.darkened(0.19),1)
		for x in range(int(span.x)+20,int(span.y)-20,140):
			var shift=(int(y/24)%2)*55
			if x+shift<span.y-12:
				canvas.draw_line(Vector2(x+shift,y),Vector2(x+shift,y+21),DATA[id].floor.darkened(0.13),1)
	# Mooring bollards and repeated rail stanchions define the deck edge.
	for y in range(320,1700,100):
		var span=deck_span(y)
		for x in [span.x+8,span.y-8]:
			canvas.draw_circle(Vector2(x,y),4,Color("c7c3ad"))
			canvas.draw_circle(Vector2(x,y)+Vector2(1,1),2,Color("343f40"))
	for floor_data in floors:
		canvas.draw_rect(floor_data.rect,floor_data.color)
		canvas.draw_rect(floor_data.rect.grow(-8),floor_data.color.lightened(0.15),false,2)
	for prop in props: draw_prop(canvas,prop,time)
	if zoom>0.3:
		for label_data in labels:
			var text: String=label_data.name
			var width=FONT.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x
			canvas.draw_string(FONT,label_data.p-Vector2(width/2,0),text,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color(0.95,0.92,0.79,0.65))
	canvas.draw_set_transform(Vector2.ZERO)

func draw_prop(c: CanvasItem,prop: Dictionary,time: float):
	var r: Rect2=prop.rect
	var p=r.position
	var size=r.size
	var mid=r.get_center()
	match prop.kind:
		"wall":
			rect_art(c,r,wall_color,wall_color.darkened(0.32))
		"mast":
			c.draw_circle(mid+Vector2(6,8),49,Color(0,0,0,0.25))
			c.draw_circle(mid,43,Color("423228"))
			c.draw_circle(mid,30,Color("b68a53"))
			c.draw_circle(mid,21,Color("68452b"))
			for end in [Vector2(-170,-75),Vector2(170,-75),Vector2(-170,75),Vector2(170,75)]: c.draw_line(mid,mid+end,Color(0.18,0.15,0.12,0.5),2,true)
		"rope":
			for radius in [7,12,17]: c.draw_arc(mid,radius,0,TAU,24,Color("c3a16b"),3,true)
		"cargo":
			rect_art(c,r,Color("6b472d"),Color("c29459"))
			c.draw_line(p+Vector2(6,6),r.end-Vector2(6,6),Color("a9804c"),8)
			c.draw_line(p+Vector2(size.x-6,6),p+Vector2(6,size.y-6),Color("a9804c"),8)
			c.draw_rect(r.grow(-6),Color("352c26"),false,2)
		"cannon":
			rect_art(c,Rect2(p+Vector2(15,0),Vector2(60,60)),Color("664d37"))
			for dy in [8,52]: c.draw_circle(p+Vector2(45,dy),12,Color("202b2b"))
			c.draw_line(p+Vector2(5,30),p+Vector2(90,30),Color("273d40"),23,true)
			c.draw_line(p+Vector2(5,25),p+Vector2(90,25),Color("62736e"),4,true)
		"hatch":
			rect_art(c,r,Color("282c2b"),Color("b79564"))
			for x in range(int(p.x)+10,int(r.end.x),18): c.draw_line(Vector2(x,p.y),Vector2(x,r.end.y),Color("74634a"),5)
		"helm":
			c.draw_circle(mid,28,Color("49382c"))
			c.draw_arc(mid,25,0,TAU,32,Color("c7a575"),6,true)
			for i in range(8): c.draw_line(mid,mid+Vector2.from_angle(TAU*i/8)*38,Color("ae8854"),5,true)
			c.draw_circle(mid,8,Color("dfc28c"))
		"chart":
			rect_art(c,r,Color("5b3c29"),Color("bf9565"))
			c.draw_rect(r.grow(-14),Color("c9bd8d"))
			c.draw_polyline(PackedVector2Array([p+Vector2(24,30),p+Vector2(70,55),p+Vector2(100,25),p+Vector2(170,60)]),Color("716b54"),3)
			c.draw_arc(p+Vector2(170,35),18,0,TAU,32,Color("a0674a"),2)
		"sail":
			var a=p+Vector2(0,40)
			c.draw_colored_polygon(PackedVector2Array([a,a+Vector2(175,85),a+Vector2(10,170)]),Color(0.81,0.76,0.59,0.28))
		"pool":
			rect_art(c,r.grow(14),Color("e3ded0"),Color("faf1dc"))
			c.draw_rect(r,Color("227a8d"))
			c.draw_rect(r.grow(-7),Color("3393a1"),false,5)
			for row in range(12):
				var y=p.y+15+row*27
				var points=PackedVector2Array()
				for i in range(17): points.append(Vector2(p.x+12+i*(size.x-24)/16,y+sin(i*0.7+time*1.4+row)*4))
				c.draw_polyline(points,Color(0.6,0.94,0.91,0.3),2,true)
			for x in [p.x+30,p.x+size.x-30]: c.draw_line(Vector2(x,p.y-8),Vector2(x,p.y+26),Color("edf1df"),5,true)
		"lounger":
			rect_art(c,r,Color("e0d8c3"),Color("9d8d76"))
			c.draw_rect(Rect2(p+Vector2(6,6),Vector2(size.x-12,30)),Color("7fadaa"))
			for y in range(40,int(size.y)-6,12): c.draw_line(p+Vector2(6,y),p+Vector2(size.x-6,y),Color("c3b9a3"),2)
		"sofa":
			rect_art(c,r,Color("e3ded1"),Color("9e9c90"))
			c.draw_rect(Rect2(p,Vector2(size.x,12)),Color("b1b9b0"))
			for i in range(1,3): c.draw_line(p+Vector2(size.x*i/3,15),p+Vector2(size.x*i/3,size.y-7),Color("aaa99b"),2)
		"table":
			rect_art(c,r,Color("8a7660"),Color("c6b999"))
			c.draw_circle(mid,9,Color("e2dfcb"))
		"bar", "reception":
			rect_art(c,r,Color("344b52") if id==1 else Color("796255"),Color("d5c5a0"))
			c.draw_rect(r.grow(-8),Color("b7ad93"))
			for i in range(4):
				c.draw_circle(p+Vector2(16+i*(size.x-32)/3,size.y+20),10,Color("668d8b"))
				c.draw_circle(p+Vector2(16+i*(size.x-32)/3,18),4,Color("c4e2d6"))
		"plant":
			c.draw_circle(mid,23,Color("d6cbb1"))
			for i in range(6): c.draw_circle(mid+Vector2.from_angle(i*TAU/6)*11,12,Color("456d53").lightened(i*0.025))
		"helipad":
			c.draw_arc(mid,74,0,TAU,48,Color(0.9,0.88,0.74,0.5),3,true)
			c.draw_string(FONT,mid+Vector2(-22,25),"H",HORIZONTAL_ALIGNMENT_LEFT,-1,64,Color(0.9,0.88,0.74,0.5))
		"bed":
			rect_art(c,r,Color("c5c7bc"),Color("e6e7da"))
			c.draw_rect(Rect2(p+Vector2(7,35),size-Vector2(14,44)),Color("8fa8ac"))
			c.draw_rect(Rect2(p+Vector2(9,9),Vector2(size.x-18,24)),Color("f0ebd7"))
			c.draw_line(p+Vector2(8,65),p+Vector2(size.x-8,65),Color("677f89"),5)
		"casino":
			rect_art(c,r,Color("513a2c"),Color("c7a06b"))
			c.draw_rect(r.grow(-9),Color("296555"))
			for i in range(4):
				c.draw_rect(Rect2(p+Vector2(22+i*25,25),Vector2(14,20)),Color("e3dbbd"))
				c.draw_circle(p+Vector2(20+i*32,size.y+15),10,Color("b0966a"))
		"piano":
			rect_art(c,r,Color("171d29"),Color("3b464d"))
			for i in range(12): c.draw_rect(Rect2(p+Vector2(10+i*7,size.y-20),Vector2(5,15)),Color("e7e3d1"))
		"bridge":
			rect_art(c,r,Color("2e414d"),Color("95aeb3"))
			for i in range(5):
				c.draw_rect(Rect2(p+Vector2(16+i*56,10),Vector2(40,27)),Color("75aea8"))
				c.draw_line(p+Vector2(20+i*56,29),p+Vector2(48+i*56,18),Color("b0dbba"),2)
		"lifeboat":
			c.draw_style_box(lifeboat_style(),r)
			c.draw_rect(r.grow(-12),Color("edd9b9"))
			for y in range(int(p.y)+25,int(r.end.y)-10,27): c.draw_line(Vector2(p.x+8,y),Vector2(r.end.x-8,y),Color("7c4e2f"),4)

func lifeboat_style() -> StyleBoxFlat:
	var style=StyleBoxFlat.new()
	style.bg_color=Color("cf854b")
	style.set_corner_radius_all(28)
	style.border_color=Color("ecc28e")
	style.set_border_width_all(3)
	return style

static func draw_ocean(c: CanvasItem,view: Vector2,camera: Vector2,time: float):
	c.draw_rect(Rect2(Vector2.ZERO,view),Color("0d303f"))
	for row in range(-1,int(view.y/44)+2):
		for col in range(-1,int(view.x/110)+2):
			var x=col*110-fposmod(camera.x*0.24+time*5,110)
			var y=row*44-fposmod(camera.y*0.24,44)
			var points=PackedVector2Array()
			for i in range(6): points.append(Vector2(x+i*13,y+sin(i*0.7+row+time*0.6)*3))
			c.draw_polyline(points,Color(0.27,0.57,0.63,0.10+0.05*sin(row+col)),1,true)
