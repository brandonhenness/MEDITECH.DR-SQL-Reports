USE [livemdb]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
*****************************************************************
Report Title:   HRH Surgical Readmissions Summary
Report Author:  Brandon Henness
Creation Date:  2024/10/15
Description:
    Retrieves information for surgical readmissions summary. This report will show the total number of surgical readmissions and the total number of distinct patients
    who had procedures. The report will calculate the readmission rate per 100 patients with procedures. The report will only show patients who had a surgical procedure
    and were readmitted within a specified number of days. The report will exclude patients who were in the CDU or specific locations. The report will show the initial
    and readmission information for the patient, including the procedures performed and the providers.
Modifications:  

*****************************************************************
*/

ALTER   PROCEDURE [dbo].[HRH_Surgical_Readmissions_Summary]
(
    @FromDate DATETIME,
    @ThruDate DATETIME,
    @ReadmissionDays INT = 30
)
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    -- Step 1: Get total number of surgical readmissions (numerator) by calling HRH_Surgical_Readmissions
    DECLARE @TotalReadmissions INT;

    -- Create a temp table to hold the results from HRH_Surgical_Readmissions
    CREATE TABLE #ReadmissionsResult (
        UnitNumber VARCHAR(50),
        PatientID VARCHAR(50),
        InitialAccountNumber VARCHAR(50),
        ReadmissionAccountNumber VARCHAR(50),
        InitialVisitID VARCHAR(50),
        ReadmissionVisitID VARCHAR(50),
        InitialDischargeDate DATETIME,
        ReadmitDate DATETIME,
        PatientName VARCHAR(255),
        InitialLocation VARCHAR(50),
        ReadmitLocation VARCHAR(50),
        InitialPtStatus VARCHAR(10),
        ReadmitPtStatus VARCHAR(10),
        InitialReasonForVisit VARCHAR(255),
        ReadmitReasonForVisit VARCHAR(255),
        ProcedureList VARCHAR(MAX),
        ProcedureDates VARCHAR(MAX),
        PrincipalProcedure VARCHAR(MAX),
        ProcedureDescriptions VARCHAR(MAX),
        Providers VARCHAR(MAX)
    );

    -- Insert results into temp table
    INSERT INTO #ReadmissionsResult
    EXEC dbo.HRH_Surgical_Readmissions @FromDate, @ThruDate, @ReadmissionDays;

    -- Get the total number of readmissions
    SELECT @TotalReadmissions = COUNT(*)
    FROM #ReadmissionsResult;

    -- Step 2: Get total number of distinct patients with procedures (denominator)
    DECLARE @TotalPatientsWithProcedures INT;

    -- Retrieve the total number of distinct patients who had procedures
    SELECT 
        @TotalPatientsWithProcedures = COUNT(DISTINCT PatientID)
    FROM (
        -- Surgical Procedures
        SELECT 
            AD.PatientID
        FROM BarSurgicalProcedures AS P
        JOIN AbstractData AD ON P.VisitID = AD.VisitID
        WHERE CAST(P.[DateTime] AS DATE) BETWEEN @FromDate AND @ThruDate
        AND NOT AD.LocationID = 'CDU'
        AND AD.PtStatus IN ('IN', 'SDC', 'INO')
        AND NOT P.Code IN (
			'03H733Z', '03H833Z', '03HB33Z', '03HC33Z', '03HY32Z', '04HK33Z', '04HY32Z', '05H533Z', '05H633Z', 
			'05H933Z', '05HA33Z', '05HB33Z', '05HC33Z', '05HF33Z', '05HM33Z', '05HN33Z', '05HQ33Z', '05HY33Z', 
			'05PY33Z', '05PYX3Z', '06H033Z', '06HM33Z', '06HN33Z', '06HY33Z', '3E0102A', '3E01340', '3E0134Z', 
			'3E0233Z', '3E02340', '3E0234Z', '3E023BZ', '3E03317', '3E03329', '3E0333Z', '3E0334Z', '3E0336Z', 
			'3E0337Z', '3E033GC', '3E033PZ', '3E033VJ', '3E033XZ', '3E04329', '3E0436Z', '3E043VJ', '3E043XZ', 
			'3E053VJ', '3E053XZ', '3E0636Z', '3E063VJ', '3E073GC', '3E073PZ', '3E0D7GC', '3E0DXGC', '3E0E7GC', 
			'3E0F7GC', '3E0F7SF', '3E0G36Z', '3E0G76Z', '3E0G8GC', '3E0H76Z', '3E0H8GC', '3E0K76Z', '3E0M05Z', 
			'3E0P05Z', '3E0P73Z', '3E0P7GC', '3E0P7VZ', '3E0R33Z', '3E0R3BZ', '3E0T3BZ', '3E0U33Z', '3E0U3BZ', 
			'3E0V329', '4A10X4Z', '4A1234Z', '4A12XCZ', '4A133B1', '4A133J1', '4A1BXSH', '4A1H7CZ', '4A1H8CZ', 
			'4A1HX4Z', '4A1HXCZ', '4A1HXFZ', '4A1JX2Z', '5A09357', '5A09358', '5A09359', '5A0935A', '5A0935B', 
			'5A09457', '5A09459', '5A0945A', '5A09557', '5A0955A', '5A1935Z', '5A1945Z', '5A1955Z', '6A600ZZ', 
			'6A601ZZ', '6A800ZZ', '8E0ZXY6', 'F07Z5FZ', 'F07Z9FZ', 'F07Z9ZZ', 'GZ3ZZZZ', 'GZ56ZZZ', 'GZ63ZZZ', 
			'GZHZZZZ', 'HZ2ZZZZ', 'HZ30ZZZ', 'HZ31ZZZ', 'HZ32ZZZ', 'HZ33ZZZ', 'HZ34ZZZ', 'HZ36ZZZ', 'HZ37ZZZ', 
			'HZ38ZZZ', 'HZ39ZZZ', 'HZ41ZZZ', 'HZ43ZZZ', 'HZ44ZZZ', 'HZ46ZZZ', 'HZ49ZZZ', 'HZ51ZZZ', 'HZ53ZZZ', 
			'HZ54ZZZ', 'HZ56ZZZ', 'HZ59ZZZ', 'HZ5BZZZ', 'HZ5DZZZ', 'HZ63ZZZ', 'HZ80ZZZ', 'HZ81ZZZ', 'HZ84ZZZ', 
			'HZ85ZZZ', 'HZ87ZZZ', 'HZ88ZZZ', 'HZ89ZZZ', 'HZ90ZZZ', 'HZ94ZZZ', 'HZ95ZZZ', 'HZ96ZZZ', 'HZ97ZZZ', 
			'HZ98ZZZ', 'HZ99ZZZ', 'XW033E5', 'XW033H5', 'XW033H6', 'XW033N5', 'XW043E5', 'XW0DXF5', '30230N1', 
			'30233K1', '30233L1', '30233N1', '30233P1', '30233R1', '30243K1', '30243N1', '30243R1', '30253N1', 
			'30273N1', '30277K1', '30283B1', '02HV33Z', '0W9B3ZZ', '0W9G3ZZ', '0BH17EZ', '0T9B70Z', '0W993ZZ', 
			'0T2BX0Z', '02HV33Z', '0BH17EZ', '0BH18EZ', '02H633Z', '0W9B3ZZ', '0W993ZZ', '0T9B70Z', '0T2BX0Z', 
			'10E0XZZ', '10907ZC', '0HQ9XZZ', 'OUQMXZZ', '10907ZC', '0W9F3ZX', '0W9830Z', '0W9B3ZX', '0W9G30Z', 
			'302A3N1', '0W9G3ZX', '02HV00Z', '0KQM0ZZ', '0UQGXZZ', '0UQMXZZ', '0VTTXZZ', '5A2204Z', '30243L1', 
			'0FQ00ZZ', '302A3N1', '30233H1', '10H07YZ'
        )

        UNION

        -- CPT Codes
        SELECT 
            AD.PatientID
        FROM BarCptCodes AS C
        JOIN AbstractData AD ON C.VisitID = AD.VisitID
        WHERE CAST(C.CodeDateTime AS DATE) BETWEEN @FromDate AND @ThruDate
        AND NOT C.Code LIKE 'J%'
        AND NOT AD.LocationID = 'CDU'
        AND AD.PtStatus IN ('IN', 'SDC', 'INO')
        AND NOT C.Code IN ('51700', '51701', '51702', '51102', '49082', '29105', '56605', '56606', '57520', '58301', '36590')
    ) AS CombinedProcedures;

    -- Step 3: Calculate the readmission rate per 100 patients with procedures
    DECLARE @SurgicalReadmissionRate DECIMAL(10, 2);

    IF @TotalPatientsWithProcedures > 0
    BEGIN
        -- Calculate readmissions per 100 patients with procedures
        SET @SurgicalReadmissionRate = CAST(@TotalReadmissions AS DECIMAL(10, 2)) / @TotalPatientsWithProcedures * 100;
    END
    ELSE
    BEGIN
        SET @SurgicalReadmissionRate = 0;
    END

    -- Step 4: Output the final result
    SELECT 
        @TotalReadmissions AS TotalReadmissions,
        @TotalPatientsWithProcedures AS TotalPatientsWithProcedures,
        @SurgicalReadmissionRate AS SurgicalReadmissionRate;

    -- Clean up temporary table
    DROP TABLE IF EXISTS #ReadmissionsResult;
END
