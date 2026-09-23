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

## 4. Tạo database và toàn bộ bảng ngay trong SSIS

Không cần mở SSMS để chạy script khởi tạo. Toàn bộ lệnh tạo database, drop bảng và tạo lại bảng sẽ được đặt trong các `Execute SQL Task` của package `00_Setup_Database.dtsx`.

> Package setup có tính phá hủy dữ liệu vì nó drop toàn bộ bảng trước khi tạo lại. Chỉ chạy package này khi muốn khởi tạo hoặc reset hoàn toàn Data Warehouse. Không đặt nó vào lịch ETL chạy hằng ngày.

### 4.1. Tạo project SSIS và package setup

Nếu chưa có project SSIS:

1. Mở Visual Studio.
2. Chọn `Create a new project`.
3. Chọn `Integration Services Project`.
4. Đặt tên project là `IS217_ETL`.
5. Chọn thư mục `C:\coding_space\study\IS217`.

Trong `Solution Explorer`:

1. Nhấn phải chuột vào `SSIS Packages`.
2. Chọn `New SSIS Package`.
3. Đổi tên package thành `00_Setup_Database.dtsx`.
4. Đặt `DelayValidation = True` cho package.
5. Giữ `TransactionOption = Supported` hoặc `NotSupported`; không đặt package tạo database trong transaction bắt buộc.

### 4.2. Tạo connection tới database `master`

Trong vùng `Connection Managers`, tạo một OLE DB Connection Manager tên:

```text
CM_Master
```

Cấu hình:

| Thuộc tính | Giá trị |
|---|---|
| Provider | Microsoft OLE DB Driver 19 for SQL Server |
| Server | SQL Server instance đang sử dụng, ví dụ `LAPTOP-UBHQJIPO\IS217SQL` |
| Authentication | Windows Authentication |
| Database | `master` |
| Trust Server Certificate | `True` nếu môi trường local yêu cầu |

Tất cả Execute SQL Task trong package setup sử dụng `CM_Master`. Các task tạo bảng sẽ bắt đầu bằng `USE IowaLiquorDW;` để chuyển đúng database.

### 4.3. Task 01 - Tạo database nếu chưa tồn tại

Thêm `Execute SQL Task`, đổi tên thành:

```text
01 - Create Database If Missing
```

Cấu hình:

```text
Connection      = CM_Master
SQLSourceType   = Direct input
ResultSet       = None
DelayValidation = True
```

SQL statement:

```sql
IF DB_ID('IowaLiquorDW') IS NULL
BEGIN
    EXEC('CREATE DATABASE IowaLiquorDW');
END;
```

### 4.4. Task 02 - Drop các bảng cũ

Thêm Execute SQL Task tên:

```text
02 - Drop Existing Tables
```

Nối mũi tên xanh từ task 01 tới task 02. Chọn `CM_Master` và nhập:

```sql
USE IowaLiquorDW;

-- Fact phải được drop trước vì đang tham chiếu các Dimension.
DROP TABLE IF EXISTS dbo.FACT_LIQUOR_SALES;

DROP TABLE IF EXISTS dbo.DIM_VENDOR;
DROP TABLE IF EXISTS dbo.DIM_PRODUCT;
DROP TABLE IF EXISTS dbo.DIM_STORE;
DROP TABLE IF EXISTS dbo.DIM_DATE;

DROP TABLE IF EXISTS stg.LiquorSalesReject;
DROP TABLE IF EXISTS stg.LiquorSalesRaw;
```

Không đổi thứ tự để drop Dimension trước Fact, vì khóa ngoại từ Fact có thể làm lệnh thất bại.

### 4.5. Task 03 - Tạo schema staging, Raw và Reject

Thêm Execute SQL Task tên:

```text
03 - Create Staging Tables
```

Nối từ task 02 và nhập:

```sql
USE IowaLiquorDW;

IF SCHEMA_ID('stg') IS NULL
BEGIN
    EXEC('CREATE SCHEMA stg');
END;

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

CREATE TABLE stg.LiquorSalesReject
(
    reject_id         bigint IDENTITY(1,1) NOT NULL,
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
        DEFAULT SYSDATETIME(),

    CONSTRAINT PK_LiquorSalesReject
        PRIMARY KEY (reject_id)
);
```

### 4.6. Task 04 - Tạo các bảng Dimension

Thêm Execute SQL Task tên:

```text
04 - Create Dimension Tables
```

Nối từ task 03 và nhập:

```sql
USE IowaLiquorDW;

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
```

