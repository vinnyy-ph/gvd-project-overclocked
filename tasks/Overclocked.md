# Development Specification: Overclocked - Computer Shop Simulator

This document outlines the core technical requirements, gameplay mechanics, and system architecture for the development of the **Computer Shop Simulator** based on the approved project proposal [cite: 3].

---

## 1. Core Gameplay & Progression Loop
The game is a 2D side-scrolling management simulator where the player acts as a shop owner/technician in a local cybercafe environment [cite: 54, 84].

### Primary Loop:
1.  **Customer Management**: Patrons occupy PCs for a maximum of three in-game minutes [cite: 84].
2.  **Incident Response**: Sudden technical anomalies (hardware/software) trigger mini-games that must be solved before the customer's satisfaction meter depletes [cite: 84, 97].
3.  **Financial Settlement**: Collect income based on satisfaction; daily operational expenses (electricity) are automatically deducted [cite: 84, 91].
4.  **Reinvestment**: Use profits in the **Upgrade Shop** to modernize hardware and scale the business [cite: 84, 92].

### Special Mechanics:
* **Frenzy Mode**: Applies a **1.5x multiplier** to customer satisfaction when activated [cite: 84].
* **Time Constraints**: All troubleshooting tasks are time-limited to simulate high-pressure environments [cite: 97, 119].

---

## 2. Technical Troubleshooting Mini-Games
The core of the "Playable Gameplay" consists of the following interactive modules:

| Mini-Game | Trigger Condition | Core Interaction |
| :--- | :--- | :--- |
| **Cable Management** | Hardware connection drops [cite: 94]. | Reconnect loose wires to matching color-coded slots on the PC back [cite: 94, 98]. |
| **Motherboard Plug-in** | Hardware assembly/repair [cite: 94]. | Correctly install and secure CPU and RAM onto the motherboard [cite: 94, 98]. |
| **Visitor Login Support** | Software assistance request [cite: 94]. | Accurately type a complex alphanumeric string to resolve login issues [cite: 94, 102]. |
| **Network Connection** | Wi-Fi/Internet outage [cite: 94]. | Cisco Packet Tracer-inspired link restoration between PC and server [cite: 94, 102]. |
| **System Recovery (BSOD)** | Severe system error [cite: 94]. | Follow a step-by-step diagnostic sequence to restore the PC [cite: 94, 102]. |
| **Malware & System Bugs** | Virus or logic threats [cite: 94]. | Arcade-style "whack-a-mole"/shooter to clear viruses; logic puzzles for bugs [cite: 94, 103]. |

---

## 3. Upgrade Shop & Scalability
Players reinvest currency into four primary categories [cite: 84, 92]:

* **PC Hardware**:
    * **Flat Monitors (P5,000)**: Replaces CRT; increases satisfaction by +15% [cite: 197, 199].
    * **Mid-Range CPU (P7,500)**: Reduces BSOD and system error frequency by -20% [cite: 205, 207].
    * **Graphics Upgrade (P9,000)**: Enables heavy gaming; customers pay +10% more [cite: 215, 216].
* **Shop Management**:
    * **Premium Power Strip (P3,000)**: Reduces 'Power Plug' issues shop-wide [cite: 209, 211].
    * **Cable Management Kit (P4,500)**: Makes cable puzzles faster and less frequent [cite: 218, 220].
* **Shop Space**: Unlock additional computer slots to accommodate more customers [cite: 84].
* **Aesthetics**: Improve interior visuals to enhance shop appeal [cite: 84].

---

## 4. Technical Architecture (Stack)
The development team will utilize the following tools [cite: 126-134]:

* **Game Engine**: **Godot** (Node-based architecture, 2D rendering engine) [cite: 134].
* **Programming**: **C#** for rapid gameplay scripting and **C++** for performance-critical systems [cite: 134].
* **Assets & UI/UX**:
    * **Figma**: UI/UX wireframing and navigational flow [cite: 128, 130].
    * **Photoshop**: Raster graphics for character sprites, environments, and UI components [cite: 134].
    * **Adobe After Effects**: 2D animations, motion graphics, and VFX [cite: 134].

---

## 5. Development Constraints (Out of Scope)
To maintain feasibility, the following features are **explicitly excluded** [cite: 104-113]:
* **No Multiplayer**: Strictly local, single-player [cite: 109].
* **No Real E-Commerce**: No real-world financial transactions or e-wallets [cite: 107].
* **No External Integration**: No interfacing with real ISP tools or existing management software (e.g., CafeSuite) [cite: 108].
* **No 3D**: Visuals are strictly 2D side-scrolling [cite: 110].
* **Simplified Diagnostics**: Troubleshooting uses gamified logic rather than actual coding or electrical engineering math [cite: 111, 112].

---

## 6. Required UI Screens
1.  **Main Menu**: New Game, Continue, Best Scores, Tutorial [cite: 82, 149].
2.  **In-Game HUD**: Trackers for Time, Day, and Money [cite: 84, 164].
3.  **Active Shop Floor**: The interactive side-scrolling environment [cite: 84].
4.  **Success/Financial Screen**: Daily wrap-up showing income and expenses [cite: 84, 91].
5.  **Pause Menu**: Resume, Save, Quit [cite: 84, 177].
