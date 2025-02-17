USE [livemdb]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
*****************************************************************
Report Title:   GHCH MM Purchase Order Status
Report Author:  Brandon Henness
Creation Date:  2023/01/01
Description:
    This stored procedure retrieves purchase order status data for the specified date range.
    The report includes the following columns:
    - Vendor ID
    - Vendor Name
    - Vendor Phone Number
    - Vendor Account Number
    - Email Address
    - Purchase Order Number
    - Purchase Order Status
    - EDI Program ID
    - EDI Last Transaction Type
    - Confirmation Date Time
    - Open Date Time
    - Order Date Time
    - Purchase Order Printed Date Time
    - Line ID
    - Ordered By
    - Item Number
    - Item Description
    - Vendor Catalogue
    - Manufacturer Catalogue
    - Total Ordered
    - Total Received
    - Total Canceled
    - Total Open
    - Unit of Purchase
    - Purchase Order Unit of Purchase
    - Text ID
    - Text Sequence ID
    - Text Time Stamp
    - Text Line

    The report is used to track purchase order status data for reporting purposes.
    
    The report can be run for a specific date range, status, vendor, and department or inventory.

Modifications:

*****************************************************************
*/
 
 ALTER PROCEDURE [dbo].[GHCH_MM_PurchaseOrderStatus]
    @FromDate DATETIME,
    @ThruDate DATETIME,
    @Status VARCHAR(MAX),
    @Vendor VARCHAR(MAX),
    @DeptOrInventory VARCHAR(MAX),
    @OnlyShowOpenLines BIT
    
    WITH RECOMPILE
AS
BEGIN
    SET NOCOUNT ON; 
    SET ANSI_NULLS ON; 
    SET Quoted_IDENTIFIER ON; 

CREATE TABLE #StatusList (Value VARCHAR(10))
CREATE TABLE #VendorList (Value VARCHAR(10))
CREATE TABLE #DeptOrInventoryList (Value VARCHAR(10))

INSERT INTO #StatusList
SELECT value
FROM STRING_SPLIT(@Status, ',')

INSERT INTO #VendorList
SELECT value
FROM STRING_SPLIT(@Vendor, ',')

INSERT INTO #DeptOrInventoryList
SELECT value
FROM STRING_SPLIT(@DeptOrInventory, ',')

SELECT
    MPO.VendorID AS VendorID,
    DMV.Name AS VendorName,
    DMV.MainPhoneNumber AS VendorPhoneNumber,
    DMV.OurAccountNumber AS VendorAccountNumber,
    DMVNAE.Address AS EmailAddress,
    MPO.Number AS PurchaseOrderNumber,
    MPO.Status AS PurchaseOrderStatus,
    MPO.EdiProgramID AS EdiProgramID,
    MPO.EdiLastTxnType AS EdiLastTxnType,
    MPO.ConfirmDateTime AS ConfirmDateTime,
    MPO.OpenDateTime AS OpenDateTime,
    MPO.OrderDateTime AS OrderDateTime,
    MPO.PoPrintedDateTime AS PoPrintedDateTime,
    MPOL.LineID AS LineID,
    CONCAT(MPOL.Dept, MPOL.Inventory) AS OrderedBy,
    MPOL.ItemNumber AS ItemNumber,
    MPOL.ItemDescription AS ItemDescription,
    MPOL.Catalogue AS VendorCatalogue,
    MPOL.ManufacturerCatalogue AS ManufacturerCatalogue,
    ROUND(ISNULL(MPOL.TotalOrdered, 0), 0)/MPOL.PoUpUs AS TotalOrdered,
    ROUND(ISNULL(MPOL.TotalReceived, 0), 0)/MPOL.PoUpUs AS TotalReceived,
    ROUND(ISNULL(MPOL.TotalCanceled, 0), 0)/MPOL.PoUpUs AS TotalCanceled,
    (ROUND(ISNULL(MPOL.TotalOrdered, 0), 0) - ROUND(ISNULL(MPOL.TotalReceived, 0), 0) - ROUND(ISNULL(MPOL.TotalCanceled, 0), 0))/MPOL.PoUpUs AS TotalOpen,
    MPOL.UnitOfPurchase AS UnitOfPurchase,
	MPOL.PoUpUs,
	MPOT.TextID, 
	MPOT.TextSeqID ,
	MPOT.TextTimeStamp,
	MPOT.TextLine 
	

FROM livemdb.dbo.MmPurchaseOrderLines AS MPOL
    INNER JOIN livemdb.dbo.MmPurchaseOrders AS MPO
        ON MPOL.SourceID = MPO.SourceID
        AND MPOL.PurchaseOrderID = MPO.PurchaseOrderID
    INNER JOIN livemdb.dbo.DMisVendors AS DMV
        ON MPO.SourceID = DMV.SourceID
        AND MPO.VendorID = DMV.VendorID
    LEFT JOIN livemdb.dbo.DMisVendorNameAndAddEmails AS DMVNAE
        ON MPO.SourceID = DMVNAE.SourceID
        AND MPO.VendorID = DMVNAE.VendorID
    LEFT JOIN livemdb.dbo.MmPoText AS MPOT
        ON MPOL.SourceID = MPOT.SourceID
        AND MPOL.PurchaseOrderID = MPOT.PurchaseOrderID
        AND MPOL.LineID = MPOT.LineID
   
    
WHERE MPO.OrderDateTime BETWEEN @FromDate AND @ThruDate
    AND MPOL.SourceID = 'GRY'
    AND MPO.Status IN (SELECT Value FROM #StatusList)
    AND MPO.VendorID IN (SELECT Value FROM #VendorList)
    AND CONCAT(MPOL.Dept, MPOL.Inventory) IN (SELECT Value FROM #DeptOrInventoryList)
    AND (@OnlyShowOpenLines = 1 AND ROUND(ISNULL(MPOL.TotalOrdered, 0), 0) - ROUND(ISNULL(MPOL.TotalReceived, 0), 0) - ROUND(ISNULL(MPOL.TotalCanceled, 0), 0) > 0 OR @OnlyShowOpenLines = 0)

ORDER BY MPO.VendorID ASC

END