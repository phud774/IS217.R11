# Hướng dẫn làm sạch CSV và nạp bảng Raw hoàn toàn bằng SSIS

## 1. Mục tiêu

Tài liệu này hướng dẫn xây dựng lại quá trình ETL từ đầu bằng SSIS, không sử dụng `clean_data.py` và không sử dụng thư mục `cleaned_data`.

SSIS sẽ thực hiện toàn bộ các công việc sau:

1. Đọc lần lượt 5 file CSV gốc trong thư mục `data`.
2. Đọc đủ 23 cột nguồn dưới dạng chuỗi.
3. Loại khoảng trắng thừa và đổi chuỗi rỗng thành `NULL` khi phù hợp.
4. Chọn 15 cột cần thiết cho mô hình sao.
5. Kiểm tra các trường bắt buộc.
6. Kiểm tra định dạng ngày và số.
7. Nạp dòng hợp lệ vào `stg.LiquorSalesRaw`.
8. Nạp dòng không hợp lệ vào `stg.LiquorSalesReject`.

Mô hình sao đích được mô tả trong:

```text
C:\coding_space\study\IS217\So_do_sao\iowa_liquor_star_schema.dbml
```

Ở giai đoạn này chỉ thực hiện đến bảng Raw, chưa nạp Dimension và Fact.

## 2. Kiến trúc ETL

```text
data/*.csv
5 file CSV gốc, 23 cột
          |
          v
Foreach Loop Container
          |
          v
Flat File Source
Đọc toàn bộ cột dưới dạng chuỗi
          |
          v
Derived Column
- TRIM khoảng trắng
- Chuỗi rỗng thành NULL
- Tạo 15 cột sạch
          |
          v
Conditional Split
- Thiếu trường bắt buộc -> Reject
- Hợp lệ -> kiểm tra kiểu dữ liệu
          |
          v
Data Conversion
Kiểm tra date, int và decimal
       +--+------------------+
       |                     |
       v                     v
Nạp thành công          Lỗi chuyển đổi
       |                     |
       v                     v
stg.LiquorSalesRaw    stg.LiquorSalesReject
```

> Bảng Raw vẫn dùng các cột `varchar`. Data Conversion chỉ được dùng để kiểm tra dữ liệu có chuyển được sang ngày và số hay không. Việc nạp các bảng Dimension và Fact mới sử dụng kiểu dữ liệu chính thức.

## 3. Quy tắc làm sạch

Áp dụng các quy tắc sau trong SSIS:

- Giữ nguyên mã dạng chuỗi như `store_no`, `vendor_number`, `item_no` để không mất số `0` ở đầu. Ví dụ vendor `065` không được chuyển thành số `65`.
- Dùng `TRIM` để bỏ khoảng trắng ở đầu và cuối chuỗi.
- Không tự động gộp nhiều khoảng trắng nằm giữa tên.
- Không loại 422 giao dịch thiếu `store_city` hoặc `county_name`; chuyển các giá trị này thành `NULL`.
- Không loại 2.983 giao dịch có số lượng hoặc doanh thu âm vì chúng có thể là hoàn trả hoặc điều chỉnh.
- Không thay giá trị thiếu bằng `0`.
- Không loại trùng ở bước này. Dữ liệu hiện tại có 2.590.975 `invoice_id` khác nhau.
- Không sử dụng hai cột `state_bottle_cost` và `state_bottle_retail` vì chúng trống hoàn toàn.

## 4. Tạo database và bảng staging

Mở SQL Server Management Studio và kết nối tới SQL Server sẽ được SSIS sử dụng.

### 4.1. Tạo database và schema

```sql
IF DB_ID('IowaLiquorDW') IS NULL
BEGIN
    CREATE DATABASE IowaLiquorDW;
END;
GO

USE IowaLiquorDW;
GO

IF SCHEMA_ID('stg') IS NULL
BEGIN
    EXEC('CREATE SCHEMA stg');
END;
GO
```

