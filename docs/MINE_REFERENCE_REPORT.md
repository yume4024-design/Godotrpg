# 礦坑內部參考重建與序章整合

2026-10-24，`feature/greystone-g06`，Godot4.7.2.stable.official.ed1daf0bf、Blender5.2.2 LTS。
使用者要求暫停人工驗證，建立場景Skill並依礦坑圖持續完成序章。人工Gate保持暫停，Windows自動驗收繼續；Android／iOS、第一章沒有開發。

## 交付場景與Skill

- [crystal-scene-builder](skills/crystal-scene-builder/SKILL.md)已建立並安裝至個人Codex skills。包含參考拆區、資產重用、完整Blender組裝、正交參考、材質匯出、碰撞、位置遷移及真實圖形驗證。經本次實作補入共享mesh合併、Blender例外退出碼及讀檔截圖時序規則；格式檢查通過。
- [規格](MINE_REFERENCE_SPEC.md)／[可執行layout](../data/world/mine_reference_layout.json)；八區、0／3／7m地層，完整環線、中央十字橋、南北雙向階梯，地下水、瀑布、暖火把、藍晶、營地、儲物、軌道、礦車、吊籠與塌方造景。
- 可編輯完整主檔 `source_assets/mine_reference_20261024/mine_reference_master.blend`，12個分區GLB、4個獨立機械模組。重用原G04箱桶／晶體與ENV02木支架，未重新生成既有角色或使用付費API。
- 新入口 `scenes/main/mine_reference_integration.tscn`，新礦坑 `scenes/world/mine_reference/mine.tscn`，戰鬥背景重用核心洞窟區塊。正式入口與舊礦坑保留。

## 面數與碰撞

Blender全集靜態場景 **146616 triangles**，本輪明確預算200000；不含動態角色、UI及獨立互動晶體。12區塊／4模組全部通過既有GLB結構與面數檢查，新增模組預算4096，各為礦車1084、軌道84、礦門888、吊籠204。沒有為符合角色規格而套用5000面限制。

501個明確簡化碰撞代理，加核心互動晶體碰撞；地層為實心Box、斜坡／橋側為Convex hull，和Blender來源同座標。可見樓梯搭配連續坡面碰撞；橋面材質厚度對齊實際行走面。水床為純視覺，坑中沒有補滿不可見的平地。

地面、岩壁、木材與水體採世界座標共享Shader；環境常色／程序表面不要求UV，既有GLB檢查明確使用`--allow-static --allow-missing-uv`，不宣稱UV品質Gate通過。來源SHA、實測與限制見[asset_audit](../source_assets/mine_reference_20261024/asset_audit.json)。

## 序章與存檔

沿用既有管理系統、角色ID、戰鬥數值與E001～E009。E005入口、E006核心星晶、E007守衛勝利／敗北重試、回村E008與E009皆保持原事件條件。礦坑前仍需森林教學戰，星印及Q001獎勵不重複。

全域Schema3／CH00-G06.4不變；新入口的礦坑位置版為4，舊設定預設仍為3。舊1／3座標先於原地圖驗證，再複製位置至安全入口(-44.5,0.1,28)，再做新圖實際膠囊／地板驗證。角色、裝備、背包、旗標、任務及獎勵收據保留。v1按原契約增加零交易帳本。新版位置只在新入口接受，舊設定和歷史schema不能宣稱位置4；非法原件或新座標均拒絕且不改原檔。

## 實際測試

| 項目 | 結果 |
|---|---|
| 專案Check／16個GLB結構與預算／Skill格式 | 通過 |
| 新圖完整圖形走跑：環線、中央橋、南北樓梯雙向、水道無隱形地面 | **55／0** |
| 真正v1／G06場景保存的礦坑舊檔→遷移、進度保留、非法位置拒絕、上層落點、單次獎勵 | **59／0** |
| 新入口無頭完整序章 | **58／0** |
| 新入口實際圖形完整序章、核心洞窟戰鬥、截圖、敗北重試與回村存讀 | **68／0** |
| 既有G06、NPC、劇情、交易、觸控、森林／礦坑往返、敵AI、正式序章16組回歸 | 全通過；PC觸控模擬不是手機驗收 |
| 新Windows RC1 Release完整序章／交易／舊檔遷移 | **127／0**，35.235秒，自動圖形流程 |
| 同一QA包、同一存檔、另一程序續讀 | **22／0**，10.614秒 |
| 普通候選啟動器／正常關閉 | **通過**，視窗保持12.116秒，EXE與啟動器exit0 |
| 候選／QA共用執行資源／禁止檔案 | **985個SHA一致**，989／1189檔，無工具、來源或參考圖混入 |

走跑程序使用真實1.95m CharacterBody3D及InputMap回饋轉向，只在獨立路線開頭定位，主環線內不瞬移，不設劇情／獎勵旗標。RTX3080、Windows Compatibility、1280×720、Debug引擎、60FPS上限；8780幀，平均59.526FPS、P95 16.706ms、P99 16.748ms、最大217.771ms。包含取樣與截圖成本，非GPU時間、Release長測或其他硬體保證。45個落點取樣Draw Calls 82～157，Debug引擎Memory Static 42.488～42.666MiB；不是程序Working Set、顯存或Release記憶體保證。

