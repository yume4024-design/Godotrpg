# 匯入測試診斷

- 首次實際圖形檢查21項／1失敗：既有測試假設每件模型都有貼圖；新頸部明確使用LiaAuthoredSkin純色，身體仍須有4K貼圖。首次結果保留於first_import_result.json。
- 擴充檢查器時使用Color.is_finite產生語法錯誤；改為逐r/g/b檢查。原日誌保留本機artifacts/lia_side_review_20261028/solid-parse-error.log，未計為通過。
- 最終有效宣告22項／0失敗；NotPresent反例22項／2失敗、原生程序exit1，證明宣告不存在或貼圖缺失仍被拒絕。negative_material_result.json是預期失敗，不是資產通過。
