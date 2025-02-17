USE [livemdb]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
*****************************************************************
Report Title:   HRH Readmissions Inpatient
Report Author:  Brandon Henness
Creation Date:  2024/12/30
Description:
    Retrieves information for readmissions within 30 days of discharge. This report will show the patient's demographics,
    encounter information, and the principal diagnosis for both the initial and readmit visits. The report will also show
    the attending provider for both visits. The report will only show patients who are discharged from the 2nd, 3rd, CCU,
    or ER ADMIT locations. The report will exclude patients who have a discharge disposition of AMA, E, or any discharge
    disposition that starts with HOS. The report will also exclude patients who are under 18 years of age. The report will
    show the total number of readmissions, total number of discharges, total number of readmissions for the attending provider,
    and total number of discharges for the attending provider.
Modifications:
    2023/12/01 RaceID added to code results. -JZ
    2024/12/29 Converted temp table to CTE. -BH
    2024/12/29 Converted date inputs to datetime instead of varchar. -BH
    2024/12/30 Recursively filter sequential readmissions to avoid duplicates. -BH
    2024/12/31 Added age filter. -BH
*****************************************************************
*/

ALTER   PROCEDURE [dbo].[HRH_Readmissions_Inpatient] 
    @FromDate DATETIME,
    @ThruDate DATETIME,
    @ProviderInput VARCHAR(20) = 'ALL',
    @MinAge INT = 0
