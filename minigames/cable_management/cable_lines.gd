extends Node2D

func _draw():
	var root = get_parent().get_parent()
	if root == null or not "connected" in root:
		return
		
	# Draw wires for every cable in the connected dictionary
	for key in root.connected.keys():
		draw_dynamic_wire(root, key, Color(0.3, 0.6, 1.0), 10.0)

func draw_dynamic_wire(root, key: String, wire_color: Color, width: float):
	# The source (base) is the fixed HDMI image center
	var start_point = root.get_left_anchor(key)
	# The end point is the tip (either mouse pos or port pos)
	var end_point = root.get_cable_tip(key)
	
	# Only draw if the wire is actually being pulled or is connected
	if start_point.distance_to(end_point) < 5:
		return
		
	# Calculate a more realistic wire path
	var dist = start_point.distance_to(end_point)
	var sag = dist * 0.4 # Higher multiplier = more floppy wire
	
	# Control points to create the "bend" in the wire
	var cp1 = start_point + Vector2(dist * 0.2, sag)
	var cp2 = end_point + Vector2(-dist * 0.2, sag)
	
	# Draw main thick wire
	draw_bezier_curve(start_point, cp1, cp2, end_point, wire_color, width)
	# Draw a slightly lighter highlight for 3D depth
	draw_bezier_curve(start_point, cp1, cp2, end_point, wire_color.lightened(0.4), width * 0.4)
	
	# Draw a small "plug" at the tip so the player sees what they are dragging
	draw_circle(end_point, 10.0, Color(0.1, 0.1, 0.1))
	draw_circle(end_point, 6.0, Color(0.8, 0.8, 0.8))

func draw_bezier_curve(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, color: Color, width: float):
	var points = PackedVector2Array()
	var steps = 30 # High resolution for smooth wires
	for i in range(steps + 1):
		var t = float(i) / steps
		var q0 = p0.lerp(p1, t)
		var q1 = p1.lerp(p2, t)
		var q2 = p2.lerp(p3, t)
		var r0 = q0.lerp(q1, t)
		var r1 = q1.lerp(q2, t)
		var p = r0.lerp(r1, t)
		points.append(p)
	
	draw_polyline(points, color, width, true)
