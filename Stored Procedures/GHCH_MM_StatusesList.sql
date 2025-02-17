USE [livemdb]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
*****************************************************************
Report Title:   GHCH MM Statuses List
Report Author:  Brandon Henness
Creation Date:  2023/01/01
Description:
    This stored procedure retrieves a list of statuses from the #Statuses table.
    The stored procedure returns the following columns:
    - Status: The status of the item
    
    The stored procedure is used to retrieve a list of statuses for reporting purposes.

Modifications:

*****************************************************************
*/

ALTER PROCEDURE [dbo].[GHCH_MM_StatusesList]
    
    WITH RECOMPILE
AS
BEGIN
    SET NOCOUNT ON; 
    SET ANSI_NULLS ON; 
    SET Quoted_IDENTIFIER ON; 

CREATE TABLE #Statuses (
    ID INT,
    Status VARCHAR(10)
);

INSERT INTO #Statuses (ID, Status)
VALUES (1, 'WORKING'),
    (2, 'OPEN'),
    (3, 'BACKORDER'),
    (4, 'COMPLETE'),
    (5, 'CANCELLED'),
    (6, 'CLOSED'),
    (7, 'VERIFIED'),
    (8, 'VOIDED');

SELECT Status
FROM #Statuses
ORDER BY ID;

END