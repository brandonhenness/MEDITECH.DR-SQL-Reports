USE [livemdb]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
*****************************************************************
Report Title:   HRH Get COVID Mortalities
Report Author:  Brandon Henness
Creation Date:  2024/08/17
Description:
    This stored procedure is used to extract COVID mortalities and lab
    specimen data for the specified date range, ensuring unique VisitID
    results and including specific columns.

    The stored procedure accepts the following parameters:
    - StartDate: The start date of the date range
    - EndDate: The end date of the date range

    The stored procedure retrieves the COVID mortality data from the
    AbstractData and MicSpecimens tables and the lab specimen data from
    the AbstractData and LabSpecimens tables. The COVID mortality data is
    filtered based on the patient status, location ID, and discharge date.
    The lab specimen data is filtered based on the collection date and the
    test print number ID. The COVID mortalities and lab specimen data are
    combined and returned in a table format.

    The stored procedure returns the following columns:
    - AccountNumber: The account number of the patient
    - Name: The name of the patient
    - AdmitDateTime: The admission date and time of the patient
    - DischargeDateTime: The discharge date and time of the patient
    - DischargeDispositionID: The discharge disposition ID of the patient
    - LocationID: The location ID of the patient
    - CollectionDateTime: The collection date and time of the lab specimen
    - VisitID: The visit ID of the patient
    - ReasonForVisit: The reason for the patient's visit
    - PtStatus: The patient status
    - ARRVLDATETIME: The arrival date and time of the patient
    - ResultColumn: The result column of the lab specimen
    - ResultRW: The result RW of the lab specimen
    - Result: The result of the lab specimen

    The stored procedure is used to extract COVID mortalities and lab
    specimen data for the specified date range.

Modifications:

*****************************************************************
*/

