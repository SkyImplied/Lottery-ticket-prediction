#!/usr/bin/env python3
"""Analyze 快乐8 historical draws and build a cautious baseline model.

This is statistical analysis, not a guarantee of future results. Lottery draws
are designed to be random; the model is intentionally evaluated against a
random baseline and should be treated as an experiment.
"""

from __future__ import annotations

import csv
import json
import math
import random
from collections import Counter, defaultdict
from datetime import datetime, timezone
from itertools import combinations
from pathlib import Path
from statistics import mean, pstdev


ROOT = Path(__file__).resolve().parents[2]
DATA_DIR = ROOT / "data" / "kl8"
OUT_DIR = ROOT / "outputs" / "kl8"
DRAW_PATH = DATA_DIR / "draws.csv"

NUMBERS = list(range(1, 81))

# Current public prize table reflected by 中彩网快乐8 page / recent draw details.
# Floating jackpot awards are listed for classification but excluded from fixed
# expected-value arithmetic unless a numeric cap is explicitly used.
PLAY_RULES = {
    1: {1: 4.5},
    2: {2: 19},
    3: {3: 52, 2: 3},
    4: {4: 93, 3: 5, 2: 3},
    5: {5: 1000, 4: 21, 3: 3},
    6: {6: 2880, 5: 30, 4: 10, 3: 3},
    7: {7: 8500, 6: 288, 5: 28, 4: 4},
    8: {8: 50000, 7: 800, 6: 88, 5: 10, 4: 3, 0: 2},
    9: {"9_float": "浮动，25万封顶", 8: 2000, 7: 225, 6: 22, 5: 5, 4: 3, 0: 2},
    10: {"10_float": "浮动，500万封顶", 9: 8000, 8: 720, 7: 80, 6: 5, 5: 3, 0: 2},
}


def parse_numbers(value: str) -> list[int]:
    nums = [int(x) for x in value.split()]
    if len(nums) != 20 or len(set(nums)) != 20:
        raise ValueError(f"Invalid draw numbers: {value!r}")
    return nums


