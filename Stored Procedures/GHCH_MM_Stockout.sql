USE [livemdb]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
*****************************************************************
Report Title:   GHCH MM Stockout
Report Author:  Brandon Henness
Creation Date:  2023/03/01
Description:
    This stored procedure retrieves a list of items that are at or below the specified days on hand.
    The stored procedure filters the items based on the following criteria:
    - Inventory: The inventory items to include in the report
    - DaysOnHand: The number of days on hand to filter the items
    - ShowPurchaseOrders: A flag to indicate whether to include purchase order information in the report

    The stored procedure returns the following columns:
    - ItemNumber: The item number of the item
    - ItemDescription: The description of the item
    - QuantityOnHand: The quantity on hand of the item
    - QuantityOnOrder: The quantity on order of the item
    - UnitOfIssue: The unit of issue of the item
    - AverageUsage: The average usage of the item
    - DaysOnHand: The number of days on hand of the item
    - VendorID: The vendor ID of the item
    - VendorName: The name of the vendor
    - VendorPhoneNumber: The phone number of the vendor
    - VendorAccountNumber: The account number of the vendor
    - EmailAddress: The email address of the vendor
    - PurchaseOrderNumber: The purchase order number of the item
    - EdiProgramID: The EDI program ID of the item
    - TransmissionStatus: The transmission status of the item
    - TransmissionDateTime: The transmission date time of the item
    - LineID: The line ID of the item
    - OrderedBy: The order by of the item
    - TotalOpen: The total open of the item
    - UnitOfPurchase: The unit of purchase of the item
    - TextID: The text ID of the item
    - TextSeqID: The text sequence ID of the item
    - TextTimeStamp: The text time stamp of the item
    - TextLine: The text line of the item

    The stored procedure is used to retrieve a list of items that are at or below the specified days on hand.
    
    The stored procedure can be run for a specific inventory and days on hand.
    
    The stored procedure can also include purchase order information in the report.
    
    The stored procedure is used to track stockout items in the inventory.

Modifications:

*****************************************************************
*/

ALTER PROCEDURE [dbo].[GHCH_MM_Stockout] 
    --@FromDate DATETIME,
    --@ThruDate DATETIME,
    @Inventory VARCHAR(MAX),
    @DaysOnHand INT,
    @ShowPurchaseOrders BIT

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

DECLARE @StockOut TABLE
(ItemNumber VARCHAR(50),
ItemDescription VARCHAR(50),
QuantityOnHand INT,
QuantityOnOrder INT,
UnitOfIssue VARCHAR(50),
AverageUsage FLOAT,
DaysOnHand FLOAT,
VendorID VARCHAR(50),
VendorName VARCHAR(50),
VendorPhoneNumber VARCHAR(50),
VendorAccountNumber VARCHAR(50),
EmailAddress VARCHAR(50),
PurchaseOrderNumber VARCHAR(50),
EdiProgramID VARCHAR(50),
TransmissionStatus VARCHAR(50),
TransmissionDateTime DATETIME,
LineID VARCHAR(50),
OrderedBy VARCHAR(50),
TotalOpen INT,
UnitOfPurchase VARCHAR(50),
TextID INT,
TextSeqID INT,
TextTimeStamp DATETIME,
TextLine VARCHAR(50))

INSERT INTO @StockOut
(ItemNumber,
ItemDescription,
QuantityOnHand,
QuantityOnOrder,
UnitOfIssue,
AverageUsage,
DaysOnHand,
VendorID,
VendorName,
VendorPhoneNumber,
VendorAccountNumber,
EmailAddress,
PurchaseOrderNumber,
EdiProgramID,
TransmissionStatus,
TransmissionDateTime,
LineID,
OrderedBy,
TotalOpen,
UnitOfPurchase,
TextID,
TextSeqID,
TextTimeStamp,
TextLine)

