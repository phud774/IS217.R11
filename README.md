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
