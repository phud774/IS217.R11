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
        "notes": [
            "distinct_non_null là số giá trị khác nhau chính xác, không tính null.",
            "blank_count đếm chuỗi rỗng hoặc chỉ có khoảng trắng; nan_count đếm NaN của cột số.",
            "Các file values bỏ qua null; tỷ lệ pct_of_rows tính trên toàn bộ dòng.",
            "File values của cột nhiều giá trị chỉ chứa các giá trị xuất hiện nhiều nhất, trừ khi dùng --all-values.",
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
        "## Lưu ý đọc kết quả",
        "",
        "- Null, chuỗi trống (kể cả chỉ có khoảng trắng) và NaN được đếm riêng.",
        "- Số giá trị phân biệt được tính chính xác trên toàn bộ dữ liệu; null không được tính.",
        "- Cột có nhiều giá trị chỉ xuất các giá trị phổ biến nhất theo mặc định. Dùng `--all-values` để xuất hết.",
        "- Giá trị âm có thể là giao dịch hoàn trả hoặc điều chỉnh; cần xem nghiệp vụ trước khi loại bỏ.",
        "",
    ])
    (args.output / "report.md").write_text("\n".join(report), encoding="utf-8")
    print(f"Done. Reports: {args.output.resolve()}")


if __name__ == "__main__":
    main()
