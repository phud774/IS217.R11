# Hướng dẫn nạp Dimension và Fact từ bảng Raw bằng SSIS

## 1. Mục tiêu

Tài liệu này tiếp nối file `HUONG_DAN_SSIS_CLEAN_VA_LOAD_RAW.md` sau khi dữ liệu đã được làm sạch và nạp vào:

```text
stg.LiquorSalesRaw
```

Mục tiêu của giai đoạn này là:

1. Chuyển dữ liệu chuỗi trong Raw sang đúng kiểu `date`, `int` và `decimal`.
2. Nạp bốn bảng Dimension:
   - `dbo.DIM_DATE`
   - `dbo.DIM_STORE`
   - `dbo.DIM_PRODUCT`
   - `dbo.DIM_VENDOR`
3. Tra cứu surrogate key của từng Dimension.
4. Nạp `dbo.FACT_LIQUOR_SALES`.
5. Chuyển các dòng không hợp lệ hoặc Lookup không thành công sang bảng Reject.
6. Kiểm tra số dòng và tổng các measure sau khi hoàn tất.

Tài liệu sử dụng chiến lược **full load** phù hợp với project hiện tại: Raw được nạp lại đầy đủ, sau đó Dimension và Fact được xóa dữ liệu cũ và nạp lại. Package setup không được chạy hằng ngày vì package đó drop toàn bộ bảng.

## 2. Điều kiện trước khi thực hiện

Chỉ bắt đầu phần này khi các điều kiện sau đã đúng:

- Database `IowaLiquorDW` đã tồn tại.
- `stg.LiquorSalesRaw` có `2.590.975` dòng.
- `invoice_id` có `2.590.975` giá trị khác nhau.
- Các truy vấn `TRY_CONVERT` cho ngày và số không phát hiện dữ liệu sai định dạng.
- Bốn bảng Dimension và bảng Fact đã được tạo nhưng đang rỗng.
- OLE DB Connection Manager kết nối được tới `IowaLiquorDW`.

Kiểm tra nhanh:

```sql
USE IowaLiquorDW;

SELECT COUNT_BIG(*) AS raw_rows
FROM stg.LiquorSalesRaw;

SELECT
    SUM(CASE WHEN TRY_CONVERT(date, ordered_on, 23) IS NULL THEN 1 ELSE 0 END) AS invalid_date,
    SUM(CASE WHEN TRY_CONVERT(int, bottle_volume_ml) IS NULL THEN 1 ELSE 0 END) AS invalid_volume,
    SUM(CASE WHEN TRY_CONVERT(int, sales_bottles) IS NULL THEN 1 ELSE 0 END) AS invalid_bottles,
    SUM(CASE WHEN TRY_CONVERT(decimal(19,2), sales_dollars) IS NULL THEN 1 ELSE 0 END) AS invalid_dollars,
    SUM(CASE WHEN TRY_CONVERT(decimal(19,3), sales_liters) IS NULL THEN 1 ELSE 0 END) AS invalid_liters
FROM stg.LiquorSalesRaw;
```

Kết quả mong đợi:

| Chỉ tiêu | Giá trị |
|---|---:|
| `raw_rows` | 2.590.975 |
| Tất cả cột `invalid_*` | 0 |

## 3. Kiến trúc ETL

```text
stg.LiquorSalesRaw
        |
        +--> 02_Load_Dimensions.dtsx
        |       +--> DIM_DATE
        |       +--> DIM_STORE
        |       +--> DIM_PRODUCT
        |       +--> DIM_VENDOR
        |
        +--> 03_Load_Fact.dtsx
                |
                +--> Conditional Split
                |       +--> dòng sai -> stg.LiquorSalesReject
                |       |
                |       +--> dòng hợp lệ
                |               |
                |               +--> Lookup DIM_DATE
                |               +--> Lookup DIM_STORE
                |               +--> Lookup DIM_PRODUCT
                |               +--> Lookup DIM_VENDOR
                |                       |
                |                       +--> FACT_LIQUOR_SALES
                |                       +--> no match -> Reject
                |
                +--> kiểm tra kết quả
```

