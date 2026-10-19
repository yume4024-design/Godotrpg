"""Safety regressions for current live-snapshot workflow conversion; no jobs."""
import contextlib
import hashlib
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts/tools'))
import prepare_reference_asset as workflow

SNAPSHOT = ROOT / 'source_assets/npc_rebuild_20261020/item_merchant'


class WorkflowTest(unittest.TestCase):
    def test_current_snapshot_preserves_sources_and_four_full_image_chains(self):
        source = SNAPSHOT / 'workflow_source.json'
        before = source.read_bytes()
        with tempfile.TemporaryDirectory(dir=ROOT / 'artifacts') as directory:
            output = Path(directory) / 'candidate'
            with contextlib.redirect_stdout(io.StringIO()):
                workflow.prepare(source, SNAPSHOT / 'live_slots.values.json', 'item_merchant', 'npc', output)
            graph = json.loads((output / 'full.api.json').read_text(encoding='utf8'))
            inputs = json.loads((output / 'inputs.api.json').read_text(encoding='utf8'))
            manifest = json.loads((output / 'generation_manifest.json').read_text(encoding='utf8'))
            self.assertEqual(before, source.read_bytes())
            self.assertEqual(manifest['source_workflow_sha256'], hashlib.sha256(before).hexdigest())
            self.assertFalse(manifest['generation_submitted'])
            self.assertEqual(manifest['candidate_target'], 13800)
            resolution = next(n['inputs']['target_resolution'] for n in graph.values() if n['class_type'] == 'Trellis2UpsampleStage')
            self.assertIs(type(resolution), int)
            self.assertEqual(resolution, 1536)
            self.assertEqual(len({v['load_node'] for v in manifest['views'].values()}), 4)
            for view, entry in manifest['views'].items():
                self.assertEqual(graph[entry['load_node']]['inputs']['image'], 'crystal_item_merchant_' + view + '.png')
            # User's four ImageCropV2 nodes are bypassed in this current snapshot.
            # Never silently activate stale composite-sheet bounding boxes.
            self.assertNotIn('ImageCropV2', {n['class_type'] for n in graph.values()})
            self.assertFalse(any('Trellis' in n['class_type'] or 'Pixal' in n['class_type'] for n in inputs.values()))
            with self.assertRaises(FileExistsError):
                workflow.prepare(source, SNAPSHOT / 'live_slots.values.json', 'item_merchant', 'npc', output)

    def test_unapproved_reference_cannot_queue_or_write_workflow(self):
        with tempfile.TemporaryDirectory(dir=ROOT / 'artifacts') as directory:
            root = Path(directory)
            catalog = root / 'source_assets/reference_library_20261020/catalog.json'
            catalog.parent.mkdir(parents=True)
            catalog.write_text(json.dumps({'pending': {'ready_for_generation': False}}), encoding='utf8')
            with patch.object(workflow, 'ROOT', root), self.assertRaises(ValueError):
                workflow.prepare(SNAPSHOT / 'workflow_source.json', SNAPSHOT / 'live_slots.values.json', 'pending', 'npc', root / 'out')
            self.assertFalse((root / 'out').exists())

    def test_changed_remesher_stops_without_guessing_or_partial_outputs(self):
        with tempfile.TemporaryDirectory(dir=ROOT / 'artifacts') as directory:
            root = Path(directory)
            document = json.loads((SNAPSHOT / 'workflow_source.json').read_text(encoding='utf8'))
            for node in document['nodes']:
                if node['type'] == 'RemeshMesh': node['type'] = 'ChangedUnknownRemesher'
            source = root / 'changed.json'
            source.write_text(json.dumps(document), encoding='utf8')
            with self.assertRaises(ValueError):
                workflow.prepare(source, SNAPSHOT / 'live_slots.values.json', 'item_merchant', 'npc', root / 'out')
            self.assertFalse((root / 'out').exists())


if __name__ == '__main__': unittest.main(verbosity=2)
