# 主角重製 — 2026-10-20 候選進度

**2026-10-22更新：** 新雷恩10655面／19骨／14段與330面可換劍完成獨立可玩接入，控制器93／0、村莊64／0、正常速度序章84／0及另程序9／0；原88／0與G06 576／0。正式外觀預設仍保留、莉雅本輪重製仍待；[最新報告](REN_RUNTIME_INTEGRATION_REPORT.md)。下方未做狀態是各較早階段時點，不代表此次終態。

**整體 IN_PROGRESS。** 2026-10-21 雷恩新衣褲拓樸及腰帶縫合候選已完成：10655面／19骨／七段，127影格、保留表面、原角法線門檻及2.550458mm腰帶連接PASS，Godot獨立72／0；[最新報告](REN_AUTHORED_GARMENT_REPORT.md)。正式控制器／持劍／村莊戰鬥／存讀檔回歸未做，沒有替換正式引用。莉雅的新一輪生成尚未開始。既有兩人模型與正式v0.6.1保留，不將原4815／4806面角色改名當作新成果；下方較早的run接縫FAIL為保留的歷史診斷。

## 雷恩本輪來源及生成

- 已核准獨立四視圖，含修正朝右；使用 source_adoption_20261020.json 的原圖 SHA 收據。四路條件圖實際查看完整身體、前左背右與透明度；來源測試 4 組再次通過。
- 重新讀取使用者目前 `3d_pixal3d_multi_views.json`，SHA256 `1f85e6acb0b5dfac0b1aaaefe24c9252f4127d015ed8bc8cca6abb74286e7275`；副本 shape 1536／texture 4096／remesh 768／target 13800、smooth 0／drop-small 0，保留原件。兩份 API 都 valid，沒有 partner／付費節點。
- 條件 job `d770e973-042b-48c0-8826-ba582cd43212`；正式單件生成 `ee346813-4b08-4d96-bae8-236190aee72a`，均 completed。送件前實測 RTX 3080 可用 VRAM 11039605878 bytes；未批次排第二位角色。
- 原始形狀 **8294120 triangles／148837672 bytes** 留本機 outputs，未加入 Git；生成貼圖 GLB **12824 triangles** 原件保留，Blender 匯入去除 16 個退化面後 **12808**，沒有額外減面。
- 模型、工作流、prompt_id、原件及輸出 SHA、失敗及最終證據在 `source_assets/character_rebuild_20261020/ren/`。

## 表面修整及實際限制

初版眼部有黑色貼圖污痕，受控同燈光比較確認關閉 normal map 仍有污痕，不把問題全歸為法線。用內建 imagegen，依已核准雷恩參考修補現有頭部 emission 圖，原生成 PNG 保留於 Codex generated_images 並複製進專案；完整提示詞／Alpha／SHA 在 head_projection。

只在正面 head span 0.60m／center-z 1.70m 的有界區域投影，背面明確留空；原 UV 及幾何沿用，4K emission 回烘後改簡單粗糙材質。第一版 centroid-depth mask 在部分被瀏海遮住的三角面留下黑條，保留 FAIL 及 head-review 圖；第二版明確使用 front_facing 模式，已在真實 Blender／Godot 正、側、斜側檢查，沒有新增頭髮或臉部幾何。

第二版正面眼睛可讀性已改善，仍有眼下明暗接縫、衣料／扣件貼圖粗糙、AI 手部待握持驗證等限制；不宣稱五指獨立骨架、口型、眨眼或正式美術完工。此階段為靜態候選，後續綁定前繼續檢查手／肩／腰衣擺區域。

## 可執行結果

| 檢查 | 實際結果 |
|---|---|
| 生成原件 GLB 靜態預檢 | PASS，12824／15000，UV／索引／有限值；無骨架如實標示 |
| 修整 GLB＋Blender evaluated | PASS，兩者 12808／15000；1.95m、原點貼地 |
| Godot 靜態候選 | **18 checks／0 failures**，九張全身／頭部畫面、4K albedo、UV、有限座標、重新實例化；沒有 Skeleton／動作如實記錄 |
| 工具預設投影回歸 | 預設 span／center／來源資料相同，正背 render pixels 逐像素相同 |
| 工具預設道具商回烘回歸 | 4096² albedo pixels 與已核准 surface_v1 完全相同；舊資產未寫入 |
| 既有雷恩／莉雅 | TestPixalCharacters **88／0**，仍為 4815／4806 面、七段動作與原法杖，非本輪新角色動作通過 |
| 新骨架／動作 | 19 骨／七段；原 12808 面接縫版 run FAIL。後續 14074 面分層副本的 127 影格數值 PASS，但真實跑步穿插／角法線保存 FAIL，仍拒用；[最新分層報告](REN_GARMENT_LAYER_REPORT.md) |
| 新掛點／正式行走／戰鬥／存讀檔／效能 | **NOT_STARTED**，未提前替換正式引用 |

Godot 4.7.2.stable.official.ed1daf0bf，Blender 5.2.2 LTS。日誌：check-20261020-114938-826、testpixalcharacters-20261020-115330-027；新候選獨立 APPDATA 日誌在 artifacts/character_rebuild_20261020/ren/godot_static。沒有新增實體鍵鼠／手把或 Android 驗收。

畫面微評（靜態預覽）：COMP-SAFE-EDGE 2、COMP-NEG-SPACE 2、COMP-BALANCE 2、LIGHT-KEY-FILL 2、ORIG-READ 2、ORIG-STRUCT 1、ORIG-TILE 1、ORIG-SYN 1，13／16（B）；衣料與眼下接縫待修整，不能由面數通過推導正式品質完成。

## 交付與下一項

- 執行用獨立預覽：`assets/models/rebuilt_characters/ren_static.glb`；源工作檔 `ren/face_v2/ren_surface.blend`，原件與第一版保留。GLB SHA256 `f94a54b6eec3875f137e6dd87b79d501ef0d90b7a240f09061a80c857f14a0f0`。
- `tools/review_static_character.ps1` 重現靜態圖形檢查；不是可控制的角色或正式遊戲入口。
- 下一項：依接縫工作單處理真正衣褲分界，重跑七段變形及實際播放回復／掛點測試；通過才正式戰鬥／探索整合。莉雅按其已核准金髮紫衣設計逐件製作，不同時排隊。
- A03 蝙蝠完整收翼、A05 旅館拓樸、A04、場景模組整合、免費素材逐件適配、Windows Gate 及完整 C1 仍保留於持續目標；沒有將此報告當作第一章完成。