### 4.2. Tạo bảng Raw

```sql
USE IowaLiquorDW;
GO

IF OBJECT_ID('stg.LiquorSalesRaw', 'U') IS NULL
BEGIN
    CREATE TABLE stg.LiquorSalesRaw
    (
        invoice_id        varchar(30)  NULL,
        ordered_on        varchar(20)  NULL,
        store_no          varchar(20)  NULL,
        store_name        varchar(255) NULL,
        store_city        varchar(100) NULL,
        county_name       varchar(100) NULL,
        category_name     varchar(255) NULL,
        vendor_number     varchar(20)  NULL,
        vendor_name       varchar(255) NULL,
        item_no           varchar(30)  NULL,
        im_desc           varchar(500) NULL,
        bottle_volume_ml  varchar(30)  NULL,
        sales_bottles     varchar(30)  NULL,
        sales_dollars     varchar(50)  NULL,
        sales_liters      varchar(50)  NULL
    );
END;
GO
```

### 4.3. Tạo bảng lưu dòng lỗi

```sql
IF OBJECT_ID('stg.LiquorSalesReject', 'U') IS NULL
BEGIN
    CREATE TABLE stg.LiquorSalesReject
    (
        reject_id         bigint IDENTITY(1,1) PRIMARY KEY,
        source_file       varchar(500) NULL,
        reject_reason     varchar(100) NULL,
        error_code        int          NULL,
        error_column      int          NULL,

        invoice_id        varchar(30)  NULL,
        ordered_on        varchar(20)  NULL,
        store_no          varchar(20)  NULL,
        store_name        varchar(255) NULL,
        store_city        varchar(100) NULL,
        county_name       varchar(100) NULL,
        category_name     varchar(255) NULL,
        vendor_number     varchar(20)  NULL,
        vendor_name       varchar(255) NULL,
        item_no           varchar(30)  NULL,
        im_desc           varchar(500) NULL,
        bottle_volume_ml  varchar(30)  NULL,
        sales_bottles     varchar(30)  NULL,
        sales_dollars     varchar(50)  NULL,
        sales_liters      varchar(50)  NULL,

        rejected_at       datetime2 NOT NULL
            CONSTRAINT DF_LiquorSalesReject_rejected_at
            DEFAULT SYSDATETIME()
    );
END;
GO
```

### 4.4. Tạo các bảng Dimension

Các bảng Dimension có thể được tạo ngay từ đầu để hoàn thiện cấu trúc database. Tuy nhiên, package `Load_Raw_SSIS.dtsx` trong tài liệu này chưa nạp dữ liệu vào các bảng đó.

#### 4.4.1. Tạo `DIM_DATE`

```sql
IF OBJECT_ID('dbo.DIM_DATE', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.DIM_DATE
    (
        date_key          int         NOT NULL,
        ordered_on        date        NOT NULL,
        day_number        tinyint     NOT NULL,
        month_number      tinyint     NOT NULL,
        month_name        varchar(20) NOT NULL,
        quarter_number    tinyint     NOT NULL,
        year_number       smallint    NOT NULL,

        CONSTRAINT PK_DIM_DATE
            PRIMARY KEY (date_key),

        CONSTRAINT UQ_DIM_DATE_ordered_on
            UNIQUE (ordered_on)
    );
END;
GO
```

Quy ước `date_key` sử dụng định dạng số `YYYYMMDD`. Ví dụ ngày `2024-01-31` có `date_key = 20240131`.

#### 4.4.2. Tạo `DIM_STORE`

```sql
IF OBJECT_ID('dbo.DIM_STORE', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.DIM_STORE
    (
        store_key      int IDENTITY(1,1) NOT NULL,
        store_no       varchar(20)       NOT NULL,
        store_name     varchar(255)      NULL,
        store_city     varchar(100)      NULL,
        county_name    varchar(100)      NULL,

        CONSTRAINT PK_DIM_STORE
            PRIMARY KEY (store_key),

        CONSTRAINT UQ_DIM_STORE_store_no
            UNIQUE (store_no)
    );
END;
GO
```

