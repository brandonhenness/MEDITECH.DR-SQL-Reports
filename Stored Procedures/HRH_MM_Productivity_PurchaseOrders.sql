USE [livemdb]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
*****************************************************************
Report Title:   HRH MM Productivity Purchase Orders
Report Author:  Brandon Henness
Creation Date:  2024/11/25
Description:
    This report retrieves a list of purchase orders with relevant vendor details within a specified date range.
    The report is intended to provide a list of purchase orders for productivity tracking purposes.
    
    The report includes the following columns:
    - Purchase Order Number
    - Vendor Number
    - Vendor Name
    - Purchase Order Open Date
    
    The report filters purchase orders based on the following criteria:
    - Purchase Order Open Date within the specified date range
    - Purchase Order Status is not 'CANCELLED', 'WORKING', or 'VOIDED'
    - SourceID is 'GRY' (if applicable)
    
    The report is ordered by the Purchase Order Open Date for readability.
    
    The report is designed to be executed as a stored procedure with the following parameters:
    - @StartDate: Start date of the report
    - @EndDate: End date of the report
    
    The report is intended to be used by HRH personnel for productivity tracking and analysis.
Modifications: 
    
*****************************************************************
*/

ALTER   PROCEDURE [dbo].[HRH_MM_Productivity_PurchaseOrders]
(
    @StartDate DATE, -- Start date of the report
    @EndDate DATE    -- End date of the report
)
AS
BEGIN
    SET NOCOUNT ON;

    -- Step 1: Retrieve purchase orders within the specified date range
    SELECT
        MPO.Number AS PONumber,                          -- Purchase Order Number
        MPO.VendorID AS VendorNumber,                    -- Vendor Number
        DMV.Name AS VendorName,                          -- Vendor Name
        MPO.OpenDateTime AS OpenDate                     -- Purchase Order Open Date
    FROM
        MmPurchaseOrders AS MPO
    INNER JOIN
        DMisVendors AS DMV
        ON MPO.SourceID = DMV.SourceID
        AND MPO.VendorID = DMV.VendorID -- Join to get vendor information
    WHERE
        CAST(MPO.OpenDateTime AS DATE) BETWEEN @StartDate AND @EndDate -- Filter by date range
        AND MPO.Status NOT IN ('CANCELLED', 'WORKING', 'VOIDED') -- Exclude invalid statuses
        AND MPO.SourceID = 'GRY' -- Filter for the SourceID if applicable
    ORDER BY
        MPO.OpenDateTime; -- Order by open date for readability
END;
