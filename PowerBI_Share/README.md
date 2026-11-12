# Iowa Liquor - Power BI Share

Gói này chứa Power BI Project (`.pbip`) với đầy đủ 5 bảng và 2.590.975 giao dịch. Dữ liệu được nén và nhúng trong semantic model, không phụ thuộc SQL Server, SSAS, tài khoản hay đường dẫn trên máy người tạo.

## Cách mở

1. Clone repository bằng Git LFS hoặc tải toàn bộ thư mục `PowerBI_Share`.
2. Cài Microsoft Power BI Desktop bản 64-bit mới nhất.
3. Nhấp đúp `IowaLiquor.pbip`.
4. Nếu Power BI chưa nạp dữ liệu tự động, chọn **Home -> Refresh** và chờ hoàn tất.
5. Tạo biểu đồ trên trang `Iowa Liquor Overview`.

Không di chuyển riêng file `.pbip`; cần giữ nguyên toàn bộ cấu trúc thư mục.

## Mô hình dữ liệu

- `FACT_LIQUOR_SALES`: 2.590.975 giao dịch.
- `DIM_DATE`: 316 ngày.
- `DIM_STORE`: 2.162 cửa hàng.
- `DIM_PRODUCT`: 5.211 sản phẩm.
- `DIM_VENDOR`: 239 nhà cung cấp.

Các relationship đã được tạo từ fact tới bốn dimension. Các measure có sẵn:

- `Total Sales`
- `Total Bottles`
- `Total Liters`
- `Transaction Count`
- `Average Sale`

## Gợi ý thao tác

- Line chart: `DIM_DATE[month_name]` và measure `Total Sales`.
- Bar chart: `DIM_STORE[county_name]` và `Total Sales`.
- Treemap: `DIM_PRODUCT[category_name]` và `Total Sales`.
- Table: `DIM_VENDOR[vendor_name]`, `Total Sales`, `Total Bottles`.
- Slicer: năm, tháng, county và category.

## Kiểm tra file

`CHECKSUMS.sha256` chứa SHA-256 của toàn bộ project. Script `Scripts/build_powerbi_project.ps1` dùng để tái tạo project từ dữ liệu portable trong `SSAS_IowaLiquor_Share`.
