# 灰石村 Pixal3D 建築來源 — 2026-10-23

狀態：四種建築完成生成與候選修整；完整 Blender 場景已接入獨立 RPG 候選並通過 Windows 自動化驗收。
依使用者灰石村參考圖底部資產條製作。未把舊程序模型改名冒充 AI 成果。

## 已完成的本機生成

| 資產 | 完整工作 prompt_id | 原 GLB triangles | 修整版 triangles / 上限 |
| --- | --- | ---: | ---: |
| 旅館 | 37378b05-7ed0-4475-8a6e-c37b19c9582e | 35153 | 35247 / 40000 |
| 民宅 | 376d2f40-fb24-46b8-81ec-2a3f75494a56 | 26093 | 26063 / 30000 |
| 道具店 | 716a17d7-dc0f-45ea-950a-45e52696f7c3 | 26734 | 26720 / 30000 |
| 武器店 | e4dd3124-13bd-4c76-9b54-e3fce50e4552 | 26309 | 26351 / 30000 |

`final_candidates.json` 記錄修整版相對路徑、SHA256、三角面及驗收限制。
藍灰屋頂民宅沿用同一幾何與貼圖，在 Blender 改屋頂材質；不是第五次 AI 生成。

目前工作流來源 `workflow_source.json` SHA256：
`1f85e6acb0b5dfac0b1aaaefe24c9252f4127d015ed8bc8cca6abb74286e7275`。
原工作流未修改。本機目的地經 `server_info` 確認為 `127.0.0.1:8188`。

## 四路輸入與來源

每項保留原正交圖、獨立 RGBA 上傳圖、API 副本、實際 conditioning 成圖、
manifest、job 與 GLB / Blender 稽核。相機為水平正交正／左／背／右；
裁切去文字、保留相同比例，不鏡射冒充另一面。
`ImageCropToMask` 的 padding 依視圖尺寸補償，避免窄側面被獨立放大。

`prepare_inn_ai.py` 的名稱保留歷史，可處理四類建築：

```powershell
python scripts/tools/greystone/prepare_inn_ai.py --asset item_shop --budget 30000
```

此命令只製備輸入與 API，不排程。生成前依 Skill 檢查 GPU、validate、
實際四路成圖，再以單一重型工作送件，保留 prompt_id。
勿為重建場景重新送出已完成工作。

## 修整與限制

旅館保留門板修補；`repair01` / `repair02` 的背屋頂覆蓋試作拒用，
候選採 `door_only`，原屋頂仍有局部不規則瓦片。
其他建物以內縮灰泥外殼補缺片，保留窗戶深度、原 UV 與來源；
首版外殼遮窗已拒用，採 `shell_repair02`。
武器店另修正錯誤淺色瓦片材質，補獨立鐵砧幾何。
生成造成的細部木框／牆面不規則仍屬候選美術限制，不能用面數 PASS 抵算。

原始高面幾何在各 `job.json` 指向的本機 ComfyUI output 保存；
不把數百 MB 的原始來源或中間失敗檔當遊戲資產上傳。
Blender 匯入省略少量反向重疊幾何，原 GLB 與匯入面數分開記錄；
精確稽核確認原件沒有零面積或重複索引面，不能稱為退化面清除。
民宅來源保留兩個同向重疊面；主檔產生器精確移除後，遊戲 GLB 為 26061 面、同向重疊 0。其餘反向面保留，不盲刪。
最終修整版已另做 GLB 結構、索引、UV 與預算檢查。

完整主場景：`../greystone_blender_20261023/greystone_master.blend`。
建模與匯出入口：`scripts/tools/greystone/build_blender_village.py`、
`scripts/tools/greystone/export_blender_master.py`。每次使用獨立背景 Blender，
保留使用者正在編輯的其他工作檔。

完整功能證據及限制見 ../greystone_blender_20261023/acceptance/summary.json 與 docs/GREYSTONE_REFERENCE_REBUILD_REPORT.md。原始高面數、中間失敗 GLB／Blend 留本機；Git 僅納入重建所需修整來源及輸入／工作紀錄。
