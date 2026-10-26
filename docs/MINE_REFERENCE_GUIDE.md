# 新版礦坑序章候選

## 2026-10-26：礦坑造景 RC2

執行 `D:/RPGGAME/builds/mine-reference/rc2-ef0764c/candidate/start_mine_reference.cmd`；可攜ZIP位於同一rc2目錄。八區完整造景、深坑道、彎軌及地下水已匯出；包內137項序章／32項重啟及普通啟動器通過。[完整報告與已知差距](MINE_SCENE_COMPLETION_REPORT.md)。

此礦坑包仍沿用既有Blender村莊入口；最新參考灰石村另以`RunReferenceVillage`及其RC3查看。存檔在獨立user_test，舊RC1保留。人工驗收暫停，不沿用舊包人工結果。以下RC1路徑保留為歷史紀錄。

從專案執行：

```powershell
./tools/godot.ps1 -Mode RunMineReference
```

此入口從新版灰石村開始既有序章，經低語森林教學戰進入新礦坑，調查古代星晶、擊敗守衛，再回村交付。獨立保存於 `user://crystal_mine_reference_slot_01.json`。E009仍是章末預告，沒有建立第一章。

WASD／方向鍵或Xbox左搖桿移動，Shift／LB按住跑步，E／A互動，M／Menu手冊；F5保存、F9讀取。沿用原遊戲輸入、對話、戰鬥及交易流程。

礦坑主路：入口營地→西樓梯→礦車區→北方採掘台→上層木橋→儲物區→東樓梯→水道→核心洞窟→塌方繞路→營地。中央十字橋是另一條通路，停放礦車在橋側，水面與深坑不可行走。吊籠為靜態造景，未新增升降玩法。

Windows固定包：`D:/RPGGAME/builds/mine-reference/rc1-2d02f63/candidate/start_mine_reference.cmd`。可直接執行，或解壓同層的`ProjectCrystal-0.6.1-mine-reference-rc1-windows-x64.zip`，保留七份檔案並開啟其中的`start_mine_reference.cmd`；啟動器建立獨立`user_test`。正式v0.6.1、舊RC4及Blender村莊RC1不被覆蓋。

人工鍵鼠／Xbox驗證依2026-10-24使用者指示暫停；自動圖形及資產驗收見[報告](MINE_REFERENCE_REPORT.md)。不以PC觸控模擬宣稱Android驗收。
