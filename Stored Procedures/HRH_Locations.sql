USE [livemdb]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
*****************************************************************
Report Title:   HRH Locations
Report Author:  Brandon Henness
Creation Date:  2024/12/22
Description:
    This report retrieves a list of active clinical locations.
    The report includes the following columns:
    - Location ID
    - Name

    The report is sorted by Name.

    The report is used to track active clinical locations.
Modifications: 
    
*****************************************************************
*/

ALTER   PROCEDURE [dbo].[HRH_Locations] 
WITH RECOMPILE
AS
BEGIN
  SET NOCOUNT ON;
  SET ANSI_NULLS ON;
  SET QUOTED_IDENTIFIER ON;

    SELECT LocationID, Name
    FROM livemdb.dbo.DMisLocation
    WHERE Active = 'Y'
      AND Name NOT LIKE '*%'
      AND LocationID NOT IN (
        'ACCOUNTING', 'ADMIN', 'AP', 'BO', 'EC', 'ENG', 'ENGE', 'FOODSERV', 'FS', 'FSE', 'FSW', 'HK', 
        'HR', 'IS', 'MM', 'MRD', 'MSO', 'NC', 'OMLGH', 'PAY', 'PR', 'PC', 'PYXIS-MM', 'TELEPHONE', 'TRANS', 
        'VOL', 'XMS', 'ZZFORM', 'LLC.ADMIN', 'LLC.EC.GI', 'LLC.EC.IM', 'LLC.EC.URO'
      )
    ORDER BY Name;

END;
