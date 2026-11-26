import statistics
from collections import Counter


def summarize(latencies_ms: list[float]) -> dict[str, float]:
    ordered = sorted(latencies_ms)
    count = len(ordered)
    return {
        "count": count,
        "mean": round(statistics.fmean(ordered), 2),
        "median": statistics.median(ordered),
        "p95": ordered[int(count * 0.95) - 1],
        "max": ordered[-1],
    }


def top_paths(log_lines: list[str], limit: int = 5) -> list[tuple[str, int]]:
    paths = Counter()
    for line in log_lines:
        method, path, status = line.split()[:3]
        if status.startswith("2"):
            paths[path] += 1
    return paths.most_common(limit)


if __name__ == "__main__":
    sample = [12.5, 18.0, 9.75, 31.2, 14.0, 22.8, 11.1, 95.4, 16.3, 13.9]
    report = summarize(sample)
    for key in ("count", "mean", "median", "p95", "max"):
        print(f"{key:>6}: {report[key]}")
    logs = ["GET /cart 200", "GET /cart 200", "POST /pay 500", "GET /home 200"]
    print(top_paths(logs, limit=2))
