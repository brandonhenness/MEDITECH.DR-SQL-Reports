USE [livemdb]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
*****************************************************************
Report Title:   HRH Surgical Mortalities
Report Author:  Brandon Henness
Creation Date:  2024/10/13
Description:
    Retrieves information for surgical mortalities. This report will show patients who have died and had a surgery within a specified number of days before death.
    The report will show the patient's demographics, encounter information, and the procedure information. The report will only show patients who have a discharge
    disposition of 'E', 'DIE', or 'DOA'. The report will exclude patients who were in the CDU or specific locations. The report will show the principal procedure
    and the provider for the procedure.
Modifications:

*****************************************************************
*/

ALTER   PROCEDURE [dbo].[HRH_Surgical_Mortalities]
(
    @FromDate DATETIME,
    @ThruDate DATETIME,
    @Days INT = 30
)
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    -- Step 1: Identify patients with surgeries who died
    SELECT 
        AD.VisitID,
        AD.PatientID, 
        AD.UnitNumber,
        AD.AccountNumber, 
        AD.Name,
        AD.DischargeDateTime,
        AD.AdmitDateTime,
        AD.ReasonForVisit,
        AD.DischargeDispositionID,
        AD.PtStatus,
        AD.LocationID
    INTO #BasePopulation
    FROM AbstractData AS AD
    WHERE AD.PtStatus IN ('IN','SDC','INO')  -- Status indicating inpatient
    AND AD.DischargeDispositionID IN ('E', 'DIE', 'DOA') -- Patient died
    AND CAST(AD.DischargeDateTime AS DATE) BETWEEN @FromDate AND @ThruDate
    AND AD.LocationID NOT LIKE 'P%' -- Exclude specific locations
    AND AD.LocationID <> 'CDU';      -- Exclude CDU

    -- Step 2: Retrieve all procedures for the identified patients by joining with AbstractData to get PatientID
    SELECT 
        P.VisitID,
        AD.PatientID,
        P.Code AS ProcedureCode,
        P.[DateTime] AS ProcedureDateTime,
        P.SeqID AS ProcedurePrincipal,
        P.Description AS ProcedureDescription,
        P.ProviderID AS ProcedureProviderID
    INTO #AllProcedures
    FROM BarSurgicalProcedures AS P
    JOIN AbstractData AS AD
    ON P.VisitID = AD.VisitID
    INNER JOIN #BasePopulation AS BP
    ON AD.PatientID = BP.PatientID
    WHERE P.[DateTime] BETWEEN DATEADD(DAY, -@Days, BP.DischargeDateTime) AND BP.DischargeDateTime -- Only include procedures within @Days before death
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
    );

    -- Step 3: Retrieve all CPT codes for the identified patients by joining with AbstractData to get PatientID
    INSERT INTO #AllProcedures (VisitID, PatientID, ProcedureCode, ProcedureDateTime, ProcedurePrincipal, ProcedureDescription, ProcedureProviderID)
    SELECT 
        C.VisitID,
        AD.PatientID,
        C.Code AS ProcedureCode,
        C.CodeDateTime AS ProcedureDateTime,
        C.CptSeqID AS ProcedurePrincipal,
        C.CodeDescription AS ProcedureDescription,
        C.Surgeon AS ProcedureProviderID
    FROM BarCptCodes AS C
    JOIN AbstractData AS AD
    ON C.VisitID = AD.VisitID
    INNER JOIN #BasePopulation AS BP
    ON AD.PatientID = BP.PatientID
    WHERE C.CodeDateTime BETWEEN DATEADD(DAY, -@Days, BP.DischargeDateTime) AND BP.DischargeDateTime -- Only include CPT codes up to the discharge (death)
    AND NOT C.Code IN ('51700', '51701', '51702', '51102', '49082', '29105', '56605', '56606', '57520', '58301', '36590')

    -- Step 4: Merge procedures into string format for easier reporting
    SELECT 
        BP.VisitID,
        STRING_AGG(PR.ProcedureCode, ' | ') WITHIN GROUP (ORDER BY PR.ProcedureDateTime) AS ProcedureString,
        STRING_AGG(CONVERT(VARCHAR, PR.ProcedureDateTime, 120), ' | ') WITHIN GROUP (ORDER BY PR.ProcedureDateTime) AS ProcedureDateTimeString,
        STRING_AGG(PR.ProcedurePrincipal, ' | ') WITHIN GROUP (ORDER BY PR.ProcedureDateTime) AS ProcedurePrincipalString,
        STRING_AGG(PR.ProcedureDescription, ' | ') WITHIN GROUP (ORDER BY PR.ProcedureDateTime) AS ProcedureDescriptionString,
        STRING_AGG(PR.ProcedureProviderID, ' | ') WITHIN GROUP (ORDER BY PR.ProcedureDateTime) AS ProcedureProviderString
    INTO #ProcedureStrings
    FROM #BasePopulation AS BP
    RIGHT JOIN #AllProcedures AS PR
    ON BP.PatientID = PR.PatientID
    GROUP BY BP.VisitID;

    -- Step 5: Final output of patients who died and their procedures
    SELECT 
        V.Name AS [PatientName],
        V.UnitNumber AS [MedicalRecord], 
        V.AccountNumber AS [AccountNumber], 
        V.DischargeDateTime AS [DischargeDate],
        V.AdmitDateTime AS [AdmitDate],
        V.ReasonForVisit AS [ReasonForVisit],
        V.DischargeDispositionID AS [Disposition],
        PS.ProcedureString AS [ProcedureList],
        PS.ProcedureDateTimeString AS [ProcedureDates],
        PS.ProcedurePrincipalString AS [PrincipalProcedure],
        PS.ProcedureDescriptionString AS [ProcedureDescriptions],
        PS.ProcedureProviderString AS [Providers]
    FROM #BasePopulation AS V
    RIGHT JOIN #ProcedureStrings AS PS ON V.VisitID = PS.VisitID
    ORDER BY V.DischargeDateTime;

    -- Clean up temporary tables
    DROP TABLE IF EXISTS #BasePopulation;
    DROP TABLE IF EXISTS #AllProcedures;
    DROP TABLE IF EXISTS #ProcedureStrings;
END
