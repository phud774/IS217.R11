# Iowa Liquor SSAS - gói chạy PivotTable trên Excel

Gói này gồm database nguồn `IowaLiquorDW`, project SSAS Multidimensional và hướng dẫn deploy để dùng Excel PivotTable. Project đã được bỏ tên máy của người tạo; Data Source mặc định trỏ tới `localhost`.

## 1. Máy nhận cần có gì?

- Windows 10/11 64-bit.
- SQL Server Database Engine.
- SQL Server Analysis Services cài ở chế độ **Multidimensional and Data Mining**. Tabular mode không mở được cube này.
- SQL Server Management Studio (SSMS).
- Visual Studio 2022 và extension **Microsoft Analysis Services Projects**.
- Microsoft Excel desktop trên Windows.
- Tối thiểu khoảng 4 GB trống để restore/import, build và process.

Khuyến nghị cài Database Engine và Analysis Services trên cùng một máy để tránh cấu hình Kerberos/double-hop.

## 2. Nội dung gói

- `Database/IowaLiquorDW.bak`: backup nhanh, dùng với SQL Server 2025 (major version 17) hoặc mới hơn.
- `Portable_Data/*.dat`: dữ liệu dạng text UTF-8, dùng khi máy nhận là SQL Server 2019/2022/2025.
- `INSTALL_PORTABLE.ps1`: tạo database và nhập dữ liệu portable.
- `SSAS_Project/SSAS.slnx`: solution SSAS cần mở trong Visual Studio.
- `SQL/`: script tạo, kiểm tra database và cấp quyền đọc cho tài khoản dịch vụ SSAS.
- `SHA256SUMS.txt`: checksum để kiểm tra file sau khi gửi/giải nén.

Database đúng sau khi cài phải có:

| Bảng | Số dòng |
|---|---:|
| DIM_DATE | 316 |
| DIM_PRODUCT | 5,211 |
| DIM_STORE | 2,162 |
| DIM_VENDOR | 239 |
| FACT_LIQUOR_SALES | 2,590,975 |

## 3. Bước A - đưa database vào SQL Server

Chọn đúng **một** trong hai cách dưới đây.

### Cách 1 - nhanh nhất, restore file BAK

Chỉ dùng cách này nếu Database Engine là SQL Server 2025 (17.x) hoặc mới hơn.

1. Mở SSMS và kết nối tới **Database Engine**.
2. Chuột phải `Databases` -> `Restore Database...`.
3. Chọn `Device` -> nút `...` -> `Add` -> chọn `Database/IowaLiquorDW.bak`.
4. Đặt `Destination database` là `IowaLiquorDW`.
5. Nếu đường dẫn data/log của máy khác, vào trang `Files` và chọn `Relocate all files to folder`.
6. Bấm `OK`.
7. Mở `SQL/02_verify_database.sql` bằng SSMS, bật SQLCMD Mode nếu cần (`Query` -> `SQLCMD Mode`), rồi Execute.

Nếu gặp lỗi “backup was taken on a server running version 17...”, dùng Cách 2.

### Cách 2 - portable cho SQL Server 2019/2022/2025

Cách này cần `sqlcmd.exe` và `bcp.exe` (cài cùng SQL Server command-line utilities/client tools).

