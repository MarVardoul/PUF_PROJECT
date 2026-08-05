#!/usr/bin/env python3

import argparse
import math
import time
from collections import Counter
from pathlib import Path

import capture_signatures as cs


def print_balance_statistics(records, bit_rows, modal_signature):
    total_zeros = sum(row["zeros"] for row in bit_rows)
    total_ones = sum(row["ones"] for row in bit_rows)
    total_invalid = sum(row["invalid"] for row in bit_rows)
    total_valid = total_zeros + total_ones
    total_observations = len(records) * cs.PUF_WIDTH

    zero_rate = total_zeros / total_valid if total_valid else 0.0
    one_rate = total_ones / total_valid if total_valid else 0.0
    invalid_rate = (
        total_invalid / total_observations
        if total_observations
        else 0.0
    )

    modal_int = cs.value_to_int(modal_signature)

    if modal_int is not None:
        modal_ones = modal_int.bit_count()
        modal_zeros = cs.PUF_WIDTH - modal_ones
    else:
        modal_zeros = 0
        modal_ones = 0

    print()
    print("Zero/one balance")
    print("=" * 94)
    print(
        f"All valid bit observations: "
        f"zeros={total_zeros} ({zero_rate:.3%}), "
        f"ones={total_ones} ({one_rate:.3%})"
    )
    print(
        f"Invalid observations:       "
        f"{total_invalid}/{total_observations} "
        f"({invalid_rate:.3%})"
    )
    print(
        f"Modal signature balance:    "
        f"zeros={modal_zeros} "
        f"({modal_zeros / cs.PUF_WIDTH:.3%}), "
        f"ones={modal_ones} "
        f"({modal_ones / cs.PUF_WIDTH:.3%})"
    )


def print_bit_statistics(bit_rows, problematic_only):
    print()
    print("Per-bit statistics")
    print("=" * 94)
    print(
        "Bit  Majority   Zero    One  Invalid     P(0)     P(1)  "
        "Flip rate  Invalid rate"
    )
    print("-" * 94)

    displayed = 0

    for row in bit_rows:
        flip_rate = row["flip_rate_when_valid"]

        is_problematic = (
            row["invalid"] > 0
            or (
                isinstance(flip_rate, float)
                and not math.isnan(flip_rate)
                and flip_rate > 0
            )
        )

        if problematic_only and not is_problematic:
            continue

        valid = row["valid"]
        p_zero = row["zeros"] / valid if valid else 0.0
        p_one = row["ones"] / valid if valid else 0.0

        flip_text = (
            "n/a"
            if math.isnan(flip_rate)
            else f"{flip_rate:.3%}"
        )

        print(
            f"{row['bit_index']:3d}  "
            f"{str(row['majority']):>8}  "
            f"{row['zeros']:5d}  "
            f"{row['ones']:5d}  "
            f"{row['invalid']:7d}  "
            f"{p_zero:7.3%}  "
            f"{p_one:7.3%}  "
            f"{flip_text:>9}  "
            f"{row['invalid_rate']:11.3%}"
        )

        displayed += 1

    if displayed == 0:
        print("No problematic bits detected.")


def main():
    parser = argparse.ArgumentParser(
        description="Display partial statistics for a running PUF experiment."
    )
    parser.add_argument(
        "--interval",
        type=int,
        default=10,
        help="Refresh interval in seconds.",
    )
    parser.add_argument(
        "--problematic-only",
        action="store_true",
        help="Display only bits with invalid values or valid-value flips.",
    )
    args = parser.parse_args()

    experiment_dir = Path("experiments/latest").resolve()

    while True:
        records = []

        for csv_path in sorted(experiment_dir.glob("capture_*.csv")):
            try:
                records.append(cs.parse_capture(csv_path))
            except Exception:
                # The newest CSV may still be under construction.
                pass

        print("\033[2J\033[H", end="")
        print(f"Experiment: {experiment_dir}")
        print("=" * 94)

        if not records:
            print("No completed captures yet.")

        else:
            bit_rows = cs.calculate_bit_statistics(records)
            stats = cs.build_experiment_statistics(records, bit_rows)

            cs.print_statistics(stats, bit_rows)

            print_balance_statistics(
                records,
                bit_rows,
                stats["modal_signature"],
            )

            print_bit_statistics(
                bit_rows,
                args.problematic_only,
            )

            masks = Counter(
                record["valid_mask"]
                for record in records
            )

            print()
            print("Most frequent valid masks")
            print("=" * 94)

            for mask, count in masks.most_common(10):
                invalid_bits = (
                    cs.PUF_WIDTH
                    - cs.valid_bit_count(mask)
                )

                print(
                    f"{count:6d} × {mask}  "
                    f"invalid bits={invalid_bits}"
                )

        print()
        print(
            f"Refreshing every {args.interval} seconds. "
            "Press Ctrl+C to stop."
        )

        try:
            time.sleep(args.interval)
        except KeyboardInterrupt:
            print()
            break


if __name__ == "__main__":
    main()
