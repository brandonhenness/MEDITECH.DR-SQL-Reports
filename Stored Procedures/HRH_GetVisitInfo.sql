USE [livemdb]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
*****************************************************************
Report Title:   HRH Get Visit Info
Report Author:  Brandon Henness
Creation Date:  2024/03/26
Description:
    This stored procedure is used to get the visit information for a patient
    based on the patient's account number. The visit information is returned
    in a table format.

    The stored procedure accepts the following parameters:
    - PatientAccount: The account number of the patient

    The stored procedure retrieves the visit information from the following
    tables: AbstractData, AdmVisits, EdmPatientTriage, EdmPatients,
    DMisProvider, DEdmComplnts, EdmPatientDepartCliImpressions,
    DMisNomenclatureMaps, and AbsLocationsAndScus. The visit information is
    filtered based on the patient's account number and the visit ID. The visit
    information is then joined with the corresponding tables to get the
    required information.

    The stored procedure returns the following columns:
    - VisitID: The visit ID of the patient
    - AccountNumber: The account number of the patient
    - AdmitDateTime: The admission date and time of the patient
    - DischargeDateTime: The discharge date and time of the patient
    - EDTriageDateTime: The triage date and time of the patient
    - XferFromEdDateTime: The transfer from ED date and time of the patient

    The stored procedure is used to retrieve visit information for a patient.

Modifications:

*****************************************************************
*/

ALTER   PROCEDURE [dbo].[HRH_GetVisitInfo]
    @PatientAccount VARCHAR(50)

WITH
    RECOMPILE
AS
BEGIN
    SET NOCOUNT ON;
    SET ANSI_NULLS ON;
    SET Quoted_IDENTIFIER ON;

    WITH
        FilteredAbstractData
        AS
        (
            SELECT
                *
            FROM
                AbstractData
            WHERE AccountNumber = @PatientAccount
        )
    SELECT
        FAD.*,
        EPT.[DateTime] AS EDTriageDateTime,
        COALESCE(ABSLOC.EndDateTime, FAD.AdmitDateTime) AS XferFromEdDateTime,
        EDP.ProviderID AS EDProviderID,
        DMISP.Name AS EDProviderName,
        EDP.ComplntID,
        DEDMC.Name AS ChiefComplaint
    FROM
        FilteredAbstractData AS FAD
        INNER JOIN AdmVisits AS ADMV ON FAD.VisitID = ADMV.VisitID
        LEFT JOIN EdmPatientTriage AS EPT ON FAD.VisitID = EPT.VisitID
        LEFT JOIN EdmPatients AS EDP ON FAD.VisitID = EDP.VisitID
        LEFT JOIN DMisProvider AS DMISP ON EDP.ProviderID = DMISP.ProviderID
        LEFT JOIN DEdmComplnts AS DEDMC ON EDP.ComplntID = DEDMC.ComplntID
        LEFT JOIN EdmPatientDepartCliImpressions AS EDPDCLI ON FAD.VisitID = EDPDCLI.VisitID AND EDPDCLI.SeqID = 1
        LEFT JOIN DMisNomenclatureMaps AS DMNM ON EDPDCLI.ImpressionID = DMNM.NomenclatureID
        LEFT JOIN AbsLocationsAndScus AS ABSLOC ON FAD.VisitID = ABSLOC.VisitID AND ABSLOC.LocationID = 'ER ADMIT'

END
