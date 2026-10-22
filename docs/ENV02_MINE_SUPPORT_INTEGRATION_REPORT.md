# ENV02 新版礦坑支架整合

2026-10-22，起點 `bb1ac68c6ed804117c3b49406e9481dde663bef5`，分支 `feature/greystone-g06`。這是新版 G06 礦坑八組支架的外觀替換；原正式 v0.6.1 入口／舊礦坑及固定 RC4 包均保留。其餘環境、兩位新主角、G08 與完整第一章仍未完成。

## 實作

重用已驗證的 [804 面模組](ENV02_MINE_SUPPORT_REPORT.md)，沒有重新建模。八份共用三個 Mesh、三種既有 G04 材質，無貼圖；每份由兩柱一樑組成，總計 6432 triangles。配置沿用 x=`-12,-4,4,12`、z=`-16,16`，不移動原星晶、岩石、道路或互動點。

`scenes/world/expanded/mine.tscn` 改用 `scripts/world/mine_environment.gd`：繼承原 wilderness builder，再驗證 24 個舊 Box renderer 的位置、尺寸、型別及碰撞形狀。確認全部符合後，建立八份純視覺 PackedScene，移除舊外觀。保留原 16 個 StaticBody 木柱及其未縮放 BoxShape，沒有重複加入完整素材的碰撞。預檢失敗會保留原外觀並回報錯誤。

共享 `expanded_wilderness.gd`、森林、SceneManager、ExplorationOcclusion、劇情／獎勵、SaveCodec 均不改。八根新 Beam 使用場景宣告的 `Model/MineSupportFrame/Beam` 路徑，沿用原遮擋群組，另保留舊中央三根 Beam。遮擋時僅保留陰影，離開後恢復；柱子正常顯示和碰撞。

## Windows 原生整合測試

Godot `4.7.2.stable.official.ed1daf0bf`、Compatibility／OpenGL3、RTX3080、1280×720。測試視窗使用可還原的 no-focus override，啟動時確認 `root.unfocusable`，不改正式設定。

先在未替換礦坑上執行 `-RecordBaseline`，**18／0**。基線拒絕覆寫，包含全部碰撞的形狀／全域 Transform／layer／mask／disabled multiset、四個互動點與出入口資訊、出生／事件／鏡頭／演出標記、九個核心來源 SHA，以及 475 個實際玩家膠囊占用探測。

替換後原生圖形驗證 **84／0**：

- 34 個碰撞、4 個互動、475 個占用結果及其餘基線全部一致；沒有藉放寬存檔驗證配合新外觀。
- 真正 G06 Player 為 1.95m／半徑0.32m；在八個開口各步行穿越並反向跑回，共16段 InputMap 動線，停止時貼地且速度歸零。路線避開原開口中央的裝飾星晶，沒有移動它。
- 原木柱仍阻擋真實 Player；實際追蹤鏡頭可遮隱新橫樑，離開後恢復。共11根遮擋樑，並非把整個支架一起隱藏。
- 載入實際完成序章的隔離 QA 存檔，金幣212、莉雅 EXP300；新礦坑保存／讀取保留 party、inventory、flags、quests、rewards、story。將隔離檔位置改為木柱內部，完整 request_load 拒絕，當前狀態不變。
- 真正 E 互動離開礦坑至森林，再經森林入口返回；模型重新實例化正常。
- 查看替換前後全圖／支架近景及實際遮擋畫面。倒角、端面與金屬箍可辨識，淨空未縮小；沒有把局部支架當整張礦坑美術完成。

這是原生圖形自動操作，**不是鍵鼠／Xbox 實體驗收，也不是 Android／iOS 或新一輪30分鐘穩定性驗收**。

## 短時效能與實例盤點

同一全圖鏡頭，兩次獨立原生程序，各300影格，60FPS上限。不同程序的資源／快取生命週期不同，僅記錄觀測，不推導未鎖幀容量或單一模型記憶體增量。

| 指標 | 替換前 | 替換後 |
| --- | ---: | ---: |
| FPS | 60.004 | 60.004 |
| 平均／P95／P99 ms | 16.666／16.966／17.099 | 16.666／16.788／17.077 |
| 最大 ms | 22.446 | 17.099 |
| Draw Calls 範圍 | 535–571 | 671 |
| 引擎 MEMORY_STATIC 最大 bytes | 340670566 | 342662794 |

Draw Calls 上升是已知成本，不能宣稱效能提升。每份新支架三個 Mesh 各有三個材質 surface；本輪只共用資源，尚未做單材質頂點色／批次合併。既有整圖成本仍高，後續效能工作需比較材質批次與陰影成本，不能以60FPS上限判定沒有餘量問題。MEMORY_STATIC 不是程序 RSS。

另一次 headless 實例盤點：107 GLB／12貼圖來源，三圖正常實例化、零失敗。礦坑環境 Mesh 數仍132；原生 primitive 108→84，實例環境 triangles 32628→**38772**（舊24 Box合計288面改為6432面）；角色16160面及34碰撞不變。此盤點不是畫面可見面數或效能驗收。

## 失敗與修正

首次基線測試沒有等待初始 SceneManager 轉場完成，過早 Continue／travel 失敗，後續誤測到村莊；另引用了不存在的 quest 路徑。保存失敗，修正測試的等待及來源路徑後，才凍結真正礦坑基線，遊戲程式沒有為此改動。

首次整合83項中4項失敗：兩段路線未到、柱碰撞測試將相機相對方向寫反、以及誤把 SaveCodec 的資料檢查當完整物理位置驗證。改正後第二次84項仍有一次停止速度失敗。診斷記錄顯示已連接 XInput，左軸約(+0.0585,-0.0359)，執行中的硬體事件可能覆寫腳本 action strength；只在本 QA 程序移除移動的 joypad-motion bindings，使用同一 InputMap action 和原 Player。最終16段全部到達並停止，84／0；保留三輪失敗。沒有改正式按鍵、手把死區或宣稱硬體故障已修復。

位置拒絕測試現在真正走完整 `SaveManager.request_load`，不是用靜態資料驗證冒稱物理拒絕。

## 回歸、重現及後續

G06 全套16模式、**576／0**，manifest `g06-20261022-144321.json`；載入、敵人判斷、舊序章／重啟、新村遷移／NPC／劇情／重啟、圖形序章、觸控及交易全部通過。其中文件中的 controller／touch 仍為模擬。正式 v0.6.1 PCK SHA仍為 `a8c95f156c55a0cf15cb6b71e617c435868eb6822d0c08a014fbdefbb42002b7`，固定RC4可玩包 PCK仍為 `cda06c308442128628490ef2651548c7fd34b185fbf6976f9b36604d319d05b8`。結果另見 [凍結證據](../source_assets/environment_rebuild_20261022/mine_support_integration/README.md)。

全套第一次圖形序章68項中1項「Boss返回原位置」失敗；隨後第一次隔離設定套用過廣，Phase6刻意注入手把軸的檢查85項中1項失敗。兩輪均保留、不算通過。最終將 `-IsolateJoypadMotion` 限定為 `VisualG06Story` 程序，專門驗證手把／觸控的模式保留原綁定；`finally` 還原啟動環境。Phase5衍生測試僅在明確QA環境變數時才移除該程序的joypad-motion。正式遊戲不載入這個測試工具、InputMap不改；最終16模式576／0。不能因此把首次偏差宣稱為已修復的正式手把故障。

```powershell
./tools/godot.ps1 -Mode TestG06Story
./tools/review_mine_support_integration.ps1
./tools/test_g06.ps1 -IsolateJoypadMotion
```

runner優先使用已存在的實際 G08 長測 QA 檔，缺少時使用 TestG06Story 產物；亦可用 `-Fixture` 指定實際完成的 QA 檔。不提交本機存檔。`-RecordBaseline` 僅適用替換前來源首次取樣；現有凍結檔不可重錄覆蓋。

下一項仍是逐件處理其他環境／可見物品及主角重製。莉雅頸部三版拒用，需連續拓樸與局部 UV 修整，不能把失敗原型強行接骨架。RC4 新包實體通關仍待原問題回覆，G08.4／G08.5及第一章維持門檻；原男性村民保留、女性候選，Android／iOS暫停。
