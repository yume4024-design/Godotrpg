# 雷恩衣褲重拓樸／腰帶縫合 — 獨立候選證據

來源基線：c18d56c3976e2819e10f9a1747fe7cde4dd4048f。原crotch_repair來源SHA為93e7f80ada44f2ce8e00205f88e59f61c125c78772881bd4cd92b9740a65c850。Windows Godot4.7.2、Blender5.2.2 LTS；沒有改動使用者開啟的Blender場景。

最終候選在 ../stitched_waist_20261021/：10655面／15000、19骨、五個蒙皮mesh、七片段。GLB SHA為43a6c8cf732498a0bd9fdebbba4ad73c80b7db94de382d7d756f9087ae90eab0；Native SHA為e42d45233fc8a1e8d598a29cd95a2def37b131c7a23926bba0f72bb90fcf5301。全部保留固定配件，沒有另計尚未驗收的劍。

三份配方及失敗已保留，再以已定位頂點直接縫合到原腰帶；只移動每側衣擺114點及新褲腰16點，不再改原保留表面、UV、權重或七動作。原4K albedo完整保留，新衣有1024×512 atlas及真實厚度；並非整件重新減面。

## 已驗證的範圍

- 嚴格GLB、獨立Blender重新匯入：PASS，10655面、骨架／UV／索引／權重／有限值。
- 七動作127影格：PASS；run最大2.151242、walk1.726146倍，2.5倍門檻不變，循環端點差0。
- 保留表面：964個指定附件face ID完整保留；保留部分位置差1.22905e-7m、UV差1.68587e-7，原骨rest及127影格骨姿最大差0。
- 四角法線的INT16_2D編碼已修正；獨立開檔最大差.001959464，仍用原.002門檻。
- 衣擺上緣：六姿勢／456點，原外側分離58.627591mm，定位縫合後2.550458mm，通過5mm檢查。
- 原生Godot：72／0，22張512²直接framebuffer；走跑兩相位、七段動作、停止恢復匯入rest及重新GLTF讀取。這是隔離的GLTFDocument檢查，不是正式cached PackedScene或RPG控制器。
- Check及原正式Pixal兩人88／0；正式模型位元與基線相同。沒有新G06全套、30分鐘、實體輸入或Android／iOS驗收。

最初Godot測試因錯把匯入rest當Identity而68／7 FAIL，修正測試比對基準後68／0，增加走跑相反相位後72／0；原失敗收據及本機圖像保留。三個配方失敗、法線診斷及腰帶FAIL不混入最後PASS清單。

## 可重現命令

在專案根目錄，快查已保存候選：

    ./tools/godot.ps1 -Mode VisualRenAuthored
    ./tools/godot.ps1 -Mode TestPixalCharacters

以新輸出目錄重做定位縫合，固定v3 Native為必要輸入：

    $blenderExe = 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe'
    $renBase = 'source_assets/character_rebuild_20261020/ren/'
    & $blenderExe -b --factory-startup --python-exit-code 1 --python scripts/tools/stitch_ren_waist.py -- --input ($renBase+'authored_garment_20261021_v3/ren_rigged.blend') --plan ($renBase+'authored_trousers_plan_20261021_reviewed/plan.json') --output artifacts/ren_stitch_repro
    & $blenderExe -b --factory-startup --python-exit-code 1 --python scripts/tools/audit_asset_motion.py -- --input artifacts/ren_stitch_repro/ren_rigged.blend --category player_character --output artifacts/ren_stitch_repro/motion.json
    & $blenderExe -b --factory-startup --python-exit-code 1 --python scripts/tools/audit_ren_waist_attachment.py -- --input artifacts/ren_stitch_repro/ren_rigged.blend --plan ($renBase+'authored_trousers_plan_20261021_reviewed/plan.json') --output artifacts/ren_stitch_repro/attachment.json
    & $blenderExe -b --factory-startup --python-exit-code 1 --python scripts/tools/audit_ren_authored_preservation.py -- --source ($renBase+'crotch_repair/ren_rigged.blend') --candidate artifacts/ren_stitch_repro/ren_rigged.blend --plan ($renBase+'authored_trousers_plan_20261021_reviewed/plan.json') --output artifacts/ren_stitch_repro/preservation.json

完整重拓樸配方：

    & $blenderExe -b --factory-startup --python-exit-code 1 --python scripts/tools/rebuild_ren_lower_garment.py -- --input ($renBase+'crotch_repair/ren_rigged.blend') --plan ($renBase+'authored_trousers_plan_20261021_reviewed/plan.json') --output artifacts/ren_authored_rebuild

本輪已以新artifacts目錄再現同一配方，v3 GLB逐位元相同；Native會含輸出檔名／工作路徑，不要求重建Native位元相等。要重新產生面清單時，先用inspect_ren_garment_topology.py在新目錄建立唯讀topology.json，再傳給plan_ren_hem_retopology.py的 --topology／--whole-trousers；不可假設被Git排除的大份本機拓樸清單已隨庫提供。

## 檔案與限制

evidence.json收錄測試／失敗收據、模型與工具SHA、正式模型未改證明、再現紀錄。sha256.json列出本輪必要檔案；文字以UTF-8無BOM／LF規整雜湊，模型及圖片逐位元。三份必要Native／GLB各約12MB，失敗大模型與原尺寸PNG不提交；v3 Native為可重現縫合的固定工作來源，並非正式資產。

最終正背面、走跑兩相位及施法近景已查看，選定姿勢沒有原襠部碎片，上緣已收回腰帶。保留原AI臉手／衣料與扣件細節限制，不宣稱全部影格無穿模。下一項是正式動作控制器、持劍／掛點、實際村莊及戰鬥／存讀檔驗收；未替換正式模型、未修改角色數值／故事／Schema，未合併main，完整第一章仍未完成。