1. Mở PowerShell tại thư mục gói.
2. Chạy lệnh dưới đây, thay tên instance cho đúng:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\INSTALL_PORTABLE.ps1 -SqlInstance ".\SQLEXPRESS"
```

Ví dụ tên instance thường gặp:

- Default instance: `localhost`
- SQL Express: `.\SQLEXPRESS`
- Named instance: `localhost\MSSQLSERVER02`

Script không ghi đè database đã tồn tại. Nếu bị dừng giữa chừng, xóa database chưa hoàn tất bằng SSMS rồi chạy lại.

## 4. Cấp quyền để SSAS đọc database

Project đang dùng chế độ impersonation `ImpersonateServiceAccount`, vì vậy tài khoản chạy dịch vụ SSAS cần quyền `db_datareader` trên `IowaLiquorDW`.

1. Mở `services.msc`.
2. Tìm `SQL Server Analysis Services (...)` và xem cột/tab `Log On As`.
3. Mở `SQL/03_grant_ssas_read_template.sql` trong SSMS.
4. Sửa dòng `SsasServiceAccount` cho đúng tài khoản vừa xem. Với named instance `SSASMD`, giá trị thường là `NT SERVICE\MSOLAP$SSASMD`.
5. Bật `Query` -> `SQLCMD Mode`, rồi Execute bằng tài khoản có quyền tạo login/user.

## 5. Sửa Data Source và deploy cube

1. Mở `SSAS_Project/SSAS.slnx` bằng Visual Studio 2022.
2. Nếu project báo unsupported/incompatible, cài hoặc cập nhật extension **Microsoft Analysis Services Projects**, rồi mở lại.
3. Trong Solution Explorer, mở `Data Sources` -> `Iowa Liquor DW.ds`.
4. Bấm `Edit...` và đặt Server name bằng đúng SQL Database Engine ở Bước 3. Database là `IowaLiquorDW`. Bấm `Test Connection`.
5. Chuột phải project `SSAS` -> `Properties` -> `Deployment`:
   - `Target Server`: tên instance Analysis Services, ví dụ `localhost\SSASMD` hoặc `localhost`.
   - `Target Database`: `SSAS`.
   - `Processing Options`: `Default` hoặc `Full` cho lần đầu.
6. Chọn `Build` -> `Build Solution`.
7. Chuột phải project -> `Deploy`.
8. Nếu deploy xong nhưng chưa có dữ liệu, chuột phải cube `Iowa Liquor DW` -> `Process...` -> `Run`.

Lưu ý: SQL Database Engine và Analysis Services là hai kết nối khác nhau. Đừng nhập tên SQL instance vào ô Target Server nếu đó không phải instance SSAS.

## 6. Tạo PivotTable trong Excel

1. Mở Excel desktop -> tab `Data`.
2. Chọn `Get Data` -> `From Database` -> `From Analysis Services` (tên menu có thể hơi khác theo phiên bản Excel).
3. Nhập tên instance SSAS đã deploy ở Bước 5, ví dụ `localhost\SSASMD`.
4. Chọn Windows Authentication nếu được hỏi.
5. Chọn database `SSAS`, cube `Iowa Liquor DW`.
6. Chọn `PivotTable Report`.
7. Kéo thử:
   - Rows: `DIM DATE` -> Year/Month hoặc `DIM STORE` -> County.
   - Columns: `DIM PRODUCT` -> Category Name.
   - Values: `Sales Dollars`, `Sales Bottles`, `Sales Liters`.

Excel không đọc trực tiếp file `.cube`/`.dwproj`; cube phải được deploy và process trên một Analysis Services instance đang chạy.

## 7. Lỗi thường gặp

- **Không restore được BAK do version**: dùng `INSTALL_PORTABLE.ps1`.
- **Project incompatible**: cài Analysis Services Projects extension đúng cho Visual Studio 2022.
- **Test Connection thất bại**: kiểm tra tên SQL instance, dịch vụ Database Engine và database `IowaLiquorDW`.
- **Provider SQLOLEDB.1 not registered**: trong Data Source, tạo lại connection bằng Microsoft OLE DB Driver for SQL Server (`MSOLEDBSQL`) đã cài trên máy.
- **Process báo Login failed/permission denied**: chạy lại mục 4 với đúng tài khoản `Log On As` của dịch vụ SSAS.
- **Excel không thấy server/cube**: kiểm tra dịch vụ SSAS đang chạy, Target Server khi deploy, và dùng đúng tên SSAS instance.
- **Cube mở được nhưng trống**: Process Full lại cube/database SSAS.
- **Kết nối từ máy khác qua mạng**: cần mở firewall/cổng SSAS và cấp quyền SSAS cho tài khoản Windows; cách đơn giản nhất là chạy Excel trên cùng máy đã deploy.

## 8. Checklist trước khi gửi

- Gửi nguyên file ZIP, không chỉ gửi folder `SSAS_Project`.
- Máy nhận giải nén ZIP ra ổ cứng trước khi restore/deploy.
- Không chạy project trực tiếp bên trong ZIP.
- Sau khi giải nén có thể chạy `VERIFY_PACKAGE.ps1` để kiểm tra checksum.

