USE [livemdb]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
*****************************************************************
Report Title:   HRH Surgical Readmissions
Report Author:  Brandon Henness
Creation Date:  2024/10/15
Description:    
    Retrieves information for surgical readmissions. This report will show patients who have had a surgical procedure and were readmitted within a specified number of days.
    The report will show the patient's demographics, encounter information, and the procedure information. The report will only show patients who have had a surgical procedure
    and were readmitted within a specified number of days. The report will exclude patients who were in the CDU or specific locations. The report will show the initial
    and readmission information for the patient, including the procedures performed and the providers.
Modifications:  

*****************************************************************
*/

ALTER   PROCEDURE [dbo].[HRH_Surgical_Readmissions]
(
    @FromDate DATETIME,
    @ThruDate DATETIME,
    @ReadmissionDays INT = 30
)
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    -- Step 1: Get all patients with surgical procedures and their details (including procedure-related fields)
    -- Insert all surgical procedures (from BarSurgicalProcedures) into #AllSurgicalPatients
    SELECT 
        AD.VisitID,
        AD.PatientID,
        AD.AccountNumber,
		AD.UnitNumber,
        AD.Name,
        AD.AdmitDateTime,
        AD.DischargeDateTime,
        AD.LocationID,
        AD.PtStatus,
        AD.ReasonForVisit,
        P.[DateTime] AS ProcedureDateTime,
        P.SeqID AS ProcedurePrincipal,
        P.Code AS ProcedureCode,
        P.Description AS ProcedureDescription,
        P.ProviderID AS ProcedureProviderID
    INTO #AllSurgicalPatients
    FROM BarSurgicalProcedures AS P
    JOIN AbstractData AS AD ON P.VisitID = AD.VisitID
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

    -- Insert all CPT codes (from BarCptCodes) into #AllSurgicalPatients
    INSERT INTO #AllSurgicalPatients
    SELECT 
        AD.VisitID,
        AD.PatientID,
        AD.AccountNumber,
		AD.UnitNumber,
        AD.Name,
        AD.AdmitDateTime,
        AD.DischargeDateTime,
        AD.LocationID,
        AD.PtStatus,
        AD.ReasonForVisit,
        C.CodeDateTime AS ProcedureDateTime,
        C.CptSeqID AS ProcedurePrincipal,
        C.Code As ProcedureCode,
        C.CodeDescription AS ProcedureDescription,
        C.Surgeon AS ProcedureProviderID
    FROM BarCptCodes AS C
    JOIN AbstractData AS AD ON C.VisitID = AD.VisitID
    WHERE CAST(C.CodeDateTime AS DATE) BETWEEN @FromDate AND @ThruDate
    AND NOT C.Code LIKE 'J%'
    AND NOT AD.LocationID = 'CDU'
    AND AD.PtStatus IN ('IN', 'SDC', 'INO')
    AND NOT C.Code IN ('51700', '51701', '51702', '51102', '49082', '29105', '56605', '56606', '57520', '58301', '36590')

    -- Step 2: Identify readmissions for surgical patients
    -- A readmission is defined as a new visit within @ReadmissionDays after discharge
    SELECT
		A1.UnitNumber,
        A1.PatientID,
        A1.AccountNumber AS InitialAccountNumber,
        A2.AccountNumber AS ReadmitAccountNumber,
        A1.VisitID AS InitialVisitID,
        A2.VisitID AS ReadmissionVisitID,
        A1.DischargeDateTime AS InitialDischargeDate,
        A2.AdmitDateTime AS ReadmitDate,
        A1.LocationID AS InitialLocation,
        A2.LocationID AS ReadmitLocation,
        A1.PtStatus AS InitialPtStatus,
        A2.PtStatus AS ReadmitPtStatus,
        A1.ReasonForVisit AS InitialReasonForVisit,
        A2.ReasonForVisit AS ReadmitReasonForVisit
    INTO #Readmissions
    FROM #AllSurgicalPatients AS A1
    JOIN AbstractData AS A2 ON A1.PatientID = A2.PatientID
    WHERE A2.AdmitDateTime > A1.DischargeDateTime
    AND A2.PtStatus IN ('IN', 'SDC', 'INO', 'ER')
    AND NOT A2.LocationID LIKE 'P%'
    AND NOT A2.LocationID = 'CDU'
    AND DATEDIFF(DAY, A1.DischargeDateTime, A2.AdmitDateTime) <= @ReadmissionDays;  -- Readmission within specified days

    -- Step 3: Aggregate the procedure details for readmitted patients
    SELECT 
        PR.VisitID,
        STRING_AGG(PR.ProcedureCode, ' | ') WITHIN GROUP (ORDER BY PR.ProcedureDateTime) AS ProcedureString,
        STRING_AGG(CONVERT(VARCHAR, PR.ProcedureDateTime, 120), ' | ') WITHIN GROUP (ORDER BY PR.ProcedureDateTime) AS ProcedureDateTimeString,
        STRING_AGG(PR.ProcedurePrincipal, ' | ') WITHIN GROUP (ORDER BY PR.ProcedureDateTime) AS ProcedurePrincipalString,
        STRING_AGG(PR.ProcedureDescription, ' | ') WITHIN GROUP (ORDER BY PR.ProcedureDateTime) AS ProcedureDescriptionString,
        STRING_AGG(PR.ProcedureProviderID, ' | ') WITHIN GROUP (ORDER BY PR.ProcedureDateTime) AS ProcedureProviderString
    INTO #ProcedureStrings
    FROM #AllSurgicalPatients AS PR
    GROUP BY PR.VisitID;

    -- Step 4: Output the list of surgical patients who were readmitted
    SELECT DISTINCT
        R.UnitNumber,
        R.PatientID,
        R.InitialAccountNumber,
        R.ReadmitAccountNumber,
        R.InitialVisitID,
        R.ReadmissionVisitID,
        R.InitialDischargeDate,
        R.ReadmitDate,
        P.Name AS PatientName,
        R.InitialLocation,
        R.ReadmitLocation,
        R.InitialPtStatus,
        R.ReadmitPtStatus,
        R.InitialReasonForVisit,
        R.ReadmitReasonForVisit,
        PS.ProcedureString AS ProcedureList,
        PS.ProcedureDateTimeString AS ProcedureDates,
        PS.ProcedurePrincipalString AS PrincipalProcedure,
        PS.ProcedureDescriptionString AS ProcedureDescriptions,
        PS.ProcedureProviderString AS Providers
    FROM #Readmissions AS R
    JOIN #AllSurgicalPatients AS P ON R.PatientID = P.PatientID
    LEFT JOIN #ProcedureStrings AS PS ON P.VisitID = PS.VisitID
    WHERE P.VisitID = R.InitialVisitID
    ORDER BY R.ReadmitDate;

    -- Clean up temporary tables
    DROP TABLE IF EXISTS #AllSurgicalPatients;
    DROP TABLE IF EXISTS #Readmissions;
    DROP TABLE IF EXISTS #ProcedureStrings;
END
