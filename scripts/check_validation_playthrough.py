"""Sample-specific input replay through Godot's event dispatch and normal frames.

The policy may read state, but never writes game state, calls actions directly,
teleports characters or injects resources. This is automated play, not human QA.
"""
import argparse,json,re,shutil,sys,uuid
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
import backend as b,producer

def check(run_name,genre,revision,outcome,visual=False):
    run=ROOT/'.playseed/validation'/run_name
    if run.resolve().parent != (ROOT/'.playseed/validation').resolve():
        raise ValueError('无效验收目录')
    source=run/'projects'/genre/'revisions'/f'{revision:04d}'
    checks=ROOT/'scripts/playthrough_checks'
    body=(checks/(genre+'.gd')).read_text()
    job=run/'data/jobs'/('playthrough-'+genre+'-'+uuid.uuid4().hex);job.mkdir(parents=True)
    scratch=job/'project';shutil.copytree(source,scratch,ignore=shutil.ignore_patterns('.godot'))
    script=(checks/'driver.gd').read_text()+'\nconst EXPECTED: String = '+json.dumps(outcome)+'\nconst CAPTURE_DIR: String = '+json.dumps(str(job/'runtime') if visual else '')+'\n'+body
    (scratch/'_playthrough.gd').write_text(script);(job/'driver.gd').write_text(script)
    report={'genre':genre,'revision':revision,'outcome':outcome,'job':str(job),'scope':'Godot input events, normal fixed-60fps frames; read-only state-aware policy, no gameplay state injection'}
    try:
        extra=[] if visual else ['--headless']
        out=b.run_process(producer.sandbox_command(b,scratch,job,extra+['--fixed-fps','60','--script','_playthrough.gd','--quit-after','20000']),job,90,'playthrough',cwd=scratch,child_env=producer.runtime_env())
        match=re.search(r'PLAYTHROUGH_REPORT:(.*)',out)
        if not match: raise RuntimeError('未得到通关报告')
        report.update(json.loads(match[1]))
        if re.search(r'(?m)(SCRIPT ERROR:|ERROR:)',out): report['passed']=False
    except Exception as exc:
        report.update(passed=False,error=str(exc))
        log=job/'playthrough.log'
        match=re.search(r'PLAYTHROUGH_REPORT:(.*)',log.read_text()) if log.exists() else None
        if match:
            report.update(json.loads(match[1]))
            report['passed']=False
    finally:
        shutil.rmtree(scratch)
        b.atomic_json(run/'playthrough-reports'/f'{genre}-v{revision}-{outcome}.json',report)
    print(json.dumps(report,ensure_ascii=False),flush=True)
    return report.get('passed',False)

if __name__=='__main__':
    p=argparse.ArgumentParser(description='通过键盘鼠标事件自动试玩固定验收样本')
    p.add_argument('run');p.add_argument('genre',choices=['platformer','shooter','management','puzzle','tower_defense']);p.add_argument('revision',type=int);p.add_argument('outcome',choices=['won','lost'])
    p.add_argument('--visual',action='store_true')
    a=p.parse_args();raise SystemExit(0 if check(a.run,a.genre,a.revision,a.outcome,a.visual) else 1)
