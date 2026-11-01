# Sửa lỗi `StandardDeveloper 64` khi deploy SSAS 2025

## Triệu chứng

Visual Studio báo lỗi tương tự:

```text
The current edition 'StandardDeveloper 64' of the target SQL Server Analysis
Services instance is not supported by the client. Please update your client
libraries to the latest available version.
```

Lỗi này xảy ra trước khi cube được deploy. Nó không phải lỗi của file `.bak`,
dữ liệu, dimension hay cube. `Standard Developer` là edition mới của SQL Server
2025, còn Visual Studio đang nạp AMO/client library cũ nên chưa nhận ra edition
này. Việc SSMS vẫn kết nối được với Analysis Services không chứng minh thư viện
bên trong Visual Studio đã đủ mới, vì hai ứng dụng có bộ client riêng.

## Cách sửa khuyến nghị

Làm đúng thứ tự dưới đây trên máy bị lỗi:

1. Đóng tất cả cửa sổ Visual Studio.
2. Mở **Visual Studio Installer**, cập nhật Visual Studio lên bản mới nhất rồi
   khởi động lại Windows nếu installer yêu cầu.
3. Mở Visual Studio, vào **Extensions -> Manage Extensions -> Installed**.
4. Tìm **Microsoft Analysis Services Projects 2022+**:
   - Nếu có nút **Update**, cập nhật extension.
   - Nếu extension cũ không cập nhật được, chọn **Uninstall**, đóng Visual
     Studio để trình cài đặt gỡ extension, sau đó mở lại và cài bản chính thức
     mới nhất từ Visual Studio Marketplace.
   - Không dùng extension dành cho Visual Studio 2019. Bản 2022+ phải là
     **4.0.0 hoặc mới hơn**.
5. Cài/cập nhật **Microsoft Analysis Services OLE DB Provider (MSOLAP) x64** từ
   trang client libraries chính thức của Microsoft:
   <https://learn.microsoft.com/analysis-services/client-libraries>
6. Cập nhật SQL Server/Analysis Services 2025 từ build RTM `17.0.1000.7` lên
   Cumulative Update mới nhất. Đây không phải bước thay thế việc cập nhật
   extension, nhưng tránh các lỗi đã được sửa sau RTM:
   <https://learn.microsoft.com/troubleshoot/sql/releases/download-and-install-latest-updates>
7. Khởi động lại Windows. Mở lại `SSAS_Project/SSAS.slnx`.
8. Kiểm tra lại `SSAS -> Properties -> Deployment -> Target Server` phải là
   instance **Analysis Services**, ví dụ `DESKTOP-ABC\SQL2025`, không phải
   instance Database Engine.
9. Chọn **Build -> Rebuild Solution**, sau đó chuột phải project **SSAS ->
   Deploy**.

## Nếu vẫn còn đúng thông báo trên

1. Vào **Extensions -> Manage Extensions -> Installed** và xác nhận chỉ dùng
   extension **Microsoft Analysis Services Projects 2022+** mới nhất.
2. Đóng Visual Studio, mở **Visual Studio Installer -> More -> Repair**.
3. Sau Repair, cài lại extension, khởi động lại Windows và deploy lại.

Không cần restore lại database và cũng không cần sửa các file `.dim`, `.cube`
hay `.dsv` chỉ để xử lý thông báo `StandardDeveloper 64`.

## Lỗi có thể xuất hiện sau khi deploy đã chạy được

- `Login failed` hoặc `permission denied`: làm mục 4 trong `README.md` để cấp
  `db_datareader` cho tài khoản dịch vụ SSAS.
- `SQLOLEDB.1 not registered`: mở Data Source và tạo lại connection bằng
  Microsoft OLE DB Driver for SQL Server (`MSOLEDBSQL`).
- Kết nối đúng nhưng cube trống: chạy **Process Full** cho database/cube SSAS.
