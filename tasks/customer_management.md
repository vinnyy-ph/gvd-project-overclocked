# Task: Refactor and Implement Customer Management System

## System Overview
I currently have a shop floor scene with multiple PCs that can be locked/unlocked and occupied/unoccupied. The system needs to transition from global random event spawning to a structured, customer-driven gameplay loop.

## Detailed Requirements

### 1. Customer Spawning
- Customers must spawn randomly over time in a designated waiting area node.
- Spawning must be handled in a controlled loop (e.g., using a `Timer` node or coroutine), avoiding per-frame randomness (`_process`).

### 2. Drag-and-Drop Interaction
- The player must be able to drag a waiting customer and drop them onto an available PC.
- Implement this using appropriate Godot 4 input handling (e.g., `_gui_input`, `_input`, or `Area2D` input events depending on the specific node types used).

### 3. Assignment Constraints
A customer can only be successfully assigned to a PC if:
- The PC is currently **unlocked**.
- The PC is **not occupied** by another customer.

### 4. Customer State Machine
Each customer must implement clear internal states:
- `WAITING`
- `MOVING_TO_PC`
- `USING_PC`
- `EXITING`

**Expected Behavior:**
- **On assignment:** Switch to `MOVING_TO_PC` and translate toward the PC.
- **On arrival:** Visually sit down and switch to `USING_PC`.
- **On completion:** Visually stand up and switch to `EXITING`.

### 5. Movement
- Customers should visually move from the waiting area to the assigned PC.
- Use an appropriate movement method for a 2D scene (e.g., `move_toward`, `NavigationAgent2D`, or `Tween` interpolation based on the current scene structure).
- The movement script of the 2dsprite is in 'res://core/shop_floor/animated_sprite_2d.gd', but you may need to refactor it to accommodate the new state machine and movement logic.

### 6. Revenue System
While a customer is in the `USING_PC` state:
- Call `game_manager` to increment money periodically (e.g., +1 money every 2 seconds).
- This accumulation must be strictly **timer-based** (using `Timer` nodes or delta accumulation), not tied to frame rates.

### 7. Issue/Event System
- Completely remove the old global random issue spawning logic.
- New issue constraints:
  - Issues can **only** occur on occupied PCs.
  - Issues must be triggered by the customer currently using that specific PC.

### 8. Customer Exit Flow
Each customer must have a randomized session duration. When their timer finishes:
1. Stand up from the PC.
2. Leave the PC and exit the shop area.
3. Free/queue_free the customer node.
4. Mark the PC as unoccupied and available again.

---

## Files to Modify
- `shop_floor_scrollable.gd` (Main shop and interaction logic)
- `game_manager.gd` (Global currency, timers, and state systems)
- `shop_floor_scrollable.tscn` (Scene node structure)

---

## Assumptions (IMPORTANT)
If anything about the current implementation is unclear:
- Make reasonable assumptions regarding the scene tree and node structure.
- **Crucial:** You must clearly state all assumptions about node paths and names before providing any code. 

## Output Requirements
- Provide updated, complete, and functional GDScript code for the required files.
- Clearly separate the code changes file by file.
- Add concise comments explaining key logic, especially state transitions and timer integrations.
- Keep the code modular, strictly typed where applicable, and highly maintainable.

## Optional (If Applicable)
- Suggest concrete improvements to the node structure in `shop_floor_scrollable.tscn` if the current setup limits the drag-and-drop or state machine implementation.