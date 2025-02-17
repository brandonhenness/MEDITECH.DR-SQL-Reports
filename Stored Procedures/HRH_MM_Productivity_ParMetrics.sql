USE [livemdb]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
*****************************************************************
Report Title:   HRH MM Productivity PAR Metrics
Report Author:  Brandon Henness
Creation Date:  2024/11/23
Description:
    This report retrieves details of PAR metrics (locations and lines).
    The report includes the following columns:
    - Inventory
    - Item Number
    - Item Name
    - Is Non-Stock

    The report is sorted by Inventory, Is Non-Stock, and Item Number.

    The report is used to track PAR metrics for locations and lines.
Modifications: 
    
*****************************************************************
*/

ALTER   PROCEDURE [dbo].[HRH_MM_Productivity_ParMetrics]
AS
BEGIN
    SET NOCOUNT ON;

    -- Create a table to store the results
    CREATE TABLE #ParMetrics (
        Inventory VARCHAR(50),
        ItemNumber VARCHAR(50),
        ItemName VARCHAR(255),
        IsNonStock VARCHAR(50)
    );

    -- Insert items into the results table
    INSERT INTO #ParMetrics (Inventory, ItemNumber, ItemName, IsNonStock)
    SELECT 
        DMmStock.Inventory,
        DMmStock.StockNumber AS ItemNumber,
        DMmItems.Description AS ItemName, -- Retrieve item name from DMmItems
        CASE 
            WHEN DMmStock.TransferItem = 'Y' THEN 'Stock' -- Stock
            ELSE 'Non-Stock' -- Non-Stock
        END AS IsNonStock
    FROM 
        DMmStock
    INNER JOIN 
        DMmItems ON DMmStock.ItemID = DMmItems.ItemID -- Join to get item description
    WHERE 
        DMmStock.MrpUi IS NOT NULL
        AND DMmStock.Active = 'Y';

    -- Return the results
    SELECT 
        Inventory,
        ItemNumber,
        ItemName,
        IsNonStock
    FROM 
        #ParMetrics
    ORDER BY 
        Inventory, IsNonStock, ItemNumber;

    -- Clean up temporary table
    DROP TABLE #ParMetrics;
END;