def load_draws() -> list[dict]:
    with DRAW_PATH.open(newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    draws = []
    for row in rows:
        nums = parse_numbers(row["numbers_sorted"])
        seq = parse_numbers(row["numbers_sequence"])
        draws.append(
            {
                "issue": row["issue"],
                "draw_date": row["draw_date"],
                "week": row["week"],
                "numbers": nums,
                "number_set": set(nums),
                "sequence": seq,
                "sale_money": to_float(row.get("sale_money")),
                "prize_pool_money": to_float(row.get("prize_pool_money")),
                "fix_pool_money": to_float(row.get("fix_pool_money")),
                "source": row.get("source", ""),
            }
        )
    return sorted(draws, key=lambda d: d["issue"])


def to_float(value: str | None) -> float | None:
    if value in (None, ""):
        return None
    try:
        return float(str(value).replace(",", ""))
    except ValueError:
        return None


def comb(n: int, k: int) -> int:
    if k < 0 or k > n:
        return 0
    return math.comb(n, k)


def hit_probability(pick_count: int, hit_count: int) -> float:
    return comb(pick_count, hit_count) * comb(80 - pick_count, 20 - hit_count) / comb(80, 20)


def play_summary() -> list[dict]:
    rows = []
    for pick_count, prizes in PLAY_RULES.items():
        probs = {h: hit_probability(pick_count, h) for h in range(pick_count + 1)}
        fixed_ev = 0.0
        floating = []
        for hit, prize in prizes.items():
            if isinstance(hit, int) and isinstance(prize, (int, float)):
                fixed_ev += probs[hit] * float(prize)
            else:
                floating.append(str(prize))
        rows.append(
            {
                "play": f"选{cn_num(pick_count)}",
                "pick_count": pick_count,
                "min_hit_probability": sum(probs[h] for h in prizes if isinstance(h, int)),
                "top_hit_probability": probs[pick_count],
                "fixed_ev_yuan_per_2_yuan": fixed_ev,
                "fixed_return_rate": fixed_ev / 2.0,
                "floating_note": "；".join(floating),
            }
        )
    return rows


def cn_num(n: int) -> str:
    return "一二三四五六七八九十"[n - 1]


def zscores(values: dict[int, float]) -> dict[int, float]:
    vals = list(values.values())
    sd = pstdev(vals)
    if sd == 0:
        return {k: 0.0 for k in values}
    avg = mean(vals)
    return {k: (v - avg) / sd for k, v in values.items()}


def gap_lengths(history: list[dict]) -> dict[int, int]:
    gaps = {}
    for n in NUMBERS:
        gap = 0
        for draw in reversed(history):
            if n in draw["number_set"]:
                break
            gap += 1
        gaps[n] = gap
    return gaps


def model_scores(history: list[dict]) -> dict[int, float]:
    all_freq = Counter()
    recent_30 = Counter()
    recent_100 = Counter()
    for draw in history:
        all_freq.update(draw["number_set"])
    for draw in history[-30:]:
        recent_30.update(draw["number_set"])
    for draw in history[-100:]:
        recent_100.update(draw["number_set"])

    freq_z = zscores({n: all_freq[n] / len(history) for n in NUMBERS})
    r30_z = zscores({n: recent_30[n] / max(1, min(30, len(history))) for n in NUMBERS})
    r100_z = zscores({n: recent_100[n] / max(1, min(100, len(history))) for n in NUMBERS})
    gap_z = zscores(gap_lengths(history))

    scores = {}
    for n in NUMBERS:
        scores[n] = 0.35 * freq_z[n] + 0.25 * r100_z[n] + 0.20 * r30_z[n] + 0.20 * gap_z[n]
    return scores


def top_numbers(scores: dict[int, float], count: int) -> list[int]:
    return sorted(sorted(NUMBERS), key=lambda n: scores[n], reverse=True)[:count]


def backtest(draws: list[dict], warmup: int = 300, ticket_size: int = 10) -> dict:
    if len(draws) <= warmup + 20:
        warmup = max(30, len(draws) // 3)
    hits = []
    random_hits = []
    rng = random.Random(20260619)
    for i in range(warmup, len(draws)):
        scores = model_scores(draws[:i])
        pick = set(top_numbers(scores, ticket_size))
        actual = draws[i]["number_set"]
        hits.append(len(pick & actual))
        for _ in range(50):
            random_hits.append(len(set(rng.sample(NUMBERS, ticket_size)) & actual))

    dist = Counter(hits)
    rand_dist = Counter(random_hits)
    return {
        "warmup_draws": warmup,
        "ticket_size": ticket_size,
        "tested_draws": len(hits),
        "model_avg_hits": mean(hits) if hits else 0,
        "random_avg_hits": mean(random_hits) if random_hits else 0,
        "model_hit_distribution": dict(sorted(dist.items())),
        "random_hit_distribution": dict(sorted(rand_dist.items())),
    }


def summarize_draw_patterns(draws: list[dict]) -> dict:
    freq = Counter()
    odd_counts = []
    big_counts = []
    sums = []
    zone_counts = Counter()
    tail_counts = Counter()
    repeats = []
    pair_counts = Counter()

    prev = None
    for draw in draws:
        nums = draw["numbers"]
        freq.update(nums)
        odd_counts.append(sum(n % 2 for n in nums))
        big_counts.append(sum(n >= 41 for n in nums))
        sums.append(sum(nums))
        for n in nums:
            zone_counts[(n - 1) // 20 + 1] += 1
            tail_counts[n % 10] += 1
        if prev is not None:
            repeats.append(len(draw["number_set"] & prev["number_set"]))
        prev = draw
        pair_counts.update(tuple(sorted(pair)) for pair in combinations(nums, 2))

    expected_freq = len(draws) * 20 / 80
    chi_square = sum((freq[n] - expected_freq) ** 2 / expected_freq for n in NUMBERS)
    chi_z = (chi_square - 79) / math.sqrt(2 * 79)
    expected_pair = len(draws) * comb(20, 2) / comb(80, 2)

    return {
        "draw_count": len(draws),
        "first_issue": draws[0]["issue"],
        "last_issue": draws[-1]["issue"],
        "first_date": draws[0]["draw_date"],
        "last_date": draws[-1]["draw_date"],
        "frequency_expected": expected_freq,
        "chi_square_df79": chi_square,
        "chi_square_normal_approx_z": chi_z,
        "top_hot_numbers": [(n, freq[n], freq[n] - expected_freq) for n in sorted(NUMBERS, key=lambda x: freq[x], reverse=True)[:10]],
        "top_cold_numbers": [(n, freq[n], freq[n] - expected_freq) for n in sorted(NUMBERS, key=lambda x: freq[x])[:10]],
        "odd_avg": mean(odd_counts),
        "odd_sd": pstdev(odd_counts),
        "big_avg": mean(big_counts),
        "big_sd": pstdev(big_counts),
        "sum_avg": mean(sums),
        "sum_sd": pstdev(sums),
        "repeat_avg": mean(repeats),
        "repeat_sd": pstdev(repeats),
        "zone_counts": dict(sorted(zone_counts.items())),
        "tail_counts": dict(sorted(tail_counts.items())),
        "top_pairs": [(pair[0], pair[1], cnt, cnt - expected_pair) for pair, cnt in pair_counts.most_common(10)],
        "expected_pair_count": expected_pair,
    }


def write_csv(path: Path, rows: list[dict]) -> None:
    if not rows:
        return
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def write_markdown_report(draws: list[dict], summary: dict, play_rows: list[dict], backtests: list[dict]) -> None:
    latest_scores = model_scores(draws)
    ranked = top_numbers(latest_scores, 20)
    candidate_rows = [
        {"玩法": f"选{cn_num(k)}", "候选号码": " ".join(f"{n:02d}" for n in ranked[:k])}
        for k in range(1, 11)
    ]

    def md_table(rows: list[dict], columns: list[str]) -> str:
        lines = ["| " + " | ".join(columns) + " |", "| " + " | ".join(["---"] * len(columns)) + " |"]
        for row in rows:
            lines.append("| " + " | ".join(str(row.get(c, "")) for c in columns) + " |")
        return "\n".join(lines)

    hot_rows = [
        {"号码": f"{n:02d}", "出现次数": c, "相对期望": f"{delta:+.1f}"}
        for n, c, delta in summary["top_hot_numbers"]
    ]
    cold_rows = [
        {"号码": f"{n:02d}", "出现次数": c, "相对期望": f"{delta:+.1f}"}
        for n, c, delta in summary["top_cold_numbers"]
    ]
    pair_rows = [
        {"组合": f"{a:02d}-{b:02d}", "共现次数": c, "相对期望": f"{delta:+.1f}"}
        for a, b, c, delta in summary["top_pairs"]
    ]
    play_md_rows = [
        {
            "玩法": r["play"],
            "中奖概率": f"{100 * r['min_hit_probability']:.3f}%",
            "最高命中概率": f"{100 * r['top_hit_probability']:.6f}%",
            "固定奖期望/2元": f"{r['fixed_ev_yuan_per_2_yuan']:.3f}",
            "固定返还率": f"{100 * r['fixed_return_rate']:.1f}%",
            "浮动说明": r["floating_note"],
        }
        for r in play_rows
    ]
    bt_rows = [
        {
            "票大小": bt["ticket_size"],
            "测试期数": bt["tested_draws"],
            "模型平均命中": f"{bt['model_avg_hits']:.3f}",
            "随机平均命中": f"{bt['random_avg_hits']:.3f}",
            "模型分布": bt["model_hit_distribution"],
        }
        for bt in backtests
    ]

    content = f"""# 中国福利彩票快乐8数据分析与基线模型

生成时间：{datetime.now(timezone.utc).isoformat()}

## 结论先说

- 本数据集覆盖 {summary['first_issue']} 至 {summary['last_issue']}，共 {summary['draw_count']} 期开奖。数据来自中彩网 JSONP 接口，若接口不可用，抓取脚本会退到广东福彩静态历史页。
- 快乐8每期从 1-80 中开出 20 个号码。长期看，每个号码的理论出现率是 25%，全样本单号期望出现 {summary['frequency_expected']:.2f} 次。
- 统计上可以看到热号、冷号、连期重复、共现组合等“样本波动”，但这些不构成可稳定套利的规律。回测中的候选模型需要与随机基线比较，而不是只看下一期是否命中。
- 下面给出的候选号码是模型排序的实验输出，不是中奖保证，也不建议超预算购彩。

## 玩法分类

{md_table(play_md_rows, ['玩法', '中奖概率', '最高命中概率', '固定奖期望/2元', '固定返还率', '浮动说明'])}

说明：选九、选十包含浮动奖，表中的固定奖期望未把浮动头奖作为确定收益计入。

## 全量统计规律

- 奇数个数均值：{summary['odd_avg']:.2f}，标准差：{summary['odd_sd']:.2f}；理论中心约为 10。
- 大号（41-80）个数均值：{summary['big_avg']:.2f}，标准差：{summary['big_sd']:.2f}；理论中心约为 10。
- 单期号码和值均值：{summary['sum_avg']:.2f}，标准差：{summary['sum_sd']:.2f}；理论中心约为 810。
- 相邻两期重复号码均值：{summary['repeat_avg']:.2f}，标准差：{summary['repeat_sd']:.2f}；理论中心约为 5。
- 单号频率卡方统计量：{summary['chi_square_df79']:.2f}，df=79；正态近似 z={summary['chi_square_normal_approx_z']:.2f}。这个读数主要用于发现异常偏离，不能直接当作选号优势。

### 热号

{md_table(hot_rows, ['号码', '出现次数', '相对期望'])}

### 冷号

{md_table(cold_rows, ['号码', '出现次数', '相对期望'])}

### 高频共现二元组

{md_table(pair_rows, ['组合', '共现次数', '相对期望'])}

## 回测模型

模型分数由全量频率、近 100 期频率、近 30 期频率和当前遗漏期数组成；每期开奖前只使用此前历史。

{md_table(bt_rows, ['票大小', '测试期数', '模型平均命中', '随机平均命中', '模型分布'])}

## 下一期实验候选

候选池按模型分数排序，玩法越大风险越高，表格只是把同一排序截断成不同玩法。

{md_table(candidate_rows, ['玩法', '候选号码'])}

## 使用边界

彩票开奖结果应视为独立随机事件。历史数据能帮助校验数据质量、理解概率、避免迷信“稳赚规律”，但不能可靠预测未来开奖号。任何投注都应以娱乐预算为限。
"""
    (OUT_DIR / "analysis_report.md").write_text(content, encoding="utf-8")


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    draws = load_draws()
    summary = summarize_draw_patterns(draws)
    play_rows = play_summary()
    backtests = [backtest(draws, ticket_size=k) for k in (1, 3, 5, 10)]

    write_csv(OUT_DIR / "play_probabilities.csv", play_rows)

    freq_rows = []
    freq = Counter(n for draw in draws for n in draw["numbers"])
    gaps = gap_lengths(draws)
    scores = model_scores(draws)
    for n in NUMBERS:
        freq_rows.append(
            {
                "number": n,
                "frequency": freq[n],
                "frequency_rate": freq[n] / len(draws),
                "current_gap": gaps[n],
                "model_score": scores[n],
            }
        )
    write_csv(OUT_DIR / "number_scores.csv", sorted(freq_rows, key=lambda r: r["model_score"], reverse=True))

    summary_payload = {
        "summary": summary,
        "play_probabilities": play_rows,
        "backtests": backtests,
        "latest_ranked_numbers_top20": top_numbers(scores, 20),
        "generated_at": datetime.now(timezone.utc).isoformat(),
    }
    (OUT_DIR / "analysis_summary.json").write_text(json.dumps(summary_payload, ensure_ascii=False, indent=2), encoding="utf-8")
    write_markdown_report(draws, summary, play_rows, backtests)

    print(f"Analyzed {len(draws)} draws")
    print(f"- {OUT_DIR / 'analysis_report.md'}")
    print(f"- {OUT_DIR / 'number_scores.csv'}")
    print(f"- {OUT_DIR / 'play_probabilities.csv'}")
    print(f"- {OUT_DIR / 'analysis_summary.json'}")


if __name__ == "__main__":
    main()