Quy ước `date_key` là số `YYYYMMDD`, ví dụ `2024-01-31` tương ứng `20240131`. Các cột `store_key`, `product_key` và `vendor_key` là surrogate key được SQL Server tự sinh.

Các ràng buộc `UNIQUE` chỉ ảnh hưởng khi nạp dữ liệu vào Dimension, không ảnh hưởng bước nạp Raw. Trước khi nạp `DIM_STORE` hoặc `DIM_PRODUCT`, cần xử lý trường hợp một mã có nhiều tên hoặc thuộc tính.

### 4.7. Task 05 - Tạo bảng Fact

Thêm Execute SQL Task tên:

```text
05 - Create Fact Table
```

Nối từ task 04 và nhập:

```sql
USE IowaLiquorDW;

CREATE TABLE dbo.FACT_LIQUOR_SALES
(
    sales_key       bigint IDENTITY(1,1) NOT NULL,
    invoice_id      varchar(30)           NOT NULL,

    date_key        int                   NOT NULL,
    store_key       int                   NOT NULL,
    product_key     int                   NOT NULL,
    vendor_key      int                   NOT NULL,

    sales_bottles   int                   NOT NULL,
    sales_dollars   decimal(19,2)         NOT NULL,
    sales_liters    decimal(19,3)         NOT NULL,

    CONSTRAINT PK_FACT_LIQUOR_SALES
        PRIMARY KEY (sales_key),

    CONSTRAINT UQ_FACT_LIQUOR_SALES_invoice
        UNIQUE (invoice_id),

    CONSTRAINT FK_FACT_DATE
        FOREIGN KEY (date_key)
        REFERENCES dbo.DIM_DATE(date_key),

    CONSTRAINT FK_FACT_STORE
        FOREIGN KEY (store_key)
        REFERENCES dbo.DIM_STORE(store_key),

    CONSTRAINT FK_FACT_PRODUCT
        FOREIGN KEY (product_key)
        REFERENCES dbo.DIM_PRODUCT(product_key),

    CONSTRAINT FK_FACT_VENDOR
        FOREIGN KEY (vendor_key)
        REFERENCES dbo.DIM_VENDOR(vendor_key)
);
```

### 4.8. Task 06 - Kiểm tra schema tự động

Thêm Execute SQL Task tên:

```text
06 - Verify Created Tables
```

Nối từ task 05 và nhập:

```sql
USE IowaLiquorDW;

IF OBJECT_ID('stg.LiquorSalesRaw', 'U') IS NULL
   OR OBJECT_ID('stg.LiquorSalesReject', 'U') IS NULL
   OR OBJECT_ID('dbo.DIM_DATE', 'U') IS NULL
   OR OBJECT_ID('dbo.DIM_STORE', 'U') IS NULL
   OR OBJECT_ID('dbo.DIM_PRODUCT', 'U') IS NULL
   OR OBJECT_ID('dbo.DIM_VENDOR', 'U') IS NULL
   OR OBJECT_ID('dbo.FACT_LIQUOR_SALES', 'U') IS NULL
BEGIN
    THROW 50001, 'Database schema was not created completely.', 1;
END;
```

Nếu thiếu bất kỳ bảng nào, task sẽ thất bại và package không báo thành công sai.

Control Flow hoàn chỉnh của package setup:

```text
01 - Create Database If Missing
              |
              v
02 - Drop Existing Tables
              |
              v
03 - Create Staging Tables
              |
              v
04 - Create Dimension Tables
              |
              v
05 - Create Fact Table
              |
              v
06 - Verify Created Tables
```

### 4.9. Không dùng `GO` trong Execute SQL Task

Không đặt `GO` vào SQL Statement của Execute SQL Task. `GO` là dấu phân cách batch của SSMS và `sqlcmd`, không phải câu lệnh T-SQL mà OLE DB gửi cho SQL Server.

Nếu cần tách batch, hãy tạo nhiều Execute SQL Task như cấu trúc ở trên.

## 5. Tạo package nạp Raw

Sau khi package setup chạy thành công, tạo package thứ hai:

1. Nhấn phải chuột vào `SSIS Packages`.
2. Chọn `New SSIS Package`.
3. Đổi tên thành `01_Load_Raw_SSIS.dtsx`.
4. Đặt `DelayValidation = True`.

Hai package có nhiệm vụ khác nhau:

| Package | Khi nào chạy |
|---|---|
| `00_Setup_Database.dtsx` | Chỉ chạy khi cần tạo mới hoặc reset toàn bộ Data Warehouse |
| `01_Load_Raw_SSIS.dtsx` | Chạy để làm sạch CSV và nạp lại Raw |