Thứ tự chạy bắt buộc:

```text
Load Raw -> Load Dimensions -> Load Fact
```

Fact không được nạp trước Dimension vì các khóa ngoại chưa tồn tại.

## 4. Quy tắc dữ liệu

### 4.1. Business key và surrogate key

| Dimension | Business key từ Raw | Surrogate key trong DW |
|---|---|---|
| `DIM_DATE` | `ordered_on` | `date_key` |
| `DIM_STORE` | `store_no` | `store_key` |
| `DIM_PRODUCT` | `item_no` | `product_key` |
| `DIM_VENDOR` | `vendor_number` | `vendor_key` |

Không dùng `store_no`, `item_no` hoặc `vendor_number` làm khóa ngoại trực tiếp trong Fact.

### 4.2. Quy ước `date_key`

`date_key` dùng định dạng số `YYYYMMDD`:

```text
2024-01-01 -> 20240101
2024-12-31 -> 20241231
```

### 4.3. Xử lý một business key có nhiều thuộc tính

Dữ liệu hiện tại có:

- 20 `store_no` xuất hiện với nhiều tổ hợp tên hoặc vị trí.
- 261 `item_no` xuất hiện với nhiều tổ hợp mô tả, dung tích hoặc category.
- Không có `vendor_number` xung đột tên.

Nếu dùng `SELECT DISTINCT` trên toàn bộ thuộc tính thì một business key có thể sinh nhiều dòng và vi phạm ràng buộc `UNIQUE`. Vì vậy hướng dẫn sử dụng `ROW_NUMBER()` để chọn đúng một bản ghi cho mỗi business key.

Quy tắc Type 1 của lần full load này:

- Chọn bản ghi mới nhất theo `ordered_on`.
- Nếu cùng ngày, chọn bản ghi có `invoice_id` lớn hơn để kết quả luôn xác định.
- Dimension chỉ giữ trạng thái được chọn, không giữ lịch sử thay đổi.

### 4.4. Tên khóa sản phẩm

Database hiện dùng:

```text
product_key
```

DBML cũ có thể đang dùng `item_key`. Trong toàn bộ SSIS và tài liệu này phải dùng thống nhất `product_key`.

## 5. Bổ sung bảng Reject

Trong package setup, bổ sung bảng sau. Nếu chưa muốn sửa package setup, có thể đặt câu lệnh này trong một Execute SQL Task đầu package Fact.

```sql
USE IowaLiquorDW;

IF SCHEMA_ID('stg') IS NULL
BEGIN
    EXEC('CREATE SCHEMA stg');
END;

IF OBJECT_ID('stg.LiquorSalesReject', 'U') IS NULL
BEGIN
    CREATE TABLE stg.LiquorSalesReject
    (
        reject_key      bigint IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_LiquorSalesReject PRIMARY KEY,
        invoice_id      varchar(30)  NULL,
        ordered_on      varchar(20)  NULL,
        store_no        varchar(20)  NULL,
        vendor_number   varchar(20)  NULL,
        item_no         varchar(30)  NULL,
        sales_bottles   varchar(30)  NULL,
        sales_dollars   varchar(50)  NULL,
        sales_liters    varchar(50)  NULL,
        error_reason    varchar(100) NOT NULL,
        rejected_at     datetime2(0) NOT NULL
            CONSTRAINT DF_LiquorSalesReject_rejected_at DEFAULT SYSDATETIME()
    );
END;
```

Nếu package setup có task drop table, thêm dòng sau trước khi drop Raw:

```sql
DROP TABLE IF EXISTS stg.LiquorSalesReject;
```

## 6. Tạo package `02_Load_Dimensions.dtsx`

Trong `Solution Explorer`:

1. Nhấn phải chuột vào `SSIS Packages`.
2. Chọn `New SSIS Package`.
3. Đổi tên thành `02_Load_Dimensions.dtsx`.
4. Đặt `DelayValidation = True`.
5. Tạo hoặc dùng lại OLE DB Connection Manager `CM_IowaLiquorDW`.

