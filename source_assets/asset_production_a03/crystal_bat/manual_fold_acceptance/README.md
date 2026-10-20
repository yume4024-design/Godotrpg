# 星晶蝙蝠 — 人工局部重建與完整收翼候選

2026-10-21；Blender 5.2.2 LTS、Godot 4.7.2.stable.official.ed1daf0bf、Windows／RTX 3080 Compatibility 圖形模式。**獨立 A03 候選通過；正式 A04 戰鬥／場景／Release 尚未驗收。** 正式 `crystal_bat_visual.tscn` 與舊 GLB 保留，未新增戰鬥技能／修改 ID、數值、劇情或存檔。

## 交付與方法

- Runtime：`assets/models/rebuilt_enemies/crystal_bat_manual.glb`，SHA256 `ab487b6c94b32e9aac451348e739635684e2577f996245d3a90feb8759f7ebf7`。
- 工作檔：`source_assets/asset_production_a03/crystal_bat/manual_panels_v3/bat_manual_wings.blend`，SHA256 `f7b58eb116b84808b3c4ce181cf50c864bdd4a427462784a76e0aed848a1ffa8`。
- 獨立 PackedScene：`scenes/characters/rebuilt/crystal_bat_manual_visual.tscn`；重用 RiggedEnemyActor，`fold_wings` 僅是選用呈現動作，未寫入 enemy／skill 資料。
- 原拓樸來源：`topology_v2/crystal_bat_topology.blend`，SHA256 `6f2a43b1cb59ebc4b41525bdf1245e3d66eb1e9b79f8111ee0a3312d0c847026`。沒有新 Comfy 工作或外部素材。
- 保留 4,773 個頭／耳／身體／腳部來源面；明列移除 3,939 個生成翼部面。用 Codex 執行的 Blender Python 局部重建薄膜、翼骨與六顆立體藍晶，新增每翼三關節。這是實際幾何修整，並非第三方美術師交件，也不是原翼幾何完全保留。
- **6,249 triangles／10,000、17 骨、六段動畫**：Idle 2s、Walk／拍翼 1s、Attack 1.167s、Hit .75s、Death 1.5s、Fold Wings 2.5s。原五段舊 11 骨逐幀矩陣完全一致；新翼的形狀與蒙皮有意改變。
- 全幅展翼 1.558908m，收至身側 0.793855m，重新展翼端點相同。82°／−164°／164° 關節摺合，沒有縮放翼片、縮減完整收翼擺幅或把部分收翼改名。

## 實際驗證

| 驗證 | 實際結果 |
|---|---|
| GLB 嚴格結構／UV／Skin／四權重／預算 | PASS，6,249；`manual_panels_v3/triangle_report.json` |
| Blender 重新匯入 | PASS，6,249；零退化面；明確排除匯入器 custom-shape 球；`blender_reimport.json` |
| 原有部位保留 | 4,773 面位置／UV 一致；原 body 貼圖 bytes 一致；corner normal 再編碼最大誤差 .000359059，低於既有 .001；`manual_panels_v3/preservation_report.json` |
| 六段逐幀變形 | 220 影格 PASS，最大邊拉伸 2.294549，未提高 2.5 門檻；五段原骨姿差異 0；`manual_panels_v3/motion_report.json` |
| 完整收翼契約 | 61 幀內全身／耳腳位置差 0、scale 始終 1、背向範圍最大 Y .214092m、重展端點一致 |
| Godot 原生圖形 | **741 checks／0 failures**；四角度收翼／重展、兩側及正背拍翼極端、完整擺幅與中途切回 Idle；`godot_motion.json`、73 張 `frames/` |
| 共用控制器 | **67 checks／0 failures**，真實時間雙實例、三輪動作／受擊打斷／死亡／復原／重新實例化、完整收翼 hold 後回 Idle；`godot_controller.json` |
| 專案載入 | `tools/godot.ps1 -Mode Check`，exit 0，成功匯入候選 |

已實際查看四面、完整收翼正／兩側／背面、部分折疊兩側、兩個拍翼極端正側、攻擊、死亡及中途打斷後展翼。代表性畫面沒有舊版脫離的大翼膜／耳朵跟隨翼骨翻折。`frames/` 是實際 Godot 畫面縮至短邊 512 的 WebP；不是生成示意圖。2 Draw Calls／36,544,366 bytes 是獨立 Debug 檢視器單點快照，**不是正式戰鬥效能、Release 長測或實體輸入證明**。

## 保留的失敗與測試修正

1. 只隔離頭耳權重並改為垂直肘部摺疊，耳部改善但翼膜擠壓，最大拉伸 **7.364628**，FAIL。見 `failed_hinge_*` 與失敗圖。
2. 局部重建首份 6,257 面候選數值可動，但重新 GLB 匯入有 **5 個零面積面**，FAIL。切片交點只有約 3e−8m 差異；第二份診斷仍有 6 面。修正建模器的重複切點／零長邊，最終 6,249 面重新匯入零退化，沒有放寬驗收門檻。
3. 初次 Godot 測試以 Quaternion.IDENTITY 判耳部，**734／2 FAIL**；匯入後應比較同一角色的起始姿態。改為相對起始 quaternion 的角差後 734／0，再補中途切回 Idle 得 **741／0**。GLB 未因這項測試修正改動。中途切換沒有重現殘留問題，因此沒有不必要地重寫已正常的動作。
4. 保留檢查首次因 NumPy bool 的 JSON 序列化錯誤未產生報告；修正為原生 bool 後全部 10 組檢查通過，失敗日誌仍在。

失敗 Blend／GLB 本機保存，SHA 在 `intermediate_hashes.json`；版本化保存配方、失敗報告及代表圖，不反覆提交可重建的大型中間檔。`repair_report.json` 內 HUMAN_REVIEW 是建模完成當時的未驗收狀態，本頁及後續驗證為其驗收終態。

## 重現與未完成

從專案根目錄，用 Blender `--background --factory-startup --python-exit-code 1 --python scripts/tools/rebuild_bat_wing_panels.py -- --input source_assets/asset_production_a03/crystal_bat/topology_v2/crystal_bat_topology.blend --output <新的空目錄>` 重建。預檢用 `audit_character_glb.py`，原生變形用 `audit_asset_motion.py`，保留契約用 `check_bat_manual_preservation.py`；圖形用 `tools/review_bat_fold.ps1`，雙實例用 `tools/review_bat_fold.ps1 -Controller`，各自隔離 APPDATA。

- 局部翼部是較簡潔的手工切面造型，晶石／膜面不再與 Comfy 原網格逐點相同。保留部位仍有原始粗糙接面與耳背色塊；UV 分離的 body 邊界 6,917 條，不能宣稱全角色封閉流形。新翼原生網格邊界／非流形均為 0；glTF 的 UV／法線拆點後另記警告。
- 正式敵人接入、戰鬥名牌／單及多蝙蝠取景、G06／原生 Release 回歸與新長測仍待。沒有把舊 RC3 人工鍵鼠／Xbox 通過轉用到這個新候選。
- 雷恩／莉雅重製、NPC 正式整合、環境物件、G08 及完整第一章仍依原目標繼續；Android／iOS 暫停。
