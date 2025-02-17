USE [livemdb]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
*****************************************************************
Report Title:   HRH MM Productivity Summary
Report Author:  Brandon Henness
Creation Date:  2024/11/23
Description:
    This stored procedure calculates productivity metrics for the Materials Management department. The report will show the following metrics:
    - Total Orders Processed
    - Total Acquisition Value
    - Total PAR Locations (Non-Stock)
    - Total PAR Lines (Non-Stock)
    - Total PAR Locations (Stock)
    - Total PAR Lines (Stock)
    - Total Items Received
    - Total Items Issued
    - Total Items Put Away

    The report will default to the last quarter if no parameters are provided. The report will calculate metrics based on the provided year and quarter.
Modifications: 
    
*****************************************************************
*/

ALTER   PROCEDURE [dbo].[HRH_MM_Productivity_Summary]
(
    @Year INT = NULL,    -- Year for the report
    @Quarter INT = NULL  -- Quarter (1-4) for the report
)
AS
BEGIN
    SET NOCOUNT ON;

    -- Default to Last Quarter if no Parameters are Provided
    DECLARE @CurrentYear INT = YEAR(GETDATE());
    DECLARE @CurrentQuarter INT = DATEPART(QUARTER, GETDATE());
    DECLARE @DefaultYear INT, @DefaultQuarter INT;

    IF @CurrentQuarter = 1
    BEGIN
        SET @DefaultYear = @CurrentYear - 1;
        SET @DefaultQuarter = 4;
    END
    ELSE
    BEGIN
        SET @DefaultYear = @CurrentYear;
        SET @DefaultQuarter = @CurrentQuarter - 1;
    END;

    SET @Year = ISNULL(@Year, @DefaultYear);
    SET @Quarter = ISNULL(@Quarter, @DefaultQuarter);

    -- Calculate Start and End Dates for the Selected Quarter
    DECLARE @StartDate DATETIME, @EndDate DATETIME;
    SET @StartDate = DATEADD(QUARTER, @Quarter - 1, DATEFROMPARTS(@Year, 1, 1));
    SET @EndDate = DATEADD(SECOND, -1, DATEADD(QUARTER, 1, @StartDate));

    -- Step 1: Declare variables for metrics
    DECLARE @TotalItemsReceived FLOAT;
    DECLARE @TotalAcquisitionValue FLOAT;
    DECLARE @TotalOrdersProcessed INT;
    DECLARE @TotalItemsPutAway FLOAT;
    DECLARE @TotalItemsIssued FLOAT;

    -- Step 2: Create a temp table for Items Received details
    CREATE TABLE #ItemsReceived (
        ItemNumber VARCHAR(50),
        ItemName VARCHAR(255),
        ReceivedQuantity FLOAT,
        TransactionAmount FLOAT, -- For acquisition value
        TotalOrderQuantity FLOAT,
        UnitOfPurchase VARCHAR(50),
        PackagingString VARCHAR(255),
        TransactionDate DATETIME,
        PurchaseOrderID VARCHAR(50),
        LineID VARCHAR(50)
    );

    -- Populate the temp table by calling the detailed Items Received procedure
    INSERT INTO #ItemsReceived
    EXEC dbo.HRH_MM_Productivity_ItemsReceived @StartDate, @EndDate;

    -- Calculate total items received and acquisition value
    SELECT 
        @TotalItemsReceived = SUM(ReceivedQuantity),
        @TotalAcquisitionValue = SUM(TransactionAmount)
    FROM #ItemsReceived;

    -- Step 3: Create a temp table for ParMetrics
    CREATE TABLE #ParMetrics (
        Inventory VARCHAR(50),
        ItemNumber VARCHAR(50),
        ItemName VARCHAR(255),
        IsNonStock VARCHAR(50) -- 'Stock' or 'Non-Stock'
    );

    -- Populate the temp table by calling the updated ParMetrics procedure
    INSERT INTO #ParMetrics
    EXEC dbo.HRH_MM_Productivity_ParMetrics;

    -- Calculate PAR metrics from the updated ParMetrics table
    DECLARE @TotalParLocationsNS INT, @TotalParLinesNS INT;
    DECLARE @TotalParLocationsS INT, @TotalParLinesS INT;

    -- Calculate Non-Stock metrics
    SELECT 
        @TotalParLocationsNS = COUNT(DISTINCT Inventory),
        @TotalParLinesNS = COUNT(*)
    FROM #ParMetrics
    WHERE IsNonStock = 'Non-Stock';

    -- Calculate Stock metrics
    SELECT 
        @TotalParLocationsS = COUNT(DISTINCT Inventory),
        @TotalParLinesS = COUNT(*)
    FROM #ParMetrics
    WHERE IsNonStock = 'Stock';

    -- Step 4: Create a temp table for Purchase Orders
    CREATE TABLE #PurchaseOrders (
        PONumber VARCHAR(50),
        VendorNumber VARCHAR(50),
        VendorName VARCHAR(255),
        OpenDate DATETIME
    );

    -- Populate the temp table by calling the detailed Purchase Orders procedure
    INSERT INTO #PurchaseOrders
    EXEC dbo.HRH_MM_Productivity_PurchaseOrders @StartDate, @EndDate;

    -- Calculate total orders processed
    SELECT 
        @TotalOrdersProcessed = COUNT(*)
    FROM #PurchaseOrders;

    -- Step 5: Create a temp table for Items Put Away
    CREATE TABLE #ItemsPutAway (
        TransactionID INT,
        StockID INT,
        TransactionDate DATETIME,
        OriginalQuantity FLOAT,
        UnitOfMeasureConversion FLOAT,
        PutAwayQuantity FLOAT,
        Inventory VARCHAR(50),
        SourceID VARCHAR(50)
    );

    -- Populate the temp table by calling the detailed Items Put Away procedure
    INSERT INTO #ItemsPutAway
    EXEC dbo.HRH_MM_Productivity_ItemsPutAway @StartDate, @EndDate;

    -- Calculate total items put away
    SELECT 
        @TotalItemsPutAway = SUM(PutAwayQuantity)
    FROM #ItemsPutAway;

    -- Step 6: Create a temp table for Items Issued
    CREATE TABLE #ItemsIssued (
        TransactionID INT,
        StockID INT,
        TransactionDate DATETIME,
        IssuedQuantity FLOAT,
        UnitOfMeasureConversion FLOAT,
        Inventory VARCHAR(50),
        SourceID VARCHAR(50)
    );

    -- Populate the temp table by calling the detailed Items Issued procedure
    INSERT INTO #ItemsIssued
    EXEC dbo.HRH_MM_Productivity_ItemsIssued @StartDate, @EndDate;

    -- Calculate total items issued
    SELECT 
        @TotalItemsIssued = SUM(IssuedQuantity)
    FROM #ItemsIssued;

    -- Step 7: Output the summary result
    SELECT 
        @TotalOrdersProcessed AS OrdersProcessed,         -- Total Orders Processed
        @TotalAcquisitionValue AS AcquisitionValue,       -- Calculated Acquisition Value
        @TotalParLocationsNS AS TotalParLocationsNS,      -- Total PAR Locations (Non-Stock)
        @TotalParLinesNS AS TotalParLinesNS,              -- Total PAR Lines (Non-Stock)
        @TotalParLocationsS AS TotalParLocationsS,        -- Total PAR Locations (Stock)
        @TotalParLinesS AS TotalParLinesS,                -- Total PAR Lines (Stock)
        @TotalItemsReceived AS ItemsReceived,             -- Calculated Items Received
        @TotalItemsIssued AS ItemsIssued,                 -- Calculated Items Issued
        @TotalItemsPutAway AS ItemsPutAway                -- Calculated Items Put Away
    ;

    -- Clean up temporary tables
    DROP TABLE IF EXISTS #ItemsReceived;
    DROP TABLE IF EXISTS #PurchaseOrders;
    DROP TABLE IF EXISTS #ItemsPutAway;
    DROP TABLE IF EXISTS #ItemsIssued;
    DROP TABLE IF EXISTS #ParMetrics;
END;
