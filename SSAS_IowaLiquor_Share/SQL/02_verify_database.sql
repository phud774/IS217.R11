USE [IowaLiquorDW];
GO

SET NOCOUNT ON;

SELECT t.name AS TableName, SUM(p.rows) AS [Rows]
FROM sys.tables AS t
JOIN sys.partitions AS p
  ON p.object_id = t.object_id
 AND p.index_id IN (0, 1)
WHERE t.name IN ('DIM_DATE', 'DIM_PRODUCT', 'DIM_STORE', 'DIM_VENDOR', 'FACT_LIQUOR_SALES')
GROUP BY t.name
ORDER BY t.name;

SELECT
    COUNT_BIG(*) AS FactRows,
    SUM(CONVERT(decimal(38,2), sales_dollars)) AS TotalSalesDollars,
    SUM(CONVERT(bigint, sales_bottles)) AS TotalSalesBottles,
    SUM(CONVERT(decimal(38,3), sales_liters)) AS TotalSalesLiters
FROM dbo.FACT_LIQUOR_SALES;
GO

