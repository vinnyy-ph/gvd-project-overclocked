extends Control

@onready var daily_tip_label: Label = $DailyTip/MarginContainer/DailyTipText

var tips: Array = [
	"Customer satisfaction is the lifeblood of your business. Happy customers are more likely to accept higher repair costs and will frequently return with more lucrative projects. Always prioritize quality service to maintain a high reputation and ensure long-term profitability.",
	"Keep a very close eye on your daily expenses. Rent and electricity bills are fixed costs that add up quickly regardless of how many customers you serve. Efficiently managing your time and resources is the only way to stay in the green and avoid a surprise bankruptcy.",
	"Expanding your shop space is a critical long-term investment. While it costs a significant amount upfront, having more workbenches allows you to handle multiple customers simultaneously. Don't let your business stagnate—growth is necessary to handle the increasing complexity of modern tech.",
	"Thermal paste might seem like a small detail, but it is absolutely essential for efficient heat transfer between the CPU and its cooler. Over time, old paste dries out and loses its effectiveness, leading to thermal throttling and eventual hardware failure. Always use high-quality compound!",
	"Good cable management is about more than just aesthetics; it's a vital part of system maintenance. Tidy cables allow for unobstructed airflow throughout the chassis, which keeps internal temperatures low and extends the lifespan of every component inside the computer.",
	"Malware is becoming increasingly sophisticated and can hide in system files or even the boot sector. When a customer reports 'slow performance' or 'weird pop-ups,' don't just delete a few files. Perform a comprehensive deep scan to ensure the entire system is truly clean and secure.",
	"Data is often more valuable than the hardware it sits on. Always advise your customers on the importance of regular backups to external drives or cloud storage. A catastrophic hard drive failure is much easier to handle when you can simply restore a recent image rather than attempting recovery.",
	"The DEBUGGING (Blue Screen of Death) is a critical system error that indicates a serious problem with either your hardware or your drivers. To fix it, you'll need to analyze the stop code, check for recent changes, and systematically test your components to find the specific root cause of the instability.",
	"Networking issues are frequently caused by simple physical layer failures. Before you start reconfiguring complex IP settings or resetting the router, always check for loose Ethernet cables, damaged ports, or local interference that might be disrupting the signal. Start simple, then move up.",
	"Overclocking can provide a significant performance boost for free, but it also generates massive amounts of extra heat and can lead to system instability. Always monitor your temperatures closely and use stress-testing software to ensure your new clock speeds are stable under full load.",
	"Static electricity is a silent killer of modern electronics. Even a small discharge that you can't feel can permanently damage the sensitive circuits on a motherboard or RAM stick. Always use an anti-static wrist strap or regularly ground yourself while working inside a computer.",
	"Investing in CPU upgrades for your workshop will significantly increase your efficiency. Faster processors allow you to run diagnostic tools and repair scripts much more quickly, giving you precious extra seconds to handle multiple technical issues during a busy work day.",
	"Upgrading to flat monitors in your shop does more than just modernize the look. High-quality displays are easier for customers to read and interact with, which significantly reduces the satisfaction penalty they feel when they have to wait for your attention during peak hours.",
	"Premium graphics card upgrades for your demo units act as a magnet for high-paying enthusiasts. By showcasing what high-end hardware can do, you'll attract a more demanding but much wealthier clientele who are willing to pay top dollar for expert assembly and troubleshooting.",
	"A messy or dusty motherboard is a major safety hazard. Dust is often conductive and can trap moisture, which eventually leads to short circuits and permanent hardware damage. Use compressed air and isopropyl alcohol to keep your customers' systems running clean and cool.",
	"Never underestimate the importance of saving your progress. Whether you're working on a complex software fix or managing the shop's finances, unexpected power surges or system crashes can wipe out hours of hard work. Develop the habit of hitting that save button frequently!",
	"Sometimes, what a customer calls a 'bug' is actually an undocumented feature or a misunderstanding of how the software works. Taking the time to educate your clients on their tools can prevent future support calls and build a stronger, more trusting professional relationship.",
	"When you're faced with an incredibly complex technical problem that makes no sense, remember the golden rule of IT: have you tried turning it off and on again? A simple power cycle clears the RAM and resets the hardware state, often resolving bizarre glitches instantly.",
	"Better hardware doesn't just mean faster computers; it means better tools for your shop. High-speed diagnostic kits, professional soldering stations, and advanced recovery software will all contribute to a faster turnaround time and a more professional service.",
	"Focusing on high satisfaction levels is the most effective way to climb the global hi-score leaderboards. While money is important for upgrades, your overall reputation as a master technician is what truly defines your success in the competitive world of computer repair.",
	"Solid State Drives (SSDs) are one of the most impactful upgrades you can offer a customer. Replacing an old mechanical hard drive with an SSD will make an entire system feel brand new, significantly reducing boot times and making applications launch almost instantly.",
	"Proper ventilation is the key to a quiet computer. If a customer complains about loud fan noise, it's often because their system is overheating and the fans are spinning at maximum speed to compensate. Cleaning the heatsinks and improving intake will usually fix the noise issue.",
	"When building a new PC, the Power Supply Unit (PSU) is the one component you should never cheap out on. A low-quality PSU can have unstable voltage rails and lack proper protection circuits, which means a single failure could potentially fry every other expensive component in the build.",
	"RAM issues can be some of the hardest problems to diagnose because they often cause random, intermittent crashes. If a system is behaving unpredictably, run a dedicated memory stress test overnight to check for bad cells or timing errors that might be causing the instability.",
	"Managing a busy shop floor requires excellent multitasking skills. Try to prioritize quick fixes like simple software updates or cable checks so you can clear up space for more complex, time-consuming hardware repairs that require your undivided attention.",
	"Always keep your diagnostic software up to date. New hardware is released every month, and older tools might not properly recognize or test the latest CPUs and GPUs. Staying current with your software ensures you can provide accurate advice to every customer.",
	"The 'click of death' coming from a hard drive is a sign of imminent mechanical failure. If you hear a repetitive clicking sound, stop using the drive immediately and prioritize data recovery. Every second the drive stays powered on increases the risk of permanent data loss.",
	"A well-organized inventory will save you a massive amount of time during the day. Knowing exactly where your spare parts, cables, and tools are located means you can get straight to work on a repair instead of wasting valuable time searching through messy drawers.",
	"Don't forget to take care of yourself too! Managing a high-pressure computer shop can be stressful. Take a moment between customers to stay organized and plan your next upgrade. A calm and prepared technician is a much more effective problem solver.",
	"Word of mouth is a powerful tool in a local community. Providing a little bit of extra value—like cleaning a customer's keyboard for free—can lead to glowing recommendations and a steady stream of new business that you don't have to spend a cent on marketing for."
]

