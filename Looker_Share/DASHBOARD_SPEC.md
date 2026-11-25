# Đặc tả ba trang Looker Studio theo ba file Power BI

Ở mọi biểu đồ, `sales_dollars`, `sales_bottles` và `sales_liters` dùng phép **SUM**. Giá trị Top N tính sau khi áp dụng bộ lọc của trang và bộ lọc riêng của biểu đồ. Các tên trong dấu `code` là tên cột CSV.

## Trang 1 — `baocao1.pbix`: tổng quan phân phối năm 2024

Nguồn duy nhất: `sales_monthly_county_category.csv`.

| Biểu đồ Power BI | Cách dựng trong Looker Studio |
| --- | --- |
| Giá trị phân phối theo tháng | Line chart: `month_number`, `SUM(sales_dollars)`; file Power BI đang sắp xếp theo doanh thu giảm dần, hãy chọn cùng cách sắp xếp nếu cần khớp ảnh gốc |
| Số chai phân phối theo quý | Column chart: `quarter_number`, `SUM(sales_bottles)` |
| Top 10 quận theo giá trị phân phối | Bar chart: `county_name`, `SUM(sales_dollars)`, sắp xếp giảm dần, giới hạn 10 |
| Ba thẻ KPI | `SUM(sales_bottles)`, `SUM(sales_dollars)`, `SUM(sales_liters)` |
| Bộ lọc | `quarter_number` |

## Trang 2 — `baocao2.pbix`: danh mục, nhà cung cấp, sản phẩm

Trang này cần ba nguồn dữ liệu. Bộ lọc chung là `quarter_number` và `county_name`; xem cách đồng bộ field ID trong [README.md](README.md).

| Biểu đồ Power BI | Nguồn | Cách dựng trong Looker Studio |
| --- | --- | --- |
| Cơ cấu giá trị phân phối theo danh mục | `sales_monthly_county_category.csv` | Donut chart: `category_name`, `SUM(sales_dollars)` |
| Giá trị phân phối của 3 danh mục theo quý | `sales_monthly_county_category.csv` | Grouped column chart: `quarter_number`, series `category_name`, `SUM(sales_dollars)`; chỉ giữ `AMERICAN VODKAS`, `CANADIAN WHISKIES`, `STRAIGHT BOURBON WHISKIES` |
| Top 5 nhà cung cấp | `sales_quarterly_county_vendor.csv` | Bar chart: `vendor_key` (có thể hiển thị `vendor_name`), `SUM(sales_dollars)`, giảm dần, giới hạn 5 |
| Top 5 sản phẩm American Vodkas | `sales_quarterly_county_product.csv` | Bar chart: `product_key` (có thể hiển thị `product_name`), `SUM(sales_dollars)`; lọc `category_name = AMERICAN VODKAS`, giảm dần, giới hạn 5 |

## Trang 3 — `baocao3.pbix`: khu vực, cửa hàng và bảng tổng hợp

Nguồn duy nhất: `sales_monthly_store_category.csv`. Bộ lọc chung: `quarter_number` và `category_name`.

| Biểu đồ Power BI | Cách dựng trong Looker Studio |
| --- | --- |
| Top 10 thành phố theo sản lượng phân phối | Bar chart: `store_city`, `SUM(sales_liters)`, giảm dần, giới hạn 10 |
| Top 10 cửa hàng tại POLK | Bar chart: `store_key` (có thể hiển thị `store_name`), `SUM(sales_dollars)`; lọc `county_name = POLK`, giảm dần, giới hạn 10 |
| Giá trị phân phối của POLK, LINN, SCOTT theo quý | Grouped column chart: `quarter_number`, series `county_name`, `SUM(sales_dollars)`; chỉ giữ `POLK`, `LINN`, `SCOTT` |
| Giá trị phân phối theo cửa hàng và tháng tại DES MOINES | Pivot table: hàng `store_key` sắp xếp giảm dần, cột `month_number`, giá trị `SUM(sales_dollars)`; lọc `store_city = DES MOINES` và `county_name = POLK`; bật tổng hàng/cột để hiện Grouping and Totals |

## Kiểu dữ liệu

- Số: `year`, `month_number`, `quarter_number`, các trường `*_key`, `transaction_count`, `sales_bottles`, `sales_dollars`, `sales_liters`.
- Text: `store_no` (giữ số 0 đầu), các trường tên, quận, thành phố và danh mục.
- `sales_dollars`: định dạng USD, 2 chữ số thập phân. `sales_liters`: 3 chữ số thập phân.
