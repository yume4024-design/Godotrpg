# 資產生成與整合紀錄

## A03.1 — 菇靈候選 PASS（2026-10-20）

重用 surface_v3，未重複生成。嚴格 GLB／Blender evaluated 9811 triangles、7 骨、6 動作；196 影格離線變形及 Godot 圖形 256 項／0 失敗，四面／動作截圖已查看。5 個邊界／118 非流形邊仍記為拓樸警告；沒有看到代表性畫面的骨架碎裂。完整來源、Blend、GLB、SHA、prompt_id、報告及真實引擎 WebP 在 `source_assets/asset_production_a03/spore_sprite/`。高密度原件 223MB 留在原目錄，不加入 Git。正式遭遇引用與 RPG 狀態未改；A04 待執行。

## A02 — IN_PROGRESS（2026-10-20）

13 套／52 張獨立 RGBA 四視圖結構 PASS，12 套來源可繼續，雷恩新右視圖仍保留人工確認。四組新增 NPC 已由使用者明確採用。詳見 [來源驗收](ASSET_A02_REPORT.md)；後續單件先重用現有合格候選，不重新批次排隊。此更新不宣稱新角色 3D 模型或正式整合完成。

## A01 — PASS（2026-10-20）

基線：feature/greystone-g06，HEAD `6af86143a23131991893e07897481c88009b54bc`；origin 為使用者指定 Godotrpg。規劃中的 aa71fc7 不是目前 HEAD。工作目錄已有大量怪物／NPC 候選與報告未提交，本輪保留；提交只選 A01 變更，TASKS／CHANGELOG 使用局部提交。

原文保存：[DEVELOPMENT_MASTER_PLAN_V1.md](DEVELOPMENT_MASTER_PLAN_V1.md)，SHA256 `C5E27290D4ECA69323F04491F448D807E4C97B8F3C44275CE123166C29B242FB`。追加角色／環境要求另見 [ASSET_PRODUCTION_REQUESTS.md](ASSET_PRODUCTION_REQUESTS.md)。

### 實作

- 共用 JSON policy／schema：一般敵人 10000，菁英／Boss／玩家／NPC 15000，inclusive maximum。明確預算、固定配件與可換裝備成本分開。
- GLB 活動節點計數與嚴格預檢、Blender evaluated mesh、Godot preview 使用同一 policy。保留原 --pixal 的 list／relative path 契約與 manifest 消費者相容，詳細 Gate 另寫 sidecar。
- 四視圖檢查、工作流副本參數化、分類 Skill 與本機安裝同步。Skin 不只看全場景有沒有 Armature，還檢查 mesh 綁定與 GLB 權重。
- 實際主角：雷恩 4815、莉雅 4806、法杖 140，莉雅與法杖同屏 4946；面數沒有隨預算提高而增加。

### 測試結果

Godot 4.7.2.stable.official.ed1daf0bf；Blender 5.2.2 LTS；Windows RTX 3080 圖形回歸。

| 項目 | 結果／證據 |
|---|---|
| Python 工具測試 | 7 組 PASS；含 15 個 GLB 案例、參數、參考 Alpha／鏡射與工作流副本、舊 bundle 相容 |
| Blender GLB 檢查器 | 15／15 案例符合預期；非法資產回非零退出碼 |
| 原生 evaluated mesh | 10／10；Array modifier 邊界、重複 mesh／collection instance、NaN 與未綁定 Armature |
| 精確上限匯出再讀 | 10000 面 fixture 匯出及重新 GLB 預檢 PASS |
| Godot policy | 26 cases，0 failures；全部類別與上下邊界 |
| 角色圖形預覽 | 12 checks，0 failures；滑鼠事件模擬，不宣稱實體輸入驗收 |
| 雷恩／莉雅圖形動作回歸 | 88 checks，0 failures |
| Godot 專案載入 | PASS：check-20261020-044256-108.log |
| Skill | quick_validate.py（Python -X utf8）PASS；專案與安裝 Skill／checker SHA 一致 |

面數案例：9999 PASS／10000 PASS／10001 FAIL；14999 PASS／15000 PASS／15001 FAIL。此處 FAIL 是非法資產被正確拒絕，因此測試通過。缺 UV、缺綁定、空白／失效 Mesh、NaN／Inf、非法索引與重複實例都正確拒絕。

實際圖形畫面已查看，預覽顯示 15000 上限且未壓住控制項。截圖在 `artifacts/godot-user/Godot/app_userdata/失落星核 — Project Crystal/character_previews/`。這項視覺驗收只確認工具 UI；既有角色造型品質未因此重新認證。

結構化結果保存：[ASSET_A01_TEST_RESULTS.json](ASSET_A01_TEST_RESULTS.json)。完整可重現命令在 [ASSET_TRIANGLE_BUDGET.md](ASSET_TRIANGLE_BUDGET.md)。原始 log／fixture 在 `artifacts/asset_a01/`（Git 忽略）。Godot logs：testassetbudget-20261020-044303-150、testcharacterpreview-20261020-044342-816、testpixalcharacters-20261020-044346-768。

### 發現與修正

1. 首輪 Blender 4 個有效邊界案例失敗：匯入器骨骼 Icosphere 的 80 面被算入模型，並因無綁定造成額外錯誤。改為精確辨識 custom_shape／glTF_not_exported 輔助物件並列出排除清單；真實實例仍計數並拒絕。15 案例重跑通過。首輪保留 `blender_cases.first_failure.json`。
2. 原生未綁定 Armature 案例暴露 pose=None；增加空 pose 處理，保持 MISSING_BOUND_ARMATURE 拒絕。10 案例重跑通過；首輪 log 保留。
3. 既有 manifest 工具依賴 bundle list 格式，已保留舊格式並增加相容測試，沒有改寫正式 generation_manifest。
4. Skill 驗證器以 Windows CP950 讀 UTF-8 失敗，使用 -X utf8 執行後通過，沒有修改系統語系或外部驗證器。

### ComfyUI 檢查

server_info：本機服務可用、ComfyUI 0.41.3、comfy-cli 1.22.0、RTX 3080 12GiB。僅讀取與驗證，未更新套件／模型。

當前來源 `3d_pixal3d_multi_views.json` SHA256：`1f85e6acb0b5dfac0b1aaaefe24c9252f4127d015ed8bc8cca6abb74286e7275`。已不同於 Skill 內 2026-10-18 歷史快照，因此以當前原件為準。

副本將 target_resolution 的字串 1536 改為 INT 1536；一般敵人候選目標 9200，保留 8% 修整空間。validate_workflow：valid=true、0 errors、0 warnings、64 nodes。原始工作流不變。未排隊任何生成，未驗證新版 API 裁切／條件圖片或 GPU 生成成功；這些仍是後續製作 Gate。

### 限制與下一輪

A01 PASS 只代表工具與規範可用，沒有把現有未驗收模型改成正式資產。未開 A03 生成、未重建 Windows RC2、未合併 main、Android／iOS 暫停。JSON Schema 檔案可解析，應用工具以共用 loader 驗證；未安裝額外 jsonschema 套件，未宣稱第三方完整 meta-schema 認證。

A02 工具 READY，可開始來源盤點；全批生成輸入尚非 READY。需要五敵、五 NPC、艾琳，以及使用者新追加雷恩／莉雅各四張獨立 PNG，合計 13 套 52 張。現有來源與缺口見後續清單，A02 尚未執行正式視覺／Alpha 驗收。