WITH RECOMPILE
AS
BEGIN
    SET NOCOUNT ON; 
    SET ANSI_NULLS ON; 
    SET QUOTED_IDENTIFIER ON; 
    
    SET @ProviderInput = UPPER(@ProviderInput);

    -- CTE to gather minimal information for discharged patients
    WITH DischargedPatients AS (
        SELECT  
            AD.VisitID,
            AD.PatientID,
            AD.DischargeDateTime,
            BPROV.ProviderID AS AttendProviderID,
            [dbo].[ufn_GetAge](AD.BirthDateTime, AD.AdmitDateTime) AS Age
        FROM AbstractData AS AD
        LEFT JOIN BarVisits AS BV ON AD.VisitID = BV.VisitID
        LEFT JOIN BarVisitProviders AS BPROV ON BV.BillingID = BPROV.BillingID AND BPROV.VisitProviderTypeID = 'Attending'
        WHERE CAST(AD.DischargeDateTime AS DATE) BETWEEN @FromDate AND @ThruDate
          AND AD.PtStatus = 'IN'
          AND AD.LocationID IN ('2ND', '3RD', 'CCU', 'ER ADMIT')
          AND AD.DischargeDispositionID NOT IN ('AMA', 'E')
          AND AD.DischargeDispositionID NOT LIKE 'HOS%'
          AND [dbo].[ufn_GetAge](AD.BirthDateTime, AD.AdmitDateTime) >= @MinAge
    ),
    -- CTE to recursively track sequential readmissions within 30 days
    RecursiveReadmissions AS (
        SELECT 
            DP.VisitID AS InitialVisitID,
            AD.VisitID AS ReadmitVisitID,
            AD.PatientID,
            AD.AdmitDateTime AS ReadmitAdmitDateTime,
            AD.DischargeDateTime AS ReadmitDischargeDateTime,
            DP.AttendProviderID,
            ROW_NUMBER() OVER (PARTITION BY DP.VisitID ORDER BY AD.AdmitDateTime) AS RowNum
        FROM AbstractData AS AD
        INNER JOIN DischargedPatients DP ON AD.PatientID = DP.PatientID
        LEFT JOIN BarVisits AS BV ON AD.VisitID = BV.VisitID
        WHERE AD.AdmitDateTime BETWEEN DP.DischargeDateTime AND DATEADD(DAY, 30, DP.DischargeDateTime)
          AND AD.PtStatus = 'IN'
          AND AD.LocationID IN ('2ND', '3RD', 'CCU', 'ER ADMIT')
    ),
    FilteredReadmissions AS (
        SELECT 
            RecursiveReadmissions.InitialVisitID,
            RecursiveReadmissions.ReadmitVisitID,
            RecursiveReadmissions.PatientID,
            RecursiveReadmissions.ReadmitAdmitDateTime,
            RecursiveReadmissions.ReadmitDischargeDateTime,
            RecursiveReadmissions.AttendProviderID,
            DATEDIFF(DAY, DP.DischargeDateTime, RecursiveReadmissions.ReadmitAdmitDateTime) AS DatePeriod
        FROM RecursiveReadmissions
        INNER JOIN DischargedPatients DP ON RecursiveReadmissions.InitialVisitID = DP.VisitID
        WHERE RowNum = 1
    )
    -- Main query to retrieve full details for both initial and readmit visits
    SELECT 
        AD.PatientID,
        AD.UnitNumber,
        AD.AccountNumber,
        AD.VisitID,
        AD.Name,
        AD.Sex,
        AD.RaceID,
        [dbo].[ufn_GetAge](AD.BirthDateTime, AD.AdmitDateTime) AS Age,
        AD.AdmitDateTime,
        AD.DischargeDateTime,
        AD.ReasonForVisit,
        BDX.DiagnosisSeqID,
        BDX.DiagnosisCodeID AS PrincipalDX,
        BDX.Description AS PrincipalDXName,
        AD.DischargeDispositionID,
        AD.FinancialClassID,
        BPROV.ProviderID AS AttendProviderID,
        BPROV.Name AS AttendProviderName,
        RP.AccountNumber AS AccountNumber2,
        RP.VisitID AS VisitID2,
        RP.AdmitDateTime AS AdmitDateTime2,
        RP.DischargeDateTime AS DischargeDateTime2,
        RP.ReasonForVisit AS ReasonForVisit2,
        RBDX.DiagnosisSeqID AS DiagnosisSeqID2,
        RBDX.DiagnosisCodeID AS PrincipalDX2,
        RBDX.Description AS PrincipalDXName2,
        RP.DischargeDispositionID AS DischargeDispo2,
        FR.DatePeriod,
        (SELECT COUNT(*) FROM FilteredReadmissions) AS TotalReadmits,
        (SELECT COUNT(*) FROM DischargedPatients) AS TotalDischarges,
        (SELECT COUNT(*) FROM FilteredReadmissions FR INNER JOIN DischargedPatients DP ON FR.InitialVisitID = DP.VisitID WHERE DP.AttendProviderID = BPROV.ProviderID) AS TotalProvReadmits,
        (SELECT COUNT(*) FROM DischargedPatients DP WHERE DP.AttendProviderID = BPROV.ProviderID) AS TotalProvDischarges
    FROM AbstractData AS AD
    LEFT JOIN BarVisits AS BV ON AD.VisitID = BV.VisitID
    LEFT JOIN BarDiagnoses AS BDX ON BV.BillingID = BDX.BillingID AND BDX.DiagnosisSeqID = 1
    LEFT JOIN BarVisitProviders AS BPROV ON BV.BillingID = BPROV.BillingID AND BPROV.VisitProviderTypeID = 'Attending'
    INNER JOIN DischargedPatients AS DP ON AD.VisitID = DP.VisitID
    INNER JOIN FilteredReadmissions AS FR ON DP.VisitID = FR.InitialVisitID
    INNER JOIN AbstractData AS RP ON FR.ReadmitVisitID = RP.VisitID
    LEFT JOIN BarVisits AS RBV ON RP.VisitID = RBV.VisitID
    LEFT JOIN BarDiagnoses AS RBDX ON RBV.BillingID = RBDX.BillingID AND RBDX.DiagnosisSeqID = 1
     AND (@ProviderInput = 'ALL' OR @ProviderInput = BPROV.ProviderID)
    ORDER BY AD.RaceID ASC, AD.DischargeDateTime ASC;
END
