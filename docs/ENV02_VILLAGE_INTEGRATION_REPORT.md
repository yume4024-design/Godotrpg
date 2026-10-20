# ENV02 — 灰石村水車與作物整合

2026-10-20，**G06 新版地圖單件整合 PASS**。正式 v0.6.1 主入口、既有 RC2 包／PCK、角色、事件／獎勵與存檔 Schema 均未改動。這不是整張地圖美術、G08 或第一章完成。

## 實際變更

- `greystone_village.tscn` 的 28 組作物改引用已驗收 leafy_crop PackedScene；位置完全不變，144 面／株、共用一個 Mesh／兩材質，合計 4032 triangles。沒有新增碰撞／採收／經濟功能。
- 水車換成帶固定 A 架的 `waterwheel_bank.tscn`，1372／2500 triangles：原 Wheel 1128、FixedAxle 84，加 BankSupport 160。三 Mesh／六 surfaces，仍只用 G04 wood／iron／stone 三個共享材質；無貼圖或透明效果。
- `build_waterwheel.py --bank-mount` 為明確選項；預設無支架版本重建 GLB SHA 與已驗收原件 **完全相同** `4c0ad1c26449fc09d524b0b45d42af6a44bf50a0b53030d9eceb50ed0d7af495`。舊模型保留，沒有重造七棟建築。
- 水車原 `(31,-0.8,-4)` 穿入 RiverRock3 且未入水；移到 `(33.6,-1.35,-4)`，轉動網格不與岩石包圍盒重疊、輪緣入實際 y=-3.6m 水面約 0.10m。A 架腳延伸水面下，木支架與轉動部位軸向淨空實測約 0.125m，固定軸／架不隨輪體轉動。
- 既有 FarmBedAccess 的 x=-36 小徑穿進農舍牆，實走在 `(-36.3046,4.000846,-32.79309)` 被擋；只將這段可見支路移至 x=-34，繞過原牆。沒有移動建築、修改牆或增加地形／碰撞。
- 離線組裝工具改用相同新模組／位置，避免以後回退到佔位；沒有執行整張舊基線生成器去覆寫現有 G07／G08 場景修正。

## 驗收及保存契約

Godot **4.7.2.stable.official.ed1daf0bf**，Blender **5.2.2 LTS**，Windows／RTX 3080／Compatibility。替換前在 b5a70eb 工作樹記錄 baseline：136 碰撞形狀、七建築、出生／NPC 預留 Marker、28 作物位置，以及主入口／Runtime 配置／序章 JSON／SaveCodec SHA。

| 命令／檢查 | 實際結果與範圍 |
|---|---|
| GLB 嚴格預檢／Blender evaluated | PASS，1372／2500、0 退化面；明確純色／靜態例外，不宣稱 UV 展開 |
| `tools/godot.ps1 -Mode Check` | PASS；最終回歸再次 Check，日誌見下方 manifest |
| `tools/review_greystone_environment.ps1` | **153 checks／0 failures**，正常 60Hz／1倍時間，既有 ExplorationPlayer＋合成 InputMap 實走入口、農舍、田邊、武器店、河岸；四面資源、材質／旋轉、三個實際捕捉畫面 |
| 替換前後指紋 | **136 碰撞形狀完全一致**，含幾何／transform／layer／mask／disabled；七建築、出生／NPC Marker、28 作物 transform、五個保護檔 SHA 一致。只有水車視覺位置與小徑視覺位置改動 |
| `tools/test_g06.ps1` | **16 模式／576 斷言 PASS**，含舊序章、敵人 AI、戰鬥、單次獎勵、NPC、交易／住宿、遷移、另程序讀取及桌面觸控模擬 |
| 原始水車 builder 預設回歸 | 無支架 GLB 與既有原件 SHA 完全相同；新增變體不修改預設結果 |
| G08 Release／長測／低階 PC／Android／iOS | 本輪未執行；舊 G07／G08 指標不冒稱覆蓋本輪新渲染內容 |

回歸 manifest：`artifacts/regression/g06-20261020-154449.json`，Check 到 TestG06CommerceReload 均 passed；不是每種模式都為圖形，manifest 的 result／log 分別標明。自動輸入不等於實體鍵鼠／Xbox 驗收；沒有新增一輪使用者通關證詞。

場景專項的 baseline／report、manifest、失敗及前後 WebP 複製到 `source_assets/environment_rebuild_20261020/village_integration/`，與模型 SHA 綁定。136 個碰撞沒有改動，因此這次無須改位置版號來接受無效位置；原 SaveCodec 嚴格驗證保留，遷移／重新讀檔仍實際重跑。

保存替換前原始 CRLF 檔案 SHA，實測五個保護檔逐位元組未變。為避免重新 checkout 換行造成假失敗，可重跑基線及 acceptance 的文字 SHA 統一 UTF8／LF，二進位模型／圖片仍核對原位元組；基線同時保留原始 raw SHA。這只改測試比對方式，不改檔案內容、存檔驗證或任何遊戲資料。

## 失敗與修正證據

1. 初寫測試誤用 PackedByteArray 的 String 雜湊介面，載入拒絕；改 HashingContext 後才開始記錄 baseline，沒有把載入失敗算 PASS。
2. 首輪 133／3：田邊路線碰到既有農舍；保存報告並改支路及實走路線。
3. 次輪 133／0 但畫面水車穿岩，**視覺拒用**；保留 `failed_visual_rock.webp`，再定位／補固定架，沒有以數值通過宣稱完成。
4. 支架檢查初將水下寬石座也當木架，153／1；定位到石座最小 X 距 0.72m、輪轂半寬 0.65m。修正範圍僅檢查木料，保留 0.10m 門檻，實際木架間隙 0.124996m；石座在水下且低於輪體。失敗報告保留。

Blender 保存成功時有使用者縮圖快取寫入警告；不影響原生檔／GLB，重匯入另行通過。獨立 headless 位置診斷曾因未指定 profile 無法開預設日誌，後續已改工作區 profile／log；不拿該次診斷當圖形或玩家驗收。

## 實際畫面與限制

已看替換前／後農田、水車兩個轉動時點及穿岩失敗。新輪體完整可辨識、轉動無穿岩或固定架跟轉；田畦作物沿既有配置排列，東側支路可實走。微評：COMP-SAFE-EDGE 2、COMP-DEPTH-LAYERS 2、COMP-NEG-SPACE 2、COMP-LEAD-ENV 1、LIGHT-KEY-FILL 1、LIGHT-SPEC-LOT 2、MOT-VOL 2，12／14（B）。深色輪體局部偏暗；既有田畦後方圍欄仍穿過部分種植行，沒有為本輪裝飾而移動碰撞／失效舊位置。整圖參考還原度、UI、農耕、所有地形與鏡頭遮擋未因此宣稱完成。

下一件：處理尚未合格的角色／敵人衣褲與翼膜拓樸，並逐件完善森林／礦坑／物品；免費枯木尚未放入正式森林。A04／A05、主角重製、Windows Gate 及完整 C1 維持未完成，Android／iOS 暫停。
