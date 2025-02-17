USE [livemdb]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
*****************************************************************
Report Title:   GHCH MM Labels
Report Author:  Brandon Henness
Creation Date:  2023/02/09
Description:
    This stored procedure retrieves label data for the specified inventory items.
    The report includes the following columns:
    - Inventory
    - Location
    - Item Number
    - Item Description
    - Transfer Item

    The report is used to generate labels for inventory items.
    
    The report can be run for a specific inventory list and date range.

Modifications:

*****************************************************************
*/

ALTER PROCEDURE [dbo].[GHCH_MM_Labels]
    @Inventory VARCHAR(MAX),
    @UpdatedLabelsOnly BIT,
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

SELECT DISTINCT
    DMMS.Inventory AS Inventory, --INVENTORY
    DMMS.Location AS Location,  --LOCATION
	DMMI.Number AS ItemNumber,  --STOCK #
    DMMI.Description AS ItemDescription, --DESCRIPTION
	DMMS.TransferItem AS TransferItem --XFER ITEM

FROM livemdb.dbo.DMmStock AS DMMS
    LEFT JOIN livemdb.dbo.DMmItems AS DMMI
        ON DMMS.SourceID = DMMI.SourceID
        AND DMMS.ItemID = DMMI.ItemID
    LEFT JOIN livemdb.dbo.DMmItemFacilityAudits AS DMMIFA
        ON DMMI.SourceID = DMMIFA.SourceID
        AND DMMI.ItemID = DMMIFA.ItemID

WHERE DMMS.SourceID = 'GRY'
    AND DMMS.Active ='Y'
    AND DMMS.Inventory IN (SELECT Value FROM #InventoryList)
    AND (@UpdatedLabelsOnly = 0 OR (DMMIFA.Field = 'DESC' AND DMMIFA.AuditDateTime BETWEEN @FromDate AND @ThruDate))

ORDER BY DMMS.Location ASC

END