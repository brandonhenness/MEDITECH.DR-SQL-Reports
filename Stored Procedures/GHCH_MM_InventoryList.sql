USE [livemdb]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
*****************************************************************
Report Title:   GHCH MM Inventory List
Report Author:  Brandon Henness
Creation Date:  2023/05/10
Description:
    This stored procedure retrieves a list of inventories from the DMmInventories table.
    The stored procedure filters the inventories based on the following criteria:
    - SourceID: The source ID of the inventory
    - Active: The active status of the inventory

    The stored procedure returns the following columns:
    - Inventory: The inventory ID of the inventory
    - InventoryName: The name of the inventory

    The stored procedure is used to retrieve a list of inventories for reporting purposes.

Modifications:

*****************************************************************
*/

ALTER PROCEDURE [dbo].[GHCH_MM_InventoryList]
    
    WITH RECOMPILE
AS
BEGIN
    SET NOCOUNT ON; 
    SET ANSI_NULLS ON; 
    SET Quoted_IDENTIFIER ON; 

SELECT DISTINCT 
    DMI.InventoryID AS Inventory,
	DMI.Name AS InventoryName
FROM livemdb.dbo.DMmInventories AS DMI
WHERE DMI.SourceID = 'GRY'
    AND DMI.Active = 'Y'
ORDER BY DMI.InventoryID ASC
    
END