# spore_sprite — A03 候選驗收

2026-10-20；Godot 4.7.2.stable.official.ed1daf0bf／Blender 5.2.2 LTS／Windows RTX 3080。
狀態 PASS，範圍僅模型、骨架、代表性動畫與圖形匯入；A04 正式戰鬥／探索整合未執行。

- 分類 common_enemy，上限 10000；GLB／Godot 9811 triangles。
- 骨架 7 骨，6 片段；Blender 196 影格數值檢查 PASS。
- Godot 圖形 256 checks，0 failures；UV／貼圖／Skin、動作切換、循環／單次、四面與重新實例化驗證。
- 實際視覺檢查：四面、六動作及施法／倒下已查看；原圖設計保留，代表畫面無碎裂；非流形交疊仍為警告。
- 拓樸警告：[{"mesh": "spore_sprite_body", "boundary_edges": 5, "nonmanifold_edges": 118}]。沒有宣稱全封閉或完美自碰撞。
- 舊 Pixal3D 原始及高密度來源保留；本輪重用選定候選，沒有重複提交生成工作。雜湊、歷史 prompt_id、參數見 generation_manifest.json。

可重現：tools/review_enemy_asset.ps1 -Asset spore_sprite；離線數值工具 scripts/tools/audit_asset_motion.py；嚴格 GLB 工具 audit_character_glb.py。
產生的 4 張 WebP 為真實 Godot 畫面，不是模型示意。動畫／物理／戰鬥功能需在 A04 接線後重新驗證；數值、技能、旗標及存檔未改。
