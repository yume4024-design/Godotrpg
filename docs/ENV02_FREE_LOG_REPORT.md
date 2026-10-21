# ENV02 — 免費枯木單件適配

2026-10-20，**獨立模組 PASS／正式森林配置 NOT_STARTED**。依使用者允許網上免費場景模型修改，先核對本機無枯木／樹樁 GLB，再選取一件缺件；沒有重造已合格七建築或十七件 G04。

**2026-10-22更新：** 三件已接入G06低語森林外緣，共804面，原生52／0，原576點碰撞占用與事件位置保持。小項結果與未完成範圍見 [森林配置](ENV02_FOREST_INTEGRATION_REPORT.md)；下方NOT_STARTED為單件完成時的歷史狀態，不代表整張森林美術或效能已完成。

## 來源、版本與授權

- 作者 Kenney；[Nature Kit 官方頁](https://kenney.nl/assets/nature-kit)標 CC0、1.0／2020。實際下載包內 `License.txt` 標 **Nature Kit (2.1)**、2020-04-29；保留兩者差異，採內附版本識別。
- 免費官方 ZIP：`https://kenney.nl/media/pages/assets/nature-kit/37ac38a37b-1677698939/kenney_nature-kit.zip`，10537521 bytes，SHA256 `fa7974a0d342bfe63c38664ba9f8ec1a4aab8ea25f099bdc56870e33588c4d9d`。原包留本機並由該資料夾 .gitignore 排除。
- 只抽取 `Models/GLTF format/log_large.glb` 及原 `License.txt` 至 `source_assets/free_environment_20261020/kenney_nature/`。原件 **96 triangles**，SHA256 `e7a92369062d491e5a31a163d390e07db04ee573605bbfa84c00660d18896b4c`。沒有執行原包程式、整包匯入或捐款／付費。
- 內附 CC0 1.0 允許個人／教育／商業使用，署名非必須；本專案仍保留作者及來源。完整文本與來源清單一起提交。

## 修改與交付

`scripts/tools/greystone/adapt_kenney_log.py` 只接受已核對 SHA 的單件來源、只輸出新目錄。套用來源變換、長度 3m、地面中心原點、GLB 轉 Godot Y-up；將桃色樹皮改 G04_wood，切口改新共用 G04_wood_cut。焊接來源相同位置接縫，再做單段 0.065m 倒角及 flat shading，沒有細分／高解析貼圖。

首版 Blender 重匯入發現 4 個退化面，雖然 Godot 渲染／碰撞 574／0，仍拒用首版。失敗 GLB／Blend、報告留 `kenney_nature/fallen_log/`；第二版刪除倒角產生的退化面，**268／1000 triangles**，1 Mesh／2 surfaces／2 共用材質、無貼圖。原 UV／倒角 UV 未作正式展開，不聲稱 UV 美術驗收。

- 源工作檔／GLB：`kenney_nature/fallen_log_v2/fallen_log.{blend,glb}`。
- 遊戲資源：`assets/models/environment/fallen_log.glb`，獨立場景 `scenes/world/greystone/props/fallen_log.tscn`。
- 簡化碰撞為一個橫向 CapsuleShape3D；只擋主樹幹，枝梢與中空樹洞不提供可進入空間。碰撞形狀沒有縮放。
- 包圍盒：長 3.0m、寬約 1.644m（含枝梢）、高約 1.243m；放置時須保留視覺空間，不能只依主幹碰撞尺寸安排道路。

## 實際驗證

Godot 4.7.2.stable.official.ed1daf0bf、Blender 5.2.2 LTS、Windows／RTX 3080。

| 檢查 | 結果 |
|---|---|
| 嚴格 GLB | PASS，268／1000、有限值／索引；明確靜態及純色 UV 例外 |
| Blender 重匯入 evaluated | PASS，268、0 退化面；GLB 拆分頂點的邊界警告保留 |
| Godot Check／材質後匯入 | PASS，`check-20261020-150602-463.log` |
| 圖形／實例／碰撞 | **566 checks／0 failures**，三實例共享 Mesh／兩外部材質，射線擋幹／側路／高度、CharacterBody3D 真實 move_and_slide 停下及繞行 |
| 圖像 | 斜側、切口、正面、三實例實際畫面已查看；首版失敗不作最終證據 |
| 正式森林／戰鬥／存讀檔／效能／實體輸入 | NOT_STARTED；不是玩家完成新森林或效能基準 |

重現：先在新目錄執行 Blender 建模工具，再 `tools/godot.ps1 -Mode Check`、`tools/review_forest_log.ps1`。獨立 APPDATA／LOCALAPPDATA；測試不載入 RPG 服務或真實存檔。純色無透明／粒子，268 面暫無專用 LOD；整張森林可見性與效能仍須量測。

畫面微評：COMP-SAFE-EDGE 2、COMP-NEG-SPACE 2、COMP-BALANCE 2、LIGHT-KEY-FILL 2、ORIG-READ 2、ORIG-STRUCT 1、ORIG-TILE 1、ORIG-SYN 1，13／16（B）。輪廓仍偏方正，整張森林風格與參考還原度未由單件預覽認定完成。

下一項先做正式場景放置的淨空／碰撞／探索回歸；其他免費物件逐件查授權、適配、驗收。雷恩／莉雅、蝙蝠完整收翼、旅館拓樸、A04／A05、Windows Gate 與完整 C1 仍未完成。
