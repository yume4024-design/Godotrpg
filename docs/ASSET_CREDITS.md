# 素材來源與修改紀錄

## 2026-10-26 — 礦坑連續岩層／彎軌／工具區

- 依既有使用者礦坑參考，以本專案Blender Python原創連續岩殼、岩板、彎曲軌道、木工具架、鎬與礦石箱；重用既有模型與共享材質，未下載外部素材或呼叫付費生成服務。
- [來源、修改範圍與SHA](MINE_CONTINUITY_20261026_REPORT.md)；原箱桶、晶體、支架、角色來源保留。

## 2026-10-26 — 礦坑參考建造第一輪

- 使用者提供本輪礦坑參考圖；原完整圖與縮小裁切版均保存於docs/references。採用本專案原創Blender Python岩體、坑門包覆、木構、水體與Shader，未下載外部素材或使用付費生成服務。
- 重用既有G04箱桶／星晶及ENV02支架；僅在獨立礦坑來源複本修改材色、追加箱體接縫與斜撐，原資產檔未覆寫。[來源、修改與SHA](MINE_REFERENCE_20261026_REPORT.md)。

## 2026-10-26 — 灰石村原創建築立面與水體收尾

- 依使用者灰石村參考圖，以專案Blender Python原創建模：連續瀑布、17個水沫、14條石旁水紋、18塊河岸／崖口石，以及五種共用木框建築立面。保留原有來源檔及既有屋頂，未下載新的外部素材、付費素材或新增署名義務。
- 庭院重用本專案既有灌木與花朵，增為150株；新的Godot水流／水沫Shader由本專案撰寫。Blender程序石材由Godot共用rock材質等效呈現。
- [檔案、來源修整與測試](GREYSTONE_SCENE_COMPLETION_REPORT.md)；完整Blender主檔及獨立GLB均保存，MCP僅同步指定研究場景。

## 2026-10-26 灰石村岩壁修復

使用專案Blender Python修整既有195塊岩壁及草土邊緣，保留既有材質與來源。無新下載、付費生成或第三方授權變更。[幾何與畫面證據](GREYSTONE_CLIFF_SHADOW_REPORT.md)。

## 2026-10-25 灰石村自然岩壁與草皮

依使用者最新參考圖，以專案Blender Python重建既有岩壁外皮和草土邊緣；沿用原石材、草地、土壤shader。Blender MCP用於匯入檢視，未新增第三方下載、付費生成或授權變更。[來源與測試](GREYSTONE_NATURAL_EDGES_20261025_REPORT.md)。

## 2026-10-25 灰石村門廊、招牌與庭院

沿用使用者最新場景參考圖與既有Shrub／Flowers資產及材質；木製門廊補強、酒杯／藥瓶／鐵砧標誌和陳列架由本專案Blender Python與MCP製作。沒有新增外部下載、付費素材或授權變更。[來源與雜湊](GREYSTONE_COURTYARD_20261025_REPORT.md)。

## 2026-10-25 灰石村建築輪廓修整

沿用既有使用者參考圖及已記錄來源的建築屋身；交錯屋頂、山牆、木百葉及屋瓦底板由專案Blender Python製作。無新增第三方素材、付費生成或授權變更。[本輪來源與雜湊](GREYSTONE_ARCHITECTURE_20261025_REPORT.md)。

## 2026-10-25 灰石村視覺細節修整

既有使用者參考及專案模組來源維持不變；新增岩壁斷層網格、嵌石、窗框／小窗屋頂、材質和光照由本專案Blender Python／Godot Shader製作。無新增外部素材、付費API、貼圖下載或授權變更。來源腳本及雜湊見[修整報告](GREYSTONE_REFERENCE_FINISH_20261025_REPORT.md)。

## 2026-10-24 — 更新參考圖的灰石村模組修整

使用者提供 `docs/references/greystone_reference_20261024.png` 作佈局／配色參考，未用作表面貼圖。本輪重用先前本機 Pixal3D 合格牆面與 G04／reference_modules；以背景 Blender Python 重做屋頂、石階、拱橋、封閉船殼、階地岩面及造景，材質為本專案程序 Shader。未新增外部下載、付費素材、AI 圖像或 3D 生成服務。原始合格 GLB 與舊 Blender 主檔保留；新主檔 `source_assets/greystone_reference_20261024/greystone_master.blend`，來源／SHA 詳見其 `evidence/asset_receipt.json`。

