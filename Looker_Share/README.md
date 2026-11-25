# Dựng lại ba báo cáo Power BI bằng Looker Studio

Gói này cung cấp dữ liệu CSV để dựng lại nội dung của `baocao1.pbix`, `baocao2.pbix` và `baocao3.pbix` trong `context_for_final_project/24521109_24520010_BTA13_PowerBI_Package/Source/PowerBI`. Các biểu đồ, trường và bộ lọc tương ứng được ghi trong [DASHBOARD_SPEC.md](DASHBOARD_SPEC.md). Thư mục **chưa chứa dashboard Looker Studio đã tạo trên tài khoản Google**.

## Bắt đầu

1. Đăng nhập Looker Studio và tạo báo cáo trống.
2. Tạo nguồn dữ liệu bằng **CSV file upload** cho bốn file ở cột *Dùng cho* bên dưới. Tải từng CSV riêng và thêm các nguồn vào cùng báo cáo. Hãy chép nguyên thư mục `Data/` cho người dựng báo cáo; nếu lấy qua Git, cần tải nội dung Git LFS chứ không chỉ các file pointer.
3. Kiểm tra kiểu trường: `year`, `month_number`, `quarter_number`, `store_key`, `vendor_key`, `product_key`, `transaction_count`, `sales_bottles`, `sales_dollars`, `sales_liters` là số; `store_no` là **Text** để giữ số 0 đầu. Định dạng `sales_dollars` thành USD, `sales_liters` thành số có 3 chữ số thập phân. Đặt phép tổng hợp cho các metric là **SUM**.
4. Tạo ba trang theo [DASHBOARD_SPEC.md](DASHBOARD_SPEC.md). Dùng đúng nguồn dữ liệu ghi cho từng biểu đồ. Các biểu đồ **Top N** phải sắp xếp metric giảm dần rồi giới hạn số mục.
5. Trang 2 dùng ba nguồn dữ liệu. Để một bộ lọc quý và quận tác động lên cả ba, vào **Resource → Manage field names and IDs**, đặt cùng field ID cho các trường `quarter_number` tương ứng, và cùng field ID khác cho các trường `county_name` tương ứng. Làm việc này trước khi dựng biểu đồ; đổi ID của trường đã dùng có thể khiến biểu đồ cần chọn lại trường. Xem [hướng dẫn của Google về bộ lọc qua nhiều nguồn](https://docs.cloud.google.com/data-studio/use-controls-across-data-sources).
6. Kiểm tra tổng số liệu và các bộ lọc theo mục **Đối chiếu** trước khi chia sẻ.

## Các file dữ liệu

| File trong `Data/` | Mức tổng hợp | Dùng cho |
| --- | --- | --- |
| `sales_monthly_county_category.csv` | Tháng × quận × danh mục | Báo cáo 1; biểu đồ danh mục và danh mục theo quý ở báo cáo 2 |
| `sales_quarterly_county_vendor.csv` | Quý × quận × Vendor Key | Top 5 nhà cung cấp ở báo cáo 2 |
| `sales_quarterly_county_product.csv` | Quý × quận × Product Key | Top 5 sản phẩm American Vodkas ở báo cáo 2 |
| `sales_monthly_store_category.csv` | Tháng × Store Key × danh mục | Toàn bộ báo cáo 3, gồm bộ lọc danh mục và bảng cửa hàng–tháng |
| `sales_monthly_store.csv` | Tháng × Store Key | File cũ để phân tích cửa hàng đơn giản; không dùng cho báo cáo 3 nếu cần bộ lọc danh mục |
| `sales_monthly_vendor.csv` | Tháng × tên nhà cung cấp | File cũ để phân tích nhà cung cấp đơn giản; không dùng cho Top 5 theo Vendor Key/quận |

`store_key`, `vendor_key` và `product_key` là khóa dùng trong cube Power BI; chúng khác mã cửa hàng (`store_no`) và mã sản phẩm hiển thị trong dữ liệu nguồn. Các file đều xuất từ cùng bảng fact. **Không cộng doanh thu của nhiều file với nhau** vì sẽ tính lặp cùng giao dịch.

## Đối chiếu

- Mỗi CSV chứa toàn bộ dữ liệu năm 2024, nên tổng `SUM(transaction_count)`, `SUM(sales_bottles)`, `SUM(sales_dollars)` và `SUM(sales_liters)` của từng file phải bằng nhau khi không đặt bộ lọc.
- Báo cáo 1: lọc quý và kiểm tra biểu đồ tháng, quý, Top 10 quận cùng đổi.
- Báo cáo 2: lọc quý/quận và kiểm tra cả ba nguồn cùng đổi; ở biểu đồ sản phẩm, lọc `category_name = AMERICAN VODKAS` trước khi chọn Top 5.
- Báo cáo 3: lọc quý/danh mục và kiểm tra cả bốn biểu đồ cùng đổi. Biểu đồ cửa hàng dùng `county_name = POLK`; bảng cửa hàng–tháng dùng `store_city = DES MOINES` và `county_name = POLK` như file Power BI.
- `Data/metadata.json` ghi số dòng từng file; `Data/CHECKSUMS.sha256` dùng để kiểm tra file sau khi chuyển cho người khác.

## Tái tạo CSV từ dữ liệu gốc

Từ thư mục gốc repository, chạy PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\Looker_Share\Scripts\build_looker_share.ps1
```

Script dùng Python 3 để đọc năm file trong `SSAS_IowaLiquor_Share/Portable_Data`, ghi lại sáu CSV, metadata và checksum. Không cần SQL Server hay SSAS. Nếu dùng BigQuery thay vì tải CSV trực tiếp, xem [BigQuery/create_summary_tables.sql](BigQuery/create_summary_tables.sql).

Kiểm tra các file sau khi dựng (cần Python 3):

```powershell
python .\Looker_Share\Scripts\verify_looker_share.py
```

## Giới hạn

Các file được tổng hợp theo tháng hoặc quý để dễ tải lên Looker Studio. Chúng tái tạo các phép tổng, biểu đồ và bộ lọc nêu trong đặc tả, nhưng không hỗ trợ xem từng giao dịch hay từng ngày. Giao diện biểu đồ có thể khác Power BI. Việc tạo báo cáo trên Looker Studio, chia sẻ link và xuất PDF/video cần thực hiện trên tài khoản của người dựng báo cáo.