ALTER PROCEDURE [dbo].[HRH_Get_COVID_Mortalities]
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

    -- Create a temporary table to store the results
    CREATE TABLE #RankedResults (
        AccountNumber VARCHAR(50),
        Name VARCHAR(100),
        AdmitDateTime DATETIME,
        DischargeDateTime DATETIME,
        DischargeDispositionID VARCHAR(10),
        LocationID VARCHAR(10),
        CollectionDateTime DATETIME,
        VisitID VARCHAR(50),
        ReasonForVisit VARCHAR(255),
        PtStatus VARCHAR(10),
        ARRVLDATETIME DATETIME,
        ResultColumn VARCHAR(50),
        ResultRW VARCHAR(50),
        Result VARCHAR(50),
        RN INT
    );

    -- Insert data into the temporary table
    INSERT INTO #RankedResults
    SELECT DISTINCT  
        AD.AccountNumber,
        AD.Name,
        AD.AdmitDateTime,
        AD.DischargeDateTime,
        AD.DischargeDispositionID,
        AD.LocationID,
        MS.CollectionDateTime,
        AD.VisitID,
        AD.ReasonForVisit,
        AD.PtStatus,
        (SELECT TOP (1) StartDateTime
         FROM livemdb.dbo.EdmPatientStatusEventHistory AS STATHIST WITH (NOLOCK)
         WHERE AD.VisitID = VisitID AND EventID = 'RECEIVED'
         ORDER BY SeqID) AS 'ARRVLDATETIME',
        MSR.Special AS ResultColumn,
        NULL AS ResultRW,
        'Positive' AS Result,
        ROW_NUMBER() OVER (PARTITION BY AD.VisitID ORDER BY MS.CollectionDateTime ASC) AS RN
    FROM livemdb.dbo.AbstractData AS AD 
    INNER JOIN livemdb.dbo.MicSpecimens AS MS ON AD.VisitID = MS.VisitID 
    INNER JOIN livemdb.dbo.MicSpecimenProcResults AS MSR ON MS.SpecimenID = MSR.SpecimenID
    WHERE AD.PtStatus = 'IN'
    AND AD.LocationID IN ('2ND', '3RD', 'CCU', 'ER ADMIT')
    AND CAST(AD.DischargeDateTime AS DATE) BETWEEN @StartDate AND @EndDate
    AND MSR.ProcedureID IN ('700.0887', '700.0845')
    AND MSR.PreliminaryOrFinal = 'F'
    AND MSR.Special IN ('COVPOS', 'P', 'POS', 'POSITIVE')

    UNION ALL

    SELECT DISTINCT 
        AD.AccountNumber,
        AD.Name,
        AD.AdmitDateTime,
        AD.DischargeDateTime,
        AD.DischargeDispositionID,
        AD.LocationID,
        LS.CollectionDateTime,
        AD.VisitID,
        AD.ReasonForVisit,
        AD.PtStatus,
        (SELECT TOP (1) StartDateTime
         FROM livemdb.dbo.EdmPatientStatusEventHistory AS STATHIST WITH (NOLOCK)
         WHERE AD.VisitID = VisitID AND EventID = 'RECEIVED'
         ORDER BY SeqID) AS 'ARRVLDATETIME',
        NULL AS ResultColumn,
        LST.ResultRW,
        'Positive' AS Result,
        ROW_NUMBER() OVER (PARTITION BY AD.VisitID ORDER BY LS.CollectionDateTime ASC) AS RN
    FROM livemdb.dbo.AbstractData AS AD 
    INNER JOIN livemdb.dbo.LabSpecimens AS LS ON LS.VisitID = AD.VisitID 
    INNER JOIN livemdb.dbo.LabSpecimenTests AS LST ON LST.VisitID = LS.VisitID AND LST.SpecimenID = LS.SpecimenID 
    WHERE AD.PtStatus = 'IN'
    AND AD.LocationID IN ('2ND', '3RD', 'CCU', 'ER ADMIT')
    AND CAST(AD.DischargeDateTime AS DATE) BETWEEN @StartDate AND @EndDate
    AND NOT (LS.Status IN ('CAN'))
    AND LST.TestPrintNumberID IN ('830.400', '830.011', '830.0900', '830.0950', '830.0940', '850.0002')
    AND LST.ResultRW IN ('POS', 'P', 'COVPOS', 'POSITIVE');

    -- First Output: List all positive patients
    SELECT
        AccountNumber,
        Name,
        AdmitDateTime,
        DischargeDateTime,
        DischargeDispositionID,
        LocationID,
        CollectionDateTime,
        VisitID,
        ReasonForVisit,
        PtStatus,
        ARRVLDATETIME,
        ResultColumn,
        ResultRW,
        Result
    FROM #RankedResults
    WHERE RN = 1
    ORDER BY AdmitDateTime ASC;

    -- Second Output: Numerator and Denominator Calculation by Month with Total
    SELECT
        MonthYear,
        SUM(ExpiredPositiveCOVIDPatients) AS ExpiredPositiveCOVIDPatients,
        SUM(TotalPositiveCOVIDPatients) AS TotalPositiveCOVIDPatients
    FROM (
        SELECT 
            FORMAT(DischargeDateTime, 'MMMM yyyy') AS MonthYear,
            COUNT(DISTINCT CASE 
                WHEN DischargeDispositionID IN ('E', 'DIE', 'DOA', 'X.EXT') 
                THEN AccountNumber 
                END) AS ExpiredPositiveCOVIDPatients,
            COUNT(DISTINCT AccountNumber) AS TotalPositiveCOVIDPatients,
            MIN(CONVERT(DATE, DischargeDateTime)) AS MinDischargeDate
        FROM #RankedResults
        WHERE RN = 1
        GROUP BY FORMAT(DischargeDateTime, 'MMMM yyyy'), YEAR(DischargeDateTime), MONTH(DischargeDateTime)

        UNION ALL

        SELECT 
            'Total' AS MonthYear,
            COUNT(DISTINCT CASE 
                WHEN DischargeDispositionID IN ('E', 'DIE', 'DOA', 'X.EXT') 
                THEN AccountNumber 
                END) AS ExpiredPositiveCOVIDPatients,
            COUNT(DISTINCT AccountNumber) AS TotalPositiveCOVIDPatients,
            NULL AS MinDischargeDate
        FROM #RankedResults
        WHERE RN = 1
    ) AS CombinedResults
    GROUP BY MonthYear, MinDischargeDate
    ORDER BY 
        CASE 
            WHEN MinDischargeDate IS NULL THEN 1 ELSE 0 
        END, 
        MinDischargeDate;

    -- Drop the temporary table
    DROP TABLE #RankedResults;
END
