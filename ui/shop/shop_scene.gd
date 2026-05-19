extends Control

@onready var item_list = $ItemList
@onready var balance_label = $ParallaxCheckeredBG/TimerLabel
@onready var return_btn = $ParallaxCheckeredBG/ReturnButton
@onready var edit_shop_btn = %EditShopBtn

# Upgrade bars and buttons
@onready var cpu_bar = $Upgrades/CPUUpgradeBar
@onready var cpu_btn = $Upgrades/CPUUpgradeBar/CPUUpgradeBtn

@onready var gpu_bar = $Upgrades/GPUUpgradeBar
@onready var gpu_btn = $Upgrades/GPUUpgradeBar/GPUUpgradeBtn2

@onready var monitor_bar = $Upgrades/MonitorUpgradeBar
@onready var monitor_btn = $Upgrades/MonitorUpgradeBar/MonitorUpgradeBtn

@onready var cable_bar = $Upgrades/CableManagementUpgradeBar
@onready var cable_btn = $Upgrades/CableManagementUpgradeBar/CableManagementUpgradeBtn

@onready var speed_bar = $Upgrades/SpeedUpgradeBar
@onready var speed_btn = $Upgrades/SpeedUpgradeBar/SpeedUpgradeBtn

@onready var pc_slot_bar = $Upgrades/PCSlotUpgradeBar
@onready var pc_slot_btn = $Upgrades/PCSlotUpgradeBar/PCSlotUpgradeBtn

# Filter Buttons
@onready var filter_all = $Buttons/AllFilterBtn
@onready var filter_cashier = $Buttons/CashierFilter
@onready var filter_pc_units = $Buttons/PCUnitsFilter
@onready var filter_floors = $Buttons/FloorsFilterBtn
@onready var filter_walls = $Buttons/WallsFilterBtn
@onready var filter_hanging = $Buttons/HangingFilterBtn
@onready var filter_misc = $Buttons/MiscFilterBtn

var buy_prompt_scene = preload("res://ui/prompts/BuyPrompt.tscn")

var item_categories = {
	"all": [
		"res://assets/images/shop_decorations/cashier_decos",
		"res://assets/images/shop_decorations/pc_decos",
		"res://assets/images/shop_decorations/chair_decos",
		"res://assets/images/shop_decorations/floors",
		"res://assets/images/shop_decorations/walls",
		"res://assets/images/shop_decorations/wall_decos",
		"res://assets/images/shop_decorations/misc_decos"
	],
	"cashier": ["res://assets/images/shop_decorations/cashier_decos"],
	"pc_units": ["res://assets/images/shop_decorations/pc_decos", "res://assets/images/shop_decorations/chair_decos"],
	"floors": ["res://assets/images/shop_decorations/floors"],
	"walls": ["res://assets/images/shop_decorations/walls"],
	"hanging": ["res://assets/images/shop_decorations/wall_decos"],
	"misc": ["res://assets/images/shop_decorations/misc_decos"]
}

const UPGRADE_MAPPING = {
	"cpu": "mid_range_cpu",
	"gpu": "graphics_upgrade",
	"monitor": "flat_monitors",
	"cable": "cable_management_kit",
	"speed": "premium_power_strip",
	"pc_slot": "shop_space"
}

const UPGRADE_COSTS = {
	"cpu": 1500,
	"gpu": 2000,
	"monitor": 1000,
	"cable": 1200,
	"speed": 800,
	"pc_slot": 2500
}

const DECO_PRICE = 500

func _ready() -> void:
	# Enable mobile-friendly scrolling behavior for ItemList
	item_list.allow_search = false
	item_list.auto_width = false
	item_list.auto_height = false
	item_list.max_columns = 0 # Let it auto-flow based on width
	item_list.same_column_width = true
	item_list.fixed_icon_size = Vector2i(160, 160) # Standardize icon size
	
	# Hide global pause button in the shop
	if has_node("/root/PauseMenu"):
		PauseMenu.pause_button.visible = false
	
	# Connect filter buttons
	filter_all.pressed.connect(_on_filter_pressed.bind("all"))
	filter_cashier.pressed.connect(_on_filter_pressed.bind("cashier"))
	filter_pc_units.pressed.connect(_on_filter_pressed.bind("pc_units"))
	filter_floors.pressed.connect(_on_filter_pressed.bind("floors"))
	filter_walls.pressed.connect(_on_filter_pressed.bind("walls"))
	filter_hanging.pressed.connect(_on_filter_pressed.bind("hanging"))
	filter_misc.pressed.connect(_on_filter_pressed.bind("misc"))
	
	# Connect upgrade buttons
	cpu_btn.pressed.connect(_on_upgrade_pressed.bind("cpu", cpu_bar))
	gpu_btn.pressed.connect(_on_upgrade_pressed.bind("gpu", gpu_bar))
	monitor_btn.pressed.connect(_on_upgrade_pressed.bind("monitor", monitor_bar))
	cable_btn.pressed.connect(_on_upgrade_pressed.bind("cable", cable_bar))
	speed_btn.pressed.connect(_on_upgrade_pressed.bind("speed", speed_bar))
	pc_slot_btn.pressed.connect(_on_upgrade_pressed.bind("pc_slot", pc_slot_bar))
	
	# Connect item list selection
	item_list.item_selected.connect(_on_item_selected)
	
	# Connect utility buttons
	return_btn.pressed.connect(_on_return_pressed)
	edit_shop_btn.pressed.connect(_on_edit_shop_pressed)
	
	# Initialize list with "All" category first as requested
	_on_filter_pressed("all")
	
	# Initialize upgrade bars visually
	_update_all_upgrade_bars()
	_update_balance_label()

