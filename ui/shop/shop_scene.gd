extends Control

@onready var item_list = $ItemList

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
		"res://assets/images/shop_decorations/cashier_decos/",
		"res://assets/images/shop_decorations/pc_decos/",
		"res://assets/images/shop_decorations/chair_decos/",
		"res://assets/images/shop_decorations/floors/",
		"res://assets/images/shop_decorations/walls/",
		"res://assets/images/shop_decorations/wall_decos/",
		"res://assets/images/shop_decorations/misc_decos/"
	],
	"cashier": ["res://assets/images/shop_decorations/cashier_decos/"],
	"pc_units": ["res://assets/images/shop_decorations/pc_decos/", "res://assets/images/shop_decorations/chair_decos/"],
	"floors": ["res://assets/images/shop_decorations/floors/"],
	"walls": ["res://assets/images/shop_decorations/walls/"],
	"hanging": ["res://assets/images/shop_decorations/wall_decos/"],
	"misc": ["res://assets/images/shop_decorations/misc_decos/"]
}

var upgrades_level = {
	"cpu": 0,
	"gpu": 0,
	"monitor": 0,
	"cable": 0,
	"speed": 0,
	"pc_slot": 0
}

func _ready() -> void:
	# Enable mobile-friendly scrolling behavior for ItemList
	item_list.allow_search = false
	
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
	
	# Initialize list with "All" category first as requested
	_on_filter_pressed("all")
	
	# Initialize upgrade bars visually
	_update_all_upgrade_bars()

func _on_filter_pressed(category: String) -> void:
	item_list.clear()
	var directories = item_categories[category]
	for dir_path in directories:
		_load_items_from_directory(dir_path)

func _load_items_from_directory(dir_path: String) -> void:
	var dir = DirAccess.open(dir_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				if file_name.ends_with(".png.import"):
					var img_path = dir_path + file_name.replace(".import", "")
					var tex = load(img_path)
					if tex:
						item_list.add_item("", tex)
			file_name = dir.get_next()

func _on_upgrade_pressed(upgrade_id: String, bar_rect: TextureRect) -> void:
	if upgrades_level[upgrade_id] < 10:
		_show_buy_prompt("p1,000", func(): 
			upgrades_level[upgrade_id] += 1
			_update_upgrade_bar(upgrade_id, bar_rect)
		)

func _on_item_selected(index: int) -> void:
	_show_buy_prompt("p500", func():
		print("Bought item at index: ", index)
		# Future logic for applying the decoration goes here
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
	var level = upgrades_level[upgrade_id]
	if level == 0:
		bar_rect.texture = load("res://assets/images/upgrades/empty_bar.png")
	else:
		var tex_path = "res://assets/images/upgrades/with_values/" + str(level) + ".png"
		if FileAccess.file_exists(tex_path) or ResourceLoader.exists(tex_path):
			var tex = load(tex_path)
			if tex:
				bar_rect.texture = tex