Control Flow:

```text
01 - Clear Fact and Dimensions
              |
              v
02 - DFT Load DIM_DATE
              |
              v
03 - DFT Load DIM_STORE
              |
              v
04 - DFT Load DIM_PRODUCT
              |
              v
05 - DFT Load DIM_VENDOR
              |
              v
06 - Verify Dimensions
```

Nối các task bằng precedence constraint màu xanh `Success`.

## 7. Task 01 - Xóa dữ liệu Fact và Dimension cũ

Tạo Execute SQL Task tên:

```text
01 - Clear Fact and Dimensions
```

Cấu hình:

```text
Connection    = CM_IowaLiquorDW
SQLSourceType = Direct input
ResultSet     = None
```

SQL statement:

```sql
DELETE FROM dbo.FACT_LIQUOR_SALES;

DELETE FROM dbo.DIM_VENDOR;
DELETE FROM dbo.DIM_PRODUCT;
DELETE FROM dbo.DIM_STORE;
DELETE FROM dbo.DIM_DATE;

DBCC CHECKIDENT ('dbo.FACT_LIQUOR_SALES', RESEED, 0);
DBCC CHECKIDENT ('dbo.DIM_VENDOR', RESEED, 0);
DBCC CHECKIDENT ('dbo.DIM_PRODUCT', RESEED, 0);
DBCC CHECKIDENT ('dbo.DIM_STORE', RESEED, 0);
```

Fact phải được xóa trước vì đang tham chiếu các Dimension. Không thể `TRUNCATE` trực tiếp một Dimension đang được khóa ngoại tham chiếu.

## 8. Data Flow nạp `DIM_DATE`

### 8.1. Tạo Data Flow

Tạo Data Flow Task tên:

```text
02 - DFT Load DIM_DATE
```

Bên trong Data Flow tạo:

```text
SRC - Distinct Dates -> DST - DIM_DATE
```

### 8.2. OLE DB Source

Chọn `SQL command` và dùng truy vấn:

```sql
WITH src AS
(
    SELECT DISTINCT
        TRY_CONVERT(date, ordered_on, 23) AS ordered_on
    FROM stg.LiquorSalesRaw
    WHERE TRY_CONVERT(date, ordered_on, 23) IS NOT NULL
)
SELECT
    CONVERT(int, CONVERT(char(8), ordered_on, 112)) AS date_key,
    ordered_on,
    CONVERT(tinyint, DAY(ordered_on)) AS day_number,
    CONVERT(tinyint, MONTH(ordered_on)) AS month_number,
    CONVERT(varchar(20), DATENAME(month, ordered_on)) AS month_name,
    CONVERT(tinyint, DATEPART(quarter, ordered_on)) AS quarter_number,
    CONVERT(smallint, YEAR(ordered_on)) AS year_number
FROM src;
```

### 8.3. OLE DB Destination

Cấu hình:

| Thuộc tính | Giá trị |
|---|---|
| Data access mode | Table or view - fast load |
| Destination | `[dbo].[DIM_DATE]` |
| Table lock | Bật |
| Check constraints | Bật |

Ánh xạ bảy cột cùng tên từ Source sang Destination.

Kết quả mong đợi:

```text
316 dòng
```

## 9. Data Flow nạp `DIM_STORE`

Tạo Data Flow Task tên:

```text
03 - DFT Load DIM_STORE
```

Data Flow:

```text
SRC - Latest Store -> DST - DIM_STORE
```

OLE DB Source dùng:

```sql
WITH ranked AS
(
    SELECT
        store_no,
        NULLIF(store_name, '') AS store_name,
        store_city,
        county_name,
        ROW_NUMBER() OVER
        (
            PARTITION BY store_no
            ORDER BY
                TRY_CONVERT(date, ordered_on, 23) DESC,
                invoice_id DESC
        ) AS rn
    FROM stg.LiquorSalesRaw
    WHERE NULLIF(store_no, '') IS NOT NULL
)
SELECT
    store_no,
    store_name,
    store_city,
    county_name
FROM ranked
WHERE rn = 1;
```