`store_key` là surrogate key do SQL Server tự sinh. Khi nạp Dimension sau này, không ánh xạ dữ liệu nguồn vào cột này.

Trong Raw, một `store_no` vẫn có thể xuất hiện nhiều lần hoặc đi cùng nhiều `store_name`. Ràng buộc `UNIQUE (store_no)` chỉ được kiểm tra khi dữ liệu được đưa vào `DIM_STORE`. Trước bước đó cần chọn một bản ghi đại diện, chẳng hạn thông tin mới nhất theo `ordered_on`, hoặc triển khai SCD Type 2 nếu cần lưu lịch sử.

#### 4.4.3. Tạo `DIM_PRODUCT`

```sql
IF OBJECT_ID('dbo.DIM_PRODUCT', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.DIM_PRODUCT
    (
        product_key       int IDENTITY(1,1) NOT NULL,
        item_no           varchar(30)       NOT NULL,
        im_desc           varchar(500)      NULL,
        bottle_volume_ml  int               NULL,
        category_name     varchar(255)      NULL,

        CONSTRAINT PK_DIM_PRODUCT
            PRIMARY KEY (product_key),

        CONSTRAINT UQ_DIM_PRODUCT_item_no
            UNIQUE (item_no)
    );
END;
GO
```

Tài liệu này dùng tên `product_key` để thống nhất với bảng `DIM_PRODUCT`. Nếu DBML đang dùng `item_key`, cần đổi DBML sang `product_key` trước khi tạo bảng Fact.

#### 4.4.4. Tạo `DIM_VENDOR`

```sql
IF OBJECT_ID('dbo.DIM_VENDOR', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.DIM_VENDOR
    (
        vendor_key     int IDENTITY(1,1) NOT NULL,
        vendor_number  varchar(20)       NOT NULL,
        vendor_name    varchar(255)      NULL,

        CONSTRAINT PK_DIM_VENDOR
            PRIMARY KEY (vendor_key),

        CONSTRAINT UQ_DIM_VENDOR_vendor_number
            UNIQUE (vendor_number)
    );
END;
GO
```

#### 4.4.5. Chạy toàn bộ lệnh Dimension

Các câu lệnh sử dụng `IF OBJECT_ID(...) IS NULL`, vì vậy có thể chạy lại mà không tạo trùng bảng. Chúng không xóa và không ghi đè dữ liệu trong bảng đã tồn tại.

### 4.5. Kiểm tra các bảng đã tạo

```sql
SELECT
    SCHEMA_NAME(schema_id) AS schema_name,
    name AS table_name
FROM sys.tables
WHERE object_id IN
(
    OBJECT_ID('stg.LiquorSalesRaw'),
    OBJECT_ID('stg.LiquorSalesReject'),
    OBJECT_ID('dbo.DIM_DATE'),
    OBJECT_ID('dbo.DIM_STORE'),
    OBJECT_ID('dbo.DIM_PRODUCT'),
    OBJECT_ID('dbo.DIM_VENDOR')
);
```

Kết quả phải có sáu bảng:

```text
stg.LiquorSalesRaw
stg.LiquorSalesReject
dbo.DIM_DATE
dbo.DIM_STORE
dbo.DIM_PRODUCT
dbo.DIM_VENDOR
```

## 5. Tạo project và package SSIS

Nếu chưa có project SSIS mới:

1. Mở Visual Studio.
2. Chọn `Create a new project`.
3. Chọn `Integration Services Project`.
4. Đặt tên project, ví dụ `IS217_ETL`.
5. Chọn thư mục dự án `C:\coding_space\study\IS217`.

Trong `Solution Explorer`:

1. Nhấn phải chuột vào `SSIS Packages`.
2. Chọn `New SSIS Package`.
3. Đổi tên package thành `Load_Raw_SSIS.dtsx`.

Không cần sử dụng package cũ và không cần gọi Python từ Execute Process Task.

