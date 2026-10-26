# 新版參考灰石村 Windows 候選

版本：0.6.1-greystone-reference-rc3；源碼 `d0bb61006298a92f470889552039f218d9ae81e0`。

啟動本機固定包：

```text
D:\RPGGAME\builds\greystone-reference\rc3-d0bb610-verified\candidate\start_reference_village.cmd
```

也可解壓上一層建置目錄的 `ProjectCrystal-0.6.1-greystone-reference-rc3-windows-x64.zip`，執行其中啟動器。exe、pck與啟動器保持同資料夾。等待載入畫面進入灰石村；視窗關閉後，啟動器會正常退出。

- 鍵盤：WASD／方向鍵走路，按住Shift跑步，E互動，M旅途手冊，F5存檔／F9讀檔。
- Xbox：左搖桿移動，按住 **LB跑步**，放開恢復走路；A互動／確認，B返回，Menu開啟手冊。LS不再觸發跑步。
- 從廣場可經旅館旁的石階到上游路線，再抵達礦坑；中央橋、東岸階梯及上游橋形成環路。礦坑劇情仍需先完成森林教學。

啟動器將測試資料放在包內 `user_test`，不讀寫正式使用者存檔。匯入舊槽的功能只在舊槽已存在於同一隔離使用者資料目錄時才有來源；本包不自動搬移其他版本存檔。原 v0.6.1、RC4、舊 Blender 與礦坑候選包保留。

本包是參考圖還原修整候選。完整功能、圖形模式與打包證據見 [報告](GREYSTONE_SCENE_COMPLETION_REPORT.md)。人工鍵鼠／Xbox驗證按使用者指示暫停，沒有以自動操作代替人工通過；美術仍存在岩壁／屋身細節與參考圖的差距。Android／iOS／第一章未啟動。

本輪包已通過143項序章／交易／遷移與28項新程序讀檔檢查，普通啟動12.17秒並正常關閉；不是人工或30分鐘長測。舊RC2仍在`builds/greystone-reference/rc2-122891e`，新包不會覆蓋它。