## 2026-10-24 — 礦坑內部參考場景

使用者提供`docs/references/mine_interior_reference.png`作構圖與模組設計參考，未把概念圖當遊戲貼圖。新岩層、橋、鐵軌、礦車、吊籠、營帳與造景由本專案Blender Python製作，來源`source_assets/mine_reference_20261024/mine_reference_master.blend`；重用G04 crate／barrel／crystal_blue及ENV02 mine_support_frame，沿用原作者與授權紀錄，來源SHA列於`assets/models/mine_reference/manifest.json`。本輪未下載第三方素材或使用付費API；岩土／木紋／水流／火把為本專案共享Shader。[範圍與檢查](MINE_REFERENCE_REPORT.md)。

## 2026-10-24 — 灰石村程序表面與水體

本專案原創 GDScript／Godot shader 與 Blender 程序節點製作土粒、草色、礦物紋理、波紋及水深泡沫；未下載第三方貼圖、模型、外掛或使用付費服務。沿用既有灰石村參考、模型與授權紀錄；兩片水底為原水面網格的純視覺衍生。來源配方、測試與限制見[材質報告](GREYSTONE_SURFACE_REPORT.md)。

## 2026-10-23 灰石村 AI 建築候選

使用者灰石村概念圖 `docs/references/greystone_20261023.png` 為設計來源；內建 imagegen 建立旅館、民宅、道具店、武器店獨立正交來源，再由本機 ComfyUI Pixal3D 生成。來源與 workflow SHA / prompt ID 保存在 `source_assets/greystone_ai_20261023/`。Blender 修補由本專案腳本完成；未下載第三方模型、未購買素材、未傳至外部 3D 服務。場景／RPG Windows 自動化驗收已完成；局部 AI 木框／屋瓦不規則與未驗收平台見重建報告。

## 2026-10-23 — 灰石村參考圖底部模組

使用者提供docs/references/greystone_20261023.png作造型參考；本機Blender5.2.2原創程序幾何，四建築與十件設施／環境模組，無外部下載模型或貼圖。GLB位於assets/models/greystone/reference_modules，工作檔及配方、面數／UV／實際畫面與限制見[重建報告](GREYSTONE_REFERENCE_REBUILD_REPORT.md)。參考圖本身保留為使用者提供資料，不當作新建模輸出。

## 2026-10-22 — 原創礦坑支架模組

Project Crystal原創Blender參數化木架，804 triangles、三個剛性Mesh；沿用本專案G04木材／端木／鐵材配色與共用材質，沒有下載商店模型、付費生成或外部貼圖。來源scripts/tools/greystone/build_mine_support.py、source_assets/environment_rebuild_20261022/mine_support/mine_support_frame.blend，遊戲GLB assets/models/environment/mine_support_frame.glb；來源／輸出SHA、失敗輪次及獨立驗收見[報告](ENV02_MINE_SUPPORT_REPORT.md)。後續已以八份純視覺PackedScene接入新版G06礦坑，原碰撞及正式v0.6.1保留，見[整合報告](ENV02_MINE_SUPPORT_INTEGRATION_REPORT.md)；不將原生幾何佔位當作這次新製模型。

## 2026-10-22 — 莉雅新生成與頭部底色衍生

沿用使用者已核准金髮藍眼紫衣四視圖與既有本機Pixal3D權重／工作流；單件prompt 5a7e6c0e-7cf5-4ad1-8844-bb9838777e58，沒有付費partner節點或第三方商店下載。本輪內建imagegen依實際頭部emission投影與原設計修整底色，正面區域回烘既有UV，原圖／模型保留，沒有新增髮型或造型授權主張。新1254²真Alpha修整圖已存入專案，完整提示詞、來源SHA、工作原件與限制見[莉雅報告](LIA_REBUILD_20261022_REPORT.md)及source_assets/character_rebuild_20261020/lia/head_projection/repair_provenance.json。靜態候選未宣稱綁定或正式可用。

## 2026-10-22 — 雷恩動作衍生與原創青銅短劍