## 6. Tạo biến package

Mở menu `SSIS` -> `Variables`, sau đó tạo hai biến ở scope package:

| Name | Data type | Value |
|---|---|---|
| `FilePath` | String | Đường dẫn file CSV đầu tiên |
| `SourceFolder` | String | `C:\coding_space\study\IS217\data` |

Giá trị ban đầu của `User::FilePath`:

```text
C:\coding_space\study\IS217\data\iowa_liquor_sales_2024_1261_rows_part_0001.csv
```

## 7. Tạo OLE DB Connection Manager

Trong vùng `Connection Managers`:

1. Nhấn phải chuột.
2. Chọn `New OLE DB Connection`.
3. Chọn `New`.
4. Cấu hình kết nối tới SQL Server.
5. Chọn database `IowaLiquorDW`.
6. Bấm `Test Connection`.
7. Đổi tên connection thành `CM_IowaLiquorDW`.

Thiết lập cơ bản:

| Thuộc tính | Giá trị |
|---|---|
| Provider | Microsoft OLE DB Driver 19 for SQL Server |
| Server | SQL Server instance đang sử dụng |
| Authentication | Windows Authentication hoặc tài khoản được cấp |
| Database | `IowaLiquorDW` |

`Initial Catalog` của connection phải là `IowaLiquorDW`.

## 8. Tạo Flat File Connection Manager

Trong `Connection Managers`:

1. Chọn `New Flat File Connection`.
2. Đặt tên `FF_Iowa_Source`.
3. Chọn file mẫu:

```text
C:\coding_space\study\IS217\data\iowa_liquor_sales_2024_1261_rows_part_0001.csv
```

### 8.1. General

| Thiết lập | Giá trị |
|---|---|
| Format | Delimited |
| Text qualifier | `"` |
| Header row delimiter | `{CR}{LF}` |
| Header rows to skip | `0` |
| Column names in first data row | Bật |
| Code page | `65001 (UTF-8)` |

Text qualifier phải là dấu nháy kép vì dữ liệu có giá trị chứa dấu phẩy, ví dụ:

```text
"MAST-JAGERMEISTER US, INC"
```

### 8.2. Columns

Kiểm tra:

```text
Row delimiter    = {CR}{LF}
Column delimiter = Comma {,}
```

SSIS phải nhận đúng 23 cột.

### 8.3. Advanced

Đặt toàn bộ 23 cột thành:

```text
DataType = string [DT_STR]
CodePage = 65001
```

Không để SSIS tự nhận dạng các mã thành số.

| Cột nguồn | Độ rộng |
|---|---:|
| `invoice_id` | 30 |
| `ordered_on` | 20 |
| `store_no` | 20 |
| `store_name` | 255 |
| `store_address` | 255 |
| `store_city` | 100 |
| `store_zip_code` | 20 |
| `county_fips_code` | 20 |
| `county_name` | 100 |
| `category_code` | 20 |
| `category_name` | 255 |
| `vendor_number` | 20 |
| `vendor_name` | 255 |
| `item_no` | 30 |
| `im_desc` | 500 |
| `pack` | 30 |
| `bottle_volume_ml` | 30 |
| `state_bottle_cost` | 50 |
| `state_bottle_retail` | 50 |
| `sales_bottles` | 30 |
| `sales_dollars` | 50 |
| `sales_liters` | 50 |
| `sales_gallons` | 50 |

### 8.4. Gắn connection với biến file

Chọn `FF_Iowa_Source`, nhấn `F4` để mở Properties.

Tại `Expressions`, thêm:

| Property | Expression |
|---|---|
| `ConnectionString` | `@[User::FilePath]` |

Đặt:

```text
DelayValidation = True
```

## 9. Xây dựng Control Flow

Control Flow cần có dạng:

```text
01 - Truncate Staging
            |
            v
02 - Loop Source Files
            |
            +-- DFT - Clean and Load Raw
```

### 9.1. Execute SQL Task xóa dữ liệu cũ

