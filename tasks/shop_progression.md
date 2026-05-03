This is a great analysis! Let's align the game with the specification, but FIRST, a critical rule: DO NOT switch to C# or C++. We are keeping the entire project in GDScript for this prototype. Ignore that discrepancy in the spec.

Let's implement the Shop Overhaul and the Progression mechanics. Please execute the following steps in order:

1. UPGRADE SHOP OVERHAUL:
- Update `save_manager.gd` and the Upgrade Shop UI/Script to include the exact items from the spec: 
  * Flat Monitors (₱5,000)
  * Mid-Range CPU (₱7,500)
  * Graphics Upgrade (₱9,000)
  * Premium Power Strip (₱3,000)
  * Cable Management Kit (₱4,500)
- Add "Shop Space" upgrades to unlock additional PC slots.
- Ensure the UI scales nicely to fit these new items.

2. PC SLOT PROGRESSION:
- Update `shop_floor_scrollable.gd` and the shop scene. The player should only start with 2 active PC stations.
- The remaining 6 stations should be hidden or visually disabled.
- Tie these slots directly to the "Shop Space" upgrades from the SaveManager. When a player buys a space upgrade, it permanently unlocks that PC station on the floor.

3. DYNAMIC EXPENSES & DECAY:
- Update `game_manager.gd` to include a slow Satisfaction Decay over time whenever an issue is active on the floor but hasn't been clicked yet.
- Update the End-of-Day logic to calculate proper Operational Expenses (Electricity + Rent) instead of the flat ₱20, scaling slightly based on how many PC slots are unlocked.

Take this step-by-step. Start with Step 1 and Step 2 so we get the shop and PC slots working perfectly before moving to the math in Step 3.