"""Phân tích dữ liệu CSV lớn bằng Polars lazy API.

Chạy từ bất kỳ thư mục nào: python EDA/EDA.py
Mặc định đọc toàn bộ CSV trong ../data và ghi báo cáo vào thư mục EDA.
"""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

import polars as pl


HERE = Path(__file__).resolve().parent
ROOT = HERE.parent

# Mã định danh phải là chuỗi để giữ số 0 đầu và tránh thống kê số học vô nghĩa.
ID_COLUMNS = {
    "invoice_id", "store_no", "store_zip_code", "county_fips_code",
    "category_code", "vendor_number", "item_no",
}
NUMBER_COLUMNS = {
    "pack", "bottle_volume_ml", "state_bottle_cost", "state_bottle_retail",
    "sales_bottles", "sales_dollars", "sales_liters", "sales_gallons",
}
RELATIONSHIPS = (
    ("store_no", "store_name"),
    ("store_no", "store_address"),
    ("store_no", "store_city"),
    ("store_no", "store_zip_code"),
    ("store_no", "county_fips_code"),
    ("store_no", "county_name"),
    ("item_no", "im_desc"),
    ("item_no", "pack"),
    ("item_no", "bottle_volume_ml"),
    ("item_no", "category_code"),
    ("item_no", "category_name"),
    ("item_no", "vendor_number"),
    ("vendor_number", "vendor_name"),
    ("county_fips_code", "county_name"),
    ("category_code", "category_name"),
)


def relationship_value(column: str) -> pl.Expr:
    """Bỏ khoảng trắng hai đầu và xem chuỗi rỗng như giá trị thiếu."""
    value = pl.col(column).cast(pl.String).str.strip_chars()
    return pl.when(value == "").then(None).otherwise(value)


def check_relationships(
    data: pl.LazyFrame, profiles: list[dict], output: Path
) -> tuple[list[dict], int]:
    """Kiểm tra cả mã -> thuộc tính và thuộc tính -> mã trên toàn bộ CSV."""
    available = {profile["column"]: profile for profile in profiles}
    summaries: list[dict] = []
    conflicts: list[dict] = []
    checked_pairs = 0

    # Số source_value mẫu tối đa được in ra terminal khi gặp quan hệ 1 -> nhiều.
    MAX_CONFLICT_EXAMPLES = 5

    for key, attribute in RELATIONSHIPS:
        if key not in available or attribute not in available:
            continue

        checked_pairs += 1
        print(f"  Relationship: {key} <-> {attribute}", flush=True)

        date = (
            pl.col("ordered_on")
            if "ordered_on" in available
            else pl.lit(None, dtype=pl.String)
        )

        pairs = collect(
            data.select(
                relationship_value(key).alias("key_value"),
                relationship_value(attribute).alias("attribute_value"),
                date.alias("ordered_on"),
            )
            .filter(
                pl.col("key_value").is_not_null()
                & pl.col("attribute_value").is_not_null()
            )
            .group_by("key_value", "attribute_value")
            .agg(
                pl.len().alias("pair_rows"),
                pl.col("ordered_on").min().alias("first_date"),
                pl.col("ordered_on").max().alias("last_date"),
            )
        )

        for source_column, target_column, source_field, target_field in (
            (key, attribute, "key_value", "attribute_value"),
            (attribute, key, "attribute_value", "key_value"),
        ):
            by_source = (
                pairs.group_by(source_field)
                .agg(
                    pl.len().alias("distinct_targets"),
                    pl.col("pair_rows").sum().alias("rows"),
                )
            )

            multiple = (
                by_source
                .filter(pl.col("distinct_targets") > 1)
                .sort(
                    ["distinct_targets", "rows"],
                    descending=[True, True],
                )
            )

            summaries.append({
                "source_column": source_column,
                "target_column": target_column,
                "source_distinct": by_source.height,
                "source_missing_rows": available[source_column]["missing_count"],
                "target_missing_rows": available[target_column]["missing_count"],
                "sources_with_multiple_targets": multiple.height,
                "affected_rows": int(multiple["rows"].sum() or 0),
                "max_targets_per_source": int(
                    by_source["distinct_targets"].max() or 0
                ),
            })

            if multiple.height:
                detail = pairs.join(
                    multiple.select(source_field),
                    on=source_field,
                )

                # ---------------------------------------------------------
                # In một vài ví dụ quan hệ 1 source -> nhiều target
                # ---------------------------------------------------------
                print(
                    f"    [CONFLICT] {multiple.height:,} "
                    f"{source_column} có nhiều {target_column}",
                    flush=True,
                )

                example_sources = multiple.head(MAX_CONFLICT_EXAMPLES)

                for example in example_sources.iter_rows(named=True):
                    source_value = example[source_field]
                    distinct_targets = int(example["distinct_targets"])

                    targets = (
                        detail
                        .filter(pl.col(source_field) == source_value)
                        .sort("pair_rows", descending=True)
                    )

                    print(
                        f"      {source_column} = {source_value!r} "
                        f"-> {distinct_targets} giá trị:",
                        flush=True,
                    )

                    for target_row in targets.iter_rows(named=True):
                        print(
                            f"        - {target_column} = "
                            f"{target_row[target_field]!r} "
                            f"({target_row['pair_rows']:,} dòng, "
                            f"{target_row['first_date']} -> "
                            f"{target_row['last_date']})",
                            flush=True,
                        )

                if multiple.height > MAX_CONFLICT_EXAMPLES:
                    print(
                        f"      ... còn "
                        f"{multiple.height - MAX_CONFLICT_EXAMPLES:,} "
                        f"{source_column} khác",
                        flush=True,
                    )

                # ---------------------------------------------------------
                # Vẫn lưu toàn bộ conflict như code cũ
                # ---------------------------------------------------------
                for row in detail.iter_rows(named=True):
                    conflicts.append({
                        "source_column": source_column,
                        "target_column": target_column,
                        "source_value": row[source_field],
                        "target_value": row[target_field],
                        "pair_rows": row["pair_rows"],
                        "first_date": row["first_date"],
                        "last_date": row["last_date"],
                    })

    pl.DataFrame(
        summaries,
        schema={
            "source_column": pl.String,
            "target_column": pl.String,
            "source_distinct": pl.Int64,
            "source_missing_rows": pl.Int64,
            "target_missing_rows": pl.Int64,
            "sources_with_multiple_targets": pl.Int64,
            "affected_rows": pl.Int64,
            "max_targets_per_source": pl.Int64,
        },
    ).write_csv(output / "key_relationships.csv")

    pl.DataFrame(
        conflicts,
        schema={
            "source_column": pl.String,
            "target_column": pl.String,
            "source_value": pl.String,
            "target_value": pl.String,
            "pair_rows": pl.Int64,
            "first_date": pl.String,
            "last_date": pl.String,
        },
    ).sort(
        "source_column",
        "target_column",
        "source_value",
        "pair_rows",
        descending=[False, False, False, True],
    ).write_csv(
        output / "key_relationship_conflicts.csv"
    )

    return summaries, checked_pairs


def arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=ROOT / "data", help="Thư mục chứa CSV")
    parser.add_argument("--output", type=Path, default=HERE, help="Thư mục ghi báo cáo")
    parser.add_argument("--max-values", type=int, default=100,
                        help="Số giá trị phổ biến nhất xuất cho mỗi cột (mặc định: 100)")
    parser.add_argument("--all-values", action="store_true",
                        help="Xuất mọi giá trị phân biệt; file có thể rất lớn")
    args = parser.parse_args()
    if args.max_values < 1:
        parser.error("--max-values phải lớn hơn 0")
    return args


def collect(frame: pl.LazyFrame) -> pl.DataFrame:
    return frame.collect(engine="streaming")


def main() -> None:
    args = arguments()
    files = sorted(args.input.glob("*.csv"))
    if not files:
        raise SystemExit(f"Không tìm thấy file CSV trong {args.input}")
    args.output.mkdir(parents=True, exist_ok=True)

    with files[0].open("r", encoding="utf-8-sig", newline="") as source:
        columns = next(csv.reader(source))
    overrides = {name: pl.String for name in columns if name in ID_COLUMNS}
    overrides.update({name: pl.Float64 for name in columns if name in NUMBER_COLUMNS})
    if "ordered_on" in columns:
        overrides["ordered_on"] = pl.String  # ISO YYYY-MM-DD; so sánh từ điển vẫn đúng thứ tự.

    data = pl.scan_csv(
        [str(path) for path in files],
        schema_overrides=overrides,
        infer_schema_length=10_000,
        low_memory=True,
    )
    schema = data.collect_schema()
    columns = list(schema)
    total_rows = int(collect(data.select(pl.len().alias("rows")))["rows"][0])
    print(f"Analyzing {total_rows:,} rows, {len(columns)} columns, {len(files)} files")

    # Một lượt scan cho thống kê cột. N_unique là giá trị chính xác, kể cả null.
    expressions: list[pl.Expr] = []
    for i, name in enumerate(columns):
        col = pl.col(name)
        expressions += [
            col.null_count().alias(f"n_{i}"),
            col.n_unique().alias(f"u_{i}"),
        ]
        if schema[name] == pl.String:
            expressions.append(
                col.str.strip_chars().eq("").fill_null(False).sum().alias(f"b_{i}")
            )
        if schema[name].is_numeric():
            expressions += [
                col.is_nan().fill_null(False).sum().alias(f"nan_{i}"),
                col.min().alias(f"min_{i}"),
                col.max().alias(f"max_{i}"),
                col.mean().alias(f"mean_{i}"),
                col.std().alias(f"std_{i}"),
                col.eq(0).fill_null(False).sum().alias(f"zero_{i}"),
                col.lt(0).fill_null(False).sum().alias(f"negative_{i}"),
            ]
        elif name == "ordered_on":
            expressions += [col.min().alias(f"min_{i}"), col.max().alias(f"max_{i}")]
    stats = collect(data.select(expressions)).row(0, named=True)

    profiles: list[dict] = []
    numeric: list[dict] = []
    for i, name in enumerate(columns):
        nulls = int(stats[f"n_{i}"])
        blanks = int(stats.get(f"b_{i}", 0))
        nan_count = int(stats.get(f"nan_{i}", 0))
        distinct = int(stats[f"u_{i}"]) - int(nulls > 0)
        missing = nulls + blanks + nan_count
        profiles.append({
            "column": name,
            "dtype": str(schema[name]),
            "non_null_count": total_rows - nulls,
            "null_count": nulls,
            "blank_count": blanks,
            "nan_count": nan_count,
            "missing_count": missing,
            "missing_pct": round(100 * missing / total_rows, 4) if total_rows else 0,
            "distinct_non_null": distinct,
            "values_exported": "all" if args.all_values or distinct <= args.max_values else f"top_{args.max_values}",
        })
        if schema[name].is_numeric():
            numeric.append({
                "column": name,
                "min": stats[f"min_{i}"],
                "max": stats[f"max_{i}"],
                "mean": stats[f"mean_{i}"],
                "std": stats[f"std_{i}"],
                "zero_count": int(stats[f"zero_{i}"]),
                "negative_count": int(stats[f"negative_{i}"]),
            })

    pl.DataFrame(profiles).write_csv(args.output / "column_profile.csv")
    if numeric:
        pl.DataFrame(numeric).write_csv(args.output / "numeric_summary.csv")
    relationships, checked_pairs = check_relationships(data, profiles, args.output)

    # Mỗi cột được gom riêng để không giữ đồng thời 23 bảng tần suất trong RAM.
    # File riêng cho từng cột giúp xem đầy đủ tên giá trị, kể cả dấu phẩy / xuống dòng.
    values_dir = args.output / "values"
    values_dir.mkdir(exist_ok=True)
    top_examples: dict[str, list[str]] = {}
    for profile in profiles:
        name = profile["column"]
        print(f"  Values: {name} ({profile['distinct_non_null']:,} distinct)", flush=True)
        frequency = (
            data.group_by(name)
            .agg(pl.len().alias("count"))
            .filter(pl.col(name).is_not_null())
            .sort("count", descending=True)
        )
        if not args.all_values:
            frequency = frequency.limit(args.max_values)
        result = collect(frequency).with_columns(
            (pl.col("count") / total_rows * 100).round(4).alias("pct_of_rows")
        )
        result.write_csv(values_dir / f"{name}.csv")
        top_examples[name] = [
            f"{str(row[name]).replace('|', '/')} ({row['count']:,})"
            for row in result.head(3).iter_rows(named=True)
        ]

    overview = {
        "source_files": [str(path.resolve()) for path in files],
        "row_count": total_rows,
        "column_count": len(columns),
        "column_names": columns,
        "date_min": stats.get(f"min_{columns.index('ordered_on')}") if "ordered_on" in columns else None,
        "date_max": stats.get(f"max_{columns.index('ordered_on')}") if "ordered_on" in columns else None,
        "value_files": "values/<column>.csv",
        "value_limit_per_column": None if args.all_values else args.max_values,
        "relationship_pairs_checked": checked_pairs,
        "relationship_summary_file": "key_relationships.csv",
        "relationship_conflicts_file": "key_relationship_conflicts.csv",
        "notes": [
            "distinct_non_null là số giá trị khác nhau chính xác, không tính null.",
            "blank_count đếm chuỗi rỗng hoặc chỉ có khoảng trắng; nan_count đếm NaN của cột số.",
            "Các file values bỏ qua null; tỷ lệ pct_of_rows tính trên toàn bộ dòng.",
            "File values của cột nhiều giá trị chỉ chứa các giá trị xuất hiện nhiều nhất, trừ khi dùng --all-values.",
            "Kiểm tra quan hệ bỏ qua cặp có mã hoặc thuộc tính bị thiếu; số dòng thiếu được ghi riêng.",
        ],
    }
    (args.output / "overview.json").write_text(
        json.dumps(overview, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    report = [
        "# Báo cáo khám phá dữ liệu",
        "",
        f"- Nguồn: {len(files)} file CSV; {total_rows:,} dòng; {len(columns)} cột.",
        f"- Khoảng ngày: {overview['date_min']} đến {overview['date_max']}.",
        f"- Bảng tần suất: tối đa {args.max_values} giá trị phổ biến nhất mỗi cột"
        if not args.all_values else "- Bảng tần suất: toàn bộ giá trị phân biệt.",
        "- `column_profile.csv`: kiểu, số null, chuỗi trống, NaN, tỷ lệ thiếu, số giá trị phân biệt.",
        "- `numeric_summary.csv`: min, max, trung bình, độ lệch chuẩn, số 0 và số âm.",
        "- `values/<tên cột>.csv`: giá trị, số lần xuất hiện và tỷ lệ trên toàn bộ dòng.",
        "- `key_relationships.csv`: mỗi chiều mã ↔ thuộc tính, số mã có nhiều giá trị và số dòng liên quan.",
        "- `key_relationship_conflicts.csv`: từng cặp giá trị xung đột, số dòng và khoảng ngày xuất hiện.",
        "",
        "## Tổng quan từng cột",
        "",
        "| Cột | Kiểu | Thiếu | Tỷ lệ thiếu | Khác nhau | 3 giá trị phổ biến |",
        "|---|---|---:|---:|---:|---|",
    ]
    for profile in profiles:
        name = profile["column"]
        popular = "; ".join(top_examples[name]).replace("`", "'") or "—"
        report.append(
            f"| `{name}` | {profile['dtype']} | {profile['missing_count']:,} | "
            f"{profile['missing_pct']:.4f}% | {profile['distinct_non_null']:,} | {popular} |"
        )
    report.extend([
        "",
        "## Kiểm tra mã và thuộc tính",
        "",
        "Giá trị null và chuỗi trống không được tính là một tên/địa chỉ khác; số dòng thiếu vẫn được ghi trong `key_relationships.csv`.",
        "",
        "| Mã | Thuộc tính | Mã có nhiều giá trị | Dòng liên quan | Thuộc tính dùng cho nhiều mã | Dòng thiếu thuộc tính |",
        "|---|---|---:|---:|---:|---:|",
    ])
    for forward, reverse in zip(relationships[::2], relationships[1::2]):
        report.append(
            f"| `{forward['source_column']}` | `{forward['target_column']}` | "
            f"{forward['sources_with_multiple_targets']:,} | {forward['affected_rows']:,} | "
            f"{reverse['sources_with_multiple_targets']:,} | {forward['target_missing_rows']:,} |"
        )
    invoice = next((profile for profile in profiles if profile["column"] == "invoice_id"), None)
    if invoice:
        unique = invoice["missing_count"] == 0 and invoice["distinct_non_null"] == total_rows
        report.extend([
            "",
            f"- `invoice_id`: {'duy nhất trên mọi dòng' if unique else 'có giá trị thiếu hoặc trùng'} "
            f"({invoice['distinct_non_null']:,} mã trên {total_rows:,} dòng).",
        ])
    report.extend([
        "",
        "## Lưu ý đọc kết quả",
        "",
        "- Null, chuỗi trống (kể cả chỉ có khoảng trắng) và NaN được đếm riêng.",
        "- Số giá trị phân biệt được tính chính xác trên toàn bộ dữ liệu; null không được tính.",
        "- Cột có nhiều giá trị chỉ xuất các giá trị phổ biến nhất theo mặc định. Dùng `--all-values` để xuất hết.",
        "- Giá trị âm có thể là giao dịch hoàn trả hoặc điều chỉnh; cần xem nghiệp vụ trước khi loại bỏ.",
        "- Một mã có nhiều thuộc tính có thể do thay đổi theo thời gian; xem ngày trong file xung đột trước khi chuẩn hóa.",
        "- Nhiều mã dùng cùng một tên không tự động là lỗi; cần đối chiếu nghiệp vụ trước khi gộp.",
        "",
    ])
    (args.output / "report.md").write_text("\n".join(report), encoding="utf-8")
    print(f"Done. Reports: {args.output.resolve()}")


if __name__ == "__main__":
    main()