func _update_balance_label():
	if GameManager.dev_mode:
		balance_label.text = "P UNLIMITED"
	else:
		balance_label.text = "P" + str(GameManager.money)

func _on_filter_pressed(category: String) -> void:
	item_list.clear()
	if not item_categories.has(category):
		return
		
	var directories = item_categories[category]
	for dir_path in directories:
		_load_items_from_directory(dir_path, category)

func _load_items_from_directory(dir_path: String, category: String) -> void:
	var dir = DirAccess.open(dir_path)
	if dir:
		var files = dir.get_files()
		var added_files = [] # Track added files to avoid duplicates (e.g. file.png and file.png.import)
		
		for file_name in files:
			# In exported builds, original files might not exist, but .import or .remap files do
			if file_name.ends_with(".png") or file_name.ends_with(".png.import") or file_name.ends_with(".png.remap"):
				var clean_name = file_name.replace(".import", "").replace(".remap", "")
				if clean_name in added_files:
					continue
					
				var img_path = dir_path.path_join(clean_name)
				var tex = load(img_path)
				if tex:
					added_files.append(clean_name)
					var idx = item_list.add_icon_item(tex)
					item_list.set_item_metadata(idx, {
						"path": img_path,
						"category": _get_category_from_path(dir_path),
						"name": clean_name.replace(".png", "")
					})
					
					# Mark as owned visually using icon modulation
					var is_active = false
					if category == "floors":
						is_active = (img_path == SaveManager.current_floor)
					elif category == "walls":
						is_active = (img_path == SaveManager.current_wall)
					else:
						is_active = (img_path in SaveManager.owned_decorations)
						
					if is_active:
						item_list.set_item_icon_modulate(idx, Color(0.5, 1, 0.5, 1.0)) # Green tint

func _get_category_from_path(path: String) -> String:
	if "cashier_decos" in path: return "cashier_decos"
	if "pc_decos" in path: return "pc_decos"
	if "chair_decos" in path: return "chair_decos_actual"
	if "floors" in path: return "floors"
	if "walls" in path: return "walls"
	if "wall_decos" in path: return "wall_decos"
	if "misc_decos" in path: return "misc_decos"
	return "misc_decos"

func _on_upgrade_pressed(upgrade_id: String, bar_rect: TextureRect) -> void:
	var save_key = UPGRADE_MAPPING[upgrade_id]
	var current_level = SaveManager.unlocked_upgrades.get(save_key, 0)
	
	if current_level < 10:
		var cost = UPGRADE_COSTS[upgrade_id] * (current_level + 1)
		_show_buy_prompt("p" + str(cost), func(): 
			if GameManager.money >= cost or GameManager.dev_mode:
				GameManager.money -= cost
				SaveManager.unlocked_upgrades[save_key] = current_level + 1
				SaveManager.save_game()
				_update_upgrade_bar(upgrade_id, bar_rect)
				_update_balance_label()
				AudioManager.play_sfx("coin")
		)

func _on_item_selected(index: int) -> void:
	var data = item_list.get_item_metadata(index)
	var img_path = data["path"]
	var category = data["category"]
	
	if img_path in SaveManager.owned_decorations or img_path == SaveManager.current_floor or img_path == SaveManager.current_wall:
		# If it's already active, just return. If it's a generic decoration already owned, return.
		if category != "floors" and category != "walls":
			return 
		
	_show_buy_prompt("p" + str(DECO_PRICE), func():
		if GameManager.money >= DECO_PRICE or GameManager.dev_mode:
			GameManager.money -= DECO_PRICE
			
			if category == "floors":
				SaveManager.current_floor = img_path
			elif category == "walls":
				SaveManager.current_wall = img_path
			else:
				SaveManager.owned_decorations.append(img_path)
				
			SaveManager.save_game()
			_update_balance_label()
			
			# Refresh list to update "OWNED" status (modulate) for the whole category if floor/wall
			if category == "floors" or category == "walls":
				_on_filter_pressed(category)
			else:
				# Update single item in list visually
				item_list.set_item_icon_modulate(index, Color(0.5, 1, 0.5, 1.0)) # Green tint
				
			AudioManager.play_sfx("coin")
	)

func _show_buy_prompt(price: String, on_confirm: Callable) -> void:
	var prompt = buy_prompt_scene.instantiate()
	add_child(prompt)
	prompt.set_price(price)
	prompt.confirmed.connect(on_confirm)

func _update_all_upgrade_bars() -> void:
	_update_upgrade_bar("cpu", cpu_bar)
	_update_upgrade_bar("gpu", gpu_bar)
	_update_upgrade_bar("monitor", monitor_bar)
	_update_upgrade_bar("cable", cable_bar)
	_update_upgrade_bar("speed", speed_bar)
	_update_upgrade_bar("pc_slot", pc_slot_bar)

func _update_upgrade_bar(upgrade_id: String, bar_rect: TextureRect) -> void:
	var save_key = UPGRADE_MAPPING[upgrade_id]
	var level = SaveManager.unlocked_upgrades.get(save_key, 0)
	
	if level == 0:
		bar_rect.texture = load("res://assets/images/upgrades/empty_bar.png")
	else:
		var tex_path = "res://assets/images/upgrades/with_values/" + str(level) + ".png"
		if FileAccess.file_exists(tex_path) or ResourceLoader.exists(tex_path):
			var tex = load(tex_path)
			if tex:
				bar_rect.texture = tex

func _on_return_pressed():
	if GameManager.previous_scene != "":
		get_tree().change_scene_to_file(GameManager.previous_scene)
	else:
		get_tree().change_scene_to_file("res://ui/daily_summary/daily_summary.tscn")

func _on_edit_shop_pressed():
	get_tree().change_scene_to_file("res://core/shop_floor/shop_floor_scrollable_editable.tscn")
