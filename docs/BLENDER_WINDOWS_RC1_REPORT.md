# 灰石村 Blender Windows RC1 固定包驗證

2026-10-24（Asia/Taipei），功能分支 `feature/greystone-g06`。
版本 `0.6.1-greystone-blender-rc1`，正式 base version 仍為 0.6.1。

## 準備檢查點

已建立兩個獨立 Windows x86_64 release presets、繼承既有載入邊界的候選入口、
獨立存檔啟動器、可重製匯出工具及原生 Release 序章／服務／遷移測試。
Godot 4.7.2 載入與 PowerShell 語法檢查通過。
固定提交匯出、PCK 資源稽核、包內圖形／序章／重啟與普通啟動仍進行中，未標記通過。

舊 RC4、v0.6.1、既有模型、數值、故事與存檔 schema 保留。新包不合併 main。
Android／iOS、第一章、新模型、本包實體輸入與 30 分鐘長測不列入本輪完成項。

相關入口：[試玩指南](BLENDER_WINDOWS_RC1_GUIDE.md)、[材質成果](GREYSTONE_SURFACE_REPORT.md)。
