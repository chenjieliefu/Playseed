"""Open a saved game using Playseed's normal checked-version action."""
from pathlib import Path
import argparse
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
import backend
import producer


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('idea_id')
    args = parser.parse_args()
    game = producer.read_game(backend, args.idea_id)
    if not game:
        raise SystemExit('请先在 Playseed 中制作游戏。')
    job = backend.DATA / 'jobs' / ('open-web-' + backend.now().replace(':', '-'))
    job.mkdir(parents=True, exist_ok=True)
    request = {'action': 'play_created', 'idea_id': args.idea_id,
               'game_revision': game['current_revision']}
    backend.atomic_json(job / 'request.json', request)
    result = backend.process_request(request, job)
    backend.atomic_json(job / 'result.json', result)
    print(result['summary'])


if __name__ == '__main__':
    main()
