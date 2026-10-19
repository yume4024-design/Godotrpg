# Crystal Bat — HUMAN_REVIEW（2026-10-20）

面數 9686／10000、11 骨、UV／貼圖／Skin 與五段既有動作均可載入。數值檢查通過不能代表此模型可交付。

收翼三次候選：v1 最大邊拉伸 2.78825 FAIL；v2 沿網格鄰接平滑權重反而達 3.24194 FAIL；v3 改為局部空間 Gaussian 平滑，最大收翼拉伸 1.92445，196 影格及 Godot 378 項數值檢查 PASS。**但真實收翼側圖有脫離翼膜，visual FAIL，沒有採用。**

恢復原五動作候選並重跑：159 影格及 Godot 318 項通過，查看拍翼極端側圖後確認同樣的脫離翼膜存在。因此撤回先採「穩定五動作版」的建議；此新版模型整體沒有通過 A03.4，不能進入正式遊戲。

證據：failed_fold_front.webp、failed_fold_side.webp、failed_baseline_walk_side.webp；三版原件本機留存 action_extension_v*，大檔由局部 .gitignore 排除。失敗／數值報告保留，原正式 scenes/characters/crystal_bat_visual.tscn 及舊模型未改。

依 ai-3d-agent 的三次修整上限停止自動重試；下一步需要人工拓樸／膜面連接及骨架區域重整。14 邊界／160 非流形邊仍在，未宣稱 watertight。Android／iOS 暫停。
