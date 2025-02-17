USE [livemdb]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
*****************************************************************
Report Title:   HRH ER Chief Complaint
Report Author:  Brandon Henness, Dave Lenartz
Creation Date:  2024/12/23
Description:
    This stored procedure retrieves chief complaint information for ER trauma reports.
    The report includes the following columns:
    - Unit Number
    - Account Number
    - Name
    - Birth Date Time
    - Age
    - Received Date Time
    - Admit Date Time
    - Discharge Date Time
    - Discharge Disposition ID
    - Arrival ID
    - Reason for Visit
    - ED Provider ID
    - ED Provider Name
    - Complaint ID
    - Chief Complaint
    - Primary Diagnosis Code
    - Primary Diagnosis

    The report is used to track chief complaints for ER trauma reports.

    The report can be run for a specific date range.

Modifications:

*****************************************************************
*/

ALTER   PROCEDURE [dbo].[HRH_ER_Chief_Complaint] 
  @FromDate DATE, 
  @ThruDate DATE
WITH RECOMPILE
AS
BEGIN
  SET NOCOUNT ON;
  SET ANSI_NULLS ON;
  SET QUOTED_IDENTIFIER ON;

  -- CTE to filter down to one EDMPH record per VisitID
  WITH FilteredEDMPH AS (
    SELECT 
        EDMPH.VisitID,
        EDMPH.StartDateTime,
        EDMPH.EventID,
        ROW_NUMBER() OVER (
            PARTITION BY EDMPH.VisitID 
            ORDER BY EDMPH.StartDateTime DESC
        ) AS rn
    FROM EdmPatientStatusEventHistory AS EDMPH
    WHERE 
        EDMPH.EventID = 'RECEIVED'
        AND CAST(EDMPH.StartDateTime AS DATE) BETWEEN @FromDate AND @ThruDate
  ),

  -- CTE to get the primary diagnosis for each visit
  RankedDiagnoses AS (
    SELECT 
        ADG.VisitID,
        ADG.Diagnosis,
        DAD.Name AS PrimaryDiagnosis,
        ROW_NUMBER() OVER (
            PARTITION BY ADG.VisitID 
            ORDER BY ADG.DiagnosisSeqID
        ) AS rn
    FROM AbsDrgDiagnoses AS ADG
    INNER JOIN DAbsDiagnoses AS DAD
        ON ADG.Diagnosis = DAD.DiagnosisCodeID
        AND DAD.Active = 'Y'
    WHERE EXISTS (
        SELECT 1
        FROM FilteredEDMPH AS EDMPH
        WHERE EDMPH.VisitID = ADG.VisitID
    )
  )

  -- Final SELECT pulling only the top rows from each CTE
  SELECT 
    ABSD.UnitNumber,
    ABSD.AccountNumber,
    ABSD.Name,
    ABSD.BirthDateTime,
    [dbo].[ufn_GetAge](ABSD.BirthDateTime, ABSD.AdmitDateTime) AS Age,
    FMPH.StartDateTime AS ReceivedDateTime,
    ABSD.AdmitDateTime,
    ABSD.DischargeDateTime,
    ABSD.DischargeDispositionID,
    ABSD.ArrivalID,
    ABSD.ReasonForVisit,
    EDP.ProviderID AS EDProviderID,
    DMISP.Name AS EDProviderName,
    EDP.ComplntID,
    DEDMC.Name AS ChiefComplaint,
    RD.Diagnosis AS PrimaryDiagnosisCode,
    RD.PrimaryDiagnosis
  FROM 
    AbstractData AS ABSD
  INNER JOIN EdmPatients AS EDP ON ABSD.VisitID = EDP.VisitID
  INNER JOIN FilteredEDMPH AS FMPH ON ABSD.VisitID = FMPH.VisitID AND FMPH.rn = 1
  LEFT JOIN RankedDiagnoses AS RD ON ABSD.VisitID = RD.VisitID AND RD.rn = 1
  LEFT JOIN DMisProvider AS DMISP ON EDP.ProviderID = DMISP.ProviderID
  LEFT JOIN DEdmComplnts AS DEDMC ON EDP.ComplntID = DEDMC.ComplntID
  ORDER BY 
    FMPH.StartDateTime;

END
