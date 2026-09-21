USE IowaLiquorDW;
GO

CREATE TABLE dbo.DIM_DATE
(
    date_key          int          NOT NULL,
    ordered_on        date         NOT NULL,
    day_number        tinyint      NOT NULL,
    month_number      tinyint      NOT NULL,
    month_name        varchar(20)  NOT NULL,
    quarter_number    tinyint      NOT NULL,
    year_number       smallint     NOT NULL,

    CONSTRAINT PK_DIM_DATE PRIMARY KEY (date_key),
    CONSTRAINT UQ_DIM_DATE_ordered_on UNIQUE (ordered_on)
);
GO

CREATE TABLE dbo.DIM_STORE
(
    store_key      int IDENTITY(1,1) NOT NULL,
    store_no       varchar(20)       NOT NULL,
    store_name     varchar(255)      NULL,
    store_city     varchar(100)      NULL,
    county_name    varchar(100)      NULL,

    CONSTRAINT PK_DIM_STORE PRIMARY KEY (store_key),
    CONSTRAINT UQ_DIM_STORE_store_no UNIQUE (store_no)
);
GO

CREATE TABLE dbo.DIM_PRODUCT
(
    product_key       int IDENTITY(1,1) NOT NULL,
    item_no           varchar(30)       NOT NULL,
    im_desc           varchar(500)      NULL,
    bottle_volume_ml  int               NULL,
    category_name     varchar(255)      NULL,

    CONSTRAINT PK_DIM_PRODUCT PRIMARY KEY (product_key),
    CONSTRAINT UQ_DIM_PRODUCT_item_no UNIQUE (item_no)
);
GO

CREATE TABLE dbo.DIM_VENDOR
(
    vendor_key     int IDENTITY(1,1) NOT NULL,
    vendor_number  varchar(20)       NOT NULL,
    vendor_name    varchar(255)      NULL,

    CONSTRAINT PK_DIM_VENDOR PRIMARY KEY (vendor_key),
    CONSTRAINT UQ_DIM_VENDOR_vendor_number UNIQUE (vendor_number)
);
GO

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
GO