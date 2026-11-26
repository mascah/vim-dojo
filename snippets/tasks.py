import argparse
import json
from pathlib import Path

STORE = Path.home() / ".tasks.json"


def load() -> list[dict]:
    if not STORE.exists():
        return []
    return json.loads(STORE.read_text(encoding="utf-8"))


def save(tasks: list[dict]) -> None:
    STORE.write_text(json.dumps(tasks, indent=2), encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(prog="tasks", description="A tiny task list.")
    sub = parser.add_subparsers(dest="command", required=True)
    add = sub.add_parser("add", help="add a task")
    add.add_argument("title")
    add.add_argument("--due", help="a date such as 2026-12-01")
    sub.add_parser("list", help="show open tasks")
    done = sub.add_parser("done", help="mark a task finished")
    done.add_argument("number", type=int)
    args = parser.parse_args()

    tasks = load()
    if args.command == "add":
        tasks.append({"title": args.title, "due": args.due, "done": False})
    elif args.command == "done":
        tasks[args.number - 1]["done"] = True
    else:
        for number, task in enumerate(tasks, start=1):
            if not task["done"]:
                print(f"{number:>3}  {task['title']}  {task['due'] or ''}")
    save(tasks)
