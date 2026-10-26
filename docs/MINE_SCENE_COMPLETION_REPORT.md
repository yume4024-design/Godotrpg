# 礦坑造景整合候選與 Windows RC2

2026-10-26，承接 b617652，依使用者礦坑八區參考與 crystal-scene-builder 完成造景組裝候選。人工美術／實體輸入驗收依使用者指示維持暫停，不能將自動回歸寫成人工認可。

## 交付場景

入口營地、西部礦車軌道、中央木橋岔路、北部水晶採掘、東北儲物、東部地下水、南部塌方、東南核心洞窟均已建置；沿用八區地形、五組彎軌、十組工具工作區、吊籠／支架／礦車、箱桶及地下水系統。

本輪將規則岩牆貼片換為60組錯落岩壁支塊，補113處岩緣、21組坑壁岩座與122塊低矮碎礦石。六處坑道加深至4.35m，具有後退端壁、內側岩襯、三道木肋及延伸鐵軌。22處火焰改為收尖外形與熱度漸層；水晶使用共用切面／反光／微發光Shader，避免單一亮藍色。

實景檢查另發現中央橋東側木板與土平台共面造成鋸齒閃紋；以實際三角形BVH重現29個共面取樣失敗。橋板提高3cm，碰撞不變；修正後至少20個平頂取樣保持2cm以上間距，斜倒角另檢查大於2mm，另核對原生近景。初次診斷錯把斜倒角套用平頂2cm門檻，已按法線區分，並以相同最終判準重跑舊檔，舊檔仍失敗。失敗JSON與畫面保留，未將先前有缺陷的畫面作最終交付。

完整可編輯主檔：[mine_reference_master.blend](../source_assets/mine_reference_20261024/mine_reference_master.blend)。12個場景GLB＋4個獨立機械GLB；靜態場景199,112三角面／200,000預算。模型由專案Blender Python生成，重用既有來源，沒有新增付費或外部素材。

## 遊戲契約及實際驗證

Godot 4.7.2.stable.official.ed1daf0bf、Blender 5.2.2 LTS、Windows／RTX3080／Compatibility OpenGL。501個碰撞、layout4及JSON SHA與修改前一致；角色ID、戰鬥數值、劇情／任務／獎勵及Save Schema未改。新裝飾無碰撞；沒有為水道加入隱形可走平地。

| 原始專案命令模式 | 檢查／失敗 |
|---|---:|
| TestMineReference | 55／0 |
| TestMineReferenceMigration | 59／0 |
| VisualMineReferenceStory | 68／0 |
| TestMineReferenceStoryReload | 7／0 |
| VisualReferenceStory | 68／0 |
| TestReferenceStoryReload | 7／0 |

合計264項／0失敗，包含真正CharacterBody＋InputMap走跑與上下階、兩個村莊整合入口的序章／戰鬥返回／單次獎勵、舊檔遷移及新程序讀取。另完成Check匯入、16GLB結構、908岩體組件閉合／方向／正體積及世界邊界檢查、3670模型淨空射線／0命中，以及14張原生視圖。射線是道路取樣，不等於所有角落或相機無遮擋認證。

動線8780幀、平均59.47FPS、P95 16.71ms、P99 16.79ms、最大244.60ms；Draw Calls 85–169，引擎靜態記憶體42.50–42.68MiB。60FPS限制、Debug原生畫面，含截圖／測試成本；不是GPU時間、程序RSS、Release長測或Android數據。

## 實景與參考偏差

![完整礦坑](../source_assets/mine_reference_20261024/evidence/completion_20261026/overview.webp)

![採掘區](../source_assets/mine_reference_20261024/evidence/completion_20261026/review_crystal.webp)

![坑道深度](../source_assets/mine_reference_20261024/evidence/completion_20261026/review_tunnel_depth.webp)

參考的八區鄰接、上下層、中央橋、藍水／暖木構與道具種類已接入；遊戲版保留約5m主通道和鏡頭淨空，因此平台間距、矩形地形邊界、部分岩壁輪廓及道具比例仍與概念圖不同。這是可玩的完整造景候選，不宣稱嚴格逐像素還原或美術人工驗收通過。礦車、吊籠、塌方及坑口為靜態造景；未新增運輸、採礦或額外劇情。正式0.6.1入口保留，Android／iOS與第一章暫停。

## Windows 固定包

版本契約已更新為0.6.1-mine-reference-rc2；包來源提交、建置與包內測試在後續固定來源建置完成後補記，現階段不得沿用RC1測試認證RC2。

[資產／SHA](../source_assets/mine_reference_20261024/evidence/completion_20261026/asset_receipt.json)、[測試](../source_assets/mine_reference_20261024/evidence/completion_20261026/tests.json)、[動線](../source_assets/mine_reference_20261024/evidence/completion_20261026/traversal.json)、[碰撞保留](../source_assets/mine_reference_20261024/evidence/completion_20261026/protected_layout.json)。