OLE DB Destination:

```text
[dbo].[DIM_STORE]
```

Mappings:

| Input | Destination |
|---|---|
| `store_no` | `store_no` |
| `store_name` | `store_name` |
| `store_city` | `store_city` |
| `county_name` | `county_name` |

Không map `store_key`; SQL Server tự sinh cột Identity.

Kết quả mong đợi:

```text
2.162 dòng
```

## 10. Data Flow nạp `DIM_PRODUCT`

Tạo Data Flow Task tên:

```text
04 - DFT Load DIM_PRODUCT
```

OLE DB Source dùng:

```sql
WITH ranked AS
(
    SELECT
        item_no,
        NULLIF(im_desc, '') AS im_desc,
        TRY_CONVERT(int, bottle_volume_ml) AS bottle_volume_ml,
        NULLIF(category_name, '') AS category_name,
        ROW_NUMBER() OVER
        (
            PARTITION BY item_no
            ORDER BY
                TRY_CONVERT(date, ordered_on, 23) DESC,
                invoice_id DESC
        ) AS rn
    FROM stg.LiquorSalesRaw
    WHERE NULLIF(item_no, '') IS NOT NULL
)
SELECT
    item_no,
    im_desc,
    bottle_volume_ml,
    category_name
FROM ranked
WHERE rn = 1;
```

OLE DB Destination:

```text
[dbo].[DIM_PRODUCT]
```

Mappings:

| Input | Destination |
|---|---|
| `item_no` | `item_no` |
| `im_desc` | `im_desc` |
| `bottle_volume_ml` | `bottle_volume_ml` |
| `category_name` | `category_name` |

Không map `product_key`.

Kết quả mong đợi:

```text
5.211 dòng
```

## 11. Data Flow nạp `DIM_VENDOR`

Tạo Data Flow Task tên:

```text
05 - DFT Load DIM_VENDOR
```

OLE DB Source dùng:

```sql
WITH ranked AS
(
    SELECT
        vendor_number,
        NULLIF(vendor_name, '') AS vendor_name,
        ROW_NUMBER() OVER
        (
            PARTITION BY vendor_number
            ORDER BY
                TRY_CONVERT(date, ordered_on, 23) DESC,
                invoice_id DESC
        ) AS rn
    FROM stg.LiquorSalesRaw
    WHERE NULLIF(vendor_number, '') IS NOT NULL
)
SELECT
    vendor_number,
    vendor_name
FROM ranked
WHERE rn = 1;
```

OLE DB Destination:

```text
[dbo].[DIM_VENDOR]
```

Không map `vendor_key`.

Kết quả mong đợi:

```text
239 dòng
```

## 12. Task kiểm tra Dimension

Tạo Execute SQL Task tên:

```text
06 - Verify Dimensions
```

SQL statement:

```sql
IF (SELECT COUNT_BIG(*) FROM dbo.DIM_DATE) <> 316
    THROW 50010, 'DIM_DATE row count is invalid.', 1;

IF (SELECT COUNT_BIG(*) FROM dbo.DIM_STORE) <> 2162
    THROW 50011, 'DIM_STORE row count is invalid.', 1;

IF (SELECT COUNT_BIG(*) FROM dbo.DIM_PRODUCT) <> 5211
    THROW 50012, 'DIM_PRODUCT row count is invalid.', 1;

IF (SELECT COUNT_BIG(*) FROM dbo.DIM_VENDOR) <> 239
    THROW 50013, 'DIM_VENDOR row count is invalid.', 1;
```

Các con số trên đúng với bộ CSV hiện tại. Nếu thay bộ dữ liệu nguồn, thay phần kiểm tra cố định bằng truy vấn so sánh số business key giữa Raw và Dimension.

## 13. Tạo package `03_Load_Fact.dtsx`

1. Tạo SSIS Package mới.
2. Đổi tên thành `03_Load_Fact.dtsx`.
3. Đặt `DelayValidation = True`.
4. Dùng `CM_IowaLiquorDW`.

