# 圓潤卡通角色與場景驗收

日期：2026-10-13。使用者指定「圓潤可愛的卡通風格」，並追加「場景也要」。範圍為 P3 後插入的美術更新；P4、完整序章與 P6 交付仍未完成。

## 成果與來源

五個角色／敵人保留辨識配色，新增五官、髮束、耳朵、分層服裝和職業裝備；探索與戰鬥共用模型。新增十個環境 GLB，村莊／森林改為瓦頂建築、圓冠樹、覆苔石、花草、圓角路面、木箱及營火；戰鬥使用獨立林地舞台。前景兩棵樹縮小樹冠，避免遮擋守衛演練點。

全部為專案原創 Blender Python 幾何與色盤，無素材商店下載／購買／外部生成。來源登錄見 [ASSET_CREDITS](ASSET_CREDITS.md)。Blender MCP 未連線，使用隔離背景程序；沒有操作使用者的既有 Blender 場景。保留 authoring 與遊戲整理版本。

| 模型 | 三角面 | 模型 | 三角面 |
| --- | ---: | --- | ---: |
| ren | 4,666 | round_tree | 2,000 |
| lia | 4,664 | guild_house | 4,620 |
| guildmaster | 4,678 | cottage | 4,620 |
| forest_slime | 1,912 | moss_rock | 360 |
| corrupted_guardian | 4,340 | flower_patch | 1,596 |
| chest_base | 688 | chest_lid | 324 |
| campfire | 1,824 | signpost | 212 |
| path_strip | 100 | | |

每資產上限 5,000 三角面；不是整張地圖的面數。來源 `source_assets/cartoon_v1/*_metrics.json`，模型 `assets/models/cartoon/*.glb`，兩套可重建腳本在 tools。超標原稿保存後在副本作一次比例減面，再按視覺關節合併及清理退化面。模型沒有第三方貼圖／字型。

## 實作邊界

- CartoonActor 僅控制六組剛性網格關節及膠凍伸縮；沒有蒙皮骨架、權重或完整動作庫。死亡停止待機，玩家步行由實際水平速度驅動。
- 外觀以 CombatantDefinition.appearance 注入；載入外觀之前必須先指定 Resource.script，已修正最初的 null 外觀錯誤。BattleCatalog 會拒絕缺少外觀的定義。
- 環境為場景中的靜態模型；碰撞／互動資料與造型分離。兩地所有 StaticBody3D、CollisionShape3D 與 BoxShape3D 宣告和提交 25eb481 逐項比較一致。開箱仍操作原 Lid 節點，獎勵來源沒有改動。
- 攝影機僅拉近戰鬥，雙敵站位稍微错開；探索仍固定斜 45 度。未新增引擎版本或外掛。

## 驗證紀錄

引擎：`4.7.2.stable.official.ed1daf0bf`；Blender：`5.2.2 LTS d13f752e3b9c`。Windows 實際畫面使用 Compatibility／OpenGL 3.3、NVIDIA RTX 3080（驅動 617.42）。以下為實際執行，非預期結果。

| 命令／檢查 | 預期及實際 | 證據 |
| --- | --- | --- |
| `tools/godot.ps1 -Mode Check` | 所有新 GLB 匯入及 GDScript 解析成功，無錯誤 | artifacts/logs/check-20261013-061114-518.log |
| `-Mode TestArt` | 17 項通過：五模型面數／材質／關節、步行及死亡停止 | artifacts/logs/testart-20261013-015008-404.log |
| `-Mode VisualArt` | 21 項通過，正／側／背／步行姿勢輸出 | artifacts/logs/visualart-20261013-014756-907.log；artifacts/cartoon/cast-*.webp |
| `-Mode VisualPhase2` | 66 項通過：實際鍵盤移動、E 互動、開箱、切圖、對話鎖、旗標及小視窗 | artifacts/logs/visualphase2-20261013-061143-966.log；artifacts/phase2/*.webp |
| `-Mode VisualPhase3` | 85 項通過：渲染按鈕、目標、攻防魔法／道具、勝敗重試／返回、主線橋接 | artifacts/logs/visualphase3-20261013-061010-862.log；artifacts/phase3/*.webp |
| `-Mode Test` | P1 24 項物理與輸入回歸通過 | artifacts/logs/test-20261013-061209-145.log |
| `-Mode Smoke` | 主場景 120 次迴圈正常退出，無載入／腳本錯誤 | artifacts/logs/smoke-20261013-061355-098.log |
| Blender GLB 獨立重新匯入 | 15 個模型全部 basic_checks_passed=true；面數 ≤5,000、存在 UV 和材質、零退化面 | artifacts/cartoon/validation/*/report.json |

畫面已查看：模型正側背、步行；村莊公會／寶箱／960×540 對話；森林空地／路牌；雙史萊姆、守衛、倒下與 960×540 戰鬥。造型／色彩可區分，互動目標與战鬥員沒有被背景遮擋；角色、HP、指令可讀。屋瓦、窗框及樹冠取代原方塊／尖錐。這是實際 Godot 畫面檢查，不是只憑無頭輸出判定美術合格。

## 重建與遊玩

```powershell
Set-Location D:\RPGGAME
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' --background --factory-startup --python-exit-code 1 --python tools/build_cartoon_assets.py
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' --background --factory-startup --python-exit-code 1 --python tools/build_cartoon_environment.py
.\tools\godot.ps1 -Mode Check
.\tools\godot.ps1 -Mode VisualArt
.\tools\godot.ps1 -Mode Run
```

重建覆寫此專案的生成模型／來源整理檔，編輯過的版本需另存後再重建。場景佈置直接保存在 village.tscn、forest.tscn 和 battle_grove.tscn，無需執行一次性搬移工具。

## 限制與後續

GLB 重新匯入後仍有 nonmanifold/boundary edge 警告；來源合併網格統計為零非流形／退化面，沒有宣稱 GLB 可直接用於封閉實體或列印。UV 是基本生成 UV，沒有獨立手繪貼圖圖集。未驗證蒙皮變形、完整動畫、全地圖任意攝影機遮擋或不同硬體效能門檻；未做效能認證或 Windows 匯出。營火是靜態造型，目前無粒子、音效或光照閃爍。

下一階段仍按 TASKS 的 P4 隊伍／養成執行。角色完整動作、環境變化、可散布字型及效能／匯出驗收保留給後續美術與交付工作。
