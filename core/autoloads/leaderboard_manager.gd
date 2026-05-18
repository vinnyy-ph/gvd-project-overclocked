extends Node

const LEADERBOARD_PATH = "user://leaderboard.json"
const MAX_ENTRIES = 100

var entries: Array = []

func _ready():
	load_leaderboard()
	if entries.is_empty():
		_create_mock_data()

func load_leaderboard():
	if not FileAccess.file_exists(LEADERBOARD_PATH):
		entries = []
		return
		
	var file = FileAccess.open(LEADERBOARD_PATH, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		if json.parse(json_string) == OK:
			entries = json.data
			# Ensure entries are sorted
			sort_entries()

func save_leaderboard():
	var json_string = JSON.stringify(entries)
	var file = FileAccess.open(LEADERBOARD_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()

func add_entry(player_name: String, day: int, money: float, pc_slots: int):
	var new_entry = {
		"name": player_name,
		"day": day,
		"money": money,
		"pc_slots": pc_slots,
		"score": (day * 1000) + money # Simple scoring formula
	}
	
	entries.append(new_entry)
	sort_entries()
	
	if entries.size() > MAX_ENTRIES:
		entries.resize(MAX_ENTRIES)
		
	save_leaderboard()

func sort_entries():
	entries.sort_custom(func(a, b): return a["score"] > b["score"])

func get_entries() -> Array:
	return entries

func _create_mock_data():
	var mock_names = ["ApexTech", "ByteMaster", "CyberSurge", "DataDrift", "EchoNode", "FluxCore", "GridGuard", "HashHustle", "IonIntel", "JoltJoint", "KiloKey", "LinkLayer", "MetaMicro", "NanoNet", "OrbitOps", "PulsePower", "QuarkQuant", "RayRoot", "SyncStack", "TeraTask"]
	for i in range(100):
		var name = mock_names[i % mock_names.size()] + str(i + 1)
		var day = randi_range(1, 100)
		var money = randf_range(100, 100000)
		var pc_slots = randi_range(2, 6)
		add_entry(name, day, money, pc_slots)
	save_leaderboard()