Control Flow:

```text
01 - Prepare Fact Load
          |
          v
02 - DFT Load Fact
          |
          v
03 - Verify Fact
```

## 14. Task chuẩn bị nạp Fact

Tạo Execute SQL Task:

```text
01 - Prepare Fact Load
```

SQL statement:

```sql
IF NOT EXISTS (SELECT 1 FROM dbo.DIM_DATE)
   OR NOT EXISTS (SELECT 1 FROM dbo.DIM_STORE)
   OR NOT EXISTS (SELECT 1 FROM dbo.DIM_PRODUCT)
   OR NOT EXISTS (SELECT 1 FROM dbo.DIM_VENDOR)
BEGIN
    THROW 50020, 'Dimensions must be loaded before Fact.', 1;
END;

TRUNCATE TABLE dbo.FACT_LIQUOR_SALES;
TRUNCATE TABLE stg.LiquorSalesReject;
```

`FACT_LIQUOR_SALES` có thể truncate vì không có bảng nào khác tham chiếu nó.

## 15. Xây dựng Data Flow nạp Fact

Tạo Data Flow Task:

```text
02 - DFT Load Fact
```

Luồng chính:

```text
SRC - Typed Raw
        |
        v
SPL - Valid Rows
        |
        +--> Invalid Row ----------------------> DST - Reject
        |
        +--> Valid Row
                |
                v
            LKP - Date
                |
                v
            LKP - Store
                |
                v
            LKP - Product
                |
                v
            LKP - Vendor
                |
                v
            DST - FACT_LIQUOR_SALES

Mỗi No Match Output của Lookup
        -> thêm error_reason
        -> Union All
        -> DST - Reject
```

### 15.1. OLE DB Source chuyển kiểu

Đặt tên:

```text
SRC - Typed Raw
```

Chọn `SQL command`:

```sql
SELECT
    invoice_id,
    ordered_on AS ordered_on_raw,
    store_no,
    vendor_number,
    item_no,
    sales_bottles AS sales_bottles_raw,
    sales_dollars AS sales_dollars_raw,
    sales_liters AS sales_liters_raw,

    TRY_CONVERT(date, ordered_on, 23) AS ordered_on,
    TRY_CONVERT(int, sales_bottles) AS sales_bottles,
    TRY_CONVERT(decimal(19,2), sales_dollars) AS sales_dollars,
    TRY_CONVERT(decimal(19,3), sales_liters) AS sales_liters,

    CONVERT(varchar(100),
        CASE
            WHEN NULLIF(invoice_id, '') IS NULL THEN 'EMPTY_INVOICE_ID'
            WHEN TRY_CONVERT(date, ordered_on, 23) IS NULL THEN 'INVALID_ORDERED_ON'
            WHEN NULLIF(store_no, '') IS NULL THEN 'EMPTY_STORE_NO'
            WHEN NULLIF(item_no, '') IS NULL THEN 'EMPTY_ITEM_NO'
            WHEN NULLIF(vendor_number, '') IS NULL THEN 'EMPTY_VENDOR_NUMBER'
            WHEN TRY_CONVERT(int, sales_bottles) IS NULL THEN 'INVALID_SALES_BOTTLES'
            WHEN TRY_CONVERT(decimal(19,2), sales_dollars) IS NULL THEN 'INVALID_SALES_DOLLARS'
            WHEN TRY_CONVERT(decimal(19,3), sales_liters) IS NULL THEN 'INVALID_SALES_LITERS'
            ELSE NULL
        END
    ) AS error_reason
FROM stg.LiquorSalesRaw;
```

`TRY_CONVERT` không làm Data Flow dừng khi gặp giá trị sai. Dòng sai nhận `error_reason` và đi sang Reject.

### 15.2. Conditional Split

Thêm Conditional Split tên:

```text
SPL - Valid Rows
```

Tạo output:

| Output name | Condition |
|---|---|
| `Invalid Row` | `!ISNULL(error_reason)` |

Đặt `Default output name` thành:

```text
Valid Row
```

