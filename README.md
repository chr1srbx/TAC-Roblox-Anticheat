# 🛡️ Tayia's Anticheat (TAC)

A lightweight and effective **Client/Server Anticheat** solution for Roblox.

> 💻 **Test Game:**  
> [Try it here on Roblox](https://www.roblox.com/games/116869323919467/anticheat-attempt#ropro-quick-play)

> 💬 **If you are interested in implementing this anticheat into your game with custom detections and tweaks tailored to your game :**  
> DM me on Discord: **c___s**

---

## ✨ Features

TAC helps detect and mitigate **common exploits** used in Roblox games:

### 🎮 Movement Exploit Detection
- 🚀 Speed Hack
- 🕊️ Fly
- 🌐 Teleport
- 🔁 Infinite Jump
- 🧱 Noclip
- 💥 Fling
- ⏱️ Lag Switch

### 🧪 Debugging/Tool Detection
- 🔍 Dex Explorer (Supports most executors except poorly built ones like Xeno)

### 📢 Notifications & Logging
- 📬 **Discord Webhook** support for automatic kicks/bans  
  ![Webhook Example](https://github.com/user-attachments/assets/ff165b67-1f3e-4908-b57e-bc93363acf23)

### 🧠 Sanity Checks
- (Simple sanity check between client and server, I can make it customizable based on your game needs)

---

## 🛠️ Setup Instructions

1. **Place Scripts:**
   - 🧩 `TAC Local` → `StarterPlayerScripts`
   - ⚙️ `TAC` and `TACLoader` → `ServerScriptService`

2. **Create RemoteEvent:**
   - Add a `RemoteEvent` called **Send** in `ReplicatedStorage`
   - If renamed, update references in both **TAC** and **TAC Local**

---

## 📈 Realtime Performance

- **Idle Usage:** `0.050 - 0.150%`  
- **Triggered w/ 1-10 CCU:** `0.5%`

> 🧠 Lightweight enough for any game

**Memory Snapshot:**  
![Memory](https://github.com/user-attachments/assets/a7582e6b-444d-47dc-b02a-1492817d002a)  
**Activity Snapshot:**  
![Activity](https://github.com/user-attachments/assets/36490eab-7e3f-4c5b-b705-43cc482dcb5b)

---

## 📍 Games Using TAC

### ✅ [Downhill Battles](https://www.roblox.com/games/4838844130/Downhill-Battles) (Heavily Modified Version of TAC)

**Before TAC:**

![Before](https://github.com/user-attachments/assets/3d598af8-1a44-46ac-8547-a6afe751bb43)

**After TAC:**

![After](https://github.com/user-attachments/assets/8cc6e7bb-9277-4871-8c93-5706358365ac)

---

## 🚀 Overview

TAC is built for:
- 🧠 **Simplicity** – plug and play
- ⚡ **Performance** – very low overhead
- 🔒 **Security** – detects a wide range of exploit behaviors

---

## 🤝 Credits

Created with ❤️ by **Tayia**  
DM for collabs, questions, or custom detections: `c___s` on Discord
