#!/usr/bin/env python3
"""Fetch bundled draw data for all app-supported lottery games."""

from __future__ import annotations

import json
import re
import ssl
import time
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlencode
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parents[1]
RESOURCE_PATH = ROOT / "CaipiaoPredictor" / "Sources" / "CaipiaoPredictor" / "Resources" / "bundled_draws.json"
ENDPOINT = "https://jc.zhcw.com/port/client_json.php"

GAMES = {
    "kl8": {"lottery_id": "6", "issue_count": 3000},
    "ssq": {"lottery_id": "1", "issue_count": 1500},
    "fc3d": {"lottery_id": "2", "issue_count": 2500},
    "qlc": {"lottery_id": "3", "issue_count": 1500},
    "dlt": {"lottery_id": "281", "issue_count": 1500},
    "pl3": {"lottery_id": "283", "issue_count": 2500},
    "pl5": {"lottery_id": "284", "issue_count": 2500},
    "qxc": {"lottery_id": "287", "issue_count": 1500},
}
PAGE_SIZE = 500

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X) AppleWebKit/605.1.15 Safari/605.1.15",
    "Referer": "https://www.zhcw.com/",
}


def fetch_text(url: str) -> str:
    request = Request(url, headers=HEADERS)
    context = ssl._create_unverified_context()
    with urlopen(request, timeout=30, context=context) as response:
        data = response.read()
        charset = response.headers.get_content_charset() or "utf-8"
    return data.decode(charset, errors="replace")


def parse_jsonp(payload: str) -> dict:
    start = payload.find("(")
    end = payload.rfind(")")
    if start < 0 or end <= start:
        raise ValueError("Response is not JSONP")
    return json.loads(payload[start + 1 : end])


def parse_numbers(value: str) -> list[int]:
    return [int(item) for item in (value or "").split() if item.isdigit() and int(item) >= 0]


def parse_digits(value: str, expected_count: int) -> list[int]:
    spaced = parse_numbers(value)
    if len(spaced) == expected_count and all(0 <= digit <= 9 for digit in spaced):
        return spaced
    digits = [int(char) for char in value or "" if char.isdigit()]
    return digits[:expected_count]


def make_components(game: str, item: dict) -> dict[str, list[int]] | None:
    front = parse_numbers(item.get("frontWinningNum", ""))
    back = parse_numbers(item.get("backWinningNum", ""))

    if game == "kl8":
        return {"main": sorted(front[:20])} if len(front) >= 20 else None
    if game == "ssq":
        return {"front": sorted(front[:6]), "back": sorted(back[:1])} if len(front) >= 6 and len(back) >= 1 else None
    if game in {"fc3d", "pl3"}:
        digits = parse_digits(item.get("frontWinningNum", ""), 3)
        return {"digits": digits} if len(digits) == 3 else None
    if game == "qlc":
        if len(front) < 7:
            return None
        if back:
            special = back[0]
        elif len(front) >= 8:
            special = front[7]
        else:
            special = None
        return {"front": sorted(front[:7]), "back": [special] if special is not None else []}
    if game == "dlt":
        return {"front": sorted(front[:5]), "back": sorted(back[:2])} if len(front) >= 5 and len(back) >= 2 else None
    if game == "pl5":
        digits = parse_digits(item.get("frontWinningNum", ""), 5)
        return {"digits": digits} if len(digits) == 5 else None
    if game == "qxc":
        merged = " ".join(value for value in [item.get("frontWinningNum", ""), item.get("backWinningNum", "")] if value and value != "-1")
        digits = parse_digits(merged, 7)
        return {"digits": digits} if len(digits) == 7 else None
    return None


def fetch_game_page(game: str, lottery_id: str, issue_count: int, page_num: int) -> list[dict]:
    params = {
        "transactionType": "10001001",
        "lotteryId": lottery_id,
        "issueCount": str(issue_count),
        "startIssue": "",
        "endIssue": "",
        "startDate": "",
        "endDate": "",
        "type": "0",
        "pageNum": str(page_num),
        "pageSize": str(PAGE_SIZE),
        "tt": str(time.time()),
        "callback": "lottery_callback",
    }
    payload = fetch_text(f"{ENDPOINT}?{urlencode(params)}")
    decoded = parse_jsonp(payload)
    if decoded.get("resCode") and decoded.get("resCode") != "000000":
        raise RuntimeError(f"{game}: {decoded.get('resCode')} {decoded.get('message')}")

    rows: list[dict] = []
    for item in decoded.get("data", []):
        components = make_components(game, item)
        if not components:
            continue
        rows.append(
            {
                "issue": item.get("issue", ""),
                "drawDate": item.get("openTime", ""),
                "week": item.get("week", ""),
                "components": components,
                "saleMoney": to_float(item.get("saleMoney")),
                "prizePoolMoney": to_float(item.get("prizePoolMoney")),
                "source": "zhcw_jsonp",
            }
        )
    return rows


def fetch_game(game: str, lottery_id: str, issue_count: int) -> list[dict]:
    by_issue: dict[str, dict] = {}
    pages = max(1, (issue_count + PAGE_SIZE - 1) // PAGE_SIZE)
    for page_num in range(1, pages + 1):
        rows = fetch_game_page(game, lottery_id, issue_count, page_num)
        if not rows:
            break
        for row in rows:
            by_issue[row["issue"]] = row
        if len(rows) < PAGE_SIZE:
            break
        time.sleep(0.12)
    return sorted(by_issue.values(), key=lambda row: natural_issue_key(row["issue"]))


def natural_issue_key(issue: str) -> tuple[int, str]:
    digits = re.sub(r"\D", "", issue or "")
    return (int(digits) if digits else 0, issue)


def to_float(value: str | None) -> float | None:
    if value in (None, "", "-1"):
        return None
    try:
        return float(str(value).replace(",", ""))
    except ValueError:
        return None


def main() -> None:
    games: dict[str, list[dict]] = {}
    latest: dict[str, dict[str, str]] = {}

    for game, config in GAMES.items():
        draws = fetch_game(game, config["lottery_id"], config["issue_count"])
        games[game] = draws
        if draws:
            latest[game] = {
                "issue": draws[-1]["issue"],
                "drawDate": draws[-1]["drawDate"],
                "count": str(len(draws)),
            }
        print(f"{game}: {len(draws)} draws, latest {latest.get(game, {}).get('issue', '-')}")

    payload = {
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "source": ENDPOINT,
        "games": games,
        "latest": latest,
    }
    RESOURCE_PATH.parent.mkdir(parents=True, exist_ok=True)
    RESOURCE_PATH.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    print(RESOURCE_PATH)


if __name__ == "__main__":
    main()
