USE [livemdb]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
*****************************************************************
Report Title:   HRH Naloxone Distribution Locations
Report Author:  Brandon Henness
Creation Date:  2024/12/22
Description:
    Generates a list of active clinical locations. This report is used to identify locations where Naloxone is distributed.
Modifications: 
    2024/12/23 Excluded locations with names starting with '*' and non-clinical locations. -BH
    2024/12/23 Changed returned locations to be ER and CDU only. -BH
*****************************************************************
*/

ALTER   PROCEDURE [dbo].[HRH_Naloxone_Distribution_Locations] 
WITH RECOMPILE
AS
BEGIN
  SET NOCOUNT ON;
  SET ANSI_NULLS ON;
  SET QUOTED_IDENTIFIER ON;

    SELECT LocationID, Name
    FROM livemdb.dbo.DMisLocation
    WHERE LocationID IN ('ER', 'CDU')
    ORDER BY Name;

END;
