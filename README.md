# Iowa Liquor Sales 2024

Bộ dữ liệu này chứa **2.590.975 giao dịch bán đồ uống có cồn tại bang Iowa (Hoa Kỳ)** trong năm 2024. Mỗi dòng tương ứng với một mặt hàng trong hóa đơn, kèm thông tin về cửa hàng, khu vực, sản phẩm, nhà cung cấp, số lượng và doanh thu.

## Tổng quan

| Thuộc tính | Giá trị |
|---|---:|
| Khoảng thời gian | 01/01/2024 – 31/12/2024 |
| Số bản ghi | 2.590.975 |
| Số thuộc tính | 23 |
| Số tệp dữ liệu | 5 |
| Tổng dung lượng | 551,6 MB (khoảng 526 MiB) |
| Định dạng | CSV, có dòng tiêu đề |

Dữ liệu phù hợp cho các bài toán phân tích doanh thu, xu hướng tiêu thụ theo thời gian, hiệu quả cửa hàng, phân bố địa lý, danh mục sản phẩm và nhà cung cấp.

## Cấu trúc thư mục

```text
IS217.R11/
├── data/
│   ├── iowa_liquor_sales_2024_1261_rows_part_0001.csv
│   ├── iowa_liquor_sales_2024_1261_rows_part_0002.csv
│   ├── iowa_liquor_sales_2024_1261_rows_part_0003.csv
│   ├── iowa_liquor_sales_2024_1261_rows_part_0004.csv
│   └── iowa_liquor_sales_2024_1261_rows_part_0005.csv
├── .gitattributes
└── README.md
```

| Tệp | Số bản ghi | Khoảng ngày | Dung lượng |
|---|---:|---|---:|
| `part_0001.csv` | 536.798 | 01/01 – 19/03 | 114,1 MB |
| `part_0002.csv` | 548.044 | 19/03 – 05/06 | 116,5 MB |
| `part_0003.csv` | 454.073 | 05/06 – 07/08 | 96,6 MB |
| `part_0004.csv` | 466.546 | 07/08 – 15/10 | 99,4 MB |
| `part_0005.csv` | 585.514 | 15/10 – 31/12 | 125,0 MB |

Các tệp được chia theo thứ tự thời gian. Một số ngày nằm ở ranh giới giữa hai phần; khi ghép dữ liệu nên dựa vào bản ghi thay vì loại bỏ toàn bộ các ngày trùng ranh giới.

## Từ điển dữ liệu

| Cột | Mô tả |
|---|---|
| `invoice_id` | Mã hóa đơn/giao dịch |
| `ordered_on` | Ngày đặt hàng (`YYYY-MM-DD`) |
| `store_no` | Mã cửa hàng |
| `store_name` | Tên cửa hàng |
| `store_address` | Địa chỉ cửa hàng |
| `store_city` | Thành phố |
| `store_zip_code` | Mã ZIP |
| `county_fips_code` | Mã FIPS của quận |
| `county_name` | Tên quận |
| `category_code` | Mã danh mục sản phẩm |
| `category_name` | Tên danh mục sản phẩm |
| `vendor_number` | Mã nhà cung cấp |
| `vendor_name` | Tên nhà cung cấp |
| `item_no` | Mã sản phẩm |
| `im_desc` | Tên/mô tả sản phẩm |
| `pack` | Số chai trong một thùng |
| `bottle_volume_ml` | Dung tích mỗi chai (ml) |
| `state_bottle_cost` | Giá vốn mỗi chai (USD) |
| `state_bottle_retail` | Giá bán lẻ mỗi chai (USD) |
| `sales_bottles` | Số chai bán ra |
| `sales_dollars` | Doanh thu (USD) |
| `sales_liters` | Sản lượng bán ra (lít) |
| `sales_gallons` | Sản lượng bán ra (gallon) |

> Một số trường có thể bị thiếu. Nên kiểm tra giá trị rỗng và kiểu dữ liệu trước khi phân tích.

## Tải dữ liệu

