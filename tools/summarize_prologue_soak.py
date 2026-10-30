"""Summarize a completed fixed-package soak without copying saves or full logs."""
import argparse
import csv
import json
import re
import statistics
from pathlib import Path


def read_json(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def summarize(run_path):
    run=read_json(run_path/'run.json')
    metrics=read_json(run_path/'metrics.json')
    if not run.get('passed') or not metrics.get('complete') or metrics.get('failures') != 0:
        raise ValueError('Soak did not complete successfully')
    if metrics.get('soak_seconds',0) < 1800 or metrics.get('display') == 'headless':
        raise ValueError('Rendered 30-minute gate not met')
    if metrics.get('source_commit') != run.get('source_commit'):
        raise ValueError('Source commit mismatch')
    hashes=run.get('package_hashes',{})
    qa_pck=[sha for path,sha in hashes.items() if path.replace('\\','/').endswith('/qa/ProjectCrystal.pck')]
    if len(qa_pck)!=1 or qa_pck[0].lower()!=metrics.get('pck_sha256','').lower():
        raise ValueError('QA package identity mismatch')
    processes={r['name']:r for r in run.get('runs',[])}
    if set(processes)!={'soak','restart'} or any(row.get('exit_code')!=0 for row in processes.values()):
        raise ValueError('Missing successful soak or restart process')
    if not run.get('restart_save_hashes'):
        raise ValueError('Missing restart save-preservation evidence')
    outputs={name:(run_path/(name+'-output.txt')).read_text(encoding='utf-8-sig') for name in ('soak','restart')}
    if any(re.search(r'(?im)^\s*(?:ERROR:|SCRIPT ERROR:|FAIL |Parse Error:)',text) for text in outputs.values()):
        raise ValueError('Process output contains errors')
    soak_match=re.search(r'G075_RESULT checks=(\d+) failures=(\d+)',outputs['soak'])
    restart_match=re.search(r'MINE_STORY_RESULT checks=(\d+) failures=(\d+)',outputs['restart'])
    if not soak_match or not restart_match or int(soak_match[1])!=metrics.get('checks') or int(soak_match[2])!=0 or int(restart_match[2])!=0:
        raise ValueError('Missing or inconsistent terminal results')
    with (run_path/'soak-process.csv').open(encoding='utf-8-sig',newline='') as f: samples=list(csv.DictReader(f))
    if not samples or len(samples)!=processes['soak'].get('samples') or not processes['soak'].get('metrics_pid'):
        raise ValueError('Rendering process samples incomplete')
    transitions=metrics.get('transitions',[])
    if not transitions:raise ValueError('No map transitions')
    return {'version':run['version'],'source_commit':run['source_commit'],'qa_pck_sha256':qa_pck[0],
            'soak_seconds':metrics['soak_seconds'],'total_seconds':metrics['total_seconds'],
            'cycles':metrics['cycles'],'checks':metrics['checks'],'failures':metrics['failures'],
            'restart_checks':int(restart_match[1]),'restart_failures':int(restart_match[2]),
            'engine':metrics['engine'],'renderer':metrics['renderer'],'display':metrics['display'],
            'debug_build':metrics['debug_build'],'fps_cap':metrics['cap_fps'],'phases':metrics['metrics'],
            'transitions':{'count':len(transitions),'mean_ms':statistics.mean(x['ms'] for x in transitions),'max_ms':max(x['ms'] for x in transitions)},
            'memory':{'sample_count':len(samples),'rendering_pid':processes['soak']['metrics_pid'],
              'working_set_sample_peak_bytes':max(int(x['working_set_bytes']) for x in samples),
              'private_sample_peak_bytes':max(int(x['private_bytes']) for x in samples),
              'working_set_lifetime_peak_bytes':max(int(x['peak_working_set_bytes']) for x in samples),
              'engine_static_peak_bytes':max(x.get('engine_peak_bytes',0) for x in metrics['metrics'].values())},
            'checkpoints':metrics['checkpoints'],'method':run['method'],
            'limits':'Automated graphical engine mounting QA PCK; not native Release benchmark or physical-input acceptance. Frame times include test diagnostics.'}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    if args.output.exists():raise FileExistsError('Output already exists')
    summary=summarize(args.run)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('PROLOGUE_SOAK_SUMMARY checks=%d restart=%d seconds=%.3f' % (summary['checks'],summary['restart_checks'],summary['soak_seconds']))

if __name__=='__main__':main()
