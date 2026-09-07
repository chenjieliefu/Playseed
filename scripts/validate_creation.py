"""Run isolated, real-model checks for the canonical P0 game briefs."""

import argparse
import json
import sys
import uuid
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

import backend as b
from validation_cases import validate_cases


ALL_CASES = validate_cases()
parser = argparse.ArgumentParser(description="运行 Playseed 五类 2D 游戏的真实生成验收。")
parser.add_argument("--genre", action="append", choices=[case["slug"] for case in ALL_CASES],
                    help="只运行指定样本；可重复使用。默认运行全部样本。")
parser.add_argument("--with-revisions", action="store_true",
                    help="每个样本继续执行三轮修改，会额外使用 GPT 额度。")
parser.add_argument("--model", choices=["gpt-5.6-sol", "gpt-6-astra"], default="gpt-5.6-sol")
parser.add_argument("--effort", choices=["low", "medium", "high", "xhigh", "max"], default="medium")
parser.add_argument("--output", type=Path,
                    help="验收结果目录。默认写入 .playseed/validation/，不会出现在用户项目列表中。")
args = parser.parse_args()

run_name = datetime.now().astimezone().strftime("%Y%m%d-%H%M%S")
run_root = (args.output or ROOT / ".playseed" / "validation" / run_name).resolve()
if run_root.exists() and any(run_root.iterdir()):
    raise SystemExit("验收目录必须为空，避免覆盖已有结果。")
run_root.mkdir(parents=True, exist_ok=True)

# The validation run gets its own data and project roots, so it cannot add records
# to the user's sidebar or modify a real game folder.
b.DATA = run_root / "data"
(b.DATA / "ideas").mkdir(parents=True, exist_ok=True)
(b.DATA / "jobs").mkdir(parents=True, exist_ok=True)

cases = ALL_CASES
if args.genre:
    selected = set(args.genre)
    cases = [case for case in cases if case["slug"] in selected]

summary = {
    "started_at": b.now(),
    "model": args.model,
    "reasoning_effort": args.effort,
    "with_revisions": args.with_revisions,
    "run_directory": str(run_root),
    "results": [],
}


def save_summary():
    (run_root / "summary.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8"
    )


for case in cases:
    title, premise, goal = case["title"], case["premise"], case["goal"]
    idea_id = uuid.uuid4().hex
    stamp = b.now()
    project_directory = run_root / "projects" / case["slug"]
    project_directory.mkdir(parents=True, exist_ok=True)
    idea = {
        "id": idea_id,
        "title": title,
        "revision": 1,
        "ready": True,
        "status": "confirmed",
        "confirmed_revision": 1,
        "created_at": stamp,
        "updated_at": stamp,
        "confirmed_at": stamp,
        "confirmed_by": "validation_run",
        "project_directory": str(project_directory),
        "messages": [{"role": "assistant", "text": "这是 Playseed 制作能力的验收方案。", "questions": []}],
        "questions": [],
        "history": [],
        "plan": {
            "title": title,
            "premise": premise,
            "player_goal": goal,
            "core_loop": case["loop"],
            "visual_style": case["visual"],
            "first_version": case["scope"],
            "later": ["更多关卡和专用美术素材"],
            "assumptions": ["第一版为 2D 电脑小游戏"],
        },
    }
    b.atomic_json(b.DATA / "ideas" / idea_id / "idea.json", idea)
    job = b.DATA / "jobs" / ("verify-create-" + idea_id)
    job.mkdir(parents=True)
    request = {
        "action": "build_game",
        "idea_id": idea_id,
        "revision": 1,
        "game_revision": 0,
        "model": args.model,
        "reasoning_effort": args.effort,
    }
    b.atomic_json(job / "request.json", request)
    result_record = {
        "slug": case["slug"],
        "genre": case["genre"],
        "title": title,
        "idea_id": idea_id,
        "build": "running",
        "revisions": [],
    }
    summary["results"].append(result_record)
    save_summary()
    print("START", case["genre"], title, flush=True)
    try:
        result = b.process_request(request, job)
        b.atomic_json(job / "result.json", result)
        b.status(job, "done", result["summary"])
        game = result["game"]
        result_record.update(
            build="passed",
            current_revision=game["current_revision"],
            project_directory=str(project_directory),
        )
        print("PASS", case["genre"], title, "v" + str(game["current_revision"]), flush=True)
        if args.with_revisions:
            for round_number, change_prompt in enumerate(case["revisions"], 1):
                revision_job = b.DATA / "jobs" / ("verify-revise-%s-%d" % (idea_id, round_number))
                revision_job.mkdir(parents=True)
                revision_request = {
                    "action": "revise_game",
                    "idea_id": idea_id,
                    "revision": 1,
                    "game_revision": game["current_revision"],
                    "prompt": change_prompt,
                    "model": args.model,
                    "reasoning_effort": args.effort,
                }
                b.atomic_json(revision_job / "request.json", revision_request)
                revised = b.process_request(revision_request, revision_job)
                b.atomic_json(revision_job / "result.json", revised)
                b.status(revision_job, "done", revised["summary"])
                game = revised["game"]
                result_record["revisions"].append(
                    {"round": round_number, "status": "passed", "revision": game["current_revision"]}
                )
                result_record["current_revision"] = game["current_revision"]
                print("PASS-REVISION", case["genre"], round_number,
                      "v" + str(game["current_revision"]), flush=True)
    except Exception as exc:
        if result_record["build"] == "running":
            result_record["build"] = "failed"
        result_record["error"] = str(exc)
        b.status(job, "error", str(exc))
        print("FAIL", case["genre"], title, str(exc), flush=True)
    finally:
        save_summary()

summary["finished_at"] = b.now()
save_summary()
print("RESULTS", run_root / "summary.json", flush=True)
