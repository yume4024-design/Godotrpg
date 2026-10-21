# 莉雅新來源／靜態候選證據

基線bf0a3b1，2026-10-22；**整體IN_PROGRESS，沒有綁定或正式接入**。詳見 [報告](../../../../docs/LIA_REBUILD_20261022_REPORT.md)。

- `raw/`：生成貼圖模型的Blender正／側／背，初始12454面、匯入後12442面。
- `face_v1/`：前向法線遮罩的失敗；背側摺面誤著色，不採用。
- `selected/`：深度遮罩副本；前臉改善，但頸領及後髮／身體線條仍待修整。
- `godot/`：18／0靜態報告及九張實際framebuffer，短邊512。
- `blender_import.json`、`static_surface_audit.json`：獨立匯入與面數／UV／材質檢查，沒有虛構骨架。
- `static_preservation.json`：位置／UV／索引／角法線／面數保留，以及未焊接的實際物理邊界診斷。
- `evidence.json`：正式main／Lia視覺與SaveCodec未改、原正式角色88／0及工具預設Ren18／0。
- `sha256.json`：相對專案根目錄；文字UTF8無BOM／LF，二進位原樣計算。

新靜態GLB在 `assets/models/rebuilt_characters/lia_static.glb`，原生工作檔在 `../face_v2/lia_surface.blend`。高面數原件、生成貼圖GLB及中間大圖仍保留於本機 `../outputs/`，不以大型暫存檔加入Git。投影原件、內建imagegen提示詞／Alpha／SHA、核准四圖與工作流收據均可追溯。

本輪只提交一次3D工作：5a7e6c0e-7cf5-4ad1-8844-bb9838777e58，已completed。條件工作1e256b7e-39ff-4f8c-bb81-7dc760d42119也completed；不將歷史CLI佇列或觀察timeout當成新送件理由。

重建工作流副本使用既有工具與本輪live slots，輸出需新資料夾：

```powershell
python scripts/tools/prepare_reference_asset.py --source "D:/Comfy-Desktop/ComfyUI-Installs/ComfyUI/ComfyUI/user/default/workflows/3d_pixal3d_multi_views.json" --slots source_assets/character_rebuild_20261020/lia/workflow_slots.json --asset lia --category player_character --tag 20261022 --output artifacts/lia_workflow_reproduce
```

此命令不排隊生成。再次生成前重新取得live slots、核對目前工作流SHA與模型、實際圖片及VRAM；舊收據不代表日後外部狀態不變。靜態重現入口為 `tools/review_static_character.ps1 -Character lia`，使用獨立APPDATA，無人物控制或人工輸入認證。
