USE [livemdb]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
*****************************************************************
Report Title:   GHCH MM No Activity
Report Author:  Brandon Henness
Creation Date:  2023/05/10
Description:
    This stored procedure retrieves a list of items with no activity for the specified date range.
    The report includes the following columns:
    - Inventory
    - Location
    - Item Number
    - Item Description
    - Quantity Used
    - Unit of Issue
    - Last Transaction Date

    The report is used to track items with no activity for reporting purposes.
    
    The report can be run for a specific date range and inventory.

Modifications:

*****************************************************************
*/

ALTER PROCEDURE [dbo].[GHCH_MM_NoActivity]
    @Inventory VARCHAR(MAX),
    @ExcludeAdjustments BIT,
    @FromDate DATETIME,
    @ThruDate DATETIME 

    WITH RECOMPILE
AS
BEGIN
    SET NOCOUNT ON; 
    SET ANSI_NULLS ON; 
    SET Quoted_IDENTIFIER ON; 

CREATE TABLE #InventoryList (Value VARCHAR(10))

INSERT INTO #InventoryList
SELECT value
FROM STRING_SPLIT(@Inventory, ',')

SELECT
	MMSTX.SourceID AS SourceID,
	MMSTX.StockID AS StockID,
	SUM(CASE WHEN MMSTX.TypeID ='R' THEN CAST(MMSTX.Quantity as int) *-1 ELSE CAST(MMSTX.Quantity as int) END) AS QuantityUsed,
	MAX(MMSTX.DateTime) AS LastTransactionDate

INTO #Transactions

FROM livemdb.dbo.MmStockTransactions AS MMSTX

WHERE MMSTX.SourceID = 'GRY'
    AND ((MMSTX.DateTime BETWEEN @FromDate AND @ThruDate) OR MMSTX.DateTime IS NULL)
    AND (@ExcludeAdjustments = 0 OR MMSTX.TypeID <> 'A')

GROUP BY MMSTX.SourceID, MMSTX.StockID

SELECT
    DMMS.Inventory AS Inventory,
    DMMS.Location AS Location,
	DMMI.Number AS ItemNumber,
    DMMI.Description AS ItemDescription,
	TXN.QuantityUsed/DMMS.UnitOfIssueUs AS QuantityUsed,
    DMMS.UnitOfIssue AS UnitOfIssue,
	TXN.LastTransactionDate AS LastTransactionDate

FROM livemdb.dbo.DMmStock AS DMMS
    LEFT JOIN livemdb.dbo.DMmItems AS DMMI
        ON DMMS.SourceID = DMMI.SourceID
        AND DMMS.ItemID = DMMI.ItemID
    LEFT JOIN #Transactions AS TXN
		ON DMMS.SourceID = TXN.SourceID
		AND DMMS.StockID = TXN.StockID

WHERE DMMS.SourceID = 'GRY'
    AND DMMS.Active ='Y'
    AND DMMS.Inventory IN (SELECT Value FROM #InventoryList)

ORDER BY TXN.LastTransactionDate ASC

END