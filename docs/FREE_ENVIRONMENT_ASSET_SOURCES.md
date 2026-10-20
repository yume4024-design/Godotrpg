# 免費場景素材來源與採用流程

2026-10-20 使用者追加：「埸景用的物件也可以用網上的免費素材去改」。沿用既有素材使用授權，場景／造景／物品優先重用合格模組，再挑適合的免費模型修改，缺件才自行建模。此指示不改變 13 套角色來源與角色重製要求。

以下已查閱作者官方頁面。**Kenney 已下載並只取一件枯木適配；Quaternius 仍未下載**。免費版本與付費 Source／支持方案分開記錄，按實際缺件取用，不把整包當作已適配。

| 候選來源／作者 | 官方授權／版本快照 | 優先用途 | 現況 |
|---|---|---|---|
| [Nature Kit — Kenney](https://kenney.nl/assets/nature-kit) | CC0；頁面 1.0／2020，內附 License 標 2.1，差異保留 | 森林枯木、樹樁、岩石、灌木缺件 | log_large 已適配，268 面／Godot 566／0；[報告](ENV02_FREE_LOG_REPORT.md)，正式配置待做 |
| [Ultimate Nature Pack — Quaternius](https://quaternius.com/packs/ultimatenature.html) | CC0；June 2019，150 models，未列語義版本號 | 簡單切面植被／岩石，統一調色 | NOT_DOWNLOADED |
| [Ultimate Stylized Nature Pack — Quaternius](https://quaternius.com/packs/ultimatestylizednature.html) | CC0；May 2022，63 models，未列語義版本號 | 需要較完整輪廓的森林物件 | NOT_DOWNLOADED |

採用單件時保存下載網址、原包及內附授權、作者、實際版本／SHA；記錄原模型名、選取理由及修改內容到 ASSET_CREDITS。再檢查實測面數、單件預算、共用材質、比例／方向／原點、簡化碰撞、必要 LOD 及 Godot 畫面。原件保留，新版獨立輸出 GLB／PackedScene，符合道路和 NPC 預留空間後才替換。

現有七棟 G03 建築與十七件 G04 合格資產不因素材來源增加而重造。水車、葉菜仍為本專案 Blender 原創模型，不能歸為 Kenney／Quaternius 成果。枯木僅獨立模型／碰撞驗收，沒有把單件通過當作整張森林完成。
