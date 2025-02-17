USE [livemdb]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
*****************************************************************
Report Title:   HRH MM Productivity
Report Author:  Brandon Henness
Creation Date:  2024/11/23
Description:
    This report calculates productivity metrics for the Materials Management department.
    The report includes the following metrics:
    - PAR Locations (Non-Stock)
    - PAR Lines (Non-Stock)
    - PAR Locations (Stock)
    - PAR Lines (Stock)
    - Items Received
    - Items Issued
    - Items Transferred
    - Acquisition Value
    - Orders Processed

    The report is used to track department productivity and performance.
    
    The report can be run for a specific year and quarter.
Modifications: 
    
*****************************************************************
*/

ALTER   PROCEDURE [dbo].[HRH_MM_Productivity]
    @Year INT = NULL, -- Year to run the report for
    @Quarter INT = NULL -- Quarter (1-4) to run the report for
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

    -- Combine Calculations into CTEs
    WITH ParData AS (
        SELECT 
            Inventory,
            TransferItem,
            PatientIssueOrderOnPo,
            MrpUi,
            Active,
            StockNumber
        FROM DMmStock
        WHERE MrpUi IS NOT NULL AND Active = 'Y'
    ),
    Transactions AS (
        SELECT
            Quantity,
            TypeID,
            StockID,
            DateTime,
            SourceID
        FROM MmStockTransactions
        WHERE CAST(DateTime AS DATE) BETWEEN @StartDate AND @EndDate
    ),
    PurchaseOrders AS (
        SELECT
            CASE 
                WHEN Type = 'RETURN' THEN Total * -1 
                ELSE Total 
            END AS AdjustedTotal,
            PurchaseOrderID,
            Status,
            OpenDateTime,
            OrderDateTime,
            Type
        FROM MmPurchaseOrders
        WHERE Status NOT IN ('CANCELLED', 'WORKING', 'VOIDED')
        AND (
            CAST(OpenDateTime AS DATE) BETWEEN @StartDate AND @EndDate
            OR (Type = 'RETURN' AND CAST(OrderDateTime AS DATE) BETWEEN @StartDate AND @EndDate)
        )
    ),
    ParMetrics AS (
        SELECT
            SUM(CASE WHEN TransferItem = 'Y' THEN 1 ELSE 0 END) AS ParLocationsNS,
            COUNT(CASE WHEN TransferItem = 'Y' THEN StockNumber ELSE NULL END) AS ParLinesNS,
            SUM(CASE WHEN PatientIssueOrderOnPo = 'Y' THEN 1 ELSE 0 END) AS ParLocationsS,
            COUNT(CASE WHEN PatientIssueOrderOnPo = 'Y' THEN StockNumber ELSE NULL END) AS ParLinesS
        FROM ParData
    ),
    TransactionMetrics AS (
        SELECT
            SUM(CASE WHEN TypeID = 'R' AND SourceID = 'GRY' THEN CAST(Quantity AS INT) ELSE 0 END) AS Received,
            SUM(CASE WHEN TypeID IN ('I', 'i') AND SourceID = 'GRY' THEN CAST(Quantity AS INT) ELSE 0 END) AS Issued,
            SUM(CASE WHEN TypeID = 'X' AND SourceID = 'GRY' THEN CAST(Quantity AS INT) ELSE 0 END) AS Transferred
        FROM Transactions
    ),
    OrderMetrics AS (
        SELECT
            SUM(AdjustedTotal) AS AcquisitionValue,
            COUNT(PurchaseOrderID) AS OrdersProcessed
        FROM PurchaseOrders
    )
    SELECT
        -- Combine Metrics from All CTEs
        PM.ParLocationsNS,
        PM.ParLinesNS,
        PM.ParLocationsS,
        PM.ParLinesS,
        TM.Received,
        TM.Issued,
        TM.Transferred,
        OM.AcquisitionValue,
        OM.OrdersProcessed,
        @StartDate AS QuarterStartDate,
        @EndDate AS QuarterEndDate,
        @Year AS SelectedYear,
        @Quarter AS SelectedQuarter
    FROM ParMetrics PM
    CROSS JOIN TransactionMetrics TM
    CROSS JOIN OrderMetrics OM;
END;