Thêm `Execute SQL Task` và đặt tên:

```text
01 - Truncate Staging
```

Cấu hình:

```text
Connection    = CM_IowaLiquorDW
SQLSourceType = Direct input
```

SQL statement:

```sql
TRUNCATE TABLE stg.LiquorSalesReject;
TRUNCATE TABLE stg.LiquorSalesRaw;
```

Task này giúp chạy lại package mà không nạp trùng dữ liệu.

### 9.2. Foreach Loop Container

Thêm `Foreach Loop Container` và đặt tên:

```text
02 - Loop Source Files
```

Nối precedence constraint màu xanh từ `01 - Truncate Staging` tới Foreach Loop.

Trong trang `Collection`, cấu hình:

| Thuộc tính | Giá trị |
|---|---|
| Enumerator | Foreach File Enumerator |
| Folder | `C:\coding_space\study\IS217\data` |
| Files | `iowa_liquor_sales_2024_1261_rows_part_*.csv` |
| Traverse subfolders | Không bật |
| Retrieve file name | Fully qualified |

Trong trang `Variable Mappings`:

| Variable | Index |
|---|---:|
| `User::FilePath` | `0` |

Mỗi vòng lặp, đường dẫn đầy đủ của file hiện tại được gán vào `User::FilePath`.

### 9.3. Data Flow Task

Đặt một `Data Flow Task` bên trong Foreach Loop và đổi tên thành:

```text
DFT - Clean and Load Raw
```

Đặt thuộc tính:

```text
DelayValidation = True
```

## 10. Xây dựng Data Flow

Data Flow chính:

```text
SRC - Original CSV
        |
        v
DRV - Clean Columns
        |
        v
CS - Validate Required Fields
        |
        +-- Reject_MissingRequired --> DST - Reject Missing
        |
        +-- ReadyForTypeCheck
                    |
                    v
           DC - Validate Data Types
                    |
                    +-- Success --> DST - LiquorSalesRaw
                    |
                    +-- Error ----> DST - Reject Conversion
```

### 10.1. Flat File Source

Thêm `Flat File Source` và đổi tên:

```text
SRC - Original CSV
```

Chọn:

```text
Flat file connection manager = FF_Iowa_Source
```

Trong `Columns`, giữ đủ 23 cột. Các cột không dùng sẽ được bỏ bằng cách không ánh xạ vào destination.

### 10.2. Derived Column làm sạch

Thêm `Derived Column` và đổi tên:

```text
DRV - Clean Columns
```

Tạo 15 cột mới với tiền tố `clean_`. Chọn `add as new column`, không ghi đè cột nguồn.

Mẫu expression cho trường bắt buộc, ví dụ `invoice_id`:

```text
ISNULL(invoice_id)
? (DT_STR,30,65001)""
: (DT_STR,30,65001)TRIM(invoice_id)
```

Mẫu expression cho trường được phép thiếu, ví dụ `store_city`:

```text
ISNULL(store_city) || LEN(TRIM(store_city)) == 0
? NULL(DT_STR,100,65001)
: (DT_STR,100,65001)TRIM(store_city)
```

Tạo các cột sau:

| Derived column | Source column | Độ rộng |
|---|---|---:|
| `clean_invoice_id` | `invoice_id` | 30 |
| `clean_ordered_on` | `ordered_on` | 20 |
| `clean_store_no` | `store_no` | 20 |
| `clean_store_name` | `store_name` | 255 |
| `clean_store_city` | `store_city` | 100 |
| `clean_county_name` | `county_name` | 100 |
| `clean_category_name` | `category_name` | 255 |
| `clean_vendor_number` | `vendor_number` | 20 |
| `clean_vendor_name` | `vendor_name` | 255 |
| `clean_item_no` | `item_no` | 30 |
| `clean_im_desc` | `im_desc` | 500 |
| `clean_bottle_volume_ml` | `bottle_volume_ml` | 30 |
| `clean_sales_bottles` | `sales_bottles` | 30 |
| `clean_sales_dollars` | `sales_dollars` | 50 |
| `clean_sales_liters` | `sales_liters` | 50 |

