# 灰石村 Blender 主場景

`greystone_master.blend` 是完整可編輯場景，四種本機 Pixal 建築／五 GLB 變體／七棟實例，
包含九個匯出分組與 Review 相機、燈光。所有產生操作均使用獨立背景 Blender，
沒有接管或覆蓋使用者正在編輯的其他檔案。

入口 `scenes/main/greystone_blender_integration.tscn`；執行：

```powershell
./tools/godot.ps1 -Mode RunBlenderVillage
```

場景腳本保留正式角色與共用 RPG Manager，以 layout 3／獨立槽讀寫新版位置。
原正式 main、G06 位置版 2、事件與角色／道具定義保留。
本檔的 `Bounds` 是可編輯簡化代理，glTF `-colonly` 不顯示代理外觀；
Godot 共用 geometry adapter 將箱體轉實心，並將實際裁切頂面及坡道轉成凸體地形。

重建工具：`scripts/tools/greystone/build_blender_village.py`、`export_blender_master.py`。
先建模，再匯出，再 `tools/godot.ps1 -Mode Check`，不要在遊戲測試中覆寫 GLB。
產生器直接重用 `../greystone_ai_20261023/final_candidates.json` 對應的修整來源，
不會重新送出 ComfyUI 工作。藍頂變體改材質，民宅精確同向重疊面 2 個在產生器移除。

`acceptance/` 保存本輪 Windows 自動化結果、SHA、主要輸出與真實畫面。
`legacy_exports/`、Blend 備份及 AI 失敗原型僅本機保存，不作遊戲依賴或交付模型。
詳細功能／美術限制及短程幀時間見 `docs/GREYSTONE_REFERENCE_REBUILD_REPORT.md`。
此候選不是新 Windows 發布包、實體輸入、30 分鐘長測或 Android/iOS 驗收。
