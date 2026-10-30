# 莉雅背裙局部網格修整候選 — 2026-10-30

**仍未達遊戲使用門檻。** 在獨立 Blender 副本處理背裙兩處黑色交疊尖片；第二版原生背面畫面中兩處明顯減少，但斜側仍有小裂縫，衣襬有粉色／白邊錯色，袖口與手部尖片、長頸和領口仍未處理。此候選沒有骨架或動作，未替換任何遊戲角色。正式可玩莉雅與存檔不變；人工驗收依使用者指示暫停。

## 方法與兩輪結果

來源是 `material_cleanup_v2_20261029/lia_material_cleanup.blend`，SHA256 `1e8d238dc505c3c347d125b43501093c47f4be5c59df437dd4330e1dc235e37e`；其 GLB SHA256 `bd9d5c1c8f016fb12a6e096a4cad642b32b4f728f6e02b393147ab9040b0e5ac`。以真實 Blender 背面正交圖定位兩處裂片，再用射線找到附近較大的衣料面；沒有使用 AI 圖像或將畫面塗抹後冒充模型。

- 第一版只移除 66 個局部且背後有支撐取樣的小面。保留其餘 12,012 個身體面；背面局部仍有尖片，一側更明顯，**不採用**。
- 第二版擴大至兩處局部互相疊合的 280 個小面，要求每個面四個內部取樣點均能找到相距 2.5 cm 以內的較大衣料面。其餘 11,798 個身體面的頂點、UV 逐項核對，角落法線最大偏差 0.000140；頸部網格未動。這些取樣只限制局部刪除範圍，**不證明面積完全覆蓋、網格封閉或動畫變形安全**。
- 相同 Blender 鏡頭、光源及畫面設定，兩個指定小矩形內 RGB 三色均小於 40 的深色像素計數：原始 440、第一版 152、第二版 0。這只是指定區域的影像指標，不代表全裙無破洞或整體美術合格。基準渲染重跑後像素相同，PNG 檔案雜湊不同，不以檔案雜湊宣稱逐位元相同。

[修整前背面](evidence/lia_skirt_repair_20261030/before_back.png) ／ [第一版背面](evidence/lia_skirt_repair_20261030/v1_back.png) ／ [第二版背面](evidence/lia_skirt_repair_20261030/v2_back.png) ／ [第二版斜側](evidence/lia_skirt_repair_20261030/v2_quarter.png) ／ [第二版側面](evidence/lia_skirt_repair_20261030/v2_side.png)；[第一版收據](evidence/lia_skirt_repair_20261030/v1_receipt.json)、[第二版收據](evidence/lia_skirt_repair_20261030/v2_receipt.json)。

## 實際檢查

- Blender 5.2.2 LTS 獨立背景程序；原始 blend／GLB 雜湊核對不變，未碰使用者正在開啟的 Blender 場景。
- 第二版為 **12,274／15,000 triangles**，UV／索引／有限值靜態 GLB 預檢通過；候選 GLB SHA256 `901a0bb605a4456047d3213adb354241e43ab3c73a96d55984f06ec53740c0fb`。[結果](evidence/lia_skirt_repair_20261030/static_glb_audit.json)。
- Godot 4.7.2 Compatibility／RTX 3080 圖形模式以 `GLTFDocument` 實際載入、重建實例、九視角截圖：**22／0**，高度 1.95m，4K 貼圖及頸部純色材質存在。[結果](evidence/lia_skirt_repair_20261030/godot_report.json)。這不是動畫、動態服裝、存讀檔或整體外觀通過。
- 原生背面、斜側、側面與 Godot 模型圖已檢視。**visual FAIL；rig／animation NOT_STARTED**。尖片移除未修復色彩污染、接縫或袖口。

## 候選與重現

本機試作保留於 `D:/RPGGAME/artifacts/lia-skirt-repair-experiment-20261030/` 和 `D:/RPGGAME/artifacts/lia-skirt-repair-experiment-v2-20261030/`；包含獨立 `.blend`／`.glb`，均不提交到遊戲資產。原生截圖及可追蹤工具已保存。

```powershell
# 輸出路徑必須不存在；來源 SHA 與選取數量不符時停止。
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python-exit-code 1 --python scripts/tools/repair_lia_skirt_fragments.py -- --input source_assets/character_rebuild_20261020/lia/material_cleanup_v2_20261029/lia_material_cleanup.blend --output artifacts/lia-skirt-replay --thorough
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python-exit-code 1 --python scripts/tools/render_lia_repair_inspection.py -- --input source_assets/character_rebuild_20261020/lia/material_cleanup_v2_20261029/lia_material_cleanup.blend --output artifacts/lia-skirt-baseline-replay
python scripts/tools/audit_character_glb.py --input artifacts/lia-skirt-replay/lia_skirt_repair.glb --category player_character --allow-static --output artifacts/lia-skirt-replay/audit.json
```

後續須在局部逐面修復剩餘袖口／手部、裙面與領口，按參考圖修正錯色；完成靜態外觀後才進行綁骨、權重、走跑、持杖／施法與遊戲回歸。RC5 與本輪新候選無關，不能沿用 RC5 的結果稱新莉雅已通過。