var current_tip_index: int = -1

func _ready() -> void:
	PauseMenu.pause_button.visible = false
	AudioManager.play_bgm("shop")
	_start_tip_cycle()

func _start_tip_cycle() -> void:
	while true:
		_display_next_tip()
		# Wait for the tip to be displayed and then for a reading interval
		# The interval depends on the length of the tip
		var tip_text = tips[current_tip_index]
		var wait_time = 3.0 + (tip_text.length() * 0.05) # Base 3s + 0.05s per char
		await get_tree().create_timer(wait_time).timeout

func _display_next_tip() -> void:
	current_tip_index = (current_tip_index + 1) % tips.size()
	var tip_text = ">_Daily Tip !\n" + tips[current_tip_index]
	
	daily_tip_label.text = tip_text
	daily_tip_label.visible_ratio = 0.0
	
	var duration = tip_text.length() * 0.03 # 0.03s per character for typewriter speed
	var tween = create_tween()
	tween.tween_property(daily_tip_label, "visible_ratio", 1.0, duration).set_trans(Tween.TRANS_LINEAR)

func _on_continue_button_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/profile_selection/profile_selection.tscn")

func _on_hi_score_button_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/leaderboard/leaderboard.tscn")

func _on_tutorial_button_pressed():
	GameManager.in_tutorial = true
	GameManager.new_game()
	get_tree().change_scene_to_file("res://core/shop_floor/shop_floor_scrollable_tutorial.tscn")

func _on_settings_button_pressed() -> void:
	GameManager.previous_scene = "res://ui/main_menu_v2/MainMenuV2.tscn"
	get_tree().change_scene_to_file("res://ui/settings/settings.tscn")

func _on_exit_button_pressed() -> void:
	_show_exit_confirmation()

func _show_exit_confirmation() -> void:
	var exit_prompt_scene = load("res://ui/pause/ExitPrompt.tscn")
	var exit_prompt = exit_prompt_scene.instantiate()
	add_child(exit_prompt)

func _on_new_game_button_pressed() -> void:
	var name_prompt_scene = load("res://ui/prompts/NamePrompt.tscn")
	var name_prompt = name_prompt_scene.instantiate()
	add_child(name_prompt)
	name_prompt.confirmed.connect(_on_name_prompt_confirmed)

func _on_name_prompt_confirmed(p_name: String, p_gender: String) -> void:
	# Use the next available ID for unlimited profile creation
	var target_id = SaveManager.get_next_available_id()
	
	# Create new profile and initialize game state
	SaveManager.create_new_profile(target_id, p_name, p_gender)
	GameManager.new_game()
	
	# Transition to story flow
	get_tree().change_scene_to_file("res://NewGameStoryFlow.tscn")
