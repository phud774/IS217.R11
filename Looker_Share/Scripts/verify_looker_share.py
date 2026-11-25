"""Verify Looker CSV totals, row counts, checksums and upload sizes."""

from __future__ import annotations

import csv
import hashlib
import json
from decimal import Decimal
from pathlib import Path


DATA = Path(__file__).resolve().parents[1] / "Data"
FILES = {
    "sales_monthly_county_category.csv": "county_category_rows",
    "sales_monthly_vendor.csv": "vendor_rows",
    "sales_monthly_store.csv": "store_rows",
    "sales_quarterly_county_vendor.csv": "quarterly_county_vendor_rows",
    "sales_quarterly_county_product.csv": "quarterly_county_product_rows",
    "sales_monthly_store_category.csv": "monthly_store_category_rows",
}
METRICS = ("transaction_count", "sales_bottles", "sales_dollars", "sales_liters")
UPLOAD_LIMIT = 100_000_000


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def main() -> None:
    metadata = json.loads((DATA / "metadata.json").read_text(encoding="utf-8-sig"))
    checksums = {}
    for line in (DATA / "CHECKSUMS.sha256").read_text(encoding="utf-8-sig").splitlines():
        checksum, name = line.split(maxsplit=1)
        checksums[name] = checksum.upper()

    reference = None
    county_quarter = {}
    county_quarter_category = {}
    for name, count_key in FILES.items():
        path = DATA / name
        assert path.stat().st_size <= UPLOAD_LIMIT, f"{name}: exceeds 100 MB"
        assert checksums[name] == sha256(path), f"{name}: checksum mismatch"
        totals = {metric: Decimal(0) for metric in METRICS}
        with path.open("r", encoding="utf-8-sig", newline="") as stream:
            reader = csv.DictReader(stream)
            assert set(METRICS) <= set(reader.fieldnames or ()), f"{name}: missing metric"
            count = 0
            for row in reader:
                count += 1
                for metric in METRICS:
                    totals[metric] += Decimal(row[metric])
                if "county_name" in row:
                    key = (row["year"], row["quarter_number"], row["county_name"])
                    groups = county_quarter.setdefault(name, {})
                    groups[key] = groups.get(key, Decimal(0)) + Decimal(row["sales_dollars"])
                    if "category_name" in row:
                        category_key = (*key, row["category_name"])
                        groups = county_quarter_category.setdefault(name, {})
                        groups[category_key] = groups.get(category_key, Decimal(0)) + Decimal(row["sales_dollars"])
        assert count == metadata[count_key], f"{name}: row count mismatch"
        if reference is None:
            reference = totals
        else:
            assert totals == reference, f"{name}: metric totals differ"
        print(f"{name}: {count:,} rows, {path.stat().st_size / 1_000_000:.1f} MB, totals OK")

    assert checksums["metadata.json"] == sha256(DATA / "metadata.json")
    assert reference is not None
    assert reference["transaction_count"] == metadata["source_fact_rows"]
    base = county_quarter["sales_monthly_county_category.csv"]
    for name, groups in county_quarter.items():
        assert groups == base, f"{name}: county/quarter totals differ"
    base_category = county_quarter_category["sales_monthly_county_category.csv"]
    for name, groups in county_quarter_category.items():
        assert groups == base_category, f"{name}: county/quarter/category totals differ"
    print("All six CSV files reconcile to the same source fact count and totals.")
    print("County/quarter and county/quarter/category sales totals reconcile across data sources.")
    print("Totals:", ", ".join(f"{name}={value}" for name, value in reference.items()))


if __name__ == "__main__":
    main()
