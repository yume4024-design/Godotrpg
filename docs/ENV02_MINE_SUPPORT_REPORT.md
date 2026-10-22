# ENV02 礦坑支架獨立素材

日期：2026-10-22；起點 `0b267985157f8c9109fca200d0909bce5fa82454`，分支 `feature/greystone-g06`。**本頁保存獨立素材階段；後續已接入新版G06礦坑八組位置，原生84／0，見[整合報告](ENV02_MINE_SUPPORT_INTEGRATION_REPORT.md)。** 原正式v0.6.1仍保留。G08.3 的新 RC4 實體鍵鼠／Xbox 問題仍待回覆；本素材不改固定候選 EXE／PCK。

## 交付與比例

依 [盤點](RUNTIME_ASSET_INVENTORY_REPORT.md) 的缺件，製作兩根木柱與一根橫梁，加入寬切面倒角、金屬箍、六角鉚釘與端面色。現有七建築／十七道具沒有重造；本件沿用 G04 木材、端木及鐵材資源。

| 項目 | 實測 |
| --- | --- |
| 模型 | `assets/models/environment/mine_support_frame.glb`，41476 bytes |
| GLB SHA256 | `06604313fd9273a75b258cc13263dec7d1989ad4173de0f81cb72c16d35f3abb` |
| 三角形／預算 | **804／1200**；三個剛性部件各268，八份實例6432 |
| Mesh／材質／貼圖 | 3／3／0；各Mesh三個surface，共用既有木材／端木／鐵材 `.tres` |
| 外形／原點 | 4.7×2.625×0.3m；Y軸向上，地面中央根原點，1 unit=1m |
| 原碰撞範圍 | 柱中心 x=±2.2、y=1.2，Box 0.25×2.4×0.25m；淨寬4.15m，樑下2.375m |

三個Mesh的所有頂點均在對應原木柱／橫梁的凸Box範圍內，因此三角形也不向通道額外突出；沒有新增斜撐縮窄入口。原生測得1.95m／半徑0.32m的CharacterBody3D膠囊，可用1.8m/s步行及4.5m/s反向跑步穿越，兩柱均阻擋到z約0.446m，與原柱厚度及膠囊半徑相符。

## 檔案與使用

- `scenes/world/greystone/props/mine_support_frame.tscn`：可重用完整素材，只有兩個簡化柱碰撞，CollisionShape不縮放，沒有增加原先不存在的上方碰撞。
- `mine_support_frame_visual.tscn`：純視覺版本，後續替換正式礦坑時保留原16根柱碰撞，避免雙重碰撞。
- `scenes/tools/mine_support_preview.tscn`：獨立比例預覽，附原有雷恩作比例參照，沒有RPG Managers或存檔流程。可於Godot編輯器開啟並按F6。
- `scripts/tools/greystone/build_mine_support.py`：可重現Blender生成，拒絕覆寫既有輸出資料夾；原生可編輯來源及完整證據在 [source_assets](../source_assets/environment_rebuild_20261022/mine_support/README.md)。

Blender MCP可讀目前場景，版本5.2.2，addon protocol13／server預期14，素材庫開關目前皆off；未升級或變更使用者設定。本件為專案原創，使用背景Blender，不呼叫付費生成或下載第三方模型。前後讀取的使用中Blender仍為未儲存Cube／Camera／Light場景，沒有覆寫或切換使用者場景。

## 實際測試

Godot `4.7.2.stable.official.ed1daf0bf`／Windows／Compatibility／RTX3080；Blender5.2.2 LTS。

| 測試 | 結果與限制 |
| --- | --- |
| Blender來源檢查 | 804面、零邊界／非流形邊、零零面積面；每個剛性部件含刻意重疊的封閉構件，未宣稱Boolean聯集或無所有自相交 |
| Godot載入 | Check exit0，三個材質均經既有prop_import對應到共用G04資源 |
| 無頭結構／實際物理 | **53／0**；尺寸、材質、八份共用Mesh、兩柱碰撞及膠囊move_and_slide；不作畫面通過證據 |
| 原生圖形 | **58／0**；同樣物理與結構檢查，加四張實際viewport；已查看八份、三分之四、正面比例及金屬箍近景 |
| 預覽場景 | 獨立tscn載入／20幀smoke exit0；該smoke為headless，不能單獨宣稱其畫面通過 |
| 保留範圍 | 18個主入口／正式地圖／整合腳本／劇情、任務、遭遇及存檔來源與起點一致；原男性村民、女性候選及Android／iOS暫停狀態不變 |

原生視覺取樣為910×512 WebP。適用視覺項目採0～2分記錄：COMP-FRAME、COMP-NEG-SPACE、LIGHT-KEY-FILL、COLOR-COUNT各2；鉚釘同為霧面鐵材，主要在近景辨識，屬裝飾而非互動提示。沒有文字／圖示／戰鬥FX評分，也不把比例參照的雷恩當作新主角美術驗收。

此為素材測試，不是完整Player／InputMap、正式礦坑動線、NPC、存檔、LOD或FPS驗收。九個surface／份的成本須在實際場景整合時量測，不能用804面推定Draw Calls或手機效能合格。

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --threads 2 --python scripts/tools/greystone/build_mine_support.py -- --output artifacts/env02_mine_support/new-build --budget 1200
./tools/review_mine_support.ps1
./tools/review_mine_support.ps1 -Visual
```

Visual runner只在未存在使用者override.cfg時，暫建自己擁有的no-focus啟動設定，原生驗證root.unfocusable=true；結束後比對內容再移除，正式project.godot未改。若已有使用者override則拒絕啟動而保留。測試要求新產生的結果及四張截圖，提前關閉不當作通過。

## 失敗紀錄與下一步

1. 初次背景Blender輸出雖有模型，但儲存縮圖嘗試寫入使用者快取失敗；保留該輪，改用程序內`file_preview_type=NONE`。採用最終無ERROR版本，著色viewport補色後GLB位元組保持相同。
2. 首次Godot結構53項中1項失敗：匯入多了一層`MineSupportFrame`根節點。修正視覺metadata為`Model/MineSupportFrame/Beam`並確認它指向實際Mesh；沒有放寬路徑斷言。
3. 一次路徑診斷未隔離預設日誌而出現log寫入錯誤，未列成功；改為隔離APPDATA／LOCALAPPDATA及明確本機log後重新確認。

以上為獨立製作階段的原始紀錄。其後八組純視覺支架已替換新版G06礦坑原生外觀，原生Player走跑、遮擋、往返及嚴格存讀通過；保留原碰撞與layout。後續測試、已知Draw Calls成本及其餘未完成項目見[整合報告](ENV02_MINE_SUPPORT_INTEGRATION_REPORT.md)，不將本件進度視為G08或第一章完成。