Các tệp CSV được lưu bằng [Git LFS](https://git-lfs.com/) vì có kích thước lớn. Hãy cài Git LFS trước khi clone:

```bash
git lfs install
git clone https://github.com/phud774/IS217.R11.git
cd IS217.R11
git lfs pull
```

Nếu chưa tải nội dung LFS, các tệp CSV trong thư mục làm việc chỉ là những tệp con trỏ nhỏ thay vì dữ liệu thật.

## Ví dụ sử dụng với Python

Đọc lần lượt theo từng khối để hạn chế sử dụng bộ nhớ:

```python
from pathlib import Path

import pandas as pd

files = sorted(Path("data").glob("*.csv"))

total_rows = 0
total_sales = 0.0

for file in files:
    for chunk in pd.read_csv(file, chunksize=100_000):
        total_rows += len(chunk)
        total_sales += chunk["sales_dollars"].sum()

print(f"Rows: {total_rows:,}")
print(f"Sales: ${total_sales:,.2f}")
```

Để phân tích theo ngày, có thể chuyển `ordered_on` sang kiểu thời gian:

```python
chunk["ordered_on"] = pd.to_datetime(chunk["ordered_on"], errors="coerce")
```

## Lưu ý khi phân tích

- Các mã như `store_no`, `item_no`, `category_code` và `county_fips_code` nên được xem là biến định danh, không phải đại lượng số.
- Không tự động thay giá trị thiếu ở các cột giá bằng `0`, vì điều này có thể làm sai lệch kết quả.
- Khi tổng hợp doanh thu hoặc sản lượng, nên kiểm tra giao dịch điều chỉnh/hoàn trả nếu xuất hiện giá trị âm.
- Nên loại bản ghi trùng theo toàn bộ dòng hoặc theo khóa nghiệp vụ phù hợp với mục tiêu phân tích; không chỉ dựa vào `invoice_id`, vì một hóa đơn có thể chứa nhiều mặt hàng.

## Công nghệ gợi ý

- **Python:** pandas, Polars
- **Truy vấn cục bộ:** DuckDB
- **Trực quan hóa:** Power BI, Tableau, Matplotlib, Seaborn
- **Xử lý dữ liệu lớn:** Apache Spark

## Tiến độ xây dựng Data Warehouse bằng SSIS

### Mục tiêu ETL

Nạp 5 tệp CSV đã làm sạch trong `cleaned_data/` vào SQL Server bằng SSIS, sau đó chuyển dữ liệu từ bảng staging sang mô hình sao:

```text
cleaned_data/*.csv
        |
        v
stg.LiquorSalesRaw
        |
        +--> dbo.DIM_DATE
        +--> dbo.DIM_STORE
        +--> dbo.DIM_PRODUCT
        +--> dbo.DIM_VENDOR
        |
        v
dbo.FACT_LIQUOR_SALES
```

Database đích là `IowaLiquorDW`. Các script khởi tạo được lưu tại:

- `SQL/create_db.sql`: tạo database, schema `stg` và bảng `stg.LiquorSalesRaw` gồm 15 cột dạng chuỗi.
- `SQL/create_tables.sql`: tạo `DIM_DATE`, `DIM_STORE`, `DIM_PRODUCT`, `DIM_VENDOR` và `FACT_LIQUOR_SALES` cùng khóa chính/khóa ngoại.

### Cấu hình SSIS đã thực hiện

Project SSIS nằm trong `IS217_ETL/` và package chính là `IS217_ETL/IS217_ETL/Package.dtsx`.

- Đã tạo biến package `User::FilePath` kiểu `String`. Giá trị thiết kế ban đầu trỏ tới `part_0001.csv`.
- Đã tạo `Foreach Loop Container` bằng `Foreach File Enumerator`.
- Thư mục nguồn: `C:\coding_space\study\IS217\cleaned_data`.
- Bộ lọc file: `*.csv`; không duyệt thư mục con; lấy tên file đầy đủ.
- Đã map kết quả của Foreach tại index `0` vào `User::FilePath`.
- Đã tạo Flat File Connection Manager `FF_CleanedLiquor` với code page `65001 (UTF-8)`, định dạng phân tách bằng dấu phẩy, text qualifier là dấu nháy kép và dòng đầu chứa tên cột.
- Thuộc tính `ConnectionString` của `FF_CleanedLiquor` dùng expression `@[User::FilePath]`. Vì vậy chỉ cần một Flat File Source để đọc lần lượt cả 5 file.
- Đã đặt `Header rows to skip = 0` và tăng độ rộng metadata của các cột chuỗi để không bị truncation. Các cột tên dùng độ rộng từ 100 đến 255; `im_desc` dùng 500.
- Đã kết nối SQL Server bằng `Microsoft OLE DB Driver 19 for SQL Server` (`MSOLEDBSQL19.1`) với database `IowaLiquorDW`.
- OLE DB Destination sử dụng chế độ `Table or view - fast load`, ghi vào `[stg].[LiquorSalesRaw]`, bật `TABLOCK`, đặt `Rows per batch = 100000` và `Maximum insert commit size = 100000`.
- Đã map đủ 15 cột từ Flat File Source sang OLE DB Destination.
- Đã đặt `DefaultCodePage = 65001` và `AlwaysUseDefaultCodePage = True` cho OLE DB Destination để thống nhất mã hóa UTF-8.

Luồng lặp khi package chạy:

```text
Foreach tìm một file CSV
        |
        v
User::FilePath nhận đường dẫn file hiện tại
        |
        v
FF_CleanedLiquor đọc file
        |
        v
OLE DB Destination ghi vào stg.LiquorSalesRaw
```

### Các lỗi đã xử lý

- Task `Create Star Schema` chưa được cấu hình đầy đủ gây lỗi validation. Task này không còn cần thiết vì database và các bảng đã được tạo trước bằng script SQL.
- Provider cũ `SQLNCLI11` không có trên máy. Connection Manager đã chuyển sang `MSOLEDBSQL19.1`.
- OLE DB Connection ban đầu chưa chọn Initial Catalog nên không thấy bảng staging. Connection đang sử dụng database `IowaLiquorDW`.
- Flat File Source dùng UTF-8 (`65001`) trong khi destination tự suy ra code page `1252`. OLE DB Destination đã được cấu hình dùng thống nhất code page `65001`.
- `vendor_name` ở dòng dữ liệu đầu có trường hợp dài 58 ký tự, vượt metadata 50 ký tự. Độ rộng các cột chuỗi đã được tăng theo kích thước bảng staging.

### Kết quả nạp staging

Package đã chạy thành công qua cả 5 file CSV. Màn hình Data Flow hiển thị `585.514` dòng ở vòng lặp cuối, tương ứng với file `part_0005.csv`.

Kết quả kiểm tra toàn bộ staging:

```sql
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT invoice_id) AS unique_invoices,
    MIN(TRY_CONVERT(date, ordered_on)) AS first_date,
    MAX(TRY_CONVERT(date, ordered_on)) AS last_date
FROM stg.LiquorSalesRaw;
```

| Chỉ tiêu | Kết quả |
|---|---:|
| Tổng số dòng | 2.590.975 |
| Số `invoice_id` duy nhất | 2.590.975 |
| Ngày nhỏ nhất | 2024-01-01 |
| Ngày lớn nhất | 2024-12-31 |

Kết quả xác nhận dữ liệu đã được nạp đủ, không mất dòng và không trùng `invoice_id`.

### Bước ETL tiếp theo

1. Thêm Execute SQL Task `Truncate Staging` trước Foreach Loop để package có thể chạy lại mà không tạo dữ liệu trùng.
2. Nạp `DIM_DATE` với đầy đủ 366 ngày của năm 2024.
3. Nạp `DIM_STORE`, `DIM_PRODUCT` và `DIM_VENDOR` từ staging.
4. Dùng Lookup lấy `date_key`, `store_key`, `product_key`, `vendor_key` rồi nạp `FACT_LIQUOR_SALES`.

### Lưu ý chạy lại package

Không cần chạy lại lệnh `CREATE TABLE` nếu các bảng đã tồn tại. Khi thực hiện full load, cần xóa dữ liệu staging trước khi Foreach chạy để tránh nạp trùng, ví dụ bằng một Execute SQL Task:

```sql
TRUNCATE TABLE stg.LiquorSalesRaw;
```
