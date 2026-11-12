# Gợi ý dashboard Iowa Liquor

## Trang 1 - Tổng quan

Nguồn: `sales_monthly_county_category.csv`

- Scorecard: `SUM(sales_dollars)` - Tổng doanh thu.
- Scorecard: `SUM(sales_bottles)` - Tổng số chai.
- Scorecard: `SUM(sales_liters)` - Tổng số lít.
- Time series: Dimension `month_number`, Metric `SUM(sales_dollars)`.
- Bar chart: Dimension `county_name`, Metric `SUM(sales_dollars)`, sắp xếp giảm dần.
- Treemap: Dimension `category_name`, Metric `SUM(sales_dollars)`.
- Bộ lọc: `month_name`, `county_name`, `category_name`.

## Trang 2 - Cửa hàng

Nguồn: `sales_monthly_store.csv`

- Table: `store_no`, `store_name`, `store_city`, `county_name`.
- Metrics: `SUM(sales_dollars)`, `SUM(sales_bottles)`, `SUM(transaction_count)`.
- Sắp xếp `SUM(sales_dollars)` giảm dần.
- Bộ lọc: `month_name`, `county_name`, `store_city`.

## Trang 3 - Nhà cung cấp

Nguồn: `sales_monthly_vendor.csv`

- Bar chart: `vendor_name` theo `SUM(sales_dollars)`.
- Table: `vendor_name`, `SUM(sales_bottles)`, `SUM(sales_liters)`, `SUM(sales_dollars)`.
- Bộ lọc: `month_name`, `quarter_number`.

## Kiểu dữ liệu cần kiểm tra

- `year`, `month_number`, `quarter_number`, `transaction_count`, `sales_bottles`: Number.
- `sales_dollars`: Currency (USD).
- `sales_liters`: Number, 3 chữ số thập phân.
- Các trường còn lại: Text.
