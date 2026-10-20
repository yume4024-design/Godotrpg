# 蝙蝠拓樸診斷副本 — 非正式替換

2026-10-20；Windows／Blender 5.2.2 LTS／Godot 4.7.2.stable.official.ed1daf0bf。

**整體 HUMAN_REVIEW，完整收翼 FAIL。** 本機原件、先前三次修整及失敗報告均保留，沒有第四次 Comfy 工作。

- `topology_report.json` 記錄三個重複後翼島的來源面索引、邊界及 SHA；974 面刪除後 8712 triangles、11 骨。
- 保留面幾何及 UV 精確核對，corner normals 恢復；沒有自動合併 UV 拆分點或晶石，權重與原六段動作未改。
- `triangle_report.json` 嚴格 UV／Skin／索引／有限值／分類 10000 面上限 PASS；`deformation_report.json` 196 影格、最大拉伸 2.00327，循環端點一致。
- `godot_report.json` 真實 OpenGL 圖形 376／0，GLB SHA 與報告綁定；四面、拍翼、舊部分收翼、倒下影像已查看。未測正式戰鬥、實體操作或效能。
- `failed_full_fold_*` 是額外大幅骨軸姿勢的真實 Blender 渲染；不是交付動畫。使用 world-space XYZ：Wing 左／右 Y=±0.6、Z=±0.5；WingTip 左／右 Y=±1.9、Z=∓0.8。耳部跟隨翼骨、翼膜交疊，因此拒絕。
- 另測後折 root Z=±1.7、tip Z=∓2.5，翼展約 0.687m；仍有膜面交疊，未採用、未改寫原片段。舊 clip `fold_wings` 只有部分收翼，不能用名字代替完整收翼驗收。
- topology_v1 曾含 80 面匯入器顯示球，floor=-1 的數據不代表角色。v2 精確移除 bone.custom_shape 且屬 glTF_not_exported 的 Icosphere，最終三處均為 8712，原生 floor 最低約 0.147m；未放寬門檻。
- 12978 邊界／非流形邊主要包括 GLB UV／normal 拆分，仍未證明封閉／無交疊。需要耳與主翼區域重綁及必要的膜面重拓樸。

重現工具／命令與待辦見 `docs/CRYSTAL_BAT_TOPOLOGY_REPAIR.md`。`assets/models/rebuilt_enemies/crystal_bat_topology.glb` 只是未引用的檢查副本；禁止當作 A03/A04 PASS 選取。
