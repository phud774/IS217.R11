CREATE DATABASE [IowaLiquorDW];
GO

USE [IowaLiquorDW];
GO

CREATE SCHEMA stg;
GO

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
GO