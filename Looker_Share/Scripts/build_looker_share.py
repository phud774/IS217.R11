"""Build the six Looker Studio CSVs from the portable Iowa Liquor data."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
from pathlib import Path


SEPARATOR = "|~|"
METRICS = ("transaction_count", "sales_bottles", "sales_dollars", "sales_liters")
SCHEMAS = {
    "sales_monthly_county_category.csv": (
        "year", "month_number", "month_name", "quarter_number", "county_name", "category_name"
    ),
    "sales_monthly_vendor.csv": (
        "year", "month_number", "month_name", "quarter_number", "vendor_name"
    ),
    "sales_monthly_store.csv": (
        "year", "month_number", "month_name", "quarter_number", "store_no",
        "store_name", "store_city", "county_name"
    ),
    "sales_quarterly_county_vendor.csv": (
        "year", "quarter_number", "county_name", "vendor_key", "vendor_name"
    ),
    "sales_quarterly_county_product.csv": (
        "year", "quarter_number", "county_name", "product_key", "product_name", "category_name"
    ),
    "sales_monthly_store_category.csv": (
        "year", "month_number", "month_name", "quarter_number", "store_key",
        "store_no", "store_name", "store_city", "county_name", "category_name"
    ),
}
METADATA_KEYS = {
    "sales_monthly_county_category.csv": "county_category_rows",
    "sales_monthly_vendor.csv": "vendor_rows",
    "sales_monthly_store.csv": "store_rows",
    "sales_quarterly_county_vendor.csv": "quarterly_county_vendor_rows",
    "sales_quarterly_county_product.csv": "quarterly_county_product_rows",
    "sales_monthly_store_category.csv": "monthly_store_category_rows",
}


def read_dimension(path: Path, expected_columns: int) -> dict[str, list[str]]:
    rows = {}
    with path.open("r", encoding="utf-8-sig") as stream:
        for number, line in enumerate(stream, 1):
            parts = line.rstrip("\r\n").split(SEPARATOR)
            if len(parts) != expected_columns:
                raise ValueError(f"{path}:{number}: expected {expected_columns} columns")
            rows[parts[0]] = parts
    return rows


def fixed_integer(value: str, places: int) -> int:
    sign = -1 if value.startswith("-") else 1
    if sign == -1:
        value = value[1:]
    whole, dot, fraction = value.partition(".")
    if len(fraction) > places:
        raise ValueError(f"Too many decimal places: {value}")
    return sign * (int(whole or "0") * 10**places + int(fraction.ljust(places, "0") or "0"))


def add(table: dict, key: tuple, bottles: int, cents: int, milliliters: int) -> None:
    values = table.get(key)
    if values is None:
        table[key] = [1, bottles, cents, milliliters]
    else:
        values[0] += 1
        values[1] += bottles
        values[2] += cents
        values[3] += milliliters


def format_fixed(value: int, places: int) -> str:
    sign = "-" if value < 0 else ""
    whole, fraction = divmod(abs(value), 10**places)
    return f"{sign}{whole}.{fraction:0{places}d}"


def write_csv(path: Path, fields: tuple[str, ...], table: dict) -> None:
    with path.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.writer(stream, lineterminator="\n")
        writer.writerow((*fields, *METRICS))
        for key in sorted(table):
            count, bottles, cents, milliliters = table[key]
            writer.writerow((*key, count, bottles, format_fixed(cents, 2), format_fixed(milliliters, 3)))


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def build(source: Path, output: Path) -> None:
    dates = read_dimension(source / "DIM_DATE.dat", 7)
    stores = read_dimension(source / "DIM_STORE.dat", 5)
    products = read_dimension(source / "DIM_PRODUCT.dat", 5)
    vendors = read_dimension(source / "DIM_VENDOR.dat", 3)
    tables = {name: {} for name in SCHEMAS}

    count = 0
    with (source / "FACT_LIQUOR_SALES.dat").open("r", encoding="utf-8-sig") as stream:
        for count, line in enumerate(stream, 1):
            parts = line.rstrip("\r\n").split(SEPARATOR)
            if len(parts) != 9:
                raise ValueError(f"FACT_LIQUOR_SALES.dat:{count}: expected 9 columns")
            try:
                date = dates[parts[2]]
                store = stores[parts[3]]
                product = products[parts[4]]
                vendor = vendors[parts[5]]
            except KeyError as error:
                raise ValueError(f"FACT_LIQUOR_SALES.dat:{count}: missing dimension {error}") from error

            year, month, month_name, quarter = date[6], date[3], date[4], date[5]
            store_key, store_no, store_name, city, county = store
            product_key, _, product_name, _, category = product
            vendor_key, _, vendor_name = vendor
            category = category or "Unknown"
            vendor_name = vendor_name or "Unknown"
            bottles = int(parts[6])
            cents = fixed_integer(parts[7], 2)
            milliliters = fixed_integer(parts[8], 3)
            metrics = (bottles, cents, milliliters)
            month_prefix = (year, month, month_name, quarter)
            quarter_prefix = (year, quarter, county)

            add(tables["sales_monthly_county_category.csv"], month_prefix + (county, category), *metrics)
            add(tables["sales_monthly_vendor.csv"], month_prefix + (vendor_name,), *metrics)
            add(tables["sales_monthly_store.csv"], month_prefix + (store_no, store_name, city, county), *metrics)
            add(tables["sales_quarterly_county_vendor.csv"], quarter_prefix + (vendor_key, vendor_name), *metrics)
            add(tables["sales_quarterly_county_product.csv"], quarter_prefix + (product_key, product_name, category), *metrics)
            add(
                tables["sales_monthly_store_category.csv"],
                month_prefix + (store_key, store_no, store_name, city, county, category),
                *metrics,
            )
            if count % 500_000 == 0:
                print(f"Processed {count:,} fact rows", flush=True)

    output.mkdir(parents=True, exist_ok=True)
    for name, fields in SCHEMAS.items():
        write_csv(output / name, fields, tables[name])
        print(f"Wrote {name}: {len(tables[name]):,} rows", flush=True)

    metadata = {
        "source_fact_rows": count,
        **{METADATA_KEYS[name]: len(tables[name]) for name in SCHEMAS},
        "grain": "Monthly or quarterly aggregated data for Power BI report reconstruction",
    }
    (output / "metadata.json").write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    names = ("metadata.json", *SCHEMAS)
    (output / "CHECKSUMS.sha256").write_text(
        "".join(f"{sha256(output / name)}  {name}\n" for name in names), encoding="utf-8"
    )


def main() -> None:
    root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-data", type=Path, default=root / "SSAS_IowaLiquor_Share" / "Portable_Data")
    parser.add_argument("--output-directory", type=Path, default=root / "Looker_Share" / "Data")
    args = parser.parse_args()
    build(args.source_data, args.output_directory)


if __name__ == "__main__":
    main()
