USE [livemdb]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
*****************************************************************
Report Title:   HRH MM Productivity Items Issued
Report Author:  Brandon Henness
Creation Date:  2024/11/23
Description:
    This report retrieves detailed information on items issued within a specified date range.
    The report includes the following columns:
    - Transaction ID
    - Stock ID
    - Transaction Date
    - Issued Quantity
    - Unit of Measure Conversion
    - Inventory Type
    - Source ID

    The report is sorted by Transaction Date.
    
    The report is used to track items issued and their associated details.
Modifications: 
    
*****************************************************************
*/

ALTER   PROCEDURE [dbo].[HRH_MM_Productivity_ItemsIssued]
(
    @StartDate DATE, -- Start date of the report
    @EndDate DATE    -- End date of the report
)
AS
BEGIN
    SET NOCOUNT ON;

    -- Step 1: Execute the Items Issued query
    WITH IssuedTransactions AS (
        SELECT
            MST.TransactionID,
            MST.StockID,
            MST.DateTime AS TransactionDate,
            TRY_CAST(MST.Quantity AS FLOAT) / NULLIF(MST.UnitOfMeasureConversion, 0) AS IssuedQuantity, -- Adjusted quantity
            MST.UnitOfMeasureConversion,
            MST.SourceID,
            DMS.Inventory
        FROM
            MmStockTransactions MST
        LEFT JOIN
            DMmStock DMS ON MST.StockID = DMS.StockID
        WHERE
            MST.TypeID IN ('I', 'i') -- Issued transactions
            AND CAST(MST.DateTime AS DATE) BETWEEN @StartDate AND @EndDate -- Filter by date range
            AND MST.SourceID = 'GRY' -- Specific source ID
            AND DMS.Inventory = 'GS' -- Filter for inventory type
    )
    -- Step 2: Output the detailed results
    SELECT
        TransactionID,
        StockID,
        TransactionDate,
        IssuedQuantity,
        UnitOfMeasureConversion,
        Inventory,
        SourceID
    FROM IssuedTransactions
    ORDER BY TransactionDate;
END;
