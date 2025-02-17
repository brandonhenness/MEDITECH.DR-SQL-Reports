USE [livemdb]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
*****************************************************************
Report Title:   HRH Get Mortalities Inpatient
Report Author:  Brandon Henness
Creation Date:  2024/08/17
Description:
    This stored procedure is used to list all inpatients and calculate total
    inpatient mortalities and total inpatients for each month in the specified
    date range, as well as a total for the entire period.

    The stored procedure accepts the following parameters:
    - StartDate: The start date of the date range
    - EndDate: The end date of the date range

    The stored procedure retrieves the inpatient data from the AbstractData table
    and calculates the total inpatient mortalities and total inpatients for each
    month in the specified date range. The inpatient data is filtered based on the
    patient status, location ID, and discharge date. The total inpatient mortalities
    and total inpatients are calculated based on the discharge disposition ID.

    The stored procedure returns the following columns:
    - MonthYear: The month and year of the data
    - ExpiredInpatients: The total number of expired inpatients for the month


    The stored procedure is used to list all inpatients and calculate total
    inpatient mortalities and total inpatients for each month in the specified
    date range.

Modifications:

*****************************************************************
*/

ALTER   PROCEDURE [dbo].[HRH_Get_Mortalities_Inpatient]
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

    -- Query to list all inpatients (no changes needed here)
    SELECT DISTINCT  
        AD.AccountNumber,
        AD.Name,
        AD.AdmitDateTime,
        AD.DischargeDateTime,
        AD.DischargeDispositionID,
        AD.LocationID,
        AD.VisitID,
        AD.ReasonForVisit,
        AD.PtStatus,
        (SELECT TOP (1) StartDateTime
         FROM livemdb.dbo.EdmPatientStatusEventHistory AS STATHIST WITH (NOLOCK)
         WHERE AD.VisitID = VisitID AND EventID = 'RECEIVED'
         ORDER BY SeqID) AS 'ARRVLDATETIME'
    FROM livemdb.dbo.AbstractData AS AD 
    WHERE AD.PtStatus = 'IN'
    AND AD.LocationID IN ('2ND', '3RD', 'CCU', 'ER ADMIT')
    AND CAST(AD.DischargeDateTime AS DATE) BETWEEN @StartDate AND @EndDate
    ORDER BY DischargeDateTime ASC;

    -- Numerator and Denominator Calculation by Month with Total
    SELECT *
    FROM (
        SELECT 
            FORMAT(AD.DischargeDateTime, 'MMMM yyyy') AS MonthYear,
            COUNT(DISTINCT CASE 
                WHEN AD.DischargeDispositionID IN ('E', 'DIE', 'DOA', 'X.EXT') 
                THEN AD.AccountNumber 
                END) AS ExpiredInpatients,
            COUNT(DISTINCT AD.AccountNumber) AS TotalInpatients,
            MIN(CONVERT(DATE, AD.DischargeDateTime)) AS MinDischargeDateTime
        FROM livemdb.dbo.AbstractData AS AD 
        WHERE AD.PtStatus = 'IN'
        AND AD.LocationID IN ('2ND', '3RD', 'CCU', 'ER ADMIT')
        AND CAST(AD.DischargeDateTime AS DATE) BETWEEN @StartDate AND @EndDate
        GROUP BY FORMAT(AD.DischargeDateTime, 'MMMM yyyy'), YEAR(AD.DischargeDateTime), MONTH(AD.DischargeDateTime)

        UNION ALL

        SELECT 
            'Total' AS MonthYear,
            COUNT(DISTINCT CASE 
                WHEN AD.DischargeDispositionID IN ('E', 'DIE', 'DOA', 'X.EXT') 
                THEN AD.AccountNumber 
                END) AS ExpiredInpatients,
            COUNT(DISTINCT AD.AccountNumber) AS TotalInpatients,
            NULL AS MinDischargeDateTime
        FROM livemdb.dbo.AbstractData AS AD 
        WHERE AD.PtStatus = 'IN'
        AND AD.LocationID IN ('2ND', '3RD', 'CCU', 'ER ADMIT')
        AND CAST(AD.DischargeDateTime AS DATE) BETWEEN @StartDate AND @EndDate
    ) AS CombinedResults
    ORDER BY 
        CASE 
            WHEN MinDischargeDateTime IS NULL THEN 1 ELSE 0 
        END, 
        MinDischargeDateTime;
END
