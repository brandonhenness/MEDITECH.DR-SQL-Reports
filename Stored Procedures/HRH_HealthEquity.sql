USE [livemdb]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
*****************************************************************
Report Title:   HRH Health Equity
Report Author:  Brandon Henness
Creation Date:  2024/12/22
Description:
    This report retrieves health equity data for the specified date range.

    The report is used to track health equity data for patients.
Modifications:

*****************************************************************
*/

ALTER   PROCEDURE [dbo].[HRH_HealthEquity]
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
    BPROV.ProviderID AS AttendProviderID, BPROV.Name AS AttendProviderName, AD.FinancialClassID,
    YEAR(AD.DischargeDateTime) AS DischargeYear, MONTH(AD.DischargeDateTime) AS DischargeMonth
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
    BDX.Description AS PrincipalDXName,
    YEAR(AD.AdmitDateTime) AS AdmitYear, MONTH(AD.AdmitDateTime) AS AdmitMonth
  INTO #SecondPopTable
  FROM AbstractData AS AD
  LEFT JOIN BarVisits AS BV ON AD.VisitID = BV.VisitID
  LEFT JOIN BarDiagnoses AS BDX ON BV.BillingID = BDX.BillingID AND BDX.DiagnosisSeqID = 1
  WHERE CAST(AD.AdmitDateTime AS DATE) BETWEEN @StartDate AND DATEADD(DAY, 30, @EndDate)
    AND AD.PtStatus = 'IN'
    AND AD.LocationID IN ('2ND', '3RD', 'CCU', 'ER ADMIT');

  -- Count total discharges by race, year, and month
  SELECT
    RaceID,
    YEAR(DischargeDateTime) AS DischargeYear,
    MONTH(DischargeDateTime) AS DischargeMonth,
    COUNT(DISTINCT VisitID) AS TotalDischarges
  INTO #DischargesByRaceMonth
  FROM #TempPopTable
  GROUP BY RaceID, YEAR(DischargeDateTime), MONTH(DischargeDateTime);

  -- Count total readmissions by race, year, and month
  SELECT
    TMP.RaceID,
    SEC.AdmitYear,
    SEC.AdmitMonth,
    COUNT(DISTINCT SEC.VisitID) AS TotalReadmissions
  INTO #ReadmissionsByRaceMonth
  FROM #TempPopTable AS TMP
  INNER JOIN #SecondPopTable AS SEC ON TMP.PatientID = SEC.PatientID
    AND TMP.VisitID != SEC.VisitID
    AND DATEDIFF(DAY, TMP.DischargeDateTime, SEC.AdmitDateTime) BETWEEN 0 AND 30
  GROUP BY TMP.RaceID, SEC.AdmitYear, SEC.AdmitMonth;

  -- Output RaceID, Race Name, year, month, total readmissions (numerator), and total discharges (denominator)
  SELECT
    D.RaceID,
    RACE.Name AS RaceName,
    D.DischargeYear,
    D.DischargeMonth,
    ISNULL(R.TotalReadmissions, 0) AS Numerator,
    D.TotalDischarges AS Denominator
  FROM #DischargesByRaceMonth D
  LEFT JOIN #ReadmissionsByRaceMonth R ON D.RaceID = R.RaceID
    AND D.DischargeYear = R.AdmitYear
    AND D.DischargeMonth = R.AdmitMonth
  LEFT JOIN DMisRace AS RACE ON D.RaceID = RACE.RaceID
  ORDER BY D.DischargeYear, D.DischargeMonth, D.RaceID;

END;
