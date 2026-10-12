# Phase 1 驗收報告

日期：2026-10-12（Asia/Taipei）。引擎：4.7.2.stable.official.ed1daf0bf。Windows、Compatibility / OpenGL 3.3；圖形執行輸出辨識為 NVIDIA GeForce RTX 3080。

## 已交付

- project.godot 與 Main 啟動場景；獨立 Player、World、HUD 場景，可在編輯器修改。
- 約 25 × 25 公尺的練習場，地板、四周實體邊界、石塊/矮牆、樹木與遺跡；基本天空和方向光。
- CharacterBody3D、WASD/方向鍵、地面碰撞、重力；固定 45 度正交鏡頭隨玩家平移；R 重置位置。
- 幾何體雷恩與中文 HUD。沒有新增 NPC、故事執行器、戰鬥或存檔。
- Git 本地倉庫及開發工具 Check/Smoke/Test/Editor/Run。

## 驗證結果

| 檢查 | 方法 | 結果/證據 |
| --- | --- | --- |
| 載入與匯入 | tools/godot.ps1 -Mode Check | 通過；check-20261012-150312-164.log，無解析/資源錯誤 |
| 啟動 | tools/godot.ps1 -Mode Smoke | 通過；smoke-20261012-150315-444.log，正常退出 |
| 輸入/物理 | tools/godot.ps1 -Mode Test | 24 個 PASS、failures=0；test-20261012-145835-361.log |
| 真實渲染 | phase1_visual_capture.gd，非 headless | 1280×720 起點/移動後、960×540 三張 WebP；visual-check.log |
| 編輯器 | tools/godot.ps1 -Mode Editor＋Windows 視窗檢查 | main.tscn 正常顯示場景樹、地板/樹木/模型，無錯誤輸出 |
| 桌面遊戲 | Run＋Computer Use 觀察/鍵盤操作 | 實際遊戲視窗正常；關閉後新 Run 視窗重新出現 |

物理測試載入真正 Main 場景，以 InputEventKey 經專案 Input Map 送入持續按鍵，再讀取實際物理位置；沒有直接寫入期望速度或假造碰撞結果。檢查包含落地/靜止、八種按鍵的鏡頭相對方向/放開停止、斜向等速、持續頂住石塊、接觸不浮起、邊界阻擋、鏡頭角度不變及 R 回起點。測試中的位置重置僅用於設定個別測試起點。

圖形測試則在可見遊戲中送入 W 持續移動 0.8 秒，等待實際渲染幀，保存移動前後畫面。Computer Use 另確認 Windows 遊戲/編輯器視窗及正常關閉/重啟；長按移動與碰撞的精確判定來自上述引擎測試，不宣稱已由真人完整遊玩。

## 畫面證據與檢視

本機證據在 artifacts/screenshots（被 Git 忽略，未隨提交保存）：

- [起點 1280×720](../artifacts/screenshots/phase1-start.webp)
- [移動後 1280×720](../artifacts/screenshots/phase1-moved.webp)
- [視窗 960×540](../artifacts/screenshots/phase1-960.webp)

已逐張查看：HUD 在邊緣、中央保留遊玩空間；角色與草地可辨識；移動後鏡頭跟隨且維持斜視；兩種尺寸的操作列與中文無裁切。

針對本原型的視覺抽查（godot-master Agent Vision 檢視項，0～2；不是完整美術認證）：TYPE-GLYPH-INTEGRITY 2、TYPE-FACE-CAP 2、TYPE-HUD-FLOOR 1（960 視窗次要文字偏小）、COMP-CENTER-CLEAR 2、COMP-SAFE-EDGE 2、LIGHT-PLAY-SEP 2、LIGHT-KEY-FILL 2。文字可讀且未阻擋玩法；正式 UI/模型與動畫留後續階段。

## 環境修正與限制

最初 sandbox 中的 Godot 無法寫入系統使用者設定/快取，載入檢查報錯；工具已為子程序設定專案內 APPDATA/LOCALAPPDATA，重新 Check/Smoke 通過。這只影響透過工具啟動的程序，不改系統環境；直接雙擊 Godot 使用其原本使用者設定。

圖形驗收需真實 Windows 桌面；無頭測試不等於渲染驗證。日誌皆放 artifacts/logs。此階段未測手把、Windows 匯出或故事流程；未宣稱已有正式角色動畫、遊戲存檔或 20～30 分鐘內容。
