Let's go with Option 1: Audio & Music (High Priority). I want you to handle the entire pipeline: finding/downloading the audio, organizing the folder structure, and implementing the Godot logic. 

Please execute the following steps in order:

1. FOLDER STRUCTURE: Create a new directory structure: `assets/audio/bgm/` and `assets/audio/sfx/`.

2. FETCH ASSETS: I need you to find and download royalty-free placeholder audio files (.ogg or .wav). You can use terminal commands (like curl/wget) or write and execute a quick Python script to download them from public, non-gated URLs, or generate simple placeholder beep/bloop wave files via Python.
We need:
- BGM: 1 track for the shop floor (chill), 1 track for minigames (fast-paced).
- SFX: Button click, "Issue Spawned" alert, minigame success, minigame fail, and a coin/cash sound.
Place these files in their respective folders.

3. AUDIO MANAGER: Create a new global singleton called `audio_manager.tscn` and its script `audio_manager.gd`. 
- It should have dedicated AudioStreamPlayer nodes for BGM and SFX.
- Include helper functions like `play_bgm(track_name)`, `play_sfx(sfx_name)`, and `stop_bgm()`.
- Automatically update `project.godot` to include `audio_manager.tscn` as an Autoload (Singleton) named "AudioManager", or give me the exact instructions to do it manually if you cannot safely edit project.godot.

4. INTEGRATION: Edit my existing scripts (`game_manager.gd`, `malware_minigame.gd`, `cable_management_mini_game.gd`, etc., and the shop floor script) to trigger these sounds. 
- Play the minigame BGM when a minigame starts, and revert to shop BGM when returning.
- Add success/fail SFX based on the minigame outcomes.
- Add the coin SFX when money is earned.

Take it step-by-step. Start by creating the directories and downloading/generating the placeholder audio files.