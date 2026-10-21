# 蝙蝠完整收翼 — 人工拓樸工作單

## 2026-10-21 — 正式A04接入通過

同一6249面／17骨／六段GLB已接正式野外與戰鬥視覺，原八行場景／舊GLB保留。動作67／0、六戰鬥193／0、G06 576／0、野外60／0，原生1／3隻40／0及新包序章141／0、重啟35／0。首次名牌失敗已保留並僅調整正式錨點；詳細來源／圖／數據見 [A04單件報告](../source_assets/asset_integration_a04/crystal_bat/README.md)。下方獨立候選與舊FAIL紀錄為前階段證據，沒有用短測宣稱新Windows整體或第一章完成。

## 2026-10-21 — 完整收翼獨立候選 PASS

已依保留完整收翼的選擇，由 Codex 透過 Blender 局部重建翼膜／翼骨／六藍晶及每翼三摺疊關節。保留 4773 個身體面、位置／UV與貼圖，原五段舊骨姿逐幀相同；總計6249／10000面、17骨、六段。220影格最大拉伸2.294549、重新匯入零退化；Godot實際圖形741／0、真實時間雙實例控制器67／0。展翼1.558908m→身側0.793855m→完整重展，scale始終1、頭耳腳不動；正／兩側／背面已查看。

先前單純改軸7.364628拉伸及切片零面積失敗完整保留；不是忽略失敗、減小動作或把部分收翼改名。新翼／晶石為局部手工幾何，較原生成造型簡潔，原身體粗糙接面仍在。交付、SHA、命令與圖形證據見 [完整收翼候選報告](../source_assets/asset_production_a03/crystal_bat/manual_fold_acceptance/README.md)。**正式舊蝙蝠未替換，A04戰鬥／名牌／Release／G06回歸仍待，不宣稱正式整合完成。** 下方2026-10-20 FAIL為保留的歷史。

2026-10-20，狀態 **IN_PROGRESS / FULL_FOLD_FAIL**。使用者選擇「保留完整收翼要求，安排人工拓樸修整」。本輪由 Codex 在 Blender 逐片診斷並修除重複後翼；不是第三人美術師已完成修整，完整收翼仍未合格。

## 本輪可重現進度

- 休息姿勢已確認三塊重複、脫離的後翼，478＋422＋74＝974 triangles；不是只在動畫出現的權重裂縫。真正主翼、粉色耳朵及主翼晶石保留。
- 新副本 `source_assets/asset_production_a03/crystal_bat/topology_v2/`：8712 triangles、11 骨、原六段動作。只刪除已辨認的三個島；按保留面的逐角資料核對原幾何／UV 完全一致，恢復 corner normals，未修改原權重或動畫。
- `scripts/tools/repair_bat_duplicate_wings.py` 從自己的 GLB 在獨立 Blender 程序匯入，輸出新目錄，遇到來源面數／島數改變立即拒絕；不焊接晶石或 UV 接縫。
- 首份 topology_v1 原生數值檢查誤含匯入器顯示球 80 面，且造成 floor=-1。修正包裝，只移除骨骼 custom_shape 引用且位於 glTF_not_exported 的 Icosphere；v2 原生／GLB／Godot 計數一致 8712，未降低門檻。首份報告保留。
- v2 嚴格 GLB PASS；196 影格 PASS，最大拉伸 2.00327，原部分收翼 1.92444；Godot 4.7.2 真實圖形 376 checks／0 failures，四面與側面動作已查看。這不是完整收翼或正式戰鬥 PASS。
- 手動檢查更大幅骨軸姿勢：向後反折翼展縮至約 0.687m，但膜面交疊；向下折翼仍牽動耳部，兩張失敗渲染保存在 v2 的 `failed_full_fold_front.webp`／`failed_full_fold_right.webp`。不能靠縮小動作或單純縮翼宣稱完成。
- GLB SHA256 `2f283ca6984048765332929e1b7b088e8e544d9398853d977812a08da26e3ed0`；Blend `6f2a43b1cb59ebc4b41525bdf1245e3d66eb1e9b79f8111ee0a3312d0c847026`。8712 面另存 `assets/models/rebuilt_enemies/crystal_bat_topology.glb` 僅供檢查，正式場景無引用。
- 下一項仍是耳／主翼的解剖區域隔離、翼根及肘部連續權重，必要時局部重拓樸；完整收翼／重展及 A04 未驗收。原始 GLB／Blend、三版失敗及正式舊蝙蝠均保留。

