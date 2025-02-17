USE [livemdb]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
*****************************************************************
Report Title:   HRH Naloxone Distribution
Report Author:  Brandon Henness
Creation Date:  2024/12/22
Description:
    Generates a report for Opioid Harm Prevention: Naloxone Distribution measure. This report will show the patient's demographics,
    encounter information, and the diagnosis information. The report will only show patients who have a diagnosis in the list of
    diagnoses defined by Washington State Hospital Association in the Opioid Harm Prevention: Naloxone Distribution measure. The report
    will also show the prescription information for Naloxone. The report will only show patients who have been discharged to home or
    self-care, left against medical advice, or discharged to home with planned readmission. The report will also show patients who have
    been discharged with a disposition of ELOPEMENT or FC. The report will show the principal diagnosis and other diagnoses for the patient.
    The report will show the number of patients who have received a prescription for Naloxone and the total number of patients who have
    been discharged. The report will be ordered by the discharge date in descending order.    
Modifications: 
    
*****************************************************************
*/

ALTER   PROCEDURE [dbo].[HRH_Naloxone_Distribution] 
  @FromDate DATE, 
  @ThruDate DATE,
  @LocationID varchar(10) = NULL
WITH RECOMPILE
AS
BEGIN
  SET NOCOUNT ON;
  SET ANSI_NULLS ON;
  SET QUOTED_IDENTIFIER ON;

  WITH Diagnoses AS (
    SELECT
      AD.VisitID,
      STRING_AGG(AbsDD.Diagnosis, '|') AS Diagnoses
    FROM livemdb.dbo.AbsDrgDiagnoses AS AbsDD
    JOIN livemdb.dbo.AbstractData AS AD ON AbsDD.VisitID = AD.VisitID
    WHERE AD.LocationID = @LocationID
      AND AbsDD.Diagnosis IN (
      'F11.10', 'F11.120', 'F11.121', 'F11.122', 'F11.129', 'F11.13', 'F11.14', 'F11.150', 'F11.151', 'F11.159',
      'F11.181', 'F11.182', 'F11.188', 'F11.19', 'F11.20', 'F11.220', 'F11.221', 'F11.222', 'F11.229', 'F11.23',
      'F11.24', 'F11.250', 'F11.251', 'F11.259', 'F11.281', 'F11.282', 'F11.288', 'F11.29', 'F11.90', 'F11.91',
      'F11.920', 'F11.921', 'F11.922', 'F11.929', 'F11.93', 'F11.94', 'F11.950', 'F11.951', 'F11.959', 'F11.981',
      'F11.982', 'F11.988', 'F11.99', 'F14.10', 'F14.120', 'F14.121', 'F14.122', 'F14.129', 'F14.13', 'F14.14',
      'F14.150', 'F14.151', 'F14.159', 'F14.180', 'F14.181', 'F14.182', 'F14.188', 'F14.19', 'F14.20', 'F14.220',
      'F14.221', 'F14.222', 'F14.229', 'F14.23', 'F14.24', 'F14.250', 'F14.251', 'F14.259', 'F14.280', 'F14.281',
      'F14.282', 'F14.288', 'F14.29', 'F14.90', 'F14.91', 'F14.920', 'F14.921', 'F14.922', 'F14.929', 'F14.93',
      'F14.94', 'F14.950', 'F14.951', 'F14.959', 'F14.980', 'F14.981', 'F14.982', 'F14.988', 'F14.99', 'F15.120',
      'F15.121', 'F15.122', 'F15.129', 'F15.13', 'F15.14', 'F15.150', 'F15.151', 'F15.159', 'F15.180', 'F15.181',
      'F15.182', 'F15.188', 'F15.19', 'F15.20', 'F15.220', 'F15.221', 'F15.222', 'F15.229', 'F15.23', 'F15.24',
      'F15.250', 'F15.251', 'F15.259', 'F15.280', 'F15.281', 'F15.282', 'F15.288', 'F15.29', 'F15.90', 'F15.91',
      'F15.920', 'F15.921', 'F15.922', 'F15.929', 'F15.93', 'F15.94', 'F15.950', 'F15.951', 'F15.959', 'F15.980',
      'F15.981', 'F15.982', 'F15.988', 'F15.99', 'F16.10', 'F16.120', 'F16.121', 'F16.122', 'F16.129', 'F16.14',
      'F16.150', 'F16.151', 'F16.159', 'F16.180', 'F16.183', 'F16.188', 'F16.19', 'F16.20', 'F16.220', 'F16.221',
      'F16.229', 'F16.24', 'F16.250', 'F16.251', 'F16.259', 'F16.280', 'F16.283', 'F16.288', 'F16.29', 'F16.90',
      'F16.91', 'F16.920', 'F16.921', 'F16.929', 'F16.94', 'F16.950', 'F16.951', 'F16.959', 'F16.980', 'F16.983',
      'F16.988', 'F16.99', 'F18.10', 'F18.120', 'F18.121', 'F18.129', 'F18.14', 'F18.150', 'F18.151', 'F18.159',
      'F18.17', 'F18.180', 'F18.188', 'F18.19', 'F18.20', 'F18.220', 'F18.221', 'F18.229', 'F18.24', 'F18.250',
      'F18.251', 'F18.259', 'F18.27', 'F18.280', 'F18.288', 'F18.29', 'F18.90', 'F18.91', 'F18.920', 'F18.921',
      'F18.929', 'F18.94', 'F18.950', 'F18.951', 'F18.959', 'F18.97', 'F18.980', 'F18.988', 'F18.99', 'F19.10',
      'F19.120', 'F19.121', 'F19.122', 'F19.129', 'F19.130', 'F19.131', 'F19.132', 'F19.139', 'F19.14', 'F19.150',
      'F19.151', 'F19.159', 'F19.16', 'F19.17', 'F19.180', 'F19.181', 'F19.182', 'F19.188', 'F19.19', 'F19.20',
      'F19.220', 'F19.221', 'F19.222', 'F19.229', 'F19.230', 'F19.231', 'F19.232', 'F19.239', 'F19.24', 'F19.250',
      'F19.251', 'F19.259', 'F19.26', 'F19.27', 'F19.280', 'F19.281', 'F19.282', 'F19.288', 'F19.29', 'F19.90',
      'F19.91', 'F19.920', 'F19.921', 'F19.922', 'F19.929', 'F19.930', 'F19.931', 'F19.932', 'F19.939', 'F19.94',
      'F19.950', 'F19.951', 'F19.959', 'F19.96', 'F19.97', 'F19.980', 'F19.981', 'F19.982', 'F19.988', 'F19.99',
      'P04.16', 'P04.42', 'P96.1', 'R78.2', 'R78.3', 'T40.2X1A', 'T40.2X1D', 'T40.2X1S', 'T40.2X2S', 'T40.2X3A',
      'T40.2X3D', 'T40.2X3S', 'T40.2X4A', 'T40.2X4D', 'T40.2X4S', 'T40.2X5A', 'T40.2X5D', 'T40.2X5S', 'T40.2X6A',
      'T40.2X6D', 'T40.2X6S', 'T40.3X1A', 'T40.3X1D', 'T40.3X1S', 'T40.3X2S', 'T40.3X3A', 'T40.3X3D', 'T40.3X3S',
      'T40.3X4A', 'T40.3X4D', 'T40.3X4S', 'T40.3X5A', 'T40.3X5D', 'T40.3X5S', 'T40.3X6A', 'T40.3X6D', 'T40.3X6S',
      'T40.411A', 'T40.411D', 'T40.411S', 'T40.412S', 'T40.413A', 'T40.413D', 'T40.413S', 'T40.414A', 'T40.414D',
      'T40.414S', 'T40.415A', 'T40.415D', 'T40.415S', 'T40.416A', 'T40.416D', 'T40.416S', 'T40.421A', 'T40.421D',
      'T40.421S', 'T40.422S', 'T40.423A', 'T40.423D', 'T40.423S', 'T40.424A', 'T40.424D', 'T40.424S', 'T40.425A',
      'T40.425D', 'T40.425S', 'T40.426A', 'T40.496D', 'T40.496S', 'T40.601A', 'T40.601D', 'T40.601S', 'T40.602S',
      'T40.603A', 'T40.603D', 'T40.603S', 'T40.604A', 'T40.604D', 'T40.604S', 'T40.605A', 'T40.605D', 'T40.605S',
      'T40.606A', 'T40.606D', 'T40.606S', 'T40.691A', 'T40.691D', 'T40.691S', 'T40.692S', 'T40.693A', 'T40.693D',
      'T40.693S', 'T40.694A', 'T40.694D', 'T40.694S', 'T40.695A', 'T40.695D', 'T40.695S', 'T40.901A', 'T40.901D',
      'T40.901S', 'T40.902S', 'T40.903A', 'T40.903D', 'T40.903S', 'T40.904A', 'T40.904D', 'T40.904S', 'T40.905A',
      'T40.905D', 'T40.905S', 'T40.906A', 'T40.906D', 'T40.906S', 'T40.991A', 'T40.991D', 'T40.991S', 'T40.992S',
      'T40.993A', 'T40.993D', 'T40.993S', 'T40.994A', 'T40.994D', 'T40.994S', 'T40.995A', 'T40.995D', 'T40.995S',
      'T40.996A', 'T40.996D', 'T40.996S', 'T42.3X1A', 'T42.3X1D', 'T42.3X1S', 'T42.3X2S', 'T42.3X3A', 'T42.3X3D',
      'T42.3X3S', 'T42.3X4A', 'T42.3X4D', 'T42.3X4S', 'T42.3X5A', 'T42.3X5D', 'T42.3X5S', 'T42.3X6A', 'T42.3X6D',
      'T42.3X6S', 'T42.4X1A', 'T42.4X1D', 'T42.4X1S', 'T42.4X2S', 'T42.4X3A', 'T42.4X3D', 'T42.4X3S', 'T42.4X4A',
      'T42.4X4D', 'T42.4X4S', 'T42.4X5A', 'T42.4X5D', 'T42.4X5S', 'T42.4X6A', 'T42.4X6D', 'T42.4X6S', 'T43.621A',
      'T43.621D', 'T43.621S', 'T43.622S', 'T43.623A', 'T43.623D', 'T43.623S', 'T43.624A', 'T43.624D', 'T43.624S',
      'T43.625A', 'T43.625D', 'T43.625S', 'T43.626A', 'T43.626D', 'T43.626S', 'T43.641A', 'T43.641D', 'T43.641S',
      'T43.642S', 'T43.643A', 'T43.643D', 'T43.643S', 'T43.644A', 'T43.644D', 'T43.644S', 'T43.651A', 'T43.651D',
      'T43.651S', 'T43.652S', 'T43.653A', 'T43.653D', 'T43.653S', 'T43.654A', 'T43.654D', 'T43.654S', 'T43.655A',
      'T43.655D', 'T43.655S', 'T43.656A', 'T43.656D', 'T43.656S', 'T43.691A', 'T43.691D', 'T43.691S', 'T43.692S',
      'T43.693A', 'T43.693D', 'T43.693S', 'T43.694A', 'T43.694D', 'T43.694S', 'T43.695A', 'T43.695D', 'T43.695S',
      'T43.696A', 'T43.696D', 'T43.696S', 'T43.8X1A', 'T43.8X1D', 'T43.8X1S', 'T43.8X2S', 'T43.8X3A', 'T43.8X3D',
      'T43.8X3S', 'T43.8X4A', 'T43.8X4D', 'T43.8X4S', 'T43.8X5A', 'T43.8X5D', 'T43.8X5S', 'T43.8X6A', 'T43.8X6D',
      'T43.8X6S', 'T43.91XA', 'T43.91XD', 'T43.91XS', 'T43.92XS', 'T43.93XA', 'T43.93XD', 'T43.93XS', 'T43.94XA',
      'T43.94XD', 'T43.94XS', 'T43.95XA', 'T43.95XD', 'T43.95XS', 'T43.96XA', 'T43.96XD', 'T43.96XS'
      ) -- Diagnoses codes defined by Washington State Hospital Association in the Opioid Harm Prevention: Naloxone Distribution measure. 05/31/2024
      AND CAST(AD.DischargeDateTime AS DATE) BETWEEN @FromDate AND @ThruDate
    GROUP BY AD.VisitID
  ),
  Prescriptions AS (
    SELECT
      Rx.VisitID,
      STRING_AGG(Rx.PrescriptionID, '|') AS Prescriptions
    FROM livemdb.dbo.PhaRx AS Rx
    JOIN livemdb.dbo.PhaRxMedications AS RxM ON Rx.PrescriptionID = RxM.PrescriptionID
    JOIN livemdb.dbo.DPhaDrugData AS DD ON RxM.DrugID = DD.DrugID
    WHERE DD.GenericID = 'NALOXO' AND DD.Active = 'Y' AND Rx.DiscontinueMessage = 'DISCHARGE'
    GROUP BY Rx.VisitID
  )
  SELECT
    --AD.VisitID,
	AD.AccountNumber,
	AD.UnitNumber,
    AD.Name,
    AD.LocationID,
    AD.AdmitDateTime,
    AD.DischargeDateTime,
    D.Diagnoses,
    P.Prescriptions,
    COUNT(P.Prescriptions) OVER () AS Numerator,
    COUNT(*) OVER () AS Denominator
  FROM Diagnoses AS D
  LEFT JOIN livemdb.dbo.AbstractData AS AD ON AD.VisitID = D.VisitID
  LEFT JOIN Prescriptions AS P ON AD.VisitID = P.VisitID
  LEFT JOIN livemdb.dbo.DMisDischargeDisposition AS DDD ON AD.DischargeDispositionID = DDD.DispositionID
  WHERE DDD.Ub82Code IN (
    '01', -- Discharged to home or self-care
    '07', -- Left against medical advice
    '81'  -- Discharged to home with planned readmission
  )
  OR DDD.DispositionID IN ('ELOPEMENT', 'FC') -- Manually handle missing Ub82 codes
  ORDER BY DischargeDateTime DESC

END
