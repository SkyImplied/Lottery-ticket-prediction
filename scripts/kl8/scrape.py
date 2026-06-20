#!/usr/bin/env python3
"""Fetch China Welfare Lottery Keno (快乐8) historical draws.

Primary source:
  https://jc.zhcw.com/port/client_json.php

Fallback source:
  https://www.gdfc.org.cn/datas/history/kl8/history_N.html

The script writes:
  data/kl8/draws.csv
  data/kl8/numbers_long.csv
  data/kl8/metadata.json
"""

from __future__ import annotations

import csv
import json
import re
import ssl
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable
from urllib.error import URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parents[2]
DATA_DIR = ROOT / "data" / "kl8"
ZHONGCAI_ENDPOINT = "https://jc.zhcw.com/port/client_json.php"
GDFC_FIRST_PAGE = "https://www.gdfc.org.cn/play_list_game_10.html"
GDFC_HISTORY_PAGE = "https://www.gdfc.org.cn/datas/history/kl8/history_{page}.html"

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125 Safari/537.36"
    ),
    "Referer": "https://www.zhcw.com/kl8/",
}


def fetch_text(url: str, *, insecure_tls: bool = False, timeout: int = 20) -> str:
    req = Request(url, headers=HEADERS)
    context = ssl._create_unverified_context() if insecure_tls else None
    with urlopen(req, timeout=timeout, context=context) as resp:
        raw = resp.read()
        charset = resp.headers.get_content_charset() or "utf-8"
    for enc in (charset, "utf-8", "gb18030"):
        try:
            return raw.decode(enc)
        except UnicodeDecodeError:
            continue
    return raw.decode("utf-8", errors="replace")


def parse_jsonp(payload: str) -> dict:
    match = re.search(r"^[^(]+\((.*)\)\s*;?\s*$", payload, flags=re.S)
    if not match:
        raise ValueError("Response is not JSONP")
    return json.loads(match.group(1))


def normalize_numbers(value: str) -> list[int]:
    parts = re.findall(r"\d{1,2}", value or "")
    nums = [int(p) for p in parts]
    if len(nums) != 20 or len(set(nums)) != 20 or not all(1 <= n <= 80 for n in nums):
        raise ValueError(f"Invalid 快乐8 number set: {value!r}")
    return nums


def normalize_compact_numbers(value: str) -> list[int]:
    if not re.fullmatch(r"\d{40}", value or ""):
        raise ValueError(f"Invalid compact number string: {value!r}")
    nums = [int(value[i : i + 2]) for i in range(0, 40, 2)]
    if len(nums) != 20 or len(set(nums)) != 20 or not all(1 <= n <= 80 for n in nums):
        raise ValueError(f"Invalid compact 快乐8 number set: {value!r}")
    return nums


def fetch_zhcw(issue_count: int = 3000) -> list[dict]:
    params = {
        "transactionType": "10001001",
        "lotteryId": "6",
        "issueCount": str(issue_count),
        "startIssue": "",
        "endIssue": "",
        "startDate": "",
        "endDate": "",
        "type": "0",
        "pageNum": "1",
        "pageSize": str(issue_count),
        "tt": str(time.time()),
        "callback": "kl8_callback",
    }
    url = f"{ZHONGCAI_ENDPOINT}?{urlencode(params)}"
    # Some local Python trust stores do not include the certificate chain used
    # by this endpoint, while browsers/curl can still load it. The payload is
    # public draw data, so this keeps the primary source usable in minimal envs.
    payload = fetch_text(url, insecure_tls=True)
    data = parse_jsonp(payload)
    if data.get("resCode") and data.get("resCode") != "000000":
        raise RuntimeError(f"ZHCW returned {data.get('resCode')}: {data.get('message')}")

    rows = []
    for item in data.get("data", []):
        nums = normalize_numbers(item.get("frontWinningNum", ""))
        seq_nums = normalize_numbers(item.get("seqFrontWinningNum", item.get("frontWinningNum", "")))
        rows.append(
            {
                "issue": item.get("issue", ""),
                "draw_date": item.get("openTime", ""),
                "week": item.get("week", ""),
                "numbers": nums,
                "numbers_sorted": sorted(nums),
                "numbers_sequence": seq_nums,
                "sale_money": item.get("saleMoney", ""),
                "prize_pool_money": item.get("prizePoolMoney", ""),
                "fix_pool_money": item.get("fixPoolMoney", ""),
                "source": "zhcw_jsonp",
            }
        )
    return rows


