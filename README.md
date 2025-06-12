# 🛡️ Tayia's Anticheat

A straightforward Client/Server Anticheat solution for Roblox.

Testing Place : https://www.roblox.com/games/116869323919467/anticheat-attempt#ropro-quick-play

If you wish for me to implement this anticheat into your game, with custom detections tailored to your game, shoot me a DM on discord : c___s

---

## ✨ Features

TAC is designed to detect and mitigate common exploits in Roblox games.

### 🕹️ Movement Exploits
-  **SpeedHack Detection**
-  **Fly Detection**
-  **Lag-Switch**
-  **Infinite Jump Detection**
-  **Teleportation Detection**
-  **Noclip Detection**
-  **Fling Detection**

### 🧰 Debugging/Reverse Engineering Tools
- 🔍 **Dex (Explorer) Detection** (Works on paid exploits, and free, except xeno cause they messed something up in their poorly made executor)

### 📢 Notifications & Logging
-  **Discord Webhook Integration** (for kicks/bans) ![image](https://github.com/user-attachments/assets/ff165b67-1f3e-4908-b57e-bc93363acf23)


### 📝 Sanity Checks

---
### 📍 Games used in: 
- [Downhill Battles ] (https://www.roblox.com/games/4838844130/Downhill-Battles) [HEAVILY MODIFIED] [ADDED SOON]
---

## 🚀 Overview

This anticheat system operates on both the **client and server** to provide a basic layer of security against common cheating methods. It aims to be a **lightweight** and **easy-to-integrate** solution for Roblox developers.

---

## 📝Realtime Performance

Memory : ![image](https://github.com/user-attachments/assets/a7582e6b-444d-47dc-b02a-1492817d002a)
Activity : ![image](https://github.com/user-attachments/assets/36490eab-7e3f-4c5b-b705-43cc482dcb5b) When triggered consecutively wtih 1-10 ccu its 0.5%, on idle its between 0.050 - 0.150


## 🛠️ Setup

1. **Insert the Scripts:**
   - Place the TAC scripts into `StarterPlayerScripts` or `ServerScriptService`.
2. **Make 3 RemoteEvents** for ban, kick and sanity check, then rename them in the server script.