Tạo thêm cột chứa file nguồn:

```text
Derived column: clean_source_file
Expression:     (DT_STR,500,65001)@[User::FilePath]
```

Không tạo cột sạch cho tám cột không sử dụng:

```text
store_address
store_zip_code
county_fips_code
category_code
pack
state_bottle_cost
state_bottle_retail
sales_gallons
```

### 10.3. Conditional Split kiểm tra trường bắt buộc

Thêm `Conditional Split` và đổi tên:

```text
CS - Validate Required Fields
```

Tạo output `Reject_MissingRequired` với expression:

```text
ISNULL(clean_invoice_id) || LEN(clean_invoice_id) == 0
|| ISNULL(clean_ordered_on) || LEN(clean_ordered_on) == 0
|| ISNULL(clean_store_no) || LEN(clean_store_no) == 0
|| ISNULL(clean_store_name) || LEN(clean_store_name) == 0
|| ISNULL(clean_category_name) || LEN(clean_category_name) == 0
|| ISNULL(clean_vendor_number) || LEN(clean_vendor_number) == 0
|| ISNULL(clean_vendor_name) || LEN(clean_vendor_name) == 0
|| ISNULL(clean_item_no) || LEN(clean_item_no) == 0
|| ISNULL(clean_im_desc) || LEN(clean_im_desc) == 0
|| ISNULL(clean_bottle_volume_ml) || LEN(clean_bottle_volume_ml) == 0
|| ISNULL(clean_sales_bottles) || LEN(clean_sales_bottles) == 0
|| ISNULL(clean_sales_dollars) || LEN(clean_sales_dollars) == 0
|| ISNULL(clean_sales_liters) || LEN(clean_sales_liters) == 0
```

Đổi tên default output thành:

```text
ReadyForTypeCheck
```

Không đưa `clean_store_city` và `clean_county_name` vào điều kiện Reject vì hai trường này được phép thiếu.

### 10.4. Data Conversion kiểm tra ngày và số

Nối output `ReadyForTypeCheck` vào `Data Conversion`, sau đó đổi tên component thành:

```text
DC - Validate Data Types
```

Cấu hình:

| Input column | Output alias | Data type |
|---|---|---|
| `clean_ordered_on` | `valid_ordered_on` | database date `[DT_DBDATE]` |
| `clean_bottle_volume_ml` | `valid_bottle_volume_ml` | four-byte signed integer `[DT_I4]` |
| `clean_sales_bottles` | `valid_sales_bottles` | four-byte signed integer `[DT_I4]` |
| `clean_sales_dollars` | `valid_sales_dollars` | numeric `[DT_NUMERIC]`, precision 19, scale 2 |
| `clean_sales_liters` | `valid_sales_liters` | numeric `[DT_NUMERIC]`, precision 19, scale 3 |

Trong `Configure Error Output`, đặt cho các cột:

```text
Error      = Redirect row
Truncation = Redirect row
```

Nếu có thuộc tính `LocaleID` trên Data Flow hoặc component, đặt:

```text
1033 - English (United States)
```

Dữ liệu nguồn dùng ngày `YYYY-MM-DD` và dấu chấm cho số thập phân.

### 10.5. OLE DB Destination nạp Raw

Nối output thành công của Data Conversion vào `OLE DB Destination` và đặt tên:

```text
DST - LiquorSalesRaw
```

Cấu hình:

| Thuộc tính | Giá trị |
|---|---|
| OLE DB connection manager | `CM_IowaLiquorDW` |
| Data access mode | Table or view - fast load |
| Destination table | `[stg].[LiquorSalesRaw]` |
| Table lock | Bật |
| Rows per batch | `100000` |
| Maximum insert commit size | `100000` |

Ánh xạ các cột chuỗi đã làm sạch:

