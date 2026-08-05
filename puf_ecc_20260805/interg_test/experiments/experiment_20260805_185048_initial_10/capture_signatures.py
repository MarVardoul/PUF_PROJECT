#!/usr/bin/env python3

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import os
import platform
import re
import shutil
import signal
import statistics
import subprocess
import sys
import time
from collections import Counter
from datetime import datetime
from pathlib import Path
from typing import Any


DEFAULT_PROJECT = Path("/home/marvardoul/puf_integrataion")
DEFAULT_VIVADO = Path(
    "/home/marvardoul/Desktop/Vivado/2022.2/bin/vivado"
)

PUF_WIDTH = 120
EXPECTED_VALID_MASK = "F" * (PUF_WIDTH // 4)

XILINX_PROCESSES = (
    "vivado",
    "vivado_lab",
    "hw_server",
    "cs_server",
    "xsdb",
)

ACTIVE_VIVADO_PROCESS: subprocess.Popen[str] | None = None


def kill_stale_xilinx_processes() -> None:
    """Kill Xilinx processes owned by the current user."""

    uid = str(os.getuid())

    print("Cleaning stale Xilinx hardware-server processes...")

    for process_name in XILINX_PROCESSES:
        subprocess.run(
            [
                "pkill",
                "-9",
                "-u",
                uid,
                "-x",
                process_name,
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )

    time.sleep(2)

    remaining: list[str] = []

    for process_name in XILINX_PROCESSES:
        result = subprocess.run(
            [
                "pgrep",
                "-a",
                "-u",
                uid,
                "-x",
                process_name,
            ],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            check=False,
        )

        if result.stdout.strip():
            remaining.extend(result.stdout.strip().splitlines())

    if remaining:
        print("Warning: some Xilinx processes remain:")
        for line in remaining:
            print(f"  {line}")
    else:
        print("Xilinx process cleanup complete.")


def handle_signal(signum: int, _frame: Any) -> None:
    global ACTIVE_VIVADO_PROCESS

    print(f"\nReceived signal {signum}; cleaning up...")

    if (
        ACTIVE_VIVADO_PROCESS is not None
        and ACTIVE_VIVADO_PROCESS.poll() is None
    ):
        try:
            ACTIVE_VIVADO_PROCESS.kill()
        except ProcessLookupError:
            pass

    kill_stale_xilinx_processes()
    raise SystemExit(128 + signum)


def newest_file(root: Path, suffix: str) -> Path:
    candidates = [
        path
        for path in root.rglob(f"*{suffix}")
        if path.is_file()
    ]

    if not candidates:
        raise FileNotFoundError(
            f"No {suffix} file was found under {root}"
        )

    return max(candidates, key=lambda path: path.stat().st_mtime)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()

    with path.open("rb") as file_handle:
        while True:
            block = file_handle.read(1024 * 1024)

            if not block:
                break

            digest.update(block)

    return digest.hexdigest()


def sanitize_label(label: str) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9_.-]+", "_", label.strip())
    return cleaned.strip("_")


def create_experiment_directory(
    experiments_root: Path,
    label: str,
) -> Path:
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    clean_label = sanitize_label(label)

    directory_name = f"experiment_{timestamp}"

    if clean_label:
        directory_name += f"_{clean_label}"

    experiment_dir = experiments_root / directory_name
    suffix = 1

    while experiment_dir.exists():
        experiment_dir = experiments_root / (
            f"{directory_name}_{suffix:02d}"
        )
        suffix += 1

    experiment_dir.mkdir(parents=True, exist_ok=False)
    return experiment_dir.resolve()


def update_latest_symlink(
    experiments_root: Path,
    experiment_dir: Path,
) -> None:
    latest_link = experiments_root / "latest"

    try:
        if latest_link.is_symlink() or latest_link.exists():
            if latest_link.is_dir() and not latest_link.is_symlink():
                return

            latest_link.unlink()

        latest_link.symlink_to(
            experiment_dir.name,
            target_is_directory=True,
        )
    except OSError as error:
        print(f"Warning: could not update latest symlink: {error}")


def normalize_logic_value(value: str, width: int) -> str:
    value = value.strip().replace("_", "").replace(" ", "")

    match = re.fullmatch(
        r"(?:\d+)'([hHbB])([0-9a-fA-FxXzZ]+)",
        value,
    )

    if match:
        radix = match.group(1).lower()
        digits = match.group(2)

        if "x" in digits.lower() or "z" in digits.lower():
            return digits.upper()

        base = 16 if radix == "h" else 2
        number = int(digits, base)

        return f"{number:0{(width + 3) // 4}X}"

    if value.lower().startswith("0x"):
        value = value[2:]

    if "x" in value.lower() or "z" in value.lower():
        return value.upper()

    if re.fullmatch(r"[01]+", value) and len(value) > width // 4:
        return f"{int(value, 2):0{(width + 3) // 4}X}"

    if re.fullmatch(r"[0-9a-fA-F]+", value):
        return f"{int(value, 16):0{(width + 3) // 4}X}"

    return value.upper()


def find_column(header: list[str], text: str) -> int | None:
    text = text.lower()

    for index, cell in enumerate(header):
        if text in cell.lower():
            return index

    return None


def parse_capture(csv_path: Path) -> dict[str, str]:
    with csv_path.open(
        "r",
        encoding="utf-8-sig",
        newline="",
        errors="replace",
    ) as file_handle:
        rows = list(csv.reader(file_handle))

    header_index: int | None = None

    for index, row in enumerate(rows):
        if any(
            "signature_internal" in cell.lower()
            for cell in row
        ):
            header_index = index
            break

    if header_index is None:
        raise ValueError(
            f"signature_internal was not found in {csv_path.name}"
        )

    header = rows[header_index]

    signature_index = find_column(
        header,
        "signature_internal",
    )
    valid_index = find_column(
        header,
        "signature_valid_mask",
    )

    if signature_index is None:
        raise ValueError(
            f"Signature column was not found in {csv_path.name}"
        )

    selected_row: list[str] | None = None

    for row in rows[header_index + 1 :]:
        if len(row) <= signature_index:
            continue

        if row[signature_index].strip():
            selected_row = row

    if selected_row is None:
        raise ValueError(
            f"No captured data was found in {csv_path.name}"
        )

    signature = normalize_logic_value(
        selected_row[signature_index],
        PUF_WIDTH,
    )

    valid_mask = ""

    if (
        valid_index is not None
        and len(selected_row) > valid_index
    ):
        valid_mask = normalize_logic_value(
            selected_row[valid_index],
            PUF_WIDTH,
        )

    return {
        "file": csv_path.name,
        "signature": signature,
        "valid_mask": valid_mask,
    }


def value_to_int(value: str) -> int | None:
    try:
        return int(value, 16)
    except (TypeError, ValueError):
        return None


def hamming_distance(first: str, second: str) -> int | None:
    first_int = value_to_int(first)
    second_int = value_to_int(second)

    if first_int is None or second_int is None:
        return None

    return (first_int ^ second_int).bit_count()


def masked_hamming_distance(
    signature: str,
    reference: str,
    valid_mask: str,
) -> int | None:
    signature_int = value_to_int(signature)
    reference_int = value_to_int(reference)
    mask_int = value_to_int(valid_mask)

    if None in (signature_int, reference_int, mask_int):
        return None

    assert signature_int is not None
    assert reference_int is not None
    assert mask_int is not None

    return ((signature_int ^ reference_int) & mask_int).bit_count()


def valid_bit_count(valid_mask: str) -> int:
    mask_int = value_to_int(valid_mask)

    if mask_int is None:
        return 0

    return mask_int.bit_count()


def run_vivado(
    vivado: Path,
    tcl_script: Path,
    count: int,
    output_dir: Path,
    ltx_file: Path,
    bit_file: Path,
    program: bool,
) -> None:
    global ACTIVE_VIVADO_PROCESS

    command = [
        str(vivado),
        "-mode",
        "batch",
        "-nolog",
        "-nojournal",
        "-notrace",
        "-source",
        str(tcl_script),
        "-tclargs",
        str(count),
        str(output_dir),
        str(ltx_file),
        str(bit_file),
        "1" if program else "0",
    ]

    log_path = output_dir / "vivado_capture.log"

    print()
    print("Running Vivado:")
    print(" ".join(command))
    print()

    with log_path.open("w", encoding="utf-8") as log_file:
        ACTIVE_VIVADO_PROCESS = subprocess.Popen(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
        )

        try:
            assert ACTIVE_VIVADO_PROCESS.stdout is not None

            for line in ACTIVE_VIVADO_PROCESS.stdout:
                print(line, end="")
                log_file.write(line)
                log_file.flush()

            return_code = ACTIVE_VIVADO_PROCESS.wait()

        except KeyboardInterrupt:
            print("\nCapture interrupted by user.")

            if ACTIVE_VIVADO_PROCESS.poll() is None:
                ACTIVE_VIVADO_PROCESS.kill()
                ACTIVE_VIVADO_PROCESS.wait()

            raise

        finally:
            ACTIVE_VIVADO_PROCESS = None

    if return_code != 0:
        raise RuntimeError(
            f"Vivado failed with exit code {return_code}. "
            f"See {log_path}"
        )


def calculate_bit_statistics(
    records: list[dict[str, str]],
) -> list[dict[str, Any]]:
    total = len(records)
    rows: list[dict[str, Any]] = []

    for bit_index in range(PUF_WIDTH):
        zeros = 0
        ones = 0
        invalid = 0

        for record in records:
            signature_int = value_to_int(record["signature"])
            mask_int = value_to_int(record["valid_mask"])

            if signature_int is None or mask_int is None:
                invalid += 1
                continue

            if ((mask_int >> bit_index) & 1) == 0:
                invalid += 1
                continue

            bit_value = (signature_int >> bit_index) & 1

            if bit_value == 0:
                zeros += 1
            else:
                ones += 1

        valid = zeros + ones

        if valid == 0:
            majority: str | int = "UNDEFINED"
            minority = 0
        elif zeros == ones:
            majority = "TIE"
            minority = zeros
        elif zeros > ones:
            majority = 0
            minority = ones
        else:
            majority = 1
            minority = zeros

        flip_rate = minority / valid if valid else math.nan
        invalid_rate = invalid / total if total else math.nan

        rows.append(
            {
                "bit_index": bit_index,
                "zeros": zeros,
                "ones": ones,
                "valid": valid,
                "invalid": invalid,
                "majority": majority,
                "flip_rate_when_valid": flip_rate,
                "invalid_rate": invalid_rate,
                "always_valid": invalid == 0,
                "stable_when_valid": minority == 0 and valid > 0,
                "stable_and_always_valid":
                    invalid == 0 and minority == 0 and valid > 0,
            }
        )

    return rows


def write_bit_statistics(
    path: Path,
    rows: list[dict[str, Any]],
) -> None:
    fieldnames = [
        "bit_index",
        "zeros",
        "ones",
        "valid",
        "invalid",
        "majority",
        "flip_rate_when_valid",
        "invalid_rate",
        "always_valid",
        "stable_when_valid",
        "stable_and_always_valid",
    ]

    with path.open(
        "w",
        encoding="utf-8",
        newline="",
    ) as file_handle:
        writer = csv.DictWriter(
            file_handle,
            fieldnames=fieldnames,
        )

        writer.writeheader()
        writer.writerows(rows)


def write_capture_summary(
    path: Path,
    records: list[dict[str, str]],
    reference: str,
    modal_signature: str,
) -> None:
    fieldnames = [
        "capture",
        "source_file",
        "signature",
        "valid_mask",
        "valid_mask_all_ones",
        "valid_bit_count",
        "invalid_bit_count",
        "hamming_distance_from_first",
        "hamming_distance_from_mode",
        "valid_bit_hamming_distance_from_mode",
    ]

    with path.open(
        "w",
        encoding="utf-8",
        newline="",
    ) as file_handle:
        writer = csv.DictWriter(
            file_handle,
            fieldnames=fieldnames,
        )

        writer.writeheader()

        for index, record in enumerate(records, start=1):
            number_valid = valid_bit_count(record["valid_mask"])

            writer.writerow(
                {
                    "capture": index,
                    "source_file": record["file"],
                    "signature": record["signature"],
                    "valid_mask": record["valid_mask"],
                    "valid_mask_all_ones":
                        record["valid_mask"]
                        == EXPECTED_VALID_MASK,
                    "valid_bit_count": number_valid,
                    "invalid_bit_count":
                        PUF_WIDTH - number_valid,
                    "hamming_distance_from_first":
                        hamming_distance(
                            reference,
                            record["signature"],
                        ),
                    "hamming_distance_from_mode":
                        hamming_distance(
                            modal_signature,
                            record["signature"],
                        ),
                    "valid_bit_hamming_distance_from_mode":
                        masked_hamming_distance(
                            record["signature"],
                            modal_signature,
                            record["valid_mask"],
                        ),
                }
            )


def build_experiment_statistics(
    records: list[dict[str, str]],
    bit_rows: list[dict[str, Any]],
) -> dict[str, Any]:
    signature_counts = Counter(
        record["signature"]
        for record in records
    )

    modal_signature, modal_occurrences = (
        signature_counts.most_common(1)[0]
    )

    all_valid_captures = sum(
        record["valid_mask"] == EXPECTED_VALID_MASK
        for record in records
    )

    hamming_from_mode = [
        distance
        for record in records
        if (
            distance := hamming_distance(
                modal_signature,
                record["signature"],
            )
        ) is not None
    ]

    masked_hamming_from_mode = [
        distance
        for record in records
        if (
            distance := masked_hamming_distance(
                record["signature"],
                modal_signature,
                record["valid_mask"],
            )
        ) is not None
    ]

    stable_always_valid_bits = [
        row["bit_index"]
        for row in bit_rows
        if row["stable_and_always_valid"]
    ]

    bits_with_invalids = [
        row["bit_index"]
        for row in bit_rows
        if row["invalid"] > 0
    ]

    unstable_bits = [
        row["bit_index"]
        for row in bit_rows
        if (
            isinstance(row["flip_rate_when_valid"], float)
            and not math.isnan(row["flip_rate_when_valid"])
            and row["flip_rate_when_valid"] > 0
        )
    ]

    mean_hd = (
        statistics.mean(hamming_from_mode)
        if hamming_from_mode
        else None
    )

    return {
        "capture_count": len(records),
        "all_valid_capture_count": all_valid_captures,
        "all_valid_capture_rate":
            all_valid_captures / len(records),
        "unique_signature_count": len(signature_counts),
        "modal_signature": modal_signature,
        "modal_signature_occurrences": modal_occurrences,
        "modal_signature_rate":
            modal_occurrences / len(records),
        "hamming_distance_from_mode": {
            "minimum": min(hamming_from_mode)
            if hamming_from_mode else None,
            "maximum": max(hamming_from_mode)
            if hamming_from_mode else None,
            "mean": mean_hd,
        },
        "valid_bit_hamming_distance_from_mode": {
            "minimum": min(masked_hamming_from_mode)
            if masked_hamming_from_mode else None,
            "maximum": max(masked_hamming_from_mode)
            if masked_hamming_from_mode else None,
            "mean": statistics.mean(masked_hamming_from_mode)
            if masked_hamming_from_mode else None,
        },
        "stable_and_always_valid_bit_count":
            len(stable_always_valid_bits),
        "stable_and_always_valid_bits":
            stable_always_valid_bits,
        "bits_with_invalid_results":
            bits_with_invalids,
        "bits_with_valid_value_flips":
            unstable_bits,
        "signature_occurrences": dict(
            signature_counts.most_common()
        ),
    }


def print_statistics(
    statistics_data: dict[str, Any],
    bit_rows: list[dict[str, Any]],
) -> None:
    print()
    print("Experiment statistics")
    print("=" * 78)
    print(
        f"Captures:                 "
        f"{statistics_data['capture_count']}"
    )
    print(
        f"All-valid captures:       "
        f"{statistics_data['all_valid_capture_count']} "
        f"({statistics_data['all_valid_capture_rate']:.2%})"
    )
    print(
        f"Unique signatures:        "
        f"{statistics_data['unique_signature_count']}"
    )
    print(
        f"Modal signature:          "
        f"{statistics_data['modal_signature']}"
    )
    print(
        f"Modal occurrences:        "
        f"{statistics_data['modal_signature_occurrences']} "
        f"({statistics_data['modal_signature_rate']:.2%})"
    )

    hd_stats = statistics_data["hamming_distance_from_mode"]

    print(
        f"HD from mode min/mean/max:"
        f" {hd_stats['minimum']} / "
        f"{hd_stats['mean']:.3f} / "
        f"{hd_stats['maximum']}"
    )

    print(
        f"Stable, always-valid bits:"
        f" {statistics_data['stable_and_always_valid_bit_count']}"
        f"/{PUF_WIDTH}"
    )
    print(
        f"Bits with invalid results:"
        f" {statistics_data['bits_with_invalid_results']}"
    )
    print(
        f"Bits with valid flips:    "
        f"{statistics_data['bits_with_valid_value_flips']}"
    )

    worst_bits = sorted(
        bit_rows,
        key=lambda row: (
            row["invalid_rate"],
            0.0
            if math.isnan(row["flip_rate_when_valid"])
            else row["flip_rate_when_valid"],
        ),
        reverse=True,
    )[:10]

    print()
    print("Ten worst bits")
    print(
        "bit  majority  zero  one  invalid  "
        "flip_valid  invalid_rate"
    )

    for row in worst_bits:
        flip_rate = row["flip_rate_when_valid"]

        flip_text = (
            "n/a"
            if math.isnan(flip_rate)
            else f"{flip_rate:.3%}"
        )

        print(
            f"{row['bit_index']:3d}  "
            f"{str(row['majority']):>8}  "
            f"{row['zeros']:4d}  "
            f"{row['ones']:3d}  "
            f"{row['invalid']:7d}  "
            f"{flip_text:>10}  "
            f"{row['invalid_rate']:.3%}"
        )


def write_text_summary(
    path: Path,
    statistics_data: dict[str, Any],
) -> None:
    hd_stats = statistics_data["hamming_distance_from_mode"]

    lines = [
        f"Capture count: "
        f"{statistics_data['capture_count']}",
        f"All-valid captures: "
        f"{statistics_data['all_valid_capture_count']} "
        f"({statistics_data['all_valid_capture_rate']:.6%})",
        f"Unique signatures: "
        f"{statistics_data['unique_signature_count']}",
        f"Modal signature: "
        f"{statistics_data['modal_signature']}",
        f"Modal occurrences: "
        f"{statistics_data['modal_signature_occurrences']} "
        f"({statistics_data['modal_signature_rate']:.6%})",
        f"Hamming distance from mode, minimum: "
        f"{hd_stats['minimum']}",
        f"Hamming distance from mode, mean: "
        f"{hd_stats['mean']}",
        f"Hamming distance from mode, maximum: "
        f"{hd_stats['maximum']}",
        f"Stable and always-valid bits: "
        f"{statistics_data['stable_and_always_valid_bit_count']}",
        f"Bits with invalid results: "
        f"{statistics_data['bits_with_invalid_results']}",
        f"Bits with valid flips: "
        f"{statistics_data['bits_with_valid_value_flips']}",
    ]

    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Capture versioned PUF experiments and calculate "
            "capture-level and per-bit statistics."
        )
    )

    parser.add_argument(
        "--count",
        type=int,
        default=10,
        help="Number of signatures to capture.",
    )
    parser.add_argument(
        "--project",
        type=Path,
        default=DEFAULT_PROJECT,
        help="Vivado project directory.",
    )
    parser.add_argument(
        "--vivado",
        type=Path,
        default=DEFAULT_VIVADO,
        help="Path to the Vivado executable.",
    )
    parser.add_argument(
        "--experiments-root",
        type=Path,
        default=Path("experiments"),
        help="Root directory for timestamped experiments.",
    )
    parser.add_argument(
        "--label",
        default="",
        help="Optional experiment label.",
    )
    parser.add_argument(
        "--program",
        action="store_true",
        help="Program the FPGA before capturing.",
    )

    args = parser.parse_args()

    if args.count < 1:
        print("--count must be at least 1.", file=sys.stderr)
        return 1

    script_dir = Path(__file__).resolve().parent
    tcl_script = script_dir / "capture_signatures.tcl"

    experiments_root = args.experiments_root.resolve()
    experiments_root.mkdir(parents=True, exist_ok=True)

    experiment_dir = create_experiment_directory(
        experiments_root,
        args.label,
    )

    update_latest_symlink(
        experiments_root,
        experiment_dir,
    )

    print(f"Experiment directory: {experiment_dir}")

    try:
        kill_stale_xilinx_processes()

        if not args.project.is_dir():
            raise FileNotFoundError(
                f"Project directory not found: {args.project}"
            )

        if not args.vivado.is_file():
            raise FileNotFoundError(
                f"Vivado executable not found: {args.vivado}"
            )

        if not tcl_script.is_file():
            raise FileNotFoundError(
                f"Tcl script not found: {tcl_script}"
            )

        bit_file = newest_file(args.project, ".bit")
        ltx_file = newest_file(args.project, ".ltx")

        metadata: dict[str, Any] = {
            "experiment_started":
                datetime.now().astimezone().isoformat(),
            "experiment_directory": str(experiment_dir),
            "label": args.label,
            "capture_count_requested": args.count,
            "program_fpga": args.program,
            "project_directory": str(args.project.resolve()),
            "vivado_executable": str(args.vivado.resolve()),
            "bit_file": str(bit_file),
            "bit_file_sha256": sha256_file(bit_file),
            "ltx_file": str(ltx_file),
            "ltx_file_sha256": sha256_file(ltx_file),
            "hostname": platform.node(),
            "platform": platform.platform(),
            "python_version": platform.python_version(),
            "puf_width": PUF_WIDTH,
        }

        metadata_path = experiment_dir / "experiment_metadata.json"

        metadata_path.write_text(
            json.dumps(metadata, indent=2) + "\n",
            encoding="utf-8",
        )

        shutil.copy2(
            Path(__file__).resolve(),
            experiment_dir / "capture_signatures.py",
        )
        shutil.copy2(
            tcl_script,
            experiment_dir / "capture_signatures.tcl",
        )

        print(f"Project:    {args.project.resolve()}")
        print(f"Bitstream:  {bit_file}")
        print(f"Probe file: {ltx_file}")
        print(f"Captures:   {args.count}")

        run_vivado(
            vivado=args.vivado,
            tcl_script=tcl_script,
            count=args.count,
            output_dir=experiment_dir,
            ltx_file=ltx_file,
            bit_file=bit_file,
            program=args.program,
        )

        records: list[dict[str, str]] = []

        for csv_path in sorted(
            experiment_dir.glob("capture_*.csv")
        ):
            try:
                records.append(parse_capture(csv_path))
            except ValueError as error:
                print(f"Warning: {error}", file=sys.stderr)

        if not records:
            raise RuntimeError(
                "No signatures could be parsed."
            )

        signature_counts = Counter(
            record["signature"]
            for record in records
        )

        modal_signature = signature_counts.most_common(1)[0][0]
        reference_signature = records[0]["signature"]

        capture_summary_path = (
            experiment_dir / "signature_summary.csv"
        )

        write_capture_summary(
            capture_summary_path,
            records,
            reference_signature,
            modal_signature,
        )

        bit_rows = calculate_bit_statistics(records)

        bit_statistics_path = (
            experiment_dir / "per_bit_statistics.csv"
        )

        write_bit_statistics(
            bit_statistics_path,
            bit_rows,
        )

        statistics_data = build_experiment_statistics(
            records,
            bit_rows,
        )

        statistics_path = (
            experiment_dir / "experiment_statistics.json"
        )

        statistics_path.write_text(
            json.dumps(
                statistics_data,
                indent=2,
                allow_nan=False,
            )
            + "\n",
            encoding="utf-8",
        )

        text_summary_path = (
            experiment_dir / "experiment_summary.txt"
        )

        write_text_summary(
            text_summary_path,
            statistics_data,
        )

        metadata["experiment_finished"] = (
            datetime.now().astimezone().isoformat()
        )
        metadata["capture_count_completed"] = len(records)
        metadata["status"] = "completed"

        metadata_path.write_text(
            json.dumps(metadata, indent=2) + "\n",
            encoding="utf-8",
        )

        print_statistics(
            statistics_data,
            bit_rows,
        )

        print()
        print("Saved files")
        print("=" * 78)
        print(f"Experiment:     {experiment_dir}")
        print(f"Capture summary:{capture_summary_path}")
        print(f"Per-bit stats:  {bit_statistics_path}")
        print(f"JSON stats:     {statistics_path}")
        print(f"Text summary:   {text_summary_path}")
        print(f"Metadata:       {metadata_path}")

        return 0

    except KeyboardInterrupt:
        print("Experiment interrupted.", file=sys.stderr)
        return 130

    except Exception as error:
        print(f"ERROR: {error}", file=sys.stderr)

        failure_path = experiment_dir / "experiment_failed.txt"
        failure_path.write_text(
            f"{datetime.now().astimezone().isoformat()}\n"
            f"{type(error).__name__}: {error}\n",
            encoding="utf-8",
        )

        return 1

    finally:
        kill_stale_xilinx_processes()


if __name__ == "__main__":
    signal.signal(signal.SIGINT, handle_signal)
    signal.signal(signal.SIGTERM, handle_signal)

    raise SystemExit(main())
