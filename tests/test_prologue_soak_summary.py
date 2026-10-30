import csv
import json
from pathlib import Path
import sys
import tempfile
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from summarize_prologue_soak import summarize

class SoakSummaryTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.root=Path(self.temp.name)
        self.run={'version':'test','source_commit':'a'*40,'passed':True,
                  'package_hashes':{'C:/test/qa/ProjectCrystal.pck':'b'*64},'restart_save_hashes':{'slot':'c'},
                  'method':'test','runs':[{'name':'soak','exit_code':0,'samples':1,'metrics_pid':1},{'name':'restart','exit_code':0}]}
        self.metrics={'complete':True,'failures':0,'checks':20,'soak_seconds':1801,'total_seconds':1810,
                      'source_commit':'a'*40,'pck_sha256':'b'*64,'cycles':1,'display':'Windows','engine':'test',
                      'renderer':'test','debug_build':True,'cap_fps':60,'metrics':{'mine':{'engine_peak_bytes':400}},
                      'transitions':[{'ms':300}],'checkpoints':[]}
        self.write()
        (self.root/'soak-output.txt').write_text('G075_RESULT checks=20 failures=0',encoding='utf-8')
        (self.root/'restart-output.txt').write_text('MINE_STORY_RESULT checks=25 failures=0',encoding='utf-8')
        (self.root/'soak-process.csv').write_text('seconds,working_set_bytes,private_bytes,peak_working_set_bytes,cpu_seconds\n1,100,200,120,1\n',encoding='utf-8')
    def tearDown(self):self.temp.cleanup()
    def write(self):
        (self.root/'run.json').write_text(json.dumps(self.run),encoding='utf-8')
        (self.root/'metrics.json').write_text(json.dumps(self.metrics),encoding='utf-8')
    def test_success(self):
        result=summarize(self.root)
        self.assertEqual((result['checks'],result['restart_checks']),(20,25))
        self.assertEqual(result['memory']['working_set_sample_peak_bytes'],100)
    def test_rejects_incomplete_and_headless(self):
        for key,value in [('complete',False),('soak_seconds',1799),('display','headless')]:
            previous=self.metrics[key];self.metrics[key]=value;self.write()
            with self.assertRaises(ValueError):summarize(self.root)
            self.metrics[key]=previous
    def test_rejects_mismatched_package(self):
        self.metrics['pck_sha256']='d'*64;self.write()
        with self.assertRaises(ValueError):summarize(self.root)
    def test_rejects_failed_restart_and_error_output(self):
        self.run['runs'][1]['exit_code']=1;self.write()
        with self.assertRaises(ValueError):summarize(self.root)
        self.run['runs'][1]['exit_code']=0;self.write()
        (self.root/'restart-output.txt').write_text('ERROR: failure\nMINE_STORY_RESULT checks=25 failures=0',encoding='utf-8')
        with self.assertRaises(ValueError):summarize(self.root)

if __name__=='__main__':unittest.main()