Không cần gọi Python hoặc chạy script SQL thủ công bên ngoài SSIS.

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

## 8. Tạo Flat File Connection Manager ở package scope

`User::FilePath` là biến thuộc package `01_Load_Raw_SSIS.dtsx`. Vì vậy Flat File Connection Manager sử dụng biến này cũng phải được tạo bên trong package, không tạo ở project scope.

Phân biệt hai vị trí:

```text
Đúng:
Mở 01_Load_Raw_SSIS.dtsx
└── vùng Connection Managers ở dưới package designer
    └── FF_Iowa_Source_Package

Không dùng cho trường hợp này:
Solution Explorer
└── Connection Managers
    └── FF_Iowa_Source.conmgr
```

Nếu connection xuất hiện thành file `.conmgr` trong Solution Explorer thì đó là project-level Connection Manager. Project-level Connection Manager không được dùng trực tiếp với package variable `User::FilePath` của Foreach Loop.

Thực hiện như sau:

1. Mở `01_Load_Raw_SSIS.dtsx`.
2. Tại vùng `Connection Managers` nằm phía dưới package designer, nhấn phải chuột.
3. Chọn `New Flat File Connection`.
4. Đặt tên `FF_Iowa_Source_Package`.
5. Tại ô `File name`, chọn file CSV vật lý làm file mẫu:

```text
C:\coding_space\study\IS217\data\iowa_liquor_sales_2024_1261_rows_part_0001.csv
```

Ở bước này, ô `File name` bắt buộc chứa đường dẫn thật. Không nhập `@[User::FilePath]` vào ô `File name`.

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

### 8.4. Kiểm tra file mẫu và lưu metadata

Trước khi gắn connection với biến:

1. Mở trang `Preview` của Flat File Connection Manager.
2. Xác nhận Preview hiển thị dữ liệu thật.
3. Xác nhận trang `Columns` có đúng 23 cột.
4. Xác nhận trang `Advanced` có đúng tên, kiểu và độ rộng của 23 cột.
5. Bấm `OK` để lưu Connection Manager.
6. Nhấn `Ctrl + S` để lưu package.

Tại thời điểm này, ConnectionString cơ sở vẫn phải là:

```text
C:\coding_space\study\IS217\data\iowa_liquor_sales_2024_1261_rows_part_0001.csv
```

Chưa thêm expression ở bước này. Cần cấu hình Flat File Source và tạo output metadata trước, sau đó mới gắn `ConnectionString` với `User::FilePath` tại mục 10.1.1.

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

1. Thêm `Flat File Source` và đổi tên:

```text
SRC - Original CSV
```

2. Nhấp đúp vào `SRC - Original CSV`.
3. Trong trang `Connection Manager`, chọn package-level connection:

```text
Flat file connection manager = FF_Iowa_Source_Package
```

4. Mở trang `Columns` và xác nhận cả Input Column lẫn Output Alias có đủ 23 cột.
5. Bấm `OK` để Flat File Source tạo output metadata.
6. Nhấn `Ctrl + S` để lưu package.

Không mở Derived Column trước khi Flat File Source hiển thị đủ 23 cột. Preview thành công ở Connection Manager chưa đủ; Flat File Source cũng phải được chọn đúng Connection Manager và lưu output columns.

Nếu Flat File Source đã được tạo trước khi Connection Manager hoạt động và trang `Columns` vẫn trống:

1. Xóa riêng Flat File Source cũ.
2. Không xóa `FF_Iowa_Source_Package`.
3. Tạo Flat File Source mới.
4. Chọn lại `FF_Iowa_Source_Package`.
5. Kiểm tra đủ 23 cột và bấm `OK`.

Các cột không dùng sẽ được bỏ bằng cách không ánh xạ chúng vào OLE DB Destination.

#### 10.1.1. Gắn package-level connection với `User::FilePath`

Chỉ thực hiện bước này sau khi Flat File Source đã có đủ 23 output columns:

1. Chọn `FF_Iowa_Source_Package` tại vùng Connection Managers phía dưới package designer.
2. Nhấn `F4` để mở cửa sổ Properties.
3. Tại thuộc tính `Expressions`, bấm nút `...`.
4. Thêm expression:

| Property | Expression |
|---|---|
| `ConnectionString` | `@[User::FilePath]` |

5. Bấm `Evaluate Expression`.
6. Kết quả phải là đường dẫn CSV thật:

```text
C:\coding_space\study\IS217\data\iowa_liquor_sales_2024_1261_rows_part_0001.csv
```

7. Bấm `OK` và đặt:

```text
DelayValidation = True
```

Không nhập chuỗi `@[User::FilePath]` trực tiếp vào ô `File name`. File mẫu vẫn được giữ làm ConnectionString cơ sở để SSIS có thể thiết kế và làm mới metadata; expression chỉ ghi đè đường dẫn khi package chạy.

Luồng hoạt động:

```text
Lúc thiết kế:
FF_Iowa_Source_Package đọc part_0001.csv để tạo metadata 23 cột

Lúc chạy:
Foreach gán file hiện tại vào User::FilePath
        |
        v
Expression cập nhật ConnectionString
        |
        v
Flat File Source đọc file hiện tại
```

### 10.2. Derived Column làm sạch

`Derived Column` là transformation xử lý từng dòng dữ liệu. Nó không sửa file CSV gốc và cũng chưa ghi dữ liệu vào SQL Server. Trong bước này, component nhận 23 cột từ Flat File Source, giữ nguyên các cột nguồn và tạo thêm các cột đã làm sạch có tiền tố `clean_`.

Ví dụ:

```text
Dữ liệu nguồn                 Cột mới sau Derived Column
store_no  = "  2191 "         clean_store_no   = "2191"
store_name = " KEOKUK "       clean_store_name = "KEOKUK"
store_city = ""               clean_store_city = NULL
```

Các cột nguồn vẫn còn trong pipeline. Khi nạp Raw, chỉ ánh xạ các cột `clean_*` và bỏ qua tám cột không sử dụng.

#### 10.2.1. Thêm component

1. Trong `SSIS Toolbox`, kéo `Derived Column` vào Data Flow.
2. Nối mũi tên xanh từ `SRC - Original CSV` vào component này.
3. Đổi tên component thành:

```text
DRV - Clean Columns
```

4. Nhấp đúp vào `DRV - Clean Columns` để mở `Derived Column Transformation Editor`.
5. Kiểm tra vùng `Available Input Columns` có đủ 23 cột nguồn.
6. Với mỗi dòng cấu hình bên dưới, tại cột `Derived Column` phải chọn `<add as new column>`. Không chọn thay thế cột nguồn.

Trong SSIS Expression, cấu trúc:

```text
điều_kiện ? giá_trị_khi_đúng : giá_trị_khi_sai
```

tương đương với `IF ... ELSE`. Các hàm và kiểu được dùng gồm:

| Thành phần | Ý nghĩa |
|---|---|
| `ISNULL(column)` | Kiểm tra giá trị SQL/SSIS NULL |
| `TRIM(column)` | Bỏ khoảng trắng ở đầu và cuối chuỗi |
| `LEN(column)` | Đếm số ký tự |
| `DT_STR` | Chuỗi non-Unicode trong pipeline |
| `65001` | Code page UTF-8 |
| `NULL(DT_STR,n,65001)` | Tạo NULL với kiểu và độ rộng cụ thể |

#### 10.2.2. Quy tắc cho trường bắt buộc

Các trường bắt buộc dùng mẫu sau:

```text
ISNULL(cột_nguồn)
? (DT_STR,độ_rộng,65001)""
: (DT_STR,độ_rộng,65001)TRIM(cột_nguồn)
```

Ví dụ với `invoice_id`:

```text
ISNULL(invoice_id)
? (DT_STR,30,65001)""
: (DT_STR,30,65001)TRIM(invoice_id)
```

Nếu nguồn là `NULL`, expression trả về chuỗi rỗng. Nếu nguồn có dữ liệu, expression loại khoảng trắng đầu và cuối. Sau đó Conditional Split sẽ chuyển dòng sang Reject nếu kết quả vẫn rỗng.

Không chuyển `store_no`, `vendor_number` hoặc `item_no` sang số vì các mã này có thể có số `0` ở đầu.

#### 10.2.3. Quy tắc cho trường được phép thiếu

`store_city` và `county_name` được phép thiếu. Với hai cột này, cả NULL, chuỗi rỗng và chuỗi chỉ có khoảng trắng đều được chuẩn hóa thành NULL.

Expression cho `store_city`:

```text
ISNULL(store_city)
? NULL(DT_STR,100,65001)
: (LEN(TRIM(store_city)) == 0
   ? NULL(DT_STR,100,65001)
   : (DT_STR,100,65001)TRIM(store_city))
```

Expression cho `county_name`:

```text
ISNULL(county_name)
? NULL(DT_STR,100,65001)
: (LEN(TRIM(county_name)) == 0
   ? NULL(DT_STR,100,65001)
   : (DT_STR,100,65001)TRIM(county_name))
```

Không chuyển hai trường này thành chuỗi `"Unknown"` tại Raw. Giá trị Unknown chỉ nên được bổ sung khi xây dựng Dimension nếu nghiệp vụ yêu cầu.

#### 10.2.4. Nhập đầy đủ 15 expression

Tạo lần lượt các dòng sau trong `Derived Column Transformation Editor`. Có thể nhập expression trên một dòng; việc xuống dòng trong bảng chỉ nhằm giúp đọc dễ hơn.

| Derived Column Name | Derived Column | Expression |
|---|---|---|
| `clean_invoice_id` | `<add as new column>` | `ISNULL(invoice_id) ? (DT_STR,30,65001)"" : (DT_STR,30,65001)TRIM(invoice_id)` |
| `clean_ordered_on` | `<add as new column>` | `ISNULL(ordered_on) ? (DT_STR,20,65001)"" : (DT_STR,20,65001)TRIM(ordered_on)` |
| `clean_store_no` | `<add as new column>` | `ISNULL(store_no) ? (DT_STR,20,65001)"" : (DT_STR,20,65001)TRIM(store_no)` |
| `clean_store_name` | `<add as new column>` | `ISNULL(store_name) ? (DT_STR,255,65001)"" : (DT_STR,255,65001)TRIM(store_name)` |
| `clean_store_city` | `<add as new column>` | `ISNULL(store_city) ? NULL(DT_STR,100,65001) : (LEN(TRIM(store_city)) == 0 ? NULL(DT_STR,100,65001) : (DT_STR,100,65001)TRIM(store_city))` |
| `clean_county_name` | `<add as new column>` | `ISNULL(county_name) ? NULL(DT_STR,100,65001) : (LEN(TRIM(county_name)) == 0 ? NULL(DT_STR,100,65001) : (DT_STR,100,65001)TRIM(county_name))` |
| `clean_category_name` | `<add as new column>` | `ISNULL(category_name) ? (DT_STR,255,65001)"" : (DT_STR,255,65001)TRIM(category_name)` |
| `clean_vendor_number` | `<add as new column>` | `ISNULL(vendor_number) ? (DT_STR,20,65001)"" : (DT_STR,20,65001)TRIM(vendor_number)` |
| `clean_vendor_name` | `<add as new column>` | `ISNULL(vendor_name) ? (DT_STR,255,65001)"" : (DT_STR,255,65001)TRIM(vendor_name)` |
| `clean_item_no` | `<add as new column>` | `ISNULL(item_no) ? (DT_STR,30,65001)"" : (DT_STR,30,65001)TRIM(item_no)` |
| `clean_im_desc` | `<add as new column>` | `ISNULL(im_desc) ? (DT_STR,500,65001)"" : (DT_STR,500,65001)TRIM(im_desc)` |
| `clean_bottle_volume_ml` | `<add as new column>` | `ISNULL(bottle_volume_ml) ? (DT_STR,30,65001)"" : (DT_STR,30,65001)TRIM(bottle_volume_ml)` |
| `clean_sales_bottles` | `<add as new column>` | `ISNULL(sales_bottles) ? (DT_STR,30,65001)"" : (DT_STR,30,65001)TRIM(sales_bottles)` |
| `clean_sales_dollars` | `<add as new column>` | `ISNULL(sales_dollars) ? (DT_STR,50,65001)"" : (DT_STR,50,65001)TRIM(sales_dollars)` |
| `clean_sales_liters` | `<add as new column>` | `ISNULL(sales_liters) ? (DT_STR,50,65001)"" : (DT_STR,50,65001)TRIM(sales_liters)` |

Độ rộng đầu ra của từng cột phải khớp với bảng Raw:

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

#### 10.2.5. Thêm tên file nguồn

Thêm dòng thứ 16 để biết mỗi bản ghi đến từ file nào:

| Derived Column Name | Derived Column | Expression |
|---|---|---|
| `clean_source_file` | `<add as new column>` | `(DT_STR,500,65001)@[User::FilePath]` |

Biến `User::FilePath` được Foreach Loop cập nhật trước mỗi vòng lặp. Ví dụ giá trị đầu ra:

```text
C:\coding_space\study\IS217\data\iowa_liquor_sales_2024_1261_rows_part_0001.csv
```

`clean_source_file` chỉ được map vào bảng Reject để truy vết lỗi; bảng Raw hiện tại không có cột `source_file`.

#### 10.2.6. Không cần xóa tám cột không sử dụng

Derived Column không có nhiệm vụ xóa cột. Không tạo cột `clean_*` cho tám cột sau:

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

Các cột nguồn này vẫn đi qua pipeline nhưng sẽ tự động bị bỏ khi không được map vào OLE DB Destination.

#### 10.2.7. Kiểm tra Derived Column bằng Data Viewer

Trước khi nối sang Conditional Split, nên kiểm tra kết quả:

1. Nối `DRV - Clean Columns` với `CS - Validate Required Fields`.
2. Nhấn phải chuột vào đường nối màu xanh.
3. Chọn `Enable Data Viewer` hoặc `Data Viewers` -> `Add` -> `Grid` tùy phiên bản Visual Studio.
4. Chạy package với một file mẫu.
5. So sánh các cặp cột:

```text
invoice_id        <-> clean_invoice_id
store_no          <-> clean_store_no
store_city        <-> clean_store_city
county_name       <-> clean_county_name
sales_dollars     <-> clean_sales_dollars
```

Kết quả đúng khi:

- Không còn khoảng trắng ở đầu hoặc cuối các cột `clean_*`.
- Mã `065` vẫn là `065`, không trở thành `65`.
- `store_city` và `county_name` trống được hiển thị là NULL.
- Các giá trị âm như `-12` hoặc `-144.00` vẫn được giữ.
- Cột `clean_source_file` chứa đúng file đang được Foreach Loop xử lý.

Sau khi kiểm tra xong, có thể tắt Data Viewer để package chạy nhanh hơn với toàn bộ 2.590.975 dòng.

#### 10.2.8. Lỗi thường gặp

| Hiện tượng | Nguyên nhân và cách xử lý |
|---|---|
| Expression chuyển màu đỏ | Kiểm tra đủ dấu ngoặc, dấu `?`, dấu `:` và dấu nháy kép |
| Cột mã mất số `0` đầu | Flat File Source đang nhận dạng cột là số; đổi về `DT_STR` |
| Lỗi khác code page | Bảo đảm Flat File Source và Derived Column đều dùng `65001` |
| Lỗi truncation | Tăng độ rộng metadata của cột nguồn và cast trong expression |
| Chuỗi rỗng không thành NULL | Chỉ áp dụng expression NULL dành cho `store_city` và `county_name` |
| Khoảng trắng giữa tên vẫn còn | `TRIM` chỉ bỏ khoảng trắng đầu/cuối; không tự sửa khoảng trắng bên trong tên |

Sau khi bấm `OK`, output của `DRV - Clean Columns` phải có 23 cột nguồn, 15 cột sạch và một cột `clean_source_file`. Bước tiếp theo là Conditional Split kiểm tra trường bắt buộc.

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

Chạy hai package theo thứ tự sau:

1. Nhấn phải chuột vào `00_Setup_Database.dtsx` và chọn `Execute Package`. Chỉ thực hiện bước này khi cần tạo mới hoặc reset toàn bộ schema.
2. Sau khi toàn bộ task setup chuyển màu xanh, nhấn phải chuột vào `01_Load_Raw_SSIS.dtsx` và chọn `Execute Package`.

Không chạy lại package setup sau khi đã nạp Dimension hoặc Fact, trừ khi chấp nhận xóa toàn bộ dữ liệu đó.

Trước khi chạy package Load Raw, kiểm tra:

- Thư mục `data` có đủ 5 file CSV.
- Flat File Connection Manager nhận đủ 23 cột.
- `Text qualifier` là dấu nháy kép.
- `User::FilePath` được map tại index `0` của Foreach Loop.
- OLE DB Connection Manager trỏ tới database `IowaLiquorDW`.
- Destination Raw đã map đủ 15 cột.
- Các error output của Data Conversion dùng `Redirect row`.
- Không có task Dimension hoặc Fact trong package này.

Nhấn `F5` nếu `01_Load_Raw_SSIS.dtsx` đang được chọn làm startup package.

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

Trước khi nạp dữ liệu vào Dimension và Fact, cần thống nhất tên khóa sản phẩm giữa DBML và package setup. DBML hiện dùng `item_key`, trong khi bảng được tạo bởi `00_Setup_Database.dtsx` dùng `product_key`. Nên cập nhật DBML sang `product_key` để phù hợp với tên bảng `DIM_PRODUCT`.
