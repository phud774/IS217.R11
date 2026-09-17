"""Làm sạch CSV cho 15 truy vấn và sơ đồ sao.

Chạy: python clean_data.py
Mặc định đọc data/*.csv và ghi file cùng tên vào cleaned_data/.
Dữ liệu gốc không bị sửa. Có thể đổi thư mục bằng --input và --output.
Giữ mọi giao dịch; giá trị thiếu trong các cột được giữ lại được ghi thành ô trống.
Khi nạp vào Data Warehouse, cần chuyển ô trống thành SQL NULL.
"""

from __future__ import annotations

import argparse
import csv
import os
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent

# Giữ các khóa nối của sơ đồ sao: ordered_on, store_no, item_no,
# vendor_number; invoice_id định danh từng dòng của bảng fact.
KEEP_COLUMNS = (
    "invoice_id",
    "ordered_on",
    "store_no",
    "store_name",
    "store_city",
    "county_name",
    "category_name",
    "vendor_number",
    "vendor_name",
    "item_no",
    "im_desc",
    "bottle_volume_ml",
    "sales_bottles",
    "sales_dollars",
    "sales_liters",
)

DROP_COLUMNS = {
    "store_address",
    "store_zip_code",
    "county_fips_code",
    "category_code",
    "pack",
    "state_bottle_cost",
    "state_bottle_retail",
    "sales_gallons",
}

EXPECTED_COLUMNS = set(KEEP_COLUMNS) | DROP_COLUMNS
NULL_TEXT = {"null", "none", "nan", "n/a"}


def clean_value(value: str) -> str:
    value = value.strip()
    return "" if value.casefold() in NULL_TEXT else value


def read_header(reader: csv.reader, source: Path) -> list[str]:
    header = next(reader, None)
    if header is None or len(header) != len(EXPECTED_COLUMNS) or set(header) != EXPECTED_COLUMNS:
        raise ValueError(f"Schema không đúng 23 cột dự kiến: {source}")
    return header


def clean_file(source: Path, output_dir: Path) -> tuple[int, int]:
    output_path = output_dir / source.name
    temp_path: Path | None = None
    read_count = missing_rows = 0

    try:
        with source.open("r", encoding="utf-8-sig", newline="") as input_file:
            reader = csv.reader(input_file)
            header = read_header(reader, source)
            indices = [header.index(column) for column in KEEP_COLUMNS]

            with tempfile.NamedTemporaryFile(
                mode="w", encoding="utf-8", newline="", dir=output_dir,
                prefix=f".{source.stem}.", suffix=".tmp", delete=False,
            ) as output_file:
                temp_path = Path(output_file.name)
                writer = csv.writer(output_file)
                writer.writerow(KEEP_COLUMNS)

                for row in reader:
                    read_count += 1
                    if len(row) != len(header):
                        raise ValueError(
                            f"Dòng CSV sai số cột tại {source}:{reader.line_num}"
                        )
                    selected = [clean_value(row[index]) for index in indices]
                    missing_rows += any(not value for value in selected)
                    writer.writerow(selected)

        os.replace(temp_path, output_path)
    except Exception:
        if temp_path is not None:
            temp_path.unlink(missing_ok=True)
        raise

    return read_count, missing_rows


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=ROOT / "data")
    parser.add_argument("--output", type=Path, default=ROOT / "cleaned_data")
    args = parser.parse_args()

    input_dir = args.input.resolve()
    output_dir = args.output.resolve()
    if input_dir == output_dir:
        parser.error("--input và --output phải là hai thư mục khác nhau")

    files = sorted(input_dir.glob("*.csv"))
    if not files:
        parser.error(f"Không tìm thấy CSV trong {input_dir}")
    output_dir.mkdir(parents=True, exist_ok=True)

    total_rows = total_missing = 0
    for source in files:
        rows, missing_rows = clean_file(source, output_dir)
        total_rows += rows
        total_missing += missing_rows
        print(
            f"{source.name}: kept {rows:,} rows; "
            f"rows with empty cells {missing_rows:,}"
        )

    print(
        f"Total: kept {total_rows:,} rows; "
        f"rows with empty cells {total_missing:,}"
    )
    print(f"Wrote {len(files)} files to {output_dir}")


if __name__ == "__main__":
    main()
