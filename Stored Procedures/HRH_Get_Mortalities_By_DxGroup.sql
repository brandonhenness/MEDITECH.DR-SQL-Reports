USE [livemdb]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
*****************************************************************
Report Title:   HRH Get Mortalities By Dx Group
Report Author:  Brandon Henness
Creation Date:  2024/08/18
Description:
    This stored procedure is used to list all inpatient mortalities and
    group them by primary diagnosis code for the specified date range,
    including diagnosis groups with zero mortalities.

    The stored procedure accepts the following parameters:
    - StartDate: The start date of the date range
    - EndDate: The end date of the date range

    The stored procedure retrieves the inpatient mortality data from the
    AbstractData, BarVisits, and BarDiagnoses tables and groups the data
    by primary diagnosis code range. The inpatient mortality data is filtered
    based on the patient status, discharge disposition ID, location ID, and
    discharge date. The primary diagnosis code range is determined by the
    first character of the diagnosis code. The inpatient mortalities are
    grouped by diagnosis code range and the total number of expired inpatients
    for each diagnosis code range is calculated.

    The stored procedure returns the following columns:
    - DxGroup: The diagnosis code group range
    - ExpiredInpatients: The total number of expired inpatients for the diagnosis code group

    The stored procedure is used to list all inpatient mortalities and
    group them by primary diagnosis code for the specified date range.

Modifications:

*****************************************************************
*/

ALTER   PROCEDURE [dbo].[HRH_Get_Mortalities_By_DxGroup]
    @StartDate DATETIME = NULL,
    @EndDate DATETIME = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Set default date range if not provided
    IF @StartDate IS NULL
    BEGIN
        SET @StartDate = DATEFROMPARTS(
            YEAR(DATEADD(MONTH, -1, GETDATE())),
            MONTH(DATEADD(MONTH, -1, GETDATE())),
            1
        )
        SET @EndDate = EOMONTH(DATEADD(MONTH, -1, GETDATE()))
    END
    ELSE
    BEGIN
        SET @EndDate = ISNULL(@EndDate, GETDATE())
    END;

    -- Define all possible diagnosis code groups
    WITH DxGroups AS (
        SELECT 'A00-B99' AS DxGroup, 1 AS DxOrder UNION ALL
        SELECT 'I00-I99', 2 UNION ALL
        SELECT 'J00-J99', 3 UNION ALL
        SELECT 'Z00-Z99', 4 UNION ALL
        SELECT 'S00-T88', 5 UNION ALL
        SELECT 'K00-K95', 6 UNION ALL
        SELECT 'N00-N99', 7 UNION ALL
        SELECT 'C00-D49', 8 UNION ALL
        SELECT 'Other', 9 UNION ALL
        SELECT 'U00-U85', 10 UNION ALL
        SELECT 'R00-R99', 11
    ),

    -- Query to group inpatient mortalities by diagnosis code range
    DxGrouped AS (
        SELECT 
            CASE 
                WHEN LEFT(BDX.DiagnosisCodeID, 1) = 'A' OR LEFT(BDX.DiagnosisCodeID, 1) = 'B' THEN 'A00-B99'
                WHEN LEFT(BDX.DiagnosisCodeID, 1) = 'I' THEN 'I00-I99'
                WHEN LEFT(BDX.DiagnosisCodeID, 1) = 'J' THEN 'J00-J99'
                WHEN LEFT(BDX.DiagnosisCodeID, 1) = 'Z' THEN 'Z00-Z99'
                WHEN LEFT(BDX.DiagnosisCodeID, 1) = 'S' OR LEFT(BDX.DiagnosisCodeID, 1) = 'T' THEN 'S00-T88'
                WHEN LEFT(BDX.DiagnosisCodeID, 1) = 'K' THEN 'K00-K95'
                WHEN LEFT(BDX.DiagnosisCodeID, 1) = 'N' THEN 'N00-N99'
                WHEN LEFT(BDX.DiagnosisCodeID, 1) = 'C' THEN 'C00-D49'
                WHEN LEFT(BDX.DiagnosisCodeID, 1) = 'U' THEN 'U00-U85'
                WHEN LEFT(BDX.DiagnosisCodeID, 1) = 'R' THEN 'R00-R99'
                ELSE 'Other' 
            END AS DxGroup,
            COUNT(DISTINCT AD.AccountNumber) AS ExpiredInpatients
        FROM livemdb.dbo.AbstractData AS AD
        LEFT OUTER JOIN livemdb.dbo.BarVisits AS BV ON AD.VisitID = BV.VisitID
        LEFT OUTER JOIN livemdb.dbo.BarDiagnoses AS BDX ON BV.BillingID = BDX.BillingID AND BDX.DiagnosisSeqID = '1'
        WHERE AD.PtStatus = 'IN'
        AND AD.DischargeDispositionID IN ('E', 'DIE', 'DOA', 'X.EXT')
        AND AD.LocationID IN ('2ND', '3RD', 'CCU', 'ER ADMIT')
        AND CAST(AD.DischargeDateTime AS DATE) BETWEEN @StartDate AND @EndDate
        GROUP BY 
            CASE 
                WHEN LEFT(BDX.DiagnosisCodeID, 1) = 'A' OR LEFT(BDX.DiagnosisCodeID, 1) = 'B' THEN 'A00-B99'
                WHEN LEFT(BDX.DiagnosisCodeID, 1) = 'I' THEN 'I00-I99'
                WHEN LEFT(BDX.DiagnosisCodeID, 1) = 'J' THEN 'J00-J99'
                WHEN LEFT(BDX.DiagnosisCodeID, 1) = 'Z' THEN 'Z00-Z99'
                WHEN LEFT(BDX.DiagnosisCodeID, 1) = 'S' OR LEFT(BDX.DiagnosisCodeID, 1) = 'T' THEN 'S00-T88'
                WHEN LEFT(BDX.DiagnosisCodeID, 1) = 'K' THEN 'K00-K95'
                WHEN LEFT(BDX.DiagnosisCodeID, 1) = 'N' THEN 'N00-N99'
                WHEN LEFT(BDX.DiagnosisCodeID, 1) = 'C' THEN 'C00-D49'
                WHEN LEFT(BDX.DiagnosisCodeID, 1) = 'U' THEN 'U00-U85'
                WHEN LEFT(BDX.DiagnosisCodeID, 1) = 'R' THEN 'R00-R99'
                ELSE 'Other' 
            END
    )

    -- Left Join to include all Dx Groups even if they have zero counts
    SELECT 
        DG.DxGroup,
        ISNULL(DGG.ExpiredInpatients, 0) AS ExpiredInpatients
    FROM DxGroups DG
    LEFT JOIN DxGrouped DGG
    ON DG.DxGroup = DGG.DxGroup
    ORDER BY DG.DxOrder;
END
