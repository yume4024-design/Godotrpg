# 莉雅護腕末端局部重建試作 — 2026-10-30

**視覺仍不合格，未換入遊戲。** 以五指第二版為來源，先量測現有護腕末端截面，再局部切除破損末段並建立錐形皮革表面。前面部分黑色破片減少，但護腕上方仍有碎片，重建處與原貼圖的接縫及顏色差異明顯；側面手掌過於扁平。手、護腕、原身體仍是分離或重疊表面，尚未焊接、綁骨或驗證動作。

## 實際結果

- 原護腕在手腕沿手臂方向約 -0.025m 截面，兩側橫向分別約 -0.047～0.017m、-0.040～0.023m；深度分別約 0.021～0.092m、0.028～0.103m。這是截面與模型軸的測量，不代表所有來源面為正確外殼。
- 先依截面調整手掌根部，但[實際正面](evidence/lia_bracer_rebuild_20261030/fitted_left_front.png)出現新的皮膚／護腕穿插，**不採用**。
- 改為在獨立副本各選 45／40 個末端面，以局部平面切割並製作皮革末段；色彩取現有護腕附近材質的中位樣本。11,459 個未選原面逐項核對位置、UV 與角落法線，最大法線誤差 0.000359。[正面](evidence/lia_bracer_rebuild_20261030/bracer_left_front.png)／[另一側](evidence/lia_bracer_rebuild_20261030/bracer_right_front.png)／[側面](evidence/lia_bracer_rebuild_20261030/bracer_right_side.png)。**仍 visual FAIL**。
- 第一次局部切割的新增角落法線導致自訂法線校準中止；修正為僅在選中切割區採用該面的法線，保留未選區來源法線後才成功。失敗嘗試未產生候選，也未忽略錯誤。

## 檢查

Godot 4.7.2、Windows、Compatibility／RTX 3080：GLB 靜態結構／UV 預檢通過，**12,767／15,000 triangles**；Godot `GLTFDocument` 圖形匯入與重建實例 **35／0**。[靜態報告](evidence/lia_bracer_rebuild_20261030/static_glb_audit.json)／[Godot 報告](evidence/lia_bracer_rebuild_20261030/godot_report.json)。沒有骨架／動畫測試，不代表模型已可正式使用。原始 blend 與現行可玩莉雅 GLB 雜湊仍為 `1e8d238dc505c3c347d125b43501093c47f4be5c59df437dd4330e1dc235e37e`／`d2ebab02be6b38b6d539f8a77d50d82baaebcf4e64153ac0c36b94e9fdfc96a4`。

第一次候選 GLB SHA256 `f2b2647ff24d6c7f3afeda22b1c47f9513112c8a2c79435dc87075451ce4484b`。從重建後的手部來源再執行時，選面數、切割元素與面數相同，但 GLB SHA256 為 `fe30d3a95944fabb0e95a06421e842f012cce1f3e6c1e84eaa868d0b3582f5d2`；沒有逐三角形證明兩輸出相同，不稱為位元重現。[首次收據](evidence/lia_bracer_rebuild_20261030/receipt.json)／[重跑收據](evidence/lia_bracer_rebuild_20261030/reproduce_receipt.json)。

## 重現與後續

本機試作在 `D:/RPGGAME/artifacts/lia-bracer-rebuild-20261030/`；以下輸出目錄須不存在，來源不匹配時腳本拒絕執行。另可依 [五指報告](LIA_HAND_REBUILD_20261030.md) 重建手部來源，並以 `--source-receipt` 傳入對應收據。

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python-exit-code 1 --python scripts/tools/repair_lia_bracers.py -- --input artifacts/lia-hand-trial-v2-20261030/lia_hands_trial.blend --output artifacts/lia-bracer-replay
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python-exit-code 1 --python scripts/tools/render_lia_repair_inspection.py -- --input artifacts/lia-bracer-replay/lia_bracer_trial.blend --output artifacts/lia-bracer-replay-render --hands-only
```

後續應先重建更完整的前臂／護腕邊界並處理原始破面，再銜接手掌與貼圖；不能將局部遮蓋視為正式修復。領口、衣袖、背裙、骨架／動作仍待完成；人工驗收依使用者要求保持暫停。
