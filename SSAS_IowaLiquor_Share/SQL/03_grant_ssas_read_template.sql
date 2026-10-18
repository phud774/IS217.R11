:setvar DatabaseName "IowaLiquorDW"
:setvar SsasServiceAccount "NT SERVICE\MSOLAP$SSASMD"

USE [master];
GO

DECLARE @account sysname = N'$(SsasServiceAccount)';

IF SUSER_ID(@account) IS NULL
BEGIN
    EXEC(N'CREATE LOGIN ' + QUOTENAME(@account) + N' FROM WINDOWS;');
END;
GO

USE [$(DatabaseName)];
GO

DECLARE @account sysname = N'$(SsasServiceAccount)';

IF DATABASE_PRINCIPAL_ID(@account) IS NULL
BEGIN
    EXEC(N'CREATE USER ' + QUOTENAME(@account) + N' FOR LOGIN ' + QUOTENAME(@account) + N';');
END;

IF IS_ROLEMEMBER(N'db_datareader', @account) <> 1
BEGIN
    EXEC(N'ALTER ROLE [db_datareader] ADD MEMBER ' + QUOTENAME(@account) + N';');
END;
GO