沿用使用者已核准黑髮紅衣設計、本機Pixal3D及前輪衣褲拓樸原件；本輪以Blender Python新增七個動作片段及330面青銅短劍，沒有新下載／購買外部模型或付費API。短劍具UV、三個原創色彩材質，與角色分開統計。原角色圖／模型／貼圖保留；生成權重及來源的既有授權紀錄不變。[來源、修改與限制](REN_RUNTIME_INTEGRATION_REPORT.md)／[凍結證據](../source_assets/character_rebuild_20261020/ren/runtime_acceptance_20261022/README.md)。

## 2026-10-21 — 蝙蝠人工局部翼部重建

沿用已核准原創蝙蝠與本機Pixal3D來源，Codex以Blender Python保留頭身耳腳並局部建立薄膜、翼骨與六顆立體藍晶、64²共用色盤及完整摺翼骨架。未新送Comfy工作、未下載商店或付費API素材，也不宣稱第三方美術師交件。原始圖／模型與失敗副本保留；來源SHA、修改範圍、獨立候選驗收及正式接入限制見[完整收翼報告](../source_assets/asset_production_a03/crystal_bat/manual_fold_acceptance/README.md)。既有Pixal3D權重／來源授權記錄不變。

## 2026-10-21 — 旅館老闆圍裙重拓樸與獨立動作

沿用使用者採用的酒紅背心／米白圍裙設計及既有本機Pixal3D原件（原GLB83493fd0fe0078fc18a7d0b5d9831f668b7eab4823773bb2be7263f5c7482fdc）。Codex在Blender5.2.2以原來源副本作局部前布片重拓樸、4mm厚度、原albedo UV回烘、20骨Idle／Talk；沒有新Comfy生成、下載／購買第三方模型或更動外觀授權。最終GLB3baeda38ab638039aa01e9b2a4333f118a4df277c89e683ee8b26e70ea9c111d，12785面；10888保留面位置／UV與原貼圖保存，法線有微小重新編碼差。來源／工作Blend／失敗及實際圖見source_assets/npc_rebuild_20261020/innkeeper/manual_acceptance/；屬獨立候選，正式NPC替換未完成。

## 2026-10-21 — 既有主角的探索步態衍生資產

沿用已記錄的使用者角色設計／本機Pixal3D來源，不新增外部模型或購買。Blender5.2.2在保留的ren_rigged.blend／lia_rigged.blend副本只改Walk／Run，輸出ren_locomotion.glb／lia_locomotion.glb與周期profile。POSITION／NORMAL／UV／索引／權重及五段戰鬥片段均與原GLB逐緩衝相同；4815／4806面、19骨／七段。來源SHA及輸出SHA見source_assets/exploration_locomotion_20261021/glb_preservation.json，原GLB／blend保留；本輪沒有新增第三方授權主張。

## 2026-10-20 — A04 荊棘野豬接入

沿用使用者核准四視圖、A03 本機 Pixal3D／Blender 來源；generation_manifest、舊高面數來源與既有粗糙接面限制保留。GLB SHA `3b212d70f5de4321325aba30d6de338ea9f7e8b49103d8bfa3267554fae493ed`，9998面／12骨／七段，未再生成或改貼圖、UV、網格與權重。只新增遊戲視覺PackedScene、名牌與選用Run／Charge播放；沒有新增技能、付費或第三方下載素材。舊場景在scenes/characters/legacy保留。

## 2026-10-20 — A04 菇靈與礦甲蟲視覺接入

- 重用 A03 已保存的使用者採用四視圖／本機 ComfyUI Pixal3D＋Blender 候選；來源與工作流、prompt_id、原始高面數檔案見 `source_assets/asset_production_a03/{spore_sprite,ore_beetle}/generation_manifest.json`，本輪沒有新下載或購買第三方角色。
- 菇靈 GLB SHA `bd38151d3b0e8bb48063eb72914b9c99f6ba97511d72ea1ec9b13f52de56d037`；礦甲蟲 `5eb5cc52ae0ece0595baecca218eeec1621e8a43a05c375384a9b6c58512d2af`。幾何、UV、4K貼圖、骨架與原動畫均保留，只新增遊戲動畫介面、PackedScene與名牌錨點。
- 舊 GLB 未刪、原視覺場景保存在 scenes/characters/legacy；本節記錄沿用來源，不新增模型／生成工具的授權主張。沒有付費素材或原版商業遊戲素材。

