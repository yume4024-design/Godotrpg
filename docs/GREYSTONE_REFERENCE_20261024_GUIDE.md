# 新版參考灰石村 Windows 候選

版本：0.6.1-greystone-reference-rc2；源碼 `122891e39f73833c6be4253bd03a952a92262e9b`。

啟動本機固定包：

```text
D:\RPGGAME\builds\greystone-reference\rc2-122891e\candidate\start_reference_village.cmd
```

也可解壓同目錄的 `ProjectCrystal-0.6.1-greystone-reference-rc2-windows-x64.zip`，執行其中啟動器。exe、pck與啟動器保持同資料夾。等待載入畫面進入灰石村；視窗關閉後，啟動器會正常退出。

- 鍵盤：WASD／方向鍵走路，按住Shift跑步，E互動，M旅途手冊，F5存檔／F9讀檔。
- Xbox：左搖桿移動，按住 **LB跑步**，放開恢復走路；A互動／確認，B返回，Menu開啟手冊。LS不再觸發跑步。
- 從廣場可經旅館旁的石階到上游路線，再抵達礦坑；中央橋、東岸階梯及上游橋形成環路。礦坑劇情仍需先完成森林教學。

啟動器將測試資料放在包內 `user_test`，不讀寫正式使用者存檔。匯入舊槽的功能只在舊槽已存在於同一隔離使用者資料目錄時才有來源；本包不自動搬移其他版本存檔。原 v0.6.1、RC4、舊 Blender 與礦坑候選包保留。

本包是參考圖還原修整候選。完整功能、圖形模式與打包證據見 [報告](GREYSTONE_REFERENCE_20261024_REPORT.md)。人工鍵鼠／Xbox驗證按使用者指示暫停，沒有以自動操作代替人工通過；美術仍存在岩壁／屋身細節與參考圖的差距。Android／iOS／第一章未啟動。
