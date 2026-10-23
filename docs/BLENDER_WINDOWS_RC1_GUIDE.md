# 灰石村 Blender Windows RC1 試玩

版本：`0.6.1-greystone-blender-rc1`。這是新 Blender 灰石村與地面／岩石／動態水體的獨立 Windows 候選，
保留正式 v0.6.1 及舊 RC4。驗證狀態見[固定包報告](BLENDER_WINDOWS_RC1_REPORT.md)。

## 開啟

進入 `builds/greystone-blender/rc1-<來源短SHA>/candidate/`，雙擊 `start_blender_village.cmd`。
請保留啟動器、`ProjectCrystal.exe`、`ProjectCrystal.pck` 在同一資料夾；不要只複製 EXE。
開始時會先呈現載入畫面，完成後進入旅館旁的序章。第一次建置 shader 可能較慢。

透過啟動器，存檔／設定／日誌只寫入此包旁 `user_test/`。預設從新旅程開始，不自動寫入原先遊戲 profile。
選用的「匯入先前旅程」讀取同一 profile 的 `crystal_g06_slot_01.json`，原檔保留；沒有放入舊檔時不會憑空建立進度。
本輪自動驗證使用另建的 QA profile 與複製測試檔，不是玩家存檔。

## 操作與路線

- WASD／方向鍵／Xbox 左搖桿移動；按住 Shift／Xbox LS 跑步。
- E／Xbox A 互動；對話可用 E、空白、Enter 或畫面按鈕。
- M 開啟旅途手冊；Esc 關閉；F5 保存，F9 讀取。離開前請手動保存。
- 戰鬥用滑鼠，或方向鍵／Tab 與 Enter；手把沿用目前配置。

旅館旁開場 → 公會接委託 → 莉雅加入 → 森林教學戰 → 礦坑星晶與 Boss → 返回公會交付 → 離村預告。
第一章仍只有解鎖／預告。礦口不能跳過森林教學戰。
額外檢查道具商店、旅館恢復、木橋／碼頭動線及水面，再保存、關閉、重開讀取。

新的固定包尚需實體鍵鼠／Xbox 完整通關與 Windows 長測；先前 RC3／RC4 或編輯器的結果不能代替它。
若出現問題，保留 `user_test/play-*.log` 及同名 stdout 檔，記下位置和操作。
