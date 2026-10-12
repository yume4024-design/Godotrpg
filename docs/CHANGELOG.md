# 變更紀錄

## 2026-10-12 — Phase 1 可執行探索原型

- 建立 Godot 專案、Main/Player/World/HUD、輸入/移動組件與固定斜視角鏡頭。
- 加入地板、石塊、矮牆/邊界碰撞、幾何體角色、天空/照明與操作 HUD；支援 WASD、方向鍵、R 回起點。
- 初始化本地 Git；工具增加 Test 並隔離 Godot 設定/快取以處理 sandbox 權限；新增物理/輸入測試及圖形證據工具。
- 記錄使用者允許修改素材商店資產的偏好；本輪全為自製幾何體，沒有下載或購買素材。
- 驗證：Check/Smoke 通過、24 項物理/輸入測試通過、實際 Godot 編輯器/遊戲畫面檢視、1280×720/960×540 渲染及關閉重啟確認。詳見 PHASE1_REPORT.md。
- P1 完成，P2～P6 保持待開始。

## 2026-10-12 — 加入《失落星核》Story Bible v1.0

- 原封保存使用者故事企劃為 STORY_BIBLE.md；新增 STORY_IMPLEMENTATION.md，將八事件與六項故事工作包排入 P2～P6。
- 首個版本改為 20～30 分鐘序章、雷恩/莉雅、三張地圖、B001/B002；三人容量保留，艾琳與完整六篇章/三結局排在序章後。
- 提取三份 JSON 到 data/story、data/quests、data/battles；Q001 OBJ01/OBJ02 的 required_flag 由 e003_done/e004_done 修正為 e004_done/e005_done，避免提前勾選，原稿未改。
- 補上事件等待/重入、旗標唯一擁有者、獎勵單次提交、任務交付避免循環條件與安全存檔規範；明記 EXP 分配為整合決策。
- 同步 AGENTS、README、GAME_DESIGN、ARCHITECTURE、WORKFLOW、TASKS 與 ACCEPTANCE；補列尚未實作的資源引用。
- 驗證：原文副本 SHA256 一致、JSON 解析/ID/內部引用/獎勵一致性及文件連結核對。未建立或測試任何遊戲功能，P1 仍待開始。

## 2026-10-12 — 開發流程準備

- 依使用者企劃建立 Project Crystal 的範圍、六階段任務、架構邊界、開發與驗收流程。
- 建立 AGENTS.md、README.md、docs 文件、目錄骨架與 Git/Godot 忽略規則。
- 找到資料夾內的 Godot console 執行檔，確認版本 4.7.2.stable.official.ed1daf0bf。
- 建立 tools/godot.ps1，提供版本查詢、載入檢查、啟動煙霧檢查及開啟入口。
- 本輪沒有建立 project.godot 或任何遊戲功能；Phase 1～6 均未開始。
- 驗證結果及限制見 ENVIRONMENT.md。
