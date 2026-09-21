# The Forsaken Depths — Structured V7

เวอร์ชันนี้เป็นการสร้างโครงสร้างใหม่เพื่อแก้ปัญหาจากรุ่น monolithic เดิม

## โครงสร้างหลัก

- scenes/main — ตัวจัดการเปลี่ยนหน้าจอ
- scenes/world — แผนที่ ประตู pickup shrine ritual
- scenes/actors — Player และ Enemy
- scenes/ui — Main Menu, HUD, Inventory, Battle, Game Over, Ending
- scripts/systems — GameState / Save-Load / AudioManager
- scripts/world — logic ฉากและ interaction
- scripts/actors — movement และ enemy AI
- scripts/ui — UI แต่ละหน้าจอ
- tests — runtime QA

## ระบบที่มี

- Main Menu + Continue
- Game Over screen + Retry last shrine
- Save/Load ที่ Deep Shrine
- Player collision และกำแพงจริง
- Floor / Back Wall / Actor / Foreground layers
- ประตูล็อกด้วย Rust Key / Bell Sigil และมี opening animation
- Enemy chase + encounter
- Turn-based battle พร้อมเลือก Torso / Head / Arm / Leg
- Equip weapon / armor และค่าส่งผลกับ battle
- Inventory ที่ใช้ Container จึงไม่ล้นกรอบตาม resolution
- Hunger / Torch / Mind / Body
- Objective progression
- Boss + Ending
- Audio แยก Ambient / SFX / UI และใช้ player pool ไม่ตัดกันง่าย

## ปุ่ม

- WASD / ลูกศร: เดิน
- E: interact
- I: inventory
- Esc: ปิด inventory / กลับเมนูเมื่ออยู่ในโลก
- F11: fullscreen
- Space: คำแนะนำ battle

## วิธีเปิด

เปิด project.godot ด้วย Godot 4.x ที่รองรับ project format นี้ หรือเล่น Windows build ที่แนบมากับ release package

## หมายเหตุสำคัญ

Structured V7 ตั้งใจเน้นโครงสร้างที่แก้ไขต่อได้และ QA ได้ ก่อนเพิ่ม asset หนัก ๆ เพิ่มเติม
