USE [livemdb]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
*****************************************************************
Report Title:   HRH Get Mortalities By Age Group
Report Author:  Brandon Henness
Creation Date:  2024/08/18
Description:
    This stored procedure is used to list all inpatient mortalities and
    group them by age range for the specified date range, including age
    groups with zero mortalities.

    The stored procedure accepts the following parameters:
    - StartDate: The start date of the date range
    - EndDate: The end date of the date range

    The stored procedure retrieves the inpatient mortality data from the
    AbstractData table and groups the data by age range. The inpatient
    mortality data is filtered based on the patient status, discharge
    disposition ID, location ID, and discharge date. The age range is
    determined by the age of the patient at the time of discharge. The
    inpatient mortalities are grouped by age range and the total number
    of expired inpatients for each age range is calculated.

    The stored procedure returns the following columns:
    - AgeGroup: The age range of the patient
    - ExpiredInpatients: The total number of expired inpatients for the age range

    The stored procedure is used to list all inpatient mortalities and
    group them by age range for the specified date range.

Modifications:

*****************************************************************
*/

ALTER   PROCEDURE [dbo].[HRH_Get_Mortalities_By_AgeGroup]
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

    -- Define all possible age groups
    WITH AgeGroups AS (
        SELECT '0-9' AS AgeGroup, 1 AS AgeOrder UNION ALL
        SELECT '10-19', 2 UNION ALL
        SELECT '20-29', 3 UNION ALL
        SELECT '30-39', 4 UNION ALL
        SELECT '40-49', 5 UNION ALL
        SELECT '50-59', 6 UNION ALL
        SELECT '60-69', 7 UNION ALL
        SELECT '70-79', 8 UNION ALL
        SELECT '80-89', 9 UNION ALL
        SELECT '90-99', 10 UNION ALL
        SELECT '100+', 11
    ),

    -- Query to group inpatient mortalities by age range
    AgeGrouped AS (
        SELECT 
            CASE 
                WHEN DATEDIFF(YEAR, AD.BirthDateTime, AD.DischargeDateTime) BETWEEN 0 AND 9 THEN '0-9'
                WHEN DATEDIFF(YEAR, AD.BirthDateTime, AD.DischargeDateTime) BETWEEN 10 AND 19 THEN '10-19'
                WHEN DATEDIFF(YEAR, AD.BirthDateTime, AD.DischargeDateTime) BETWEEN 20 AND 29 THEN '20-29'
                WHEN DATEDIFF(YEAR, AD.BirthDateTime, AD.DischargeDateTime) BETWEEN 30 AND 39 THEN '30-39'
                WHEN DATEDIFF(YEAR, AD.BirthDateTime, AD.DischargeDateTime) BETWEEN 40 AND 49 THEN '40-49'
                WHEN DATEDIFF(YEAR, AD.BirthDateTime, AD.DischargeDateTime) BETWEEN 50 AND 59 THEN '50-59'
                WHEN DATEDIFF(YEAR, AD.BirthDateTime, AD.DischargeDateTime) BETWEEN 60 AND 69 THEN '60-69'
                WHEN DATEDIFF(YEAR, AD.BirthDateTime, AD.DischargeDateTime) BETWEEN 70 AND 79 THEN '70-79'
                WHEN DATEDIFF(YEAR, AD.BirthDateTime, AD.DischargeDateTime) BETWEEN 80 AND 89 THEN '80-89'
                WHEN DATEDIFF(YEAR, AD.BirthDateTime, AD.DischargeDateTime) BETWEEN 90 AND 99 THEN '90-99'
                ELSE '100+' 
            END AS AgeGroup,
            COUNT(DISTINCT AD.AccountNumber) AS ExpiredInpatients
        FROM livemdb.dbo.AbstractData AS AD
        WHERE AD.PtStatus = 'IN'
        AND AD.DischargeDispositionID IN ('E', 'DIE', 'DOA', 'X.EXT')
        AND AD.LocationID IN ('2ND', '3RD', 'CCU', 'ER ADMIT')
        AND CAST(AD.DischargeDateTime AS DATE) BETWEEN @StartDate AND @EndDate
        GROUP BY 
            CASE 
                WHEN DATEDIFF(YEAR, AD.BirthDateTime, AD.DischargeDateTime) BETWEEN 0 AND 9 THEN '0-9'
                WHEN DATEDIFF(YEAR, AD.BirthDateTime, AD.DischargeDateTime) BETWEEN 10 AND 19 THEN '10-19'
                WHEN DATEDIFF(YEAR, AD.BirthDateTime, AD.DischargeDateTime) BETWEEN 20 AND 29 THEN '20-29'
                WHEN DATEDIFF(YEAR, AD.BirthDateTime, AD.DischargeDateTime) BETWEEN 30 AND 39 THEN '30-39'
                WHEN DATEDIFF(YEAR, AD.BirthDateTime, AD.DischargeDateTime) BETWEEN 40 AND 49 THEN '40-49'
                WHEN DATEDIFF(YEAR, AD.BirthDateTime, AD.DischargeDateTime) BETWEEN 50 AND 59 THEN '50-59'
                WHEN DATEDIFF(YEAR, AD.BirthDateTime, AD.DischargeDateTime) BETWEEN 60 AND 69 THEN '60-69'
                WHEN DATEDIFF(YEAR, AD.BirthDateTime, AD.DischargeDateTime) BETWEEN 70 AND 79 THEN '70-79'
                WHEN DATEDIFF(YEAR, AD.BirthDateTime, AD.DischargeDateTime) BETWEEN 80 AND 89 THEN '80-89'
                WHEN DATEDIFF(YEAR, AD.BirthDateTime, AD.DischargeDateTime) BETWEEN 90 AND 99 THEN '90-99'
                ELSE '100+' 
            END
    )

    -- Left Join to include all Age Groups even if they have zero counts
    SELECT 
        AG.AgeGroup,
        ISNULL(AGG.ExpiredInpatients, 0) AS ExpiredInpatients
    FROM AgeGroups AG
    LEFT JOIN AgeGrouped AGG
    ON AG.AgeGroup = AGG.AgeGroup
    ORDER BY AG.AgeOrder;
END
