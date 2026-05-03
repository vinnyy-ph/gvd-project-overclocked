Let's tackle Phase 1 (The Upgrade Shop) and Phase 2 (Progression & Stakes) together, as they rely on each other. We need a save system to track money and upgrades, and a shop to spend it.

Please execute the following steps in order:

1. SAVE MANAGER (Autoload):
- Create `res://scripts/autoload/save_manager.gd` (and register it in `project.godot` as an Autoload). 
- It should save and load data to `user://savegame.json`. 
- Variables to track: `current_money`, `lifetime_money`, `max_days_survived`, and an `unlocked_upgrades` dictionary (to track upgrade levels).

2. GAME OVER & HIGH SCORES:
- Update `game_manager.gd`: If satisfaction reaches 0, trigger a Game Over state and transition to a new `game_over.tscn` scene (showing final stats for that run and a "Back to Menu" button).
- Update the empty `hi_score.gd` to read `lifetime_money` and `max_days_survived` from the `SaveManager` and display them on the `hi_score.tscn` UI.

3. UPGRADE SHOP SCENE:
- Create `upgrade_shop.tscn` and `upgrade_shop.gd`.
- Add 2 purchasable upgrades: "Thermal Paste" (adds time to minigames) and "Shop Decor" (slows down satisfaction decay). 
- Buying an upgrade should deduct from `current_money`, play the "coin" or "success" SFX via AudioManager, and save the state via SaveManager.

4. DAILY LOOP INTEGRATION:
- At the end of a day (after rent is deducted), the game should no longer instantly start the next day.
- Create a `daily_summary.tscn` screen showing the day's stats (Profit/Loss). 
- Include two buttons on this screen: "Visit Shop" (goes to upgrade shop) and "Start Next Day" (resumes the shop floor loop).
- Ensure the Upgrade Shop also has a "Start Next Day" button.

Please take this step-by-step. Start by creating the `save_manager.gd` and integrating the Game Over/High Score logic. Let me know when that part is done before moving on to the Shop.