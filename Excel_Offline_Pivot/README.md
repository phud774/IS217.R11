# Iowa Liquor PivotTable chạy trực tiếp trong Excel

Folder này chứa bản offline của cube `Iowa Liquor DW`. Người dùng không cần
cài SQL Server, restore database hoặc deploy SSAS để xem và thao tác PivotTable.

## Tải folder từ GitHub

File `.cub` được lưu bằng Git LFS. Cách tải chắc chắn nhất:

```powershell
git lfs install
git clone https://github.com/phud774/IS217.R11.git
cd IS217.R11\Excel_Offline_Pivot
```

Nếu tải từng file trên trang GitHub, phải tải bản thật của
`IowaLiquor_Offline.cub`, không dùng file LFS pointer chỉ vài trăm byte.
Có thể đối chiếu checksum với `SHA256SUMS.txt` sau khi tải.

## Mở PivotTable

1. Giữ nguyên tất cả file trong cùng folder.
2. Nhấp đúp `OPEN_PIVOT.cmd`. Launcher tự tạo kết nối bằng đường dẫn đầy đủ
   tới file `.cub`, vì vậy có thể đặt folder ở vị trí bất kỳ.
3. Nếu Excel hiện cảnh báo kết nối dữ liệu, chọn cho phép mở kết nối.
4. Excel sẽ mở một PivotTable trống kết nối tới cube offline.
5. Trong **PivotTable Fields**, kéo thả các trường cần phân tích.

Gợi ý bố cục:

- Rows: `DIM DATE`, `DIM STORE`, `DIM PRODUCT` hoặc `DIM VENDOR`.
- Values: `Sales Dollars`, `Sales Bottles`, `Sales Liters` hoặc
  `FACT LIQUOR SALES Count`.
- Columns/Filters: chọn thêm cấp phân tích tùy báo cáo.

Sau khi bố trí xong, dùng **File -> Save As** để lưu workbook `.xlsx` của riêng
bạn. Workbook mới vẫn cần file `IowaLiquor_Offline.cub` để thay đổi bố cục hoặc
làm mới PivotTable, vì vậy nên tiếp tục giữ hai file trong cùng folder.

## Nếu `OPEN_PIVOT.cmd` không chạy

1. Chuột phải `OPEN_PIVOT.ps1` và chọn **Run with PowerShell**.
2. Nếu vẫn không mở, mở Excel.
3. Chọn **Data -> Existing Connections -> Browse for More...**.
4. Chọn file `IowaLiquor_Offline_*.odc` mà launcher tạo trong thư mục `%TEMP%`.
5. Chọn **PivotTable Report**.

Nếu muốn mở file ODC thủ công, sao chép `IowaLiquor_Offline.odc`, mở bản sao
bằng Notepad và thay `__CUBE_PATH__` bằng đường dẫn đầy đủ trên máy đang dùng:

```text
Data Source=C:\duong-dan-den-folder\IowaLiquor_Offline.cub
```

## Nội dung offline cube

- Dimensions: `DIM DATE`, `DIM PRODUCT`, `DIM STORE`, `DIM VENDOR`.
- Measures: `Sales Bottles`, `Sales Dollars`, `Sales Liters`,
  `FACT LIQUOR SALES Count`.
- Dữ liệu là snapshot offline; file không tự lấy dữ liệu mới từ SQL Server.
- Máy mở file cần Microsoft Excel desktop trên Windows và MSOLAP provider.
  Excel/Microsoft 365 thường cài provider này cùng các thành phần dữ liệu.

Tài liệu Microsoft:

- <https://support.microsoft.com/en-gb/excel/work-with-offline-cube-files>
- <https://support.microsoft.com/en-us/excel/overview-of-online-analytical-processing-olap>
