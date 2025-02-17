USE [livemdb]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
*****************************************************************
Report Title:   HRH MM Productivity Items Put Away
Report Author:  Brandon Henness
Creation Date:  2024/11/23
Description:
    This report retrieves detailed information on items put away within a specified date range.
    The report includes the following columns:
    - Transaction ID
    - Stock ID
    - Transaction Date
    - Original Quantity
    - Unit of Measure Conversion
    - Put Away Quantity
    - Inventory Type
    - Source ID

    The report is sorted by Transaction Date.

    The report is used to track items put away and their associated details.
Modifications: 
    
*****************************************************************
*/

ALTER   PROCEDURE [dbo].[HRH_MM_Productivity_ItemsPutAway]
(
    @StartDate DATE, -- Start date of the report
    @EndDate DATE    -- End date of the report
)
AS
BEGIN
    SET NOCOUNT ON;

    -- Step 1: Retrieve and calculate items put away
    WITH ItemsPutAway AS (
        SELECT 
            MmST.TransactionID,                        -- Transaction ID
            MmST.StockID,                              -- Stock ID
            MmST.DateTime AS TransactionDate,          -- Transaction Date
            MmST.Quantity,                             -- Original Quantity
            MmST.UnitOfMeasureConversion,              -- Unit of Measure Conversion
            CAST(MmST.Quantity AS FLOAT) / 
                NULLIF(MmST.UnitOfMeasureConversion, 0) AS PutAwayQuantity, -- Calculated Items Put Away
            DMmS.Inventory,                            -- Inventory Type
            MmST.SourceID                              -- Source ID for filtering
        FROM MmStockTransactions AS MmST
        LEFT JOIN DMmStock AS DMmS
            ON MmST.StockID = DMmS.StockID
        WHERE MmST.TypeID = 'X'                        -- TypeID for "Put Away"
          AND CAST(MmST.DateTime AS DATE) BETWEEN @StartDate AND @EndDate -- Filter by date range
          AND MmST.SourceID = 'GRY'                    -- Filter by source
          AND DMmS.Inventory = 'GS'                   -- Filter by inventory type
    )
    -- Step 2: Output the detailed results
    SELECT 
        TransactionID,
        StockID,
        TransactionDate,
        Quantity AS OriginalQuantity,
        UnitOfMeasureConversion,
        PutAwayQuantity,
        Inventory,
        SourceID
    FROM ItemsPutAway
    ORDER BY TransactionDate;
END;