## 2026-10-20 — 原創水車固定架與場景配置

水車 bank 變體新增 160 面 A 架／水下基座，仍為本專案 Blender 原創，沿用 G04 wood／iron／stone 材質；原輪體／軸 1212 面不重造，總 1372 面。無第三方模型／付費素材／大型貼圖，源檔及 SHA 見 [ENV02 整合報告](ENV02_VILLAGE_INTEGRATION_REPORT.md)。這不是 Kenney 枯木的修改內容，枯木來源仍另記。

## 2026-10-20 — Kenney 免費枯木（已下載並修改）

Kenney [Nature Kit](https://kenney.nl/assets/nature-kit)，內附 License.txt 為 CC0 1.0／Nature Kit (2.1)，署名非必須，本專案保留作者。官網仍列 1.0／2020，版本差異及 ZIP／原 log_large／修改後 GLB 的 SHA 均記錄於 [單件報告](ENV02_FREE_LOG_REPORT.md) 與 source_manifest.json。

只取 log_large.glb：3m 比例／貼地原點、單段倒角、G04 木色與新共用切口色、修除退化面；268 面、無貼圖、獨立碰撞候選。原包本機保留，原模型與完整授權提交；沒有購買、捐款或整包匯入，正式森林尚未採用。

## 2026-10-20 — 新雷恩原創來源及臉部修補

使用者已核准雷恩原創四視圖與修正右側面，本機目前 Pixal3D 工作流生成新幾何／UV／貼圖；沒有使用第三方人物、購買素材或付費 Comfy API。內建 imagegen 用原頭部渲染與核准設計修補臉部，完整提示詞／原生成圖／透明 Alpha／SHA 保存，Blender 有界正面投影至原 UV。失敗第一版與高密度來源保留；來源及範圍見 [主角重製報告](CHARACTER_REBUILD_20261020_REPORT.md)。

## 2026-10-20 — 原創葉菜與免費來源核對

葉菜為本專案 Blender 原創模型，沿用 G04 葉色共享材質，無第三方模型／貼圖／付費 API。使用者追加允許網上免費場景模型修改；官方 Kenney Nature Kit、Quaternius Ultimate Nature／Ultimate Stylized Nature 均標示 CC0，版本快照、連結、用途與尚未下載狀態見 [來源表](FREE_ENVIRONMENT_ASSET_SOURCES.md)。採用後逐件保存原包授權、SHA 與修改內容，不以候選清單冒稱已匯入。

## 2026-10-20 — ENV02 原創水車

本專案 Blender 腳本原創輪框、輻條、水斗、軸承模型，沿用本專案 G04 木／鐵／石色盤及共享材質；未下載第三方水車、購買素材或送出付費 API。Native／GLB／SHA／首版閃線及最終預覽保存，範圍見 [水車報告](ENV02_WATERWHEEL_REPORT.md)。

## 2026-10-20 — 蝙蝠拓樸檢查副本

沿用既有本機 Pixal3D 原創蝙蝠，沒有新生成、商店下載或付費 API。Codex 透過 Blender 辨認並刪除三塊重複後翼，逐角保留原 UV 與法線；未宣稱第三人美術師已完成。完整收翼仍 FAIL，來源／SHA／限制見 [修整工作單](CRYSTAL_BAT_TOPOLOGY_REPAIR.md)。

## 2026-10-20 — 女村民衣料與對話候選

女村民沿已核准原創四視圖與本機同一 Pixal3D 工作流生成；原件保留，未下載商店資產或付費 Comfy API。內建 imagegen 修補正背上半身色斑，提示詞／原圖／Alpha／SHA 保留，再由 Blender 限定區域回烘 UV。骨架／Idle／Talk／裙擺權重為專案程序製作，未宣稱人工模型師或布料物理；來源與實際驗收見 [A05 報告](ASSET_A05_REPORT.md)。

## 2026-10-20 — NPC 骨架及旅館生成失敗紀錄

道具商在本專案既有 Pixal3D／顏色修整副本加入原創 20 骨及 Idle／Talk，保留 UV／顏色。旅館老闆沿核准原創四視圖，以本機同一工作流生成；沒有第三方素材下載、購買或付費 API。前圍裙視覺失敗，兩版修整未採用；原件、參數、SHA 與失敗畫面保留，來源狀態見 [A05 報告](ASSET_A05_REPORT.md)。既有模型權重授權紀錄不變。

## 2026-10-20 — 全部來源採用及鐵匠對話候選

使用者已採用 13 套／52 張來源（含雷恩修正朝右）；原文及圖片 SHA 見 source_adoption_20261020.json。鐵匠重用本機既有 Pixal3D／Blender 來源，只在新副本新增 Talk、保留 Idle、斷開已確認異常的法線圖；未下載商店素材、購買或更改權重授權。原十動作與材質保留，候選及限制見 [A05 報告](ASSET_A05_REPORT.md)。蝙蝠保留完整收翼，人工拓樸工作單尚未完成。

## 2026-10-20 — A05 NPC 候選來源與顏色修補

道具商使用已由使用者核准的綠背心四視圖，本機現有 Pixal3D 工作流生成；沒有新商店下載或付費 Comfy API。內建 imagegen 修補衣服局部顏色，Blender 原生 BVH 投影與 emission-only 回烘，原件及提示詞／SHA 均保留。高密度來源留在本機 source_assets，未將巨型中間檔上傳。完整來源、prompt_id、測試及限制見 [A05 報告](ASSET_A05_REPORT.md)。鐵匠重用既有來源，此輪僅診斷材質。

## 2026-10-20 — A02 NPC 四視圖來源

source_assets/reference_library_20261020 保留使用者既有五敵、鐵匠、艾琳、雷恩及莉雅設計的來源／SHA；四組新 NPC 以內建 imagegen 製作，使用者明確回答「四組都採用」。雷恩第四格朝向修正另存，未覆蓋原件；其採用仍保留人工確認。圖片去背使用本機既有 BiRefNet，分離／縮放為專案機械工具，無新增第三方商店資產或付費 API。模型權重的既有授權紀錄不因本次去背而改寫。來源、prompt_id、限制與驗收見 [A02 報告](ASSET_A02_REPORT.md)。

## 2026-10-17 Pixal3D 雙角色重製

- 使用者指定本機 `3d_pixal3d_multi_views`，ComfyUI 0.41.3、模型檔 `pixal3d_multiview_int8_convrot.safetensors`；未在此儲存庫分發權重或呼叫付費 API。
- [Comfy-Org/Pixal3D](https://huggingface.co/Comfy-Org/Pixal3D) 為 [TencentARC/Pixal3D](https://huggingface.co/TencentARC/Pixal3D) 的封裝；模型頁均標示 MIT，核對日期 2026-10-17。工作流為使用者已配置副本，參照 [官方多視角模板](https://github.com/Comfy-Org/workflow_templates/blob/main/templates/3d_pixal3d_multi_views.json)。
- 雷恩／莉雅參考圖由使用者提供；副本與雜湊存於 `assets/source/pixal3d/references/`、generation_manifest.json，原件保留。
- 修改：重新生成身體／服裝／UV／PBR、比例、骨架、七段小幅動作、原創眼睛／嘴線／Blink、執行用貼圖 1K。法杖沿用本專案原創資產；不宣稱 AI 輸出為純手工建模。細節見 [重製報告](PIXAL3D_CHARACTER_REPORT.md)。

## 2026-10-17 柳木法杖

- 專案自製 Blender 幾何體及材質，無外部素材、貼圖或授權依賴。
- `assets/models/female/willow_staff.glb`、`assets/source/female/willow_staff.blend`；140 三角形，骨骼附件與既有 willow_staff 裝備 ID 對應。

## 2026-10-16 四視角女角

- CP05：依原圖重製低面數五指手型並清除生成碎片；新增手部幾何與綁定為專案自製，無外部手模型。

- CP03：依同一組使用者參考圖製作瞳孔、高光、嘴線與自製 Blink 形變；不使用外部貼圖／素材。

- 2026-10-17：新增自製 walk／run 片段、左右裙襬骨及肩髖權重，來源圖片與網格同下；無新增外部素材。

- 後續修改：保留七骨原件，新增 `lia_rigged.glb`／`lia_rigged.blend` 的 11 骨平滑肘膝權重及五段自製動畫；來源授權紀錄同下，詳見 [動畫報告](FEMALE_ANIMATION_REPORT.md)。

- 來源：使用者本次提供的四張女角圖；副本保存在 `assets/source/female/references/`。使用者授權本次建模，外部作者及散布授權未獨立確認。
- 本機 HY3D 多視角生成幾何，Blender 重建／減面、頂點配色、眼睛／衣緣／腰扣及基本七骨綁定。
- 遊戲資產：`assets/models/female/lia_user.glb`；未購買或下載素材商店角色。製作與限制見 [女角報告](FEMALE_CHARACTER_REPORT.md)。

## 2026-10-16 使用者主角

- 來源：使用者提供 `D:\3dtest\Character_MV_00002_.glb` 與專案根目錄的主角四面 PNG；由使用者授權本次修改，原作者及外部散布授權尚未獨立確認。
- 修改：重建／減面、頂點配色、眼部幾何、七骨基本綁定；輸出 `assets/models/hero/ren_user.glb` 及 `assets/source/hero/ren_user.blend`。
- 未下載或購買第三方素材。原始 GLB 與參考 PNG 保留；詳細限制見 [主角模型報告](USER_HERO_REPORT.md)。

使用者於 2026-10-12 授權使用素材商店資產並修改。正式選用時記錄來源頁、作者、版本/取得日期、授權、署名要求、原始檔與修改。允許使用素材不等於任何商店項目都可任意重製；以各項目的實際授權為準。

## Phase 1 已使用

| 素材 | 來源 | 修改/用途 |
| --- | --- | --- |
| 雷恩佔位人物 | 專案內自製 Godot BoxMesh/CylinderMesh | 橘色外套、深色頭髮/靴子、黃色圍巾及背包；無外部模型 |
| 練習場、樹木、遺跡、石塊、晶體 | 專案內自製 Godot 基本幾何體 | 場景編排、材質、碰撞形狀；晶體僅裝飾，未連接 E006 |
| HUD | 專案內自製 Control/Container/StyleBox | 位置與操作提示，不顯示未實作的 HP/任務狀態 |
| UI 字型 | Godot SystemFont 使用本機系統字型/引擎 fallback | 沒有複製或再散布字型檔；正式跨機發佈時須選定可散布字型並再次驗證 |

本輪未下載素材商店內容、未安裝外掛、未購買素材。Story Bible 的外部圖片連結僅為企劃參考，未匯入遊戲。

## Phase 2 已使用

P2 新增村莊、公會建築、森林樹木／石塊、路牌、寶箱及公會長／莉雅佔位角色，全部為專案內自製 Godot BoxMesh／PrismMesh／CylinderMesh，沒有外部素材。對話與狀態介面同樣自製，字型沿用本機 SystemFont。寶箱開啟姿態、名稱標籤和森林鏡頭區域已於遊戲中查看。

## Phase 3 已使用

P3 新增的戰鬥平台、雷恩／莉雅／守衛人形、史萊姆、回合標記與森林演練標誌皆由 Godot BoxMesh／CylinderMesh／SphereMesh 自製；戰鬥 UI、位移／傷害數字動畫同樣為專案程式生成。沿用本機 SystemFont，無下載、購買或新增外掛；正式模型、音效及可散布字型留 P6。

## 2026-10-13 卡通美術 v1（目前遊戲使用）

作者／來源：本專案原創，由 Codex 使用 Blender Python 建模。商店頁／外部版本／第三方授權文件／必要署名：不適用；沒有下載、購買、使用外部生成服務或複製企劃參考圖。工具版本 Blender 5.2.2 LTS，Godot 4.7.2。這些模型替換上列歷史階段的遊戲佔位，不影響保留的 P1 練習場。

| 素材 | 來源腳本 | 修改與用途 |
| --- | --- | --- |
| ren、lia、guildmaster | tools/build_cartoon_assets.py | 原創五官／髮型／多層服裝、背包、法杖、書本，六個剛性關節的視覺擺動 |
| forest_slime、corrupted_guardian | 同上 | 葉芽膠凍角色、分層石甲與紫晶守衛，探索演練點和戰鬥共用 |
| round_tree、guild_house、cottage | tools/build_cartoon_environment.py | 圓冠樹、瓦頂／窗框／花箱／煙囪建築，村莊／森林／戰鬥林地 |
| moss_rock、flower_patch、path_strip | 同上 | 覆苔岩石、花草、平坦圓角路面與邊界裝飾 |
| chest_base、chest_lid、campfire、signpost | 同上 | 保留開箱樞軸的木箱、金屬包邊、營火、雕刻箭頭路牌 |

原始建模檔：`source_assets/cartoon_v1/*_authoring.blend`；遊戲整理檔：同目錄 `*.blend`；面數：`*_metrics.json`；匯出：`assets/models/cartoon/*.glb`。材質為原創純色色盤，沒有外部貼圖；目前無蒙皮骨架。完整匯入／碰撞／畫面驗證與限制見 [美術報告](CARTOON_ART_REPORT.md)。

## 後續資產登錄欄位

資產名稱 / 商店與來源 URL / 作者 / 版本或取得日期 / 授權文件位置 / 必要署名 / 原始檔位置 / 修改內容 / Godot 匯入與碰撞驗證 / 使用場景。


## P5 原創礦坑與章末演出（2026-10-13）

`scenes/world/mine.tscn` 與 `scenes/battle/battle_mine.tscn` 為本專案新建；原始生成工具 `tools/build_mine_scene.py`。使用 Godot 基本曲面／幾何構造石壁、坑木、礦軌、礦燈、星晶，沿用既有原創 moss_rock GLB；沒有第三方下載、商店資產或新增署名義務。E006 的模型／光照脈衝與 E009 文字預告淡入淡出為原創程式演出。角色 GLB 及既有來源記錄不變。


## P6 聲音、光環與場景參考（2026-10-13）

- `assets/audio/original/*.wav`：本專案原創程式合成，來源工具 `tools/build_audio.py`，22,050 Hz／單聲道。四段短旋律循環（village/forest/mine/battle）、七種音效（confirm/hit/heal/guard/victory/defeat/crystal）。無外部取樣、素材商店頁或第三方署名要求；音訊可由固定種子重建。
- 攻擊／治療／防禦光環：BattleStage 使用 Godot TorusMesh／Tween 原創製作，無外部特效素材。
- `docs/references/village_reference.jpg`：使用者提供，僅作場景設計參考，未直接用作遊戲素材；排除於匯出。方向見 SCENE_ART_DIRECTION.md，0.6.1 已以原創幾何實作灰石村第一輪。
- Godot 4.7.2 及第三方引擎授權：`docs/GODOT_LICENSES.txt`，由 Engine API 取得並隨 Windows 包附上。Windows SystemFont 只在使用者系統讀取，不打包微軟字型檔。

## 灰石村 0.6.1 原創場景

`village_guild`、`village_shop`、`village_plaza`、`village_borders`、`village_valley` 五個 GLB 由 `tools/build_village_art.py` 在 Blender 5.2.2 LTS 建立；作者為本專案製作，沒有外部模型／貼圖／商店素材／付費服務。使用者參考圖僅提供色彩與場景方向，沒有擷取圖像作材質。藍色水晶徽章為本專案重新設計。原始 `.blend`、面數紀錄在 `source_assets/village_v2`，不匯出至遊戲。修改內容包含倒角建築、瓦片、花箱、條紋棚布、廣場／晶柱、河岸橋樑和遠景。沿用角色與樹木來源不變；詳見 [場景報告](VILLAGE_ART_REPORT.md)。

## 2026-10-14 灰石村新參考（設計階段）

`docs/references/graystone_village_2026_10_14.jpg` 為使用者提供的 1000003469.jpg，只作最新場景參考，未當作遊戲貼圖或模型。`graystone_village_v3_layout.svg` 與 PNG 是本專案依九區需求繪製的配置示意，非遊戲渲染、非第三方素材、未匯入 runtime。字型使用系統字型渲染，沒有打包字型檔。

## Greystone G01（2026-10-14）

scripts/tools/greystone/build_layout.py 生成原創 Godot 原生白盒，七個建物模組，無第三方素材、貼圖或付費生成。角色引用既有 Ren 視覺，授權來源不變。正式GLB尚未製作；建造參考沿用使用者提供的1000003469圖。

## Greystone G02（2026-10-14）

本專案原創程序地形，依使用者提供的灰石村圖製作。Blender5.2.2及原生Python產生59個GLB，12,409三角面（唯一資源）；23棵松樹共享一個模型。無第三方下載、付費生成或額外署名要求。原始OBJ/manifest/metrics與Blender檢視副本在source_assets/greystone_g02；產生器在scripts/tools/greystone。背景松樹屬G02尺度佈景，完整G04素材庫未完成。

## Greystone G03 素材庫改製（2026-10-14）

以下模型均由 Quaternius 製作，Poly Pizza 頁面標示 Public Domain (CC0)，素材庫搜尋顯示 CC0 1.0。可修改/再散布，無強制署名；本專案仍保留作者及來源。頁面無語意版本號，採 2026-10-14 下載版本。未購買付費素材。

| 來源 | 頁面發布日期 | 原始檔 | 使用 |
| --- | --- | --- | --- |
| [Fantasy Inn](https://poly.pizza/m/x3ZcGn3jr4) | 2021-10-03 | source_assets/greystone_g03/vendor/quaternius_fantasy_inn.glb | 旅館、公會、商店、民宅 A、農舍初版 |
| [Fantasy House](https://poly.pizza/m/BH2XHWUNmF) | 2021-10-03 | source_assets/greystone_g03/vendor/quaternius_house.glb | 民宅 B |
| [House](https://poly.pizza/m/oJJIRwv6Bo) | 2022-09-04 | source_assets/greystone_g03/vendor/quaternius_small_house.glb | 僅 Blender 候選檢視，未用於遊戲 |

修改：重新製作米白灰泥/深木色/暖窗/紅褐及灰藍屋頂材質，依地圖規格調整比例與原點，平面著色、Godot Y-up 匯出、新增床/藥瓶/劍招牌，另建簡化 Godot 碰撞。七個輸出在 assets/models/greystone/buildings；Blender 修改腳本 build_buildings.py。模型未被當作本專案原創；招牌浮雕為本專案新增。

公開 GLB 下載位址分別為 static.poly.pizza/270a08b6-87e1-47eb-ad1c-5fd7be321bcd.glb、341c9305-c6dd-4427-ad00-620ad57eb14e.glb、65d155f6-705c-4e6c-9e3a-b9974bb82324.glb，均從對應來源頁取得。外掛一鍵匯入不支援時使用公開下載，不涉及使用者 API key。

2026-10-14 G03 細化：來源沿用上述 CC0 模型。新製旅館側翼、公會門廳、單層山牆屋頂、門廊、煙囪、門板/把手、櫃檯及鍛造設施；移除旅館母型的部分屋頂/門廊幾何。材質提取至 assets/materials/greystone 共用。未加入新的第三方來源或付費資產。


## G04 程序環境素材（2026-10-14）

17 項素材由本專案 Blender Python 建立或重用原創 G02/G05 幾何；沒有新第三方下載、付費素材或貼圖。來源/變更/面數見 [G04報告](GREYSTONE_G04_REPORT.md) 與 source_assets/greystone_g04/metrics.json。既有 Quaternius 建築授權與署名記錄不變。

## 2026-10-15 原創擴充怪物

assets/models/expansion 四個 GLB（孢子菇靈、荊棘野豬、星晶蝙蝠、礦甲蟲）由本專案 Blender Python 幾何體原創建模，無第三方下載、貼圖或付費素材。來源腳本 scripts/tools/expansion/build_monsters.py；可編輯源檔 assets/source/expansion，.gdignore 排除 Godot 自動匯入。面數及限制見 WILDERNESS_EXPANSION_REPORT.md。場景重用原已記錄的 cartoon 與 greystone 素材，未變更其來源授權。

## 2026-10-17 護腕修整

女角雙側皮革護腕及金色腕帶由專案 Blender Python 以八邊形開口環自行製作，參照使用者提供的角色四視圖配色；共 64 三角形，綁定既有 Forearm 骨。沒有外部下載、貼圖或新增第三方授權。總面數與限制見 CHARACTER_POLISH_REPORT.md CP15；開口位於衣物／手腕接合處，不宣稱封閉拓樸。
