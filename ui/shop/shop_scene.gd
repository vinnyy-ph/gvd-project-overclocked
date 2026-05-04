extends Control

@onready var grid_container = $MainVBox/ShopScroll/GridContainer

# Define your base path and folder structure
const BASE_PATH = "res://assets/images/shop_decorations/"
const FOLDERS = [
	"cashier_decos", "chair_decos", "floors", 
	"misc_decos", "pc_decos", "walls", "wall_decos"
]

func _ready():
	load_shop_items()

func load_shop_items():
	# Loop through every folder in your predefined list
	for folder in FOLDERS:
		var dir_path = BASE_PATH + folder + "/"
		var dir = DirAccess.open(dir_path)
		
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			
			# ADDED: An array to track what we've already loaded in this folder
			var loaded_in_this_folder = [] 
			
			while file_name != "":
				if not dir.current_is_dir():
					# Clean the string for export safety
					var clean_name = file_name.replace(".import", "").replace(".remap", "")
					
					# ADDED: Check if it's a PNG AND if we haven't loaded it yet
					if clean_name.ends_with(".png") and not clean_name in loaded_in_this_folder:
						loaded_in_this_folder.append(clean_name) # Mark it as loaded
						
						var resource_path = dir_path + clean_name
						create_shop_item(resource_path)
						
				file_name = dir.get_next()
		else:
			print("Warning: Could not open directory -> ", dir_path)
func create_shop_item(image_path: String):
	# Load the image resource
	var texture = load(image_path)
	
	if texture:
		var button = TextureButton.new()
		button.texture_normal = texture
		
		# Because your images are exactly 180.62 x 168.85, Godot will size them perfectly.
		# If you ever want them to scale, set this to true and configure custom_minimum_size:
		button.ignore_texture_size = false 
		
		# Connect the press event to our function, passing the image path 
		# so we know EXACTLY which item was tapped.
		button.pressed.connect(_on_item_pressed.bind(image_path))
		
		# Add the button to the grid
		grid_container.add_child(button)

func _on_item_pressed(item_path: String):
	# This function fires whenever a specific item is tapped.
	print("Player wants to buy: ", item_path)
	
	# TODO: Extract the item name from the path and trigger your buy logic!
	# Example: Check if player has enough money, add to inventory, etc.
