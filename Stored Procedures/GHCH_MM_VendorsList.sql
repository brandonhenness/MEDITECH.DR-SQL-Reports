USE [livemdb]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
*****************************************************************
Report Title:   GHCH MM Vendors List
Report Author:  Brandon Henness
Creation Date:  2023/01/01
Description:
    This stored procedure retrieves a list of vendors from the DMisVendors table.
    The stored procedure filters the vendors based on the following criteria:
    - SourceID: The source ID of the vendor
    - VendorID: The vendor ID of the vendor
    - Active: The active status of the vendor

    The stored procedure returns the following columns:
    - VendorID: The vendor ID of the vendor
    - VendorName: The name of the vendor

    The stored procedure is used to retrieve a list of vendors for reporting purposes.

Modifications:

*****************************************************************
*/

ALTER PROCEDURE [dbo].[GHCH_MM_VendorsList]
    
    WITH RECOMPILE
AS
BEGIN
    SET NOCOUNT ON; 
    SET ANSI_NULLS ON; 
    SET Quoted_IDENTIFIER ON; 

SELECT DISTINCT
    DMV.VendorID AS VendorID,
    DMV.Name AS VendorName

FROM livemdb.dbo.DMisVendors AS DMV
    

WHERE DMV.SourceID = 'GRY'
    AND DMV.VendorID LIKE 'G%'
    AND DMV.Active = 'Y'

ORDER BY DMV.VendorID;
    
END