USE [livemdb]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
*****************************************************************
Report Title:   GHCH MM Productivity
Report Author:  Brandon Henness
Creation Date:  2023/02/09
Description:
    This report calculates productivity metrics for the Materials Management department.
    The report includes the following metrics:
    - Orders Processed
    - Acquisition Value
    - PAR Locations (Non-Stock)
    - PAR Lines (Non-Stock)
    - PAR Locations (Stock)
    - PAR Lines (Stock)
    - Items Received
    - Items Issued
    - Items Transferred

    The report is used to track department productivity and performance.
    
    The report can be run for a specific date range.

Modifications:

*****************************************************************
*/

  ALTER PROCEDURE [dbo].[GHCH_MM_Productivity] 
    @FromDate varchar(50) = NULL 
    ,@ThruDate VARCHAR(50) = NULL
  

 
    WITH RECOMPILE
 AS
    SET NOCOUNT ON; 
    SET ANSI_NULLS ON; 
    SET Quoted_IDENTIFIER ON; 
    
Declare @StrBeginDate varchar(50) --Added to include pts discharged on the last day of the month. KJ
      ,@StrEndDate varchar(50) 

Declare @StartDate datetime
,@EndDate datetime
,@QuarterStartDate datetime
,@QuarterEndDate datetime

set @QuarterStartDate= DATEADD(Q, DATEDIFF(Q, 0, getdate())-1, 0)
set @QuarterEndDate= DATEADD(ss,-1,DATEADD(Q, DATEDIFF(Q, 0, getdate()), 0)) 

if @FromDate is not NULL and @ThruDate is not NULL
  begin
 
  set @StrBeginDate = CONVERT( varchar, MONTH(@FromDate) )+'/'+CONVERT( varchar, DAY(@FromDate))+
                    '/'+CONVERT( varchar, YEAR(@FromDate))+ ' 00:00'     
  set @StartDate=@StrBeginDate

  set @StrEndDate = CONVERT( varchar, MONTH(@ThruDate) )+'/'+CONVERT( varchar, DAY(@ThruDate))+
                    '/'+CONVERT( varchar, YEAR(@ThruDate))+ ' 23:59' 
  set @EndDate=@StrEndDate

  end

--DECLARE @QuarterStartDate AS datetime = '2020-10-01 00:00:00.000'
--DECLARE @QuarterEndDate AS datetime = '2020-12-31 23:59:59.999'

DECLARE @ParLocationsNS AS INT

SELECT @ParLocationsNS = COUNT(*)  FROM
(
    SELECT DMMS.Inventory
    FROM DMmStock AS DMMS
    WHERE DMMS.TransferItem = 'Y'  AND DMMS.MrpUi IS NOT NULL AND DMMS.Active = 'Y'
    GROUP BY DMMS.Inventory
) AS subquery;

DECLARE @ParLinesNS AS INT

SELECT @ParLinesNS = COUNT (DMmStock.StockNumber) 
FROM DMmStock
WHERE DMmStock.TransferItem = 'Y' AND DMmStock.MrpUi IS NOT NULL AND DMmStock.Active = 'Y'

DECLARE @ParLocationsS AS INT

SELECT @ParLocationsS = COUNT(*) FROM
(
    SELECT DMmStock.Inventory
    FROM DMmStock
    WHERE DMmStock. PatientIssueOrderOnPo = 'Y' AND DMmStock.MrpUi IS NOT NULL AND DMmStock.Active = 'Y'
    GROUP BY DMmStock.Inventory
) AS subquery;

DECLARE @ParLinesS AS INT
SELECT @ParLinesS = COUNT(DMmStock.StockNumber) 
FROM DMmStock
WHERE DMmStock.PatientIssueOrderOnPo = 'Y' AND DMmStock.MrpUi IS NOT NULL AND DMmStock.Active = 'Y'

DECLARE @Received AS INT
SELECT @Received = SUM (CAST(MmStockTransactions.Quantity AS int) )
FROM MmStockTransactions
WHERE MmStockTransactions.TypeID = 'R' AND (MmStockTransactions.DateTime BETWEEN @QuarterStartDate AND @QuarterEndDate) AND SourceID = 'GRY'
-- Find column name

DECLARE @Issued AS INT
SELECT @Issued = SUM  (CAST(MmST.Quantity AS int) )
FROM MmStockTransactions AS MmST
LEFT JOIN DMmStock AS DMmS
	ON MmST.StockID = DMmS.StockID
WHERE MmST.TypeID IN ('I', 'i') AND (MmST.DateTime BETWEEN @QuarterStartDate AND @QuarterEndDate) AND MmST.SourceID = 'GRY' AND DMmS.Inventory = 'GS'

DECLARE @Transfered AS INT
SELECT @Transfered = SUM  (CAST(MmST.Quantity AS int) )
FROM MmStockTransactions AS MmST
LEFT JOIN DMmStock AS DMmS
	ON MmST.StockID = DMmS.StockID
WHERE MmST.TypeID = 'X' AND (MmST.DateTime BETWEEN @QuarterStartDate AND @QuarterEndDate) AND MmST.SourceID = 'GRY' AND DMmS.Inventory = 'GS'

DECLARE @AcquisitionValue AS FLOAT
SELECT
@AcquisitionValue = CAST(SUM(CASE WHEN MMPO.Type ='RETURN' THEN MMPO.Total  *-1 ELSE MMPO.Total END) AS FLOAT)
FROM MmPurchaseOrders AS MMPO--Lines
WHERE Status NOT IN ('CANCELLED','WORKING','VOIDED')	AND ((OpenDateTime BETWEEN @QuarterStartDate AND @QuarterEndDate) OR (Type = 'RETURN' AND OrderDateTime BETWEEN  @QuarterStartDate AND @QuarterEndDate))

DECLARE @OrdersProcessed AS INT
SELECT
@OrdersProcessed = COUNT(PurchaseOrderID)
FROM MmPurchaseOrders AS MMPO--Lines
WHERE Status NOT IN ('CANCELLED','WORKING','VOIDED')	AND ((OpenDateTime BETWEEN @QuarterStartDate AND @QuarterEndDate) OR (Type = 'RETURN' AND OrderDateTime BETWEEN  @QuarterStartDate AND @QuarterEndDate))


DECLARE @Quarter TABLE
(
	OrdersProcessed int,
	AcquisitionValue float,
	ParLocationsNS INT,
    ParLinesNS INT,
    ParLocationsS INT,
    ParLinesS INT,
    Received INT,
    Issued INT,
    Transfered INT,
	QuarterStartDate Datetime,
	QuarterEndDate DaTetime
)
INSERT INTO @Quarter
(
	OrdersProcessed,
	AcquisitionValue,
    ParLocationsNS,
    ParLinesNS,
    ParLocationsS,
    ParLinesS,
    Received,
    Issued,
    Transfered,
	QuarterStartDate,
	QuarterEndDate
)
VALUES
(
	@OrdersProcessed,
	@AcquisitionValue,
    @ParLocationsNS,
    @ParLinesNS,
    @ParLocationsS,
    @ParLinesS,
    @Received,
    @Issued,
    @Transfered,
	@QuarterStartDate,
	@QuarterEndDate
)

SELECT * FROM @Quarter