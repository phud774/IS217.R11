-- Thay `YOUR_PROJECT_ID` bằng Google Cloud project của bạn trước khi chạy.
CREATE SCHEMA IF NOT EXISTS `YOUR_PROJECT_ID.iowa_liquor`
OPTIONS(location = 'US');

CREATE OR REPLACE TABLE `YOUR_PROJECT_ID.iowa_liquor.sales_monthly_county_category` (
  year INT64,
  month_number INT64,
  month_name STRING,
  quarter_number INT64,
  county_name STRING,
  category_name STRING,
  transaction_count INT64,
  sales_bottles INT64,
  sales_dollars NUMERIC,
  sales_liters NUMERIC
);

CREATE OR REPLACE TABLE `YOUR_PROJECT_ID.iowa_liquor.sales_monthly_vendor` (
  year INT64,
  month_number INT64,
  month_name STRING,
  quarter_number INT64,
  vendor_name STRING,
  transaction_count INT64,
  sales_bottles INT64,
  sales_dollars NUMERIC,
  sales_liters NUMERIC
);

CREATE OR REPLACE TABLE `YOUR_PROJECT_ID.iowa_liquor.sales_monthly_store` (
  year INT64,
  month_number INT64,
  month_name STRING,
  quarter_number INT64,
  store_no STRING,
  store_name STRING,
  store_city STRING,
  county_name STRING,
  transaction_count INT64,
  sales_bottles INT64,
  sales_dollars NUMERIC,
  sales_liters NUMERIC
);

CREATE OR REPLACE TABLE `YOUR_PROJECT_ID.iowa_liquor.sales_quarterly_county_vendor` (
  year INT64,
  quarter_number INT64,
  county_name STRING,
  vendor_key INT64,
  vendor_name STRING,
  transaction_count INT64,
  sales_bottles INT64,
  sales_dollars NUMERIC,
  sales_liters NUMERIC
);

CREATE OR REPLACE TABLE `YOUR_PROJECT_ID.iowa_liquor.sales_quarterly_county_product` (
  year INT64,
  quarter_number INT64,
  county_name STRING,
  product_key INT64,
  product_name STRING,
  category_name STRING,
  transaction_count INT64,
  sales_bottles INT64,
  sales_dollars NUMERIC,
  sales_liters NUMERIC
);

CREATE OR REPLACE TABLE `YOUR_PROJECT_ID.iowa_liquor.sales_monthly_store_category` (
  year INT64,
  month_number INT64,
  month_name STRING,
  quarter_number INT64,
  store_key INT64,
  store_no STRING,
  store_name STRING,
  store_city STRING,
  county_name STRING,
  category_name STRING,
  transaction_count INT64,
  sales_bottles INT64,
  sales_dollars NUMERIC,
  sales_liters NUMERIC
);

-- Sau khi tạo bảng, dùng BigQuery Console > table > Load data để nạp
-- sáu file CSV tương ứng trong thư mục Data. Chọn Skip header rows = 1.