| Input | Destination |
|---|---|
| `clean_invoice_id` | `invoice_id` |
| `clean_ordered_on` | `ordered_on` |
| `clean_store_no` | `store_no` |
| `clean_store_name` | `store_name` |
| `clean_store_city` | `store_city` |
| `clean_county_name` | `county_name` |
| `clean_category_name` | `category_name` |
| `clean_vendor_number` | `vendor_number` |
| `clean_vendor_name` | `vendor_name` |
| `clean_item_no` | `item_no` |
| `clean_im_desc` | `im_desc` |
| `clean_bottle_volume_ml` | `bottle_volume_ml` |
| `clean_sales_bottles` | `sales_bottles` |
| `clean_sales_dollars` | `sales_dollars` |
| `clean_sales_liters` | `sales_liters` |

Không ánh xạ các cột `valid_*`; chúng chỉ dùng để xác nhận dữ liệu chuyển kiểu thành công.

Nếu OLE DB Destination báo lỗi khác code page, mở `Advanced Editor` và đặt:

```text
AlwaysUseDefaultCodePage = True
DefaultCodePage = 65001
```

## 11. Xử lý dòng Reject

### 11.1. Dòng thiếu trường bắt buộc

Từ output `Reject_MissingRequired`, thêm Derived Column tên:

```text
DRV - Missing Reason
```

Tạo ba cột:

```text
reject_reason       = (DT_STR,100,65001)"MISSING_REQUIRED_FIELD"
reject_error_code   = (DT_I4)0
reject_error_column = (DT_I4)0
```

Nối tới `OLE DB Destination` tên `DST - Reject Missing` và chọn bảng:

```text
[stg].[LiquorSalesReject]
```

Ánh xạ:

- `clean_source_file` vào `source_file`.
- `reject_reason` vào `reject_reason`.
- `reject_error_code` vào `error_code`.
- `reject_error_column` vào `error_column`.
- Mười lăm cột `clean_*` vào các cột dữ liệu tương ứng.

### 11.2. Dòng sai kiểu dữ liệu

Kéo mũi tên đỏ từ `DC - Validate Data Types` sang một Derived Column tên:

```text
DRV - Conversion Reason
```

Tạo cột:

```text
reject_reason = (DT_STR,100,65001)"INVALID_DATE_OR_NUMERIC_VALUE"
```

Nối đến `OLE DB Destination` tên:

```text
DST - Reject Conversion
```

Chọn bảng `[stg].[LiquorSalesReject]` và ánh xạ:

| Input | Destination |
|---|---|
| `clean_source_file` | `source_file` |
| `reject_reason` | `reject_reason` |
| `ErrorCode` | `error_code` |
| `ErrorColumn` | `error_column` |
| Các cột `clean_*` | Các cột dữ liệu tương ứng |

Không bật `Table lock` cho hai destination Reject.

## 12. Chạy package

Trước khi chạy, kiểm tra:

- Thư mục `data` có đủ 5 file CSV.
- Flat File Connection Manager nhận đủ 23 cột.
- `Text qualifier` là dấu nháy kép.
- `User::FilePath` được map tại index `0` của Foreach Loop.
- OLE DB Connection Manager trỏ tới database `IowaLiquorDW`.
- Destination Raw đã map đủ 15 cột.
- Các error output của Data Conversion dùng `Redirect row`.
- Không có task Dimension hoặc Fact trong package này.

Nhấn `F5` để chạy package.

Ở vòng lặp cuối, Data Flow có thể chỉ hiển thị `585.514` dòng. Đây là số dòng của file thứ năm, không phải tổng số dòng của cả năm file.

## 13. Kiểm tra kết quả

### 13.1. Tổng số dòng

```sql
USE IowaLiquorDW;
GO

SELECT
    COUNT_BIG(*) AS loaded_rows,
    COUNT_BIG(DISTINCT invoice_id) AS unique_invoice_ids,
    MIN(TRY_CONVERT(date, ordered_on, 23)) AS first_date,
    MAX(TRY_CONVERT(date, ordered_on, 23)) AS last_date
FROM stg.LiquorSalesRaw;

SELECT COUNT_BIG(*) AS rejected_rows
FROM stg.LiquorSalesReject;
```