def discover_gdfc_total_pages() -> int:
    html = fetch_text(GDFC_FIRST_PAGE, insecure_tls=True)
    match = re.search(r"id=['\"]label-totalpage['\"]>(\d+)<", html)
    return int(match.group(1)) if match else 1


def parse_gdfc_page(html: str) -> list[dict]:
    pattern = re.compile(
        r"<td[^>]*>\s*(20\d{5})\s*</td>\s*"
        r"<td[^>]*class=\"td-luckyno\"[^>]*luckyNo=\"(\d{40})\"",
        flags=re.S,
    )
    rows = []
    for issue, compact in pattern.findall(html):
        nums = normalize_compact_numbers(compact)
        rows.append(
            {
                "issue": issue,
                "draw_date": "",
                "week": "",
                "numbers": nums,
                "numbers_sorted": sorted(nums),
                "numbers_sequence": nums,
                "sale_money": "",
                "prize_pool_money": "",
                "fix_pool_money": "",
                "source": "gdfc_static",
            }
        )
    return rows


def fetch_gdfc() -> list[dict]:
    total_pages = discover_gdfc_total_pages()
    rows = []
    first = fetch_text(GDFC_FIRST_PAGE, insecure_tls=True)
    rows.extend(parse_gdfc_page(first))
    for page in range(2, total_pages + 1):
        html = fetch_text(GDFC_HISTORY_PAGE.format(page=page), insecure_tls=True)
        rows.extend(parse_gdfc_page(html))
        time.sleep(0.08)
    return rows


def dedupe_sort(rows: Iterable[dict]) -> list[dict]:
    by_issue = {}
    for row in rows:
        by_issue[row["issue"]] = row
    return sorted(by_issue.values(), key=lambda r: r["issue"])


def write_outputs(rows: list[dict], source_note: str) -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    draws_path = DATA_DIR / "draws.csv"
    long_path = DATA_DIR / "numbers_long.csv"
    metadata_path = DATA_DIR / "metadata.json"

    draw_fields = [
        "issue",
        "draw_date",
        "week",
        "numbers",
        "numbers_sorted",
        "numbers_sequence",
        "sale_money",
        "prize_pool_money",
        "fix_pool_money",
        "source",
    ]
    with draws_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=draw_fields)
        writer.writeheader()
        for row in rows:
            out = row.copy()
            for key in ("numbers", "numbers_sorted", "numbers_sequence"):
                out[key] = " ".join(f"{n:02d}" for n in row[key])
            writer.writerow(out)

    with long_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["issue", "draw_date", "position", "number"])
        writer.writeheader()
        for row in rows:
            for pos, num in enumerate(row["numbers_sequence"], start=1):
                writer.writerow(
                    {
                        "issue": row["issue"],
                        "draw_date": row["draw_date"],
                        "position": pos,
                        "number": num,
                    }
                )

    metadata = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "draw_count": len(rows),
        "first_issue": rows[0]["issue"] if rows else None,
        "last_issue": rows[-1]["issue"] if rows else None,
        "source_note": source_note,
        "primary_source": "https://jc.zhcw.com/port/client_json.php",
        "fallback_source": "https://www.gdfc.org.cn/play_list_game_10.html",
    }
    metadata_path.write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding="utf-8")

    print(f"Wrote {len(rows)} draws")
    print(f"- {draws_path}")
    print(f"- {long_path}")
    print(f"- {metadata_path}")


def main() -> None:
    try:
        rows = fetch_zhcw()
        source_note = "Fetched from ZHCW JSONP endpoint with draw dates and sales/prize fields."
    except (URLError, TimeoutError, ValueError, RuntimeError, json.JSONDecodeError) as exc:
        print(f"Primary ZHCW fetch failed: {exc}")
        print("Falling back to Guangdong Welfare Lottery static history pages.")
        rows = fetch_gdfc()
        source_note = "Fetched from Guangdong Welfare Lottery static history pages; date and prize fields unavailable."

    rows = dedupe_sort(rows)
    if not rows:
        raise SystemExit("No rows fetched")
    write_outputs(rows, source_note)


if __name__ == "__main__":
    main()
