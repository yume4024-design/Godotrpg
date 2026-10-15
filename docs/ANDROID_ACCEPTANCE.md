# Android 狀態紀錄

狀態：**依使用者最新指示暫停**。本輪沒有 APK，未安裝、未進行 ADB 或設備驗收。

## 2026-10-16 已完成的環境檢查

- PATH 未找到 java／adb，JAVA_HOME／ANDROID_HOME／ANDROID_SDK_ROOT 未設定。
- 預設 LocalAppData/Android/Sdk 不存在；已查 Godot 編輯器設定及常見程式目錄，未找到可用 SDK/JDK 設定。
- 專案工具隔離目錄 artifacts/godot-user/Godot/export_templates/4.7.2.stable 僅有 Windows x86_64 模板及資料檔。
- 曾建立暫時 ARM64 Debug preset 並呼叫 Godot --export-debug；引擎 exit 1，回報缺少 android_debug.apk、android_release.apk、有效 Java SDK、platform-tools/adb、build-tools/apksigner。
- 匯出日誌：artifacts/logs/exportandroiddebug-20261016-000027-065.log。builds/android/ProjectCrystal-debug-arm64.apk 不存在。

使用者隨後指示「Android先不作」，已移除本輪暫時preset、專用入口覆寫及匯出命令；正式Windows設定保留。不下載或安裝SDK，不建立簽章金鑰。

日後恢復時先依[Godot官方Android匯出文件](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)核對相符引擎模板、JDK及SDK。tools/godot.ps1使用隔離APPDATA，設定及模板須安裝到對應工具環境，不能只看一般編輯器已設定便宣稱可用。

待辦：環境安裝、ARM64 APK匯出、ADB辨識與安裝、觸控／存讀／劇情／效能設備驗收。全部未完成，不能以Windows觸控模擬或匯出預設代替。