Kết quả mong đợi:

| Chỉ tiêu | Kết quả |
|---|---:|
| `loaded_rows` | 2.590.975 |
| `unique_invoice_ids` | 2.590.975 |
| `first_date` | 2024-01-01 |
| `last_date` | 2024-12-31 |
| `rejected_rows` | 0 |

### 13.2. Kiểm tra dữ liệu thiếu vị trí

```sql
SELECT COUNT_BIG(*) AS missing_location_rows
FROM stg.LiquorSalesRaw
WHERE store_city IS NULL
   OR county_name IS NULL;
```

Kết quả dự kiến:

```text
422
```

### 13.3. Kiểm tra giá trị chưa được TRIM

```sql
SELECT COUNT_BIG(*) AS rows_with_outer_spaces
FROM stg.LiquorSalesRaw
WHERE invoice_id <> LTRIM(RTRIM(invoice_id))
   OR store_no <> LTRIM(RTRIM(store_no))
   OR vendor_number <> LTRIM(RTRIM(vendor_number))
   OR item_no <> LTRIM(RTRIM(item_no));
```

Kết quả mong đợi:

```text
0
```

### 13.4. Kiểm tra dữ liệu số và ngày

```sql
SELECT
    SUM(CASE
        WHEN TRY_CONVERT(date, ordered_on, 23) IS NULL
        THEN 1 ELSE 0
    END) AS invalid_date,

    SUM(CASE
        WHEN TRY_CONVERT(int, bottle_volume_ml) IS NULL
        THEN 1 ELSE 0
    END) AS invalid_bottle_volume,

    SUM(CASE
        WHEN TRY_CONVERT(int, sales_bottles) IS NULL
        THEN 1 ELSE 0
    END) AS invalid_sales_bottles,

    SUM(CASE
        WHEN TRY_CONVERT(decimal(19,2), sales_dollars) IS NULL
        THEN 1 ELSE 0
    END) AS invalid_sales_dollars,

    SUM(CASE
        WHEN TRY_CONVERT(decimal(19,3), sales_liters) IS NULL
        THEN 1 ELSE 0
    END) AS invalid_sales_liters
FROM stg.LiquorSalesRaw;
```

Các giá trị trên phải bằng `0`.

## 14. Tiêu chí hoàn thành bước Raw

Bước Raw hoàn thành khi đáp ứng đủ các điều kiện sau:

- SSIS đọc trực tiếp từ `C:\coding_space\study\IS217\data`.
- Không gọi `clean_data.py`.
- Không sử dụng thư mục `cleaned_data`.
- Foreach Loop đọc đủ 5 CSV.
- Flat File Source nhận đủ 23 cột nguồn.
- Derived Column tạo đủ 15 cột sạch.
- Dòng thiếu `store_city` hoặc `county_name` vẫn được giữ.
- Dòng có doanh thu hoặc số lượng âm vẫn được giữ.
- Raw có 2.590.975 dòng.
- `invoice_id` có 2.590.975 giá trị khác nhau.
- Không có dữ liệu ngày hoặc số sai định dạng trong Raw.
- Package chạy lại vẫn cho đúng số dòng nhờ bước `TRUNCATE`.
- Chưa nạp bất kỳ bảng Dimension hoặc Fact nào.

## 15. Bước tiếp theo

Sau khi hoàn thành và kiểm tra Raw, thứ tự ETL tiếp theo là:

```text
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

Trước khi nạp Dimension và Fact, cần thống nhất tên khóa sản phẩm giữa DBML và SQL. DBML hiện dùng `item_key`, trong khi script SQL hiện tại dùng `product_key`. Nên chọn một tên duy nhất; `product_key` phù hợp với tên bảng `DIM_PRODUCT`.