Nối `Invalid Row` vào destination Reject. Nối `Valid Row` vào Lookup đầu tiên.

## 16. Cấu hình bốn Lookup

Tất cả Lookup sử dụng:

```text
Connection type = OLE DB connection manager
Cache mode      = Full cache
No matching entries = Redirect rows to no match output
```

Full cache phù hợp vì các Dimension chỉ có vài trăm tới vài nghìn dòng.

### 16.1. Lookup Date

Tên component:

```text
LKP - Date
```

Reference table:

```text
[dbo].[DIM_DATE]
```

Join:

```text
Input ordered_on -> Reference ordered_on
```

Chọn output:

```text
date_key
```

### 16.2. Lookup Store

```text
Input store_no -> Reference store_no
Output         -> store_key
```

### 16.3. Lookup Product

```text
Input item_no -> Reference item_no
Output        -> product_key
```

### 16.4. Lookup Vendor

```text
Input vendor_number -> Reference vendor_number
Output               -> vendor_key
```

Nối Match Output theo đúng thứ tự Date -> Store -> Product -> Vendor.

## 17. Xử lý No Match Output

Không để Lookup ở chế độ `Fail component`. Với mỗi No Match Output:

1. Nối sang một Derived Column riêng.
2. Tạo cột mới `lookup_error` kiểu chuỗi.
3. Gán lý do tương ứng:

| Lookup | `lookup_error` |
|---|---|
| Date | `DATE_NOT_FOUND` |
| Store | `STORE_NOT_FOUND` |
| Product | `PRODUCT_NOT_FOUND` |
| Vendor | `VENDOR_NOT_FOUND` |

4. Nối các nhánh lỗi vào `Union All`.
5. Trong Union All chỉ giữ các cột cần ghi Reject.
6. Nối Union All tới `DST - Reject`.

Nếu metadata của các nhánh Lookup khác nhau, chỉ map các cột chung sau trong Union All:

```text
invoice_id
ordered_on_raw
store_no
vendor_number
item_no
sales_bottles_raw
sales_dollars_raw
sales_liters_raw
lookup_error
```

Đổi tên output `lookup_error` thành `error_reason` trước khi nối Destination hoặc map trực tiếp sang cột `error_reason`.

## 18. Destination nạp Fact

Nối Match Output của `LKP - Vendor` vào OLE DB Destination tên:

```text
DST - FACT_LIQUOR_SALES
```

Cấu hình:

| Thuộc tính | Giá trị |
|---|---|
| Data access mode | Table or view - fast load |
| Destination | `[dbo].[FACT_LIQUOR_SALES]` |
| Table lock | Bật |
| Check constraints | Bật |
| Rows per batch | `100000` |
| Maximum insert commit size | `100000` |

Mappings:

| Input | Destination |
|---|---|
| `invoice_id` | `invoice_id` |
| `date_key` | `date_key` |
| `store_key` | `store_key` |
| `product_key` | `product_key` |
| `vendor_key` | `vendor_key` |
| `sales_bottles` | `sales_bottles` |
| `sales_dollars` | `sales_dollars` |
| `sales_liters` | `sales_liters` |

Không map `sales_key`; SQL Server tự sinh Identity.

## 19. Destination nạp Reject

Tạo OLE DB Destination tên:

```text
DST - Reject
```

Destination:

```text
[stg].[LiquorSalesReject]
```

Map các cột gốc dạng chuỗi và `error_reason`. Không map `reject_key` và `rejected_at` vì SQL Server tự sinh.

Nhánh `Invalid Row` từ Conditional Split và các nhánh No Match có thể dùng hai Destination Reject riêng nếu việc hợp nhất metadata gây khó khăn. Cả hai Destination cùng ghi vào `stg.LiquorSalesReject` là hợp lệ.

## 20. Task kiểm tra Fact

Tạo Execute SQL Task tên:

```text
03 - Verify Fact
```

SQL statement:

```sql
DECLARE @raw_rows bigint =
(
    SELECT COUNT_BIG(*)
    FROM stg.LiquorSalesRaw
);

DECLARE @fact_rows bigint =
(
    SELECT COUNT_BIG(*)
    FROM dbo.FACT_LIQUOR_SALES
);

DECLARE @reject_rows bigint =
(
    SELECT COUNT_BIG(*)
    FROM stg.LiquorSalesReject
);

IF @raw_rows <> @fact_rows + @reject_rows
BEGIN
    THROW 50030, 'Raw rows do not equal Fact plus Reject rows.', 1;
END;

IF EXISTS
(
    SELECT invoice_id
    FROM dbo.FACT_LIQUOR_SALES
    GROUP BY invoice_id
    HAVING COUNT_BIG(*) > 1
)
BEGIN
    THROW 50031, 'Duplicate invoice_id exists in Fact.', 1;
END;
```

## 21. Kiểm tra kết quả cuối cùng

### 21.1. Số dòng từng bảng

```sql
SELECT 'DIM_DATE' AS table_name, COUNT_BIG(*) AS row_count FROM dbo.DIM_DATE
UNION ALL
SELECT 'DIM_STORE', COUNT_BIG(*) FROM dbo.DIM_STORE
UNION ALL
SELECT 'DIM_PRODUCT', COUNT_BIG(*) FROM dbo.DIM_PRODUCT
UNION ALL
SELECT 'DIM_VENDOR', COUNT_BIG(*) FROM dbo.DIM_VENDOR
UNION ALL
SELECT 'FACT_LIQUOR_SALES', COUNT_BIG(*) FROM dbo.FACT_LIQUOR_SALES
UNION ALL
SELECT 'LiquorSalesReject', COUNT_BIG(*) FROM stg.LiquorSalesReject;
```

Kết quả mong đợi với bộ dữ liệu hiện tại:

| Bảng | Số dòng |
|---|---:|
| `DIM_DATE` | 316 |
| `DIM_STORE` | 2.162 |
| `DIM_PRODUCT` | 5.211 |
| `DIM_VENDOR` | 239 |
| `FACT_LIQUOR_SALES` | 2.590.975 |
| `LiquorSalesReject` | 0 |

### 21.2. Tổng các measure

```sql
SELECT
    SUM(CONVERT(bigint, sales_bottles)) AS total_bottles,
    SUM(sales_dollars) AS total_dollars,
    SUM(sales_liters) AS total_liters
FROM dbo.FACT_LIQUOR_SALES;
```

Kết quả mong đợi:

| Measure | Tổng |
|---|---:|
| `total_bottles` | 31.390.251 |
| `total_dollars` | 447.235.413,62 |
| `total_liters` | 23.308.430,630 |

### 21.3. Kiểm tra khóa ngoại và Lookup

```sql
SELECT COUNT_BIG(*) AS orphan_rows
FROM dbo.FACT_LIQUOR_SALES f
LEFT JOIN dbo.DIM_DATE d ON d.date_key = f.date_key
LEFT JOIN dbo.DIM_STORE s ON s.store_key = f.store_key
LEFT JOIN dbo.DIM_PRODUCT p ON p.product_key = f.product_key
LEFT JOIN dbo.DIM_VENDOR v ON v.vendor_key = f.vendor_key
WHERE d.date_key IS NULL
   OR s.store_key IS NULL
   OR p.product_key IS NULL
   OR v.vendor_key IS NULL;
```

Kết quả mong đợi:

```text
0
```

### 21.4. So sánh Raw với Fact

```sql
SELECT
    (SELECT COUNT_BIG(*) FROM stg.LiquorSalesRaw) AS raw_rows,
    (SELECT COUNT_BIG(*) FROM dbo.FACT_LIQUOR_SALES) AS fact_rows,
    (SELECT COUNT_BIG(*) FROM stg.LiquorSalesReject) AS reject_rows;
```

Điều kiện đúng:

```text
raw_rows = fact_rows + reject_rows
```

## 22. Tạo package điều phối `Master.dtsx`

Sau khi từng package chạy độc lập thành công, tạo `Master.dtsx` với các Execute Package Task:

```text
01 - Execute Load Raw
          |
          v
02 - Execute Load Dimensions
          |
          v
03 - Execute Load Fact
```

Không đưa package setup có thao tác drop table vào Master chạy thường xuyên.

Nếu project thực tế vẫn chỉ có một `Package.dtsx` kết hợp setup và Load Raw, có thể dùng package đó làm bước đầu tiên trong lúc phát triển. Tuy nhiên cần nhớ mỗi lần chạy nó sẽ reset toàn bộ Dimension và Fact. Cấu trúc tốt hơn là tách setup và Load Raw thành hai package như tài liệu trước.

## 23. Lỗi thường gặp

| Hiện tượng | Nguyên nhân và cách xử lý |
|---|---|
| Vi phạm `UQ_DIM_STORE_store_no` | Source lấy `DISTINCT` toàn bộ thuộc tính thay vì chọn một dòng bằng `ROW_NUMBER()` |
| Vi phạm `UQ_DIM_PRODUCT_item_no` | Một `item_no` có nhiều phiên bản mô tả; dùng truy vấn ranked trong tài liệu |
| Lookup luôn trả về No Match | Kiểm tra đúng cột join, kiểu dữ liệu, khoảng trắng và thứ tự chạy Dimension trước Fact |
| Lookup báo khác kiểu dữ liệu | Business key ở cả hai phía phải là `DT_STR` có code page và độ rộng tương thích |
| Destination Fact báo lỗi khóa ngoại | Một Lookup bị bỏ qua hoặc output key chưa được map đúng |
| Fact bị trùng khi chạy lại | Task `TRUNCATE TABLE dbo.FACT_LIQUOR_SALES` chưa chạy hoặc precedence constraint bị sai |
| Dimension Identity tiếp tục tăng | Thiếu `DBCC CHECKIDENT ... RESEED, 0` sau khi `DELETE` |
| Package Fact chạy nhưng không có dòng | Conditional Split đang đảo điều kiện Valid/Invalid hoặc một Lookup redirect toàn bộ dòng |
| `product_key` không xuất hiện | Lookup/Destination đang dùng tên cũ `item_key`; đổi về `product_key` |
| Tổng tiền lệch | Kiểm tra kiểu `decimal(19,2)`, không dùng `float` cho doanh thu |
| Data Flow chậm hoặc hết RAM | Đặt Lookup ở Full Cache chỉ cho Dimension; không Sort toàn bộ 2,59 triệu dòng trong pipeline |

## 24. Tiêu chí hoàn thành

Giai đoạn Dimension và Fact hoàn thành khi:

- `DIM_DATE` có 316 dòng.
- `DIM_STORE` có 2.162 dòng và mỗi `store_no` chỉ xuất hiện một lần.
- `DIM_PRODUCT` có 5.211 dòng và mỗi `item_no` chỉ xuất hiện một lần.
- `DIM_VENDOR` có 239 dòng và mỗi `vendor_number` chỉ xuất hiện một lần.
- Fact có 2.590.975 dòng với bộ dữ liệu hiện tại.
- Không có orphan foreign key.
- Không có `invoice_id` trùng trong Fact.
- Raw bằng Fact cộng Reject.
- Tổng số chai, doanh thu và số lít khớp với Raw.
- Package có thể chạy lại mà không nhân đôi dữ liệu.
- Các dòng sai định dạng hoặc Lookup thất bại được ghi vào Reject, không bị mất âm thầm.

## 25. Thứ tự thực hiện đề xuất

```text
1. Bổ sung bảng stg.LiquorSalesReject
2. Tạo 02_Load_Dimensions.dtsx
3. Chạy và kiểm tra bốn Dimension
4. Tạo 03_Load_Fact.dtsx
5. Cấu hình Conditional Split và bốn Lookup
6. Chạy và kiểm tra Fact/Reject
7. Tạo Master.dtsx
8. Chuyển đường dẫn và connection string thành Project Parameter
9. Build project thành file .ispac
10. Deploy lên SSIS Catalog khi cần
```
