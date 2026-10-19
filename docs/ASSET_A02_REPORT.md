# A02 四視圖來源驗收（2026-10-20）

基線：feature/greystone-g06，8ddb5befd9802afb24673ee1bc5b0138f6b5b87c。狀態 **IN_PROGRESS**：13 套／52 張結構通過；12 套可供單件後續製作，雷恩修正右視圖仍保留人工確認，不把自動結構檢查當作設計核准。

## 交付及來源

來源庫：`source_assets/reference_library_20261020/`。每套均為 references/front.png、left.png、back.png、right.png，1024×1024、PNG RGBA、真 Alpha、完整輪廓、同套一致身高及 y=960 基線。蝙蝠依翼展調整整套比例，沒有截掉翼尖。原件未搬移或覆蓋。

| 組別 | 套數 | 來源／實際檢視 |
|---|---:|---|
| 五敵 | 5 | monster_rebuild_20261019 既有已修正方向獨立圖；蘑菇、甲蟲、野豬、蝙蝠、守衛各四面，保留既有設計 |
| 鐵匠 | 1 | npc/鐵匠-*；背面沒有工具袋或工具，保留正常皮帶與圍裙 |
| 道具商／旅館／男女村民 | 4 | 內建 imagegen 新製四面圖，使用者明確回答「四組都採用」；先分成四張，再供多視角條件使用 |
| 艾琳 | 1 | 艾琳角色圖/{正,左,背,右}.png；無箭袋、無武器，弓箭裝備後續獨立 |
| 莉雅 | 1 | assets/source/pixal3d/references/lia_*；保留金髮紫衣、臉部和服裝設計，只去背景及標籤 |
| 雷恩 | 1 | 主角-4面1.png 的第四格與左側同向；另存 turnaround_corrected.png，改為朝右，保留黑髮紅衣與不對稱裝備；人工採用確認待回覆 |

每張 SHA256、透明度、輪廓 bounds 及尺寸在 `structural_audit.json`；原圖／中間圖 inventory.json、裁切／縮放及輸入輸出 SHA 在各 references/normalization.json。catalog.json 將來源授權／設計確認與自動結構結果分開。不得由此宣稱 3D 模型或動畫已完成。

四組 NPC 的外觀確認原文保存在 npc_design_approval.json。商人為綠背心女性、旅館老闆為酒紅背心男性、男村民為赭黃上衣、女村民為藍背心紅棕裙；這是使用者核准的設計，不是下載的素材商店模型。

## 真實預處理

ComfyUI 0.41.3／comfy-cli 1.22.0，本機 RTX 3080 12GiB。僅使用已安裝 BiRefNet safetensors 去背；未更新節點、下載模型或使用付費 API。節點鏈：LoadImage → RemoveBackground → InvertMask → JoinImageWithAlpha → SaveImageAdvanced。JoinImageWithAlpha 本身會反轉 mask，故顯式 InvertMask 維持正確 Alpha。

| prompt_id | 用途 | 狀態 |
|---|---|---|
| 45dd0521-13b0-4ecd-85c4-633a8f0b3266 | 莉雅四圖去背 | completed，已取回 |
| 5ebc06fb-eaac-4ceb-927b-3f45b460817e | 鐵匠／艾琳八圖去背 | completed，已取回 |
| e7df9a30-adaa-4ed5-a751-ed2c003ae300 | 雷恩修正合圖去背 | completed，已取回 |

這三項為圖片預處理，**不是 Pixal3D 模型生成**。API 圖及回傳保存在 artifacts/asset_a02；圖片副本在來源庫。四組 NPC 及雷恩方向語義修正使用內建 imagegen，生成 sheet 留在來源庫，沒有以機械鏡射代替異側裝備。

## 可執行驗證

```powershell
& 'D:/Comfy-Desktop/ComfyUI-Installs/ComfyUI/ComfyUI/.venv/Scripts/python.exe' -X utf8 scripts/tools/build_asset_reference_catalog.py
& 'D:/Comfy-Desktop/ComfyUI-Installs/ComfyUI/ComfyUI/.venv/Scripts/python.exe' -X utf8 tests/asset_reference_pack_test.py
```

實際：13／13 結構 PASS、52 張 SHA 一致；三組測試 PASS（真實素材、合圖分離／原件保留、缺圖拒絕）。已查看全部 13 套四面總覽；左右方向、完整手腳／翼展、文字移除、鐵匠背面與艾琳無箭袋逐項檢視。自動 audit 仍回 HUMAN_REVIEW／ready=false；獨立 catalog 只依實際來源採用依據開放 12 套。

限制：參考圖不是精確測量的正交攝影，有微小視角／配件差異；3D 生成後須重新驗證背面、手指與關節。雷恩新第四視圖待人工確認，其餘已核准來源可按 A03 → A04 → A05 順序繼續。正式 v0.6.1、RC2、遊戲數值及存檔均未修改；Android／iOS 暫停。
