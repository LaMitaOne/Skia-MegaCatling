# Skia-MegaCatling
A feature-rich 2D Sci-Fi shooter/platformer built entirely with Delphi FMX and Skia4Delphi.
      
MegaCatling evolved from the original SkiaPlatformer base into a standalone action-platformer experience. It takes the core engine and injects it with modern platformer mechanics, advanced enemy AI, dynamic level hazards, and a seamless game flow.     
    
<img width="1920" height="1080" alt="_screenshot" src="https://github.com/user-attachments/assets/9239ac9e-7a1a-4143-93b5-018bc33e98fd" />
     
🎮 Gameplay Features     
     
     Advanced Movement: Double jumps, wall sliding, and wall jumping! Tight movement with acceleration, friction, and "squash & stretch" animations for juicy feedback.
     Procedural Generation: Every level is randomly generated. It ensures gaps are jumpable, places moving platforms over pits, spawns floating "Sky Islands" with loot, and places the exit gate.
     Seamless Loading: Screen fades to black, level generates, and fades in. No hitches or UI freezes.
     Dynamic Camera: Smooth X/Y scrolling that follows the player, keeping the action centered while clamping to map boundaries.
     Enemy Variety:
         Walkers: Patrol platforms, turn around at ledges, and shoot at you.
         Dogs: Aggressive chargers that lunge when you get too close.
         Flyers (Drones): Hover and maintain distance. 
     Hazards & Items: Moving platforms, conveyor belts, explosive crates, HP boosts, and temporary Damage boosts.
     Audio & Particles: Procedural particle explosions, muzzle flashes, running dust, and royalty-free sound effects.
     Visual Filters: Toggle between standard rendering, retro film grain, and a VHS/Cuphead-style vintage overlay.
    
🕹️ Controls    
    
     Move: A / D or Left / Right Arrows
     Jump / Double Jump / Wall Jump: W, Space, or Up Arrow
     Crouch: S or Down Arrow
     Shoot: E
     Pause Menu: Escape
     Reset Level: R (While paused)
     Switch Visual Filters: F
    
🛠️ Technical Details    
    
     Renderer: Pure Skia Canvas (No Game Engine, no FMX shapes). Procedural textures generated via Skia Surfaces/Shaders.
     Threading: Physics runs on a background thread for consistent FPS, synchronized safely with the main rendering thread via TCriticalSection.
     State Machine: Robust game states (gsTitle, gsLoading, gsPlaying, gsDead, gsWin) prevent logic errors during transitions.
     Collision: AABB (Axis-Aligned Bounding Box) tile-based collision detection, resolving X and Y axes separately to prevent "catching" on edges.

📦 What's Inside

     SkiaPlatformer.pas: The complete game engine in a single file. Clean, didactically commented, and ready for you to expand into your own MegaMan-style game.
     Sample project and zipped exe included.
    
🚀 Getting Started     
    
    Open the project in RAD Studio (Delphi).
    Ensure you have the Skia4Delphi library installed via GetIt.
    Run and play!
    
📜 Version History    
   
v 0.1:       
    - Advanced Player Physics: Implemented Double Jump, Wall Sliding, and Wall Jumping. Reworked gravity for better air control. Added "Squash & Stretch" animations for jumping and landing.     
    - New Enemy AI System:     
         Walkers: Now detect ledges (won't walk off cliffs) and shoot projectiles at the player.     
         Dogs: New aggressive charger enemy that lunges when the player is in range.     
         Flyers: Reworked drone AI. They maintain distance, break aggro if the player jumps too high, and leash back to their spawn point.     
    - Level Generation Overhaul: Added Moving Platforms (spawn over pits), Conveyor Belts, and floating "Sky Islands" containing pickups.     
    - Items & Upgrades: Added collectible crates that grant temporary Damage Boosts or restore HP.     
    
License    
     
MIT License - Do whatever you want with it. Credits appreciated but not required.    
    
Royalty free audios from https://www.pavsmusic.com/free-sound-pack-kits/      
       
More Gaming repos:   
     
🎮 Skia4Delphi Games (each one file, no ext engine):    
2D Platformer https://github.com/LaMitaOne/Skia_PlatformerGame    
2D Lemmings/Worms/Portal/Touch hybrid https://github.com/LaMitaOne/SkiaLemmings    
2D Side-scrolling space shooter https://github.com/LaMitaOne/SkiaStarPatrols    
2.5D C&C style isometric rts https://github.com/LaMitaOne/Skia-RTS-Game    
2.5D Isometric cat game https://github.com/LaMitaOne/Skia-A-Cats-Life    
2.5D Raycasting doom base https://github.com/LaMitaOne/SkiaDoomBase    
Tetris clone https://github.com/LaMitaOne/Skiatris    
    
🎮 Game components FMX:    
MRX Gamepad Core https://github.com/LaMitaOne/MRX-Gamepad-Core    

More Catlings...    
Skia Desktop Pet https://github.com/LaMitaOne/SkiaDesktopPetBase    