SELECT
	DMMI.Number AS ItemNumber,
    DMMI.Description AS ItemDescription,
	MMS.QuantityOnHand/DMMS.UnitOfIssueUs AS QuantityOnHand,
    MMS.QuantityOnOrder/DMMS.UnitOfIssueUs AS QuantityOnOrder,
    DMMS.UnitOfIssue,
	MMS.AverageUsage/DMMS.UnitOfIssueUs As AverageUsage,
    CASE WHEN MMS.AverageUsage <= 0 THEN NULL
        ELSE MMS.QuantityOnHand/MMS.AverageUsage
    END AS DaysOnHand,
    CASE WHEN @ShowPurchaseOrders = 1 THEN MPO.VendorID ELSE NULL END AS VendorID,
    CASE WHEN @ShowPurchaseOrders = 1 THEN DMV.Name ELSE NULL END AS VendorName,
    CASE WHEN @ShowPurchaseOrders = 1 THEN DMV.MainPhoneNumber ELSE NULL END AS VendorPhoneNumber,
    CASE WHEN @ShowPurchaseOrders = 1 THEN DMV.OurAccountNumber ELSE NULL END AS VendorAccountNumber,
    CASE WHEN @ShowPurchaseOrders = 1 THEN DMVNAE.Address ELSE NULL END AS EmailAddress,
    CASE WHEN @ShowPurchaseOrders = 1 THEN MPO.Number ELSE NULL END AS PurchaseOrderNumber,
    CASE WHEN @ShowPurchaseOrders = 1 THEN MPO.EdiProgramID ELSE NULL END AS EdiProgramID,
    CASE WHEN @ShowPurchaseOrders = 1 THEN
        CASE WHEN MPO.EdiLastTxnType IS NULL AND PoPrintedDateTime IS NULL THEN NULL
            WHEN MPO.EdiLastTxnType IS NULL THEN 'PRINTED'
            ELSE MPO.EdiLastTxnType
        END
        ELSE NULL
    END AS TransmissionStatus,
    CASE WHEN @ShowPurchaseOrders = 1 THEN 
        CASE WHEN MPO.EdiLastTxnType IS NULL AND PoPrintedDateTime IS NULL THEN NULL
            WHEN MPO.EdiLastTxnType IS NULL THEN MPO.PoPrintedDateTime
            ELSE MPET.SentDateTime
        END 
        ELSE NULL
    END AS TransmissionDateTime,
    CASE WHEN @ShowPurchaseOrders = 1 THEN MPOL.LineID ELSE NULL END AS LineID,
    CASE WHEN @ShowPurchaseOrders = 1 THEN CONCAT(MPOL.Dept, MPOL.Inventory) ELSE NULL END AS OrderedBy,
    CASE WHEN @ShowPurchaseOrders = 1 THEN (ROUND(ISNULL(MPOL.TotalOrdered, 0), 0) - ROUND(ISNULL(MPOL.TotalReceived, 0), 0) - ROUND(ISNULL(MPOL.TotalCanceled, 0), 0))/MPOL.PoUpUs ELSE NULL END AS TotalOpen,
    CASE WHEN @ShowPurchaseOrders = 1 THEN MPOL.UnitOfPurchase ELSE NULL END AS UnitOfPurchase,
    CASE WHEN @ShowPurchaseOrders = 1 THEN MPOT.TextID ELSE NULL END AS TextID,
    CASE WHEN @ShowPurchaseOrders = 1 THEN MPOT.TextSeqID ELSE NULL END AS TextSeqID,
    CASE WHEN @ShowPurchaseOrders = 1 THEN MPOT.TextTimeStamp ELSE NULL END AS TextTimeStamp,
    CASE WHEN @ShowPurchaseOrders = 1 THEN MPOT.TextLine ELSE NULL END AS TextLine

FROM livemdb.dbo.DMmStock AS DMMS
	LEFT JOIN livemdb.dbo.MmStock AS MMS 
		ON DMMS.SourceID = MMS.SourceID
        AND DMMS.StockID = MMS.StockID
    LEFT JOIN livemdb.dbo.DMmItems AS DMMI
        ON DMMS.SourceID = DMMI.SourceID
        AND DMMS.ItemID = DMMI.ItemID
    LEFT JOIN livemdb.dbo.MmPurchaseOrderLines AS MPOL
        ON DMMS.SourceID = MPOL.SourceID
        AND DMMS.StockID = MPOL.StockID
    LEFT JOIN livemdb.dbo.MmPurchaseOrders AS MPO
        ON MPOL.SourceID = MPO.SourceID
        AND MPOL.PurchaseOrderID = MPO.PurchaseOrderID
    LEFT JOIN livemdb.dbo.DMisVendors AS DMV
        ON MPO.SourceID = DMV.SourceID
        AND MPO.VendorID = DMV.VendorID
    LEFT JOIN livemdb.dbo.DMisVendorNameAndAddEmails AS DMVNAE
        ON MPO.SourceID = DMVNAE.SourceID
        AND MPO.VendorID = DMVNAE.VendorID
    LEFT JOIN livemdb.dbo.MmPoText AS MPOT
        ON MPOL.SourceID = MPOT.SourceID
        AND MPOL.PurchaseOrderID = MPOT.PurchaseOrderID
        AND MPOL.LineID = MPOT.LineID
    LEFT JOIN livemdb.dbo.MmPoEdiTxns AS MPET
        ON MPO.SourceID = MPET.SourceID
        AND MPO.PurchaseOrderID = MPET.PurchaseOrderID
        AND MPO.EdiLastTxnSeq = MPET.TxnSeqID

WHERE-- MPO.OrderDateTime BETWEEN @FromDate AND @ThruDate or MPO.OrderDateTime IS NULL  AND 
        DMMS.SourceID = 'GRY'
    AND DMMS.Active ='Y'
    AND (DMMS.Inventory) IN (SELECT Value FROM #InventoryList)
       AND ((CASE WHEN MMS.AverageUsage <= 0 THEN @DaysOnHand + 1 ELSE (MMS.QuantityOnHand/MMS.AverageUsage) END) <= @DaysOnHand)
    AND ((ROUND(ISNULL(MPOL.TotalOrdered, 0), 0) - ROUND(ISNULL(MPOL.TotalReceived, 0), 0) - ROUND(ISNULL(MPOL.TotalCanceled, 0), 0)) > 0 
       OR MPOL.TotalOrdered IS NULL) 
       AND (MPO.Status IN ('OPEN', 'BACKORDER', 'WORKING') OR MPO.Status IS NULL)




SELECT *
FROM @StockOut
GROUP BY ItemNumber,
ItemDescription,
QuantityOnHand,
QuantityOnOrder,
UnitOfIssue,
AverageUsage,
DaysOnHand,
VendorID,
VendorName,
VendorPhoneNumber,
VendorAccountNumber,
EmailAddress,
PurchaseOrderNumber,
EdiProgramID,
TransmissionStatus,
TransmissionDateTime,
LineID,
OrderedBy,
TotalOpen,
UnitOfPurchase,
TextID,
TextSeqID,
TextTimeStamp,
TextLine
ORDER BY DaysOnHand ASC

END