村莊BlenderRC1另有1812.205秒圖形長測1548／0及另程序97／0，詳見[舊村莊包長測](BLENDER_WINDOWS_STABILITY_REPORT.md)。該30分鐘結果**不抵算本次新礦坑長測**。

## 已修正與限制

- 共享匯入mesh在join時污染其他分區，造成箱子／晶體倍增：合併前複製活動mesh，完整重建及面數稽核。
- Blender程序節點不能直接輸出成等價GLB，木材變白：加入Godot共享木紋Shader，以實際畫面確認。
- 水道箱桶擋路、停放礦車擋中央線、橋端跨入平台時圍欄未開口：移開造景、將軌道／車靠邊、依整段連接走廊切出欄杆缺口；重跑真實Player完整動線。
- 新位置驗證首次遇到GDScript型別化Array條件式問題：改明確PackedInt32Array，存讀及原16組回歸通過。
- 遷移測試預設交易帳本的整數／JSON浮點比較修正；沒有放寬遊戲驗證。既有觸控測試首輪受QA搖桿隔離影響，移除該測試專用隔離後通過，正式InputMap未改。
- Blender腳本例外可能仍exit0：新增`--python-exit-code 1`、完成marker與來源SHA檢查，失敗的舊產物不算新成果。非阻斷的內建筆刷相對路徑警告未進入遊戲資產。
- 吊籠、軌道與礦車為靜態造景；未新增採礦或升降機玩法。與參考圖仍有岩壁密度、手繪細節與精確構圖差異，不宣稱逐像素還原。
- 人工鍵鼠／Xbox與整體G08人工Gate暫停；新礦坑尚非30分鐘長測、Android／iOS或正式v0.6.1覆寫。

## Windows固定包與重現

來源固定在 `2d02f635dcfe2a32e64fe7e18202b3144b0f0ea5` 的乾淨managed worktree，版本 `0.6.1-mine-reference-rc1`。匯出使用Godot4.7.2匹配Windows x64 Release模板；遊戲`application/config/version`基值與正式主入口仍為0.6.1，僅額外custom feature切換新候選。

- 啟動：`builds/mine-reference/rc1-2d02f63/candidate/start_mine_reference.cmd`；[操作指南](MINE_REFERENCE_GUIDE.md)。獨立`user_test`，不讀寫正式存檔。
- ZIP：`builds/mine-reference/rc1-2d02f63/ProjectCrystal-0.6.1-mine-reference-rc1-windows-x64.zip`，355980021 bytes，七檔，逐項解壓CRC檢查通過；沒有測試存檔／日誌。
- ZIP SHA256：`93394d4ad4e2bcadf4fcf57f2fa7d0e0bb4e3e6509870022c95ed1fab0fb0ae8`。
- Candidate PCK：322815188 bytes，SHA256 `dd14666045912b9cc1a93232c5d8750f0c2151951b337452cfb9a1e7cf09f833`。
- 在獨立空專案掛載兩個PCK，檢查985份共用runtime完整SHA；新礦坑GLB、Shader與場景可載入，layout與碰撞manifest兩份JSON存在。候選沒有tests／tools／來源blend或根目錄參考圖。
- 新包原生Release首次loading到ready約8.025秒（引擎ticks），不是作業系統點擊至出畫面的獨立計時；持續保留啟動畫面，不將初始化尖峰當每幀60FPS。
- 正式Windows、RC4與上一BlenderRC1的EXE／PCK六檔及村莊ZIP實際SHA均與原紀錄一致。

實際執行命令（PowerShell；匯出SourceRoot須為來源提交的乾淨工作樹）：

```powershell
./tools/godot.ps1 -Mode Check
./tools/godot.ps1 -Mode TestMineReference
./tools/godot.ps1 -Mode TestMineReferenceMigration
./tools/godot.ps1 -Mode TestMineReferenceStory
./tools/godot.ps1 -Mode VisualMineReferenceStory
./tools/build_blender_windows.ps1 -SourceRoot C:/Users/yume4/.codex/worktrees/mine-reference-rc1/RPGGAME -BuildRoot D:/RPGGAME/builds/mine-reference/rc1-2d02f63 -CandidateFamily Mine
./tools/test_mine_windows.ps1 -BuildRoot D:/RPGGAME/builds/mine-reference/rc1-2d02f63
# 使用本機Python執行；manifest由上一命令產生
python tools/audit_windows_candidate.py artifacts/mine_windows/20261024-025959/manifest.json
```

輸出及失敗紀錄留於本機artifacts，已提交的[攜帶式驗收證據](../source_assets/mine_reference_20261024/evidence/)包含來源測試結果、16組回歸摘要、Windows包原生結果、啟動／匯出／封裝收據、PCK稽核、保留包SHA與實際畫面，另有sha256.json核對完整性；不提交本機存檔或原始引擎日誌。QA使用實際遊戲管理系統與匯出資源，自動移動／加速操作不代表人類20～30分鐘遊玩或實體控制器驗收。

本輪已完成場景建造、接回序章與Windows自動圖形驗收。人工驗證維持暫停，G08總Gate保持未通過；下一個獨立技術驗收可做新礦坑候選長測，不能套用舊村莊30分鐘結果。
