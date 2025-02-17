USE [livemdb]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
*****************************************************************
Report Title:   HRH Health Equity Readmissions
Report Author:  Brandon Henness
Creation Date:  2024/12/22
Description:
    This report retrieves readmissions data for the specified date range.
    The report includes the following columns:
    - Patient ID
    - Unit Number
    - Account Number
    - Visit ID
    - Name

    The report is used to track readmissions data for patients.
Modifications:

*****************************************************************
*/

ALTER   PROCEDURE [dbo].[HRH_HealthEquityReadmissions]
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
      );
      SET @EndDate = EOMONTH(DATEADD(MONTH, -1, GETDATE()));
  END
  ELSE
  BEGIN
      SET @EndDate = ISNULL(@EndDate, GETDATE());
  END;

  -- Load primary population into implicit temp table
  SELECT DISTINCT
    AD.VisitID, AD.UnitNumber, AD.AccountNumber, AD.PatientID, AD.Name, AD.Sex, AD.RaceID, AD.LocationID,
    AD.AdmitDateTime, AD.DischargeDateTime, AD.DischargeDispositionID, AD.ReasonForVisit,
    BDX.DiagnosisSeqID, BDX.DiagnosisCodeID AS PrincipalDX, BDX.Description AS PrincipalDXName,
    BPROV.ProviderID AS AttendProviderID, BPROV.Name AS AttendProviderName, AD.FinancialClassID
  INTO #TempPopTable
  FROM AbstractData AS AD
  LEFT JOIN BarVisits AS BV ON AD.VisitID = BV.VisitID
  LEFT JOIN BarDiagnoses AS BDX ON BV.BillingID = BDX.BillingID AND BDX.DiagnosisSeqID = 1
  LEFT JOIN BarVisitProviders AS BPROV ON BV.BillingID = BPROV.BillingID AND BPROV.VisitProviderTypeID = 'Attending'
  WHERE CAST(AD.DischargeDateTime AS DATE) BETWEEN @StartDate AND @EndDate
    AND AD.PtStatus = 'IN'
    AND AD.LocationID IN ('2ND', '3RD', 'CCU', 'ER ADMIT')
    AND AD.DischargeDispositionID NOT IN ('AMA', 'E')
    AND NOT (AD.DischargeDispositionID LIKE 'HOS%');

  -- Load secondary population (potential readmissions) into implicit temp table
  SELECT DISTINCT
    AD.VisitID, AD.UnitNumber, AD.AccountNumber, AD.PatientID, AD.AdmitDateTime, AD.DischargeDateTime,
    AD.DischargeDispositionID, AD.ReasonForVisit, BDX.DiagnosisSeqID, BDX.DiagnosisCodeID AS PrincipalDX,
    BDX.Description AS PrincipalDXName
  INTO #SecondPopTable
  FROM AbstractData AS AD
  LEFT JOIN BarVisits AS BV ON AD.VisitID = BV.VisitID
  LEFT JOIN BarDiagnoses AS BDX ON BV.BillingID = BDX.BillingID AND BDX.DiagnosisSeqID = 1
  WHERE CAST(AD.AdmitDateTime AS DATE) BETWEEN @StartDate AND DATEADD(DAY, 30, @EndDate)
    AND AD.PtStatus = 'IN'
    AND AD.LocationID IN ('2ND', '3RD', 'CCU', 'ER ADMIT');

  -- Second output: List all readmissions with Race Name
  SELECT DISTINCT
    TMP.PatientID,
    TMP.UnitNumber,
    TMP.AccountNumber,
    TMP.VisitID,
    TMP.Name,
    TMP.Sex,
    TMP.RaceID,
    RACE.Name AS RaceName,
    TMP.AdmitDateTime,
    TMP.DischargeDateTime,
    TMP.ReasonForVisit,
    TMP.PrincipalDX,
    TMP.PrincipalDXName,
    TMP.AttendProviderName,
    SEC.VisitID AS ReadmitVisitID,
    SEC.AdmitDateTime AS ReadmitAdmitDateTime,
    SEC.DischargeDateTime AS ReadmitDischargeDateTime,
    SEC.PrincipalDX AS ReadmitPrincipalDX
  FROM #TempPopTable AS TMP
  INNER JOIN #SecondPopTable AS SEC ON TMP.PatientID = SEC.PatientID
    AND TMP.VisitID != SEC.VisitID
    AND DATEDIFF(DAY, TMP.DischargeDateTime, SEC.AdmitDateTime) BETWEEN 0 AND 30
  LEFT JOIN DMisRace AS RACE ON TMP.RaceID = RACE.RaceID
  ORDER BY TMP.RaceID, TMP.PatientID;

END;
