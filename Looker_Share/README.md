# Iowa Liquor - gói chia sẻ cho Data Studio (Looker Studio)

Gói này dùng để tạo dashboard trên Data Studio, tên mới của Looker Studio từ năm 2026. Không cần Power BI, SQL Server hay SSAS để dùng ba file CSV tổng hợp.

## Mở nhanh

1. Tải thư mục này hoặc clone repository.
2. Mở <https://datastudio.google.com/> và đăng nhập Google.
3. Chọn **Create** -> **Data source** -> **CSV file upload**.
4. Upload `Data/sales_monthly_county_category.csv`, sau đó bấm **Connect**.
5. Chọn **Create report**.
6. Tạo các biểu đồ theo `DASHBOARD_SPEC.md`.
7. Làm tương tự với `sales_monthly_store.csv` và `sales_monthly_vendor.csv` nếu muốn thêm trang cửa hàng và nhà cung cấp.
8. Chọn **Share**, nhập email người nhận hoặc tạo link xem báo cáo.

Các file đã được tổng hợp theo tháng nên nhỏ, tải nhanh và nằm dưới giới hạn 100 MB của CSV upload. Báo cáo Data Studio là tài nguyên trên Google Cloud; GitHub chỉ lưu dữ liệu và cấu hình, không lưu được một file dashboard ngoại tuyến như `.pbix`.

## Nội dung dữ liệu

- `sales_monthly_county_category.csv`: doanh thu theo tháng, quận/hạt và nhóm sản phẩm.
- `sales_monthly_store.csv`: doanh thu theo tháng và cửa hàng.
- `sales_monthly_vendor.csv`: doanh thu theo tháng và nhà cung cấp.
- `metadata.json`: số dòng nguồn và số dòng kết quả.
- `CHECKSUMS.sha256`: checksum để kiểm tra file sau khi tải.

Các metric có sẵn: số giao dịch, số chai, doanh thu USD và số lít.

## Dùng BigQuery

Nếu muốn quản lý dữ liệu bằng BigQuery:

1. Mở `BigQuery/create_summary_tables.sql` và thay `YOUR_PROJECT_ID`.
2. Chạy script trong BigQuery Console.
3. Nạp ba CSV tương ứng vào ba bảng; chọn CSV, UTF-8 và bỏ qua một dòng header.
4. Trong Data Studio, chọn connector **BigQuery** thay cho CSV upload.

BigQuery có thể phát sinh chi phí truy vấn tùy tài khoản và lưu lượng sử dụng.

## Tái tạo dữ liệu

Từ thư mục gốc của repository, chạy:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\Looker_Share\Scripts\build_looker_share.ps1
```

Script đọc dữ liệu portable trong `SSAS_IowaLiquor_Share/Portable_Data` và tái tạo ba CSV.
