USE [livemdb]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
*****************************************************************
Report Title:   HRH MM Get Freight
Report Author:  Brandon Henness
Creation Date:  2024/07/08
Description:
    This report retrieves freight data for the specified vendor within a specified date range.
	The report includes the following columns:
	- Vendor ID
	- Purchase Order ID
	- Vendor Name
	- Invoice ID
	- Invoice Date Time
	- Input Date Time
	- Freight
	- Freight Tax 1
	- Freight Tax 2
	- Freight Tax Code ID

	The report is sorted by Invoice Date Time in descending order.

	The report is used to track freight data for vendors.
Modifications: 
    
*****************************************************************
*/

ALTER   PROCEDURE [dbo].[HRH_MM_GetFreight]
    @StartDate DATETIME = NULL, 
    @EndDate DATETIME = NULL, 
    @VendorID VARCHAR(50) = NULL,
    @PurchaseOrderID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

	IF @StartDate IS NULL 
	BEGIN
		SET @StartDate = DATEFROMPARTS(YEAR(GETDATE()), 1, 1)
		SET @EndDate = GETDATE()
	END
	ELSE
	BEGIN
		SET @EndDate = ISNULL(@EndDate, GETDATE())
	END

    SELECT
		MPO.VendorID,
		MI.PurchaseOrderID,
		DMV.Name,
		MI.InvoiceID,
		MI.InvoiceDateTime,
		MI.InputDateTime,
		MI.Freight,
		MI.FreightTax1,
		MI.FreightTax2,
		MI.FreightTaxCodeID
    FROM MmInvoices MI
    LEFT JOIN MmPurchaseOrders MPO ON MI.PurchaseOrderID = MPO.PurchaseOrderID
	LEFT JOIN DMisVendors DMV ON MPO.VendorID = DMV.VendorID
    WHERE CAST(MI.InvoiceDateTime AS DATE) BETWEEN @StartDate AND @EndDate
    AND (@VendorID IS NULL OR MPO.VendorID = @VendorID)
    AND (@PurchaseOrderID IS NULL OR MI.PurchaseOrderID = @PurchaseOrderID)
    ORDER BY MI.InvoiceDateTime DESC
END
