USE [livemdb]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
*****************************************************************
Report Title:   GHCH MM Department Inventory List
Report Author:  Brandon Henness
Creation Date:  2023/02/13
Description:
    This stored procedure retrieves a list of department inventories from the DMmInventories table.
    The stored procedure filters the department inventories based on the following criteria:
    - SourceID: The source ID of the department inventory
    - Active: The active status of the department inventory

    The stored procedure returns the following columns:
    - Inventory: The inventory ID of the department inventory
    - InventoryName: The name of the department inventory

    The stored procedure is used to retrieve a list of department inventories for reporting purposes.

Modifications:

*****************************************************************
*/

ALTER PROCEDURE [dbo].[GHCH_MM_DepartmentInventoryList]
    
    WITH RECOMPILE
AS
BEGIN
    SET NOCOUNT ON; 
    SET ANSI_NULLS ON; 
    SET Quoted_IDENTIFIER ON; 
    
CREATE TABLE #InventoryDeptList (Value VARCHAR(10))

INSERT INTO #InventoryDeptList
SELECT DISTINCT 
    DMI.InventoryID AS InvDeptID
FROM livemdb.dbo.DMmInventories AS DMI
WHERE DMI.SourceID = 'GRY'
    AND DMI.Active = 'Y'

INSERT INTO #InventoryDeptList
SELECT DISTINCT 
    DMGLC.ValueID AS InvDeptID
FROM livemdb.dbo.DMisGlComponentValue AS DMGLC
WHERE DMGLC.SourceID = 'GRY'
	AND DMGLC.ValueID LIKE '01.%'
	AND DMGLC.ValueID BETWEEN '01.6000' AND '01.9000'
    AND DMGLC.ComponentID = 'DPT'
    AND DMGLC.DontUse IS NULL 
	AND DMGLC.Active = 'Y'

SELECT *
FROM #InventoryDeptList
ORDER BY Value
    
END