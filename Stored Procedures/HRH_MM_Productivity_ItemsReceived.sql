USE [livemdb]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
*****************************************************************
Report Title:   HRH MM Productivity Items Received
Report Author:  Brandon Henness
Creation Date:  2024/11/23
Description:
    This report retrieves detailed information on items received within a specified date range.
    The report includes the following columns:
    - Item Number
    - Item Name
    - Received Quantity
    - Transaction Amount
    - Total Order Quantity
    - Unit of Purchase
    - Packaging String
    - Transaction Date
    - Purchase Order ID
    - Line ID

    The report is sorted by Transaction Date.
    
    The report is used to track items received and their associated details.
Modifications: 
    
*****************************************************************
*/

ALTER   PROCEDURE [dbo].[HRH_MM_Productivity_ItemsReceived]
(
    @StartDate DATE, -- Start date of the report
    @EndDate DATE    -- End date of the report
)
AS
BEGIN
    SET NOCOUNT ON;

    -- Step 1: Execute the Items Received query
    WITH ReceivedTransactions AS (
        -- Filter purchase order transactions and join with relevant tables
        SELECT
            MPOL.ItemNumber,
            MPOT.PurchaseOrderID,
            MPOT.LineID,
            MPOT.QuantityPerUnitOfMeasure AS ReceivedQuantityUp, -- Received quantity for the transaction
            MPOT.Amount AS TransactionAmount, -- Amount for acquisition value
            MPOL.OrderQuantity AS TotalOrderQuantity, -- Total order quantity for reference
            MPOL.UnitOfPurchase,
            MPOL.PoUpWithUs AS PackagingString, -- Packaging string
            MPOL.ItemName, -- Item name for context
            MPOT.DateTime AS TransactionDate -- Transaction date
        FROM
            MmPurchaseOrderTransactions MPOT
        INNER JOIN
            MmPurchaseOrderLines MPOL ON MPOT.PurchaseOrderID = MPOL.PurchaseOrderID
                                       AND MPOT.LineID = MPOL.LineID
        WHERE
            MPOT.Type = 'R' -- Received transactions
            AND CAST(MPOT.DateTime AS DATE) BETWEEN @StartDate AND @EndDate -- Filter by passed date range
    ),
    DetailedResults AS (
        -- Filter and rename columns
        SELECT
            ItemNumber,
            PurchaseOrderID,
            LineID,
            ReceivedQuantityUp AS ReceivedQuantity, -- Rename for clarity
            TransactionAmount, -- Include transaction amount
            TotalOrderQuantity,
            UnitOfPurchase,
            PackagingString, -- Packaging string for descriptive purposes
            ItemName,
            TransactionDate
        FROM ReceivedTransactions
        WHERE
            ReceivedQuantityUp IS NOT NULL -- Exclude invalid rows
    )
    -- Step 2: Output the detailed results
    SELECT
        ItemNumber,
        ItemName,
        ReceivedQuantity,
        TransactionAmount, -- Include the transaction amount for acquisition value
        TotalOrderQuantity,
        UnitOfPurchase,
        PackagingString,
        TransactionDate,
        PurchaseOrderID,
        LineID
    FROM DetailedResults
    ORDER BY TransactionDate;
END;
