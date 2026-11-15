extends SceneTree
const Model=preload("res://State.gd")
const Arena=preload("res://Arena.gd")
const ShipMap=preload("res://ShipMap.gd")
func _initialize(): call_deferred("run")
func run():
	for id in range(3):
		var state=Model.new()
		state.cleared_chapters=id
		state.selected_map=id
		state.start()
		var a=Arena.new()
		a.state=state
		a.size=Vector2(480,900)
		root.add_child(a)
		a.set_process(false)
		a.spawn_clock=1000
		assert(a.ship.walkable(a.player,17))
		var destinations=[]
		destinations.append_array(a.ship.ammo_points)
		destinations.append_array(a.ship.exit_points)
		for site in a.ship.cache_points: destinations.append(site.p)
		for point in destinations:
			assert(a.ship.walkable(point,17),"Unwalkable destination ship %d: %s" % [id,point])
			var path=a.ship.grid.get_point_path(a.ship.cell_at(a.ship.spawn),a.ship.cell_at(point))
			assert(not path.is_empty(),"Unreachable destination ship %d: %s" % [id,point])
			# Walk the actual collision path from entry through the whole vessel.
			var pos=a.ship.spawn
			for step in path:
				for j in range(80):
					if pos.distance_to(step)<4: break
					pos=a.move_with_walls(pos,(step-pos).normalized()*3,17)
				assert(pos.distance_to(step)<5,"Collision route blocked %d at %s" % [id,step])
		# Actors cannot leave the hull, even under long knockbacks.
		var before=a.player
		var edge=a.move_with_walls(before,Vector2(3000,0),17)
		assert(a.ship.walkable(edge,17) and edge.x<1400)
		# A central solid prop blocks bullets and walking.
		var solid=a.ship.barriers[-1]
		assert(not a.clear_shot(solid.get_center(),solid.get_center()+Vector2(100,0)))
		# Pursuer routes from stern to the deepest salvage through furniture/doorways.
		var enemy_pos=a.ship.spawn
		var goal=a.ship.cache_points[-1].p
		for i in range(6000):
			if enemy_pos.distance_to(goal)<8: break
			enemy_pos=a.move_with_walls(enemy_pos,(a.path_target(enemy_pos,goal)-enemy_pos).normalized()*3,24)
		assert(enemy_pos.distance_to(goal)<8,"Enemy route blocked ship %d at %s" % [id,enemy_pos])
		# Enemy spawn locations always lie on traversable deck, including near edges.
		for point in [a.ship.spawn,a.ship.cache_points[-1].p]:
			a.player=point
			a.enemies=[]
			for i in range(20): a.spawn_enemy(i%4==0)
			assert(a.enemies.size()>0)
			for enemy in a.enemies: assert(a.ship.walkable(enemy.p,enemy.radius))
		a.enemies=[]
		a.player=a.crates[0].p
		var ammo=a.ammo
		a.simulate(0.01,Vector2.ZERO)
		assert(a.ammo==ammo+24 and a.crates[0].used)
		a.simulate(0.01,Vector2.ZERO)
		assert(a.ammo==ammo+24)
		a.player=a.caches[-1].p
		a.request_search()
		assert(a.searching>=0)
		a.simulate(0.8,Vector2.ZERO)
		a.player=a.ship.spawn
		a.simulate(0.01,Vector2.ZERO)
		assert(a.searching==-1 and not a.caches[-1].used)
		a.player=a.caches[-1].p
		a.request_search()
		a.simulate(1.61,Vector2.ZERO)
		assert(a.caches[-1].used and a.cargo>=360 and a.parts==3)
		var value=a.cargo
		a.request_search()
		assert(a.searching==-1 and a.cargo==value)
		a.checkpoint()
		var saved=Model.new()
		saved.load_game()
		assert(saved.selected_map==id and saved.run_data.caches[-1].used and saved.run_data.crates[0].used)
		print("PASS ship ",id,": all destinations reachable, hull/solid collision, pursuit, spawn safety, ammo/cache one-shot, search cancellation, persistence")
		a.free()
		await process_frame
	quit()