重現：Blender `--background --factory-startup --python-exit-code 1 --python scripts/tools/repair_bat_duplicate_wings.py -- --input source_assets/asset_production_a03/crystal_bat/action_extension_v3/extended.glb --output <新目錄>`；接著執行 `audit_character_glb.py`、`audit_asset_motion.py`。圖形用 `tests/asset_motion_review.gd -- --id=crystal_bat_topology --model=res://assets/models/rebuilt_enemies/crystal_bat_topology.glb --height=1.1 --category=common_enemy`，使用獨立 APPDATA，不能冒稱正式遊玩。

## 已知失敗與保留檔案

補充區域診斷：於獨立 live Blender 場景，將高頭／耳區的翼骨影響有界移除，正／兩側／背面實際檢視耳形改善，但反折翼膜仍交疊並向身後突出，完整收翼仍 FAIL。參數與觀察存 `head_region_diagnostic.json`；僅聊天內四面證據，未匯出新 GLB／未保存新的合格副本，不假裝完成完整拓樸或正式替換。

- 候選目錄：`source_assets/asset_production_a03/crystal_bat/`；9686 triangles、11 骨，來源與失敗紀錄保留。
- 原五動作及第三版收翼在側面均有脫離翼膜；`failed_baseline_walk_side.webp`、`failed_fold_side.webp`、`failed_fold_front.webp` 是實際 Godot 畫面。
- 第一／二版拉伸數值失敗；第三版數值通過仍畫面失敗。不得把五動作版當作合格替代品，也不得以減少收翼幅度取消完整收翼需求。
- `scenes/characters/crystal_bat_visual.tscn` 正式舊視覺保持原樣，A03.4 及 A04 整體未通過。

## 人工修整範圍

1. 在新 Blend 副本逐側檢查翼骨、翼膜面連接及重疊／孤立片，先標記真正膜面與晶石，不能按距離把晶石全部焊進膜面。
2. 必要時重建局部翼膜拓樸與邊界，保留翼尖、耳朵、晶石及原設計輪廓；修復後重新展 UV／補色，避免接縫出現透明缺口或拉花。
3. 重新處理翼根、肘部、翼尖權重及膜面的連續過渡；每頂點最多四權重、總和為一，避免身體與膜面受錯骨影響。
4. 完整收翼到身側、再展翼，保留拍翼、移動、攻擊、受擊與倒下；修整不改敵人 ID、數值、技能、故事、獎勵或存檔。

## 重新驗收條件

- 一般敵人上限 10000 triangles（含晶石），GLB 匯出及 Blender evaluated 兩種計數均符合。
- 逐影格檢查、循環端點及有限座標／權重 Gate；保留失敗紀錄，不能放寬既有門檻換取 PASS。
- 實際 Godot 四面與兩側的拍翼極端、完整收翼／重展、攻擊／倒下均無脫離膜片或明顯穿模。
- 確認動畫切換及恢復，再做 A04 探索／戰鬥回歸；正式替換以前保留舊模型。

ai-3d-agent 的「最多三次明確記錄的生成／修整嘗試後回報」已達上限並已回報；本次依使用者選擇做有明確面片清單的 Blender 拓樸診斷，沒有第四次 Comfy 生成或盲目權重平滑，亦未撤銷完整收翼要求。
