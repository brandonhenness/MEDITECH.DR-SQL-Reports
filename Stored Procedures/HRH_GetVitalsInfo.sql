USE [livemdb]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
*****************************************************************
Report Title:   HRH Get Vitals Info
Report Author:  Brandon Henness
Creation Date:  2024/03/26
Description:    
    This stored procedure is used to get the vitals for a patient
    based on the patient's account number. The vitals are returned
    in a table format.

    The stored procedure accepts the following parameters:
    - PatientAccount: The account number of the patient
    - AdmitValuesOnly: A flag to indicate whether to return only
      the vitals taken at the time of admission

    The stored procedure retrieves the vitals from two different
    tables: NurQueryResults and EdmPatientIntervenQueries. The
    vitals are filtered based on the patient's account number and
    the response value. The vitals are then ranked based on the
    actual date and time of the vitals.

    The stored procedure returns the following columns:
    - VisitID: The visit ID of the patient
    - Query: The query for the vitals
    - QueryID: The query ID for the vitals
    - Response: The response value for the vitals
    - ActualDateTime: The actual date and time of the vitals

    The stored procedure is used to retrieve vitals information
    for a patient.

Modifications:

*****************************************************************
*/

ALTER   PROCEDURE [dbo].[HRH_GetVitalsInfo]
    @PatientAccount VARCHAR(50),
    @AdmitValuesOnly BIT = 0

WITH
    RECOMPILE
AS
BEGIN
    SET NOCOUNT ON;
    SET ANSI_NULLS ON;
    SET Quoted_IDENTIFIER ON;


    WITH
        FilteredABSD
        AS
        (
            SELECT
                VisitID,
                AccountNumber
            FROM
                AbstractData
            WHERE AccountNumber = @PatientAccount
        ),
        CombinedVitals
        AS
        (
            -- First part, selecting from NurQueryResults
                SELECT
                    FABSD.VisitID,
                    DMQ.Query,
                    NQR.QueryID,
                    NQR.Response,
                    NQR.DateTime AS ActualDateTime
                FROM
                    FilteredABSD AS FABSD
                    LEFT JOIN NurQueryResults AS NQR ON FABSD.VisitID = NQR.VisitID
                    LEFT JOIN DMisQueries AS DMQ ON NQR.QueryID = DMQ.QueryID
                WHERE
                NQR.Response IS NOT NULL
                    AND (
                    (ISNUMERIC(NQR.Response) = 1 AND NQR.QueryID IN ('NUR-MAP', 'NURT', 'NURTC', 'NURP', 'NURR', 'PCS-65010E'))
                    OR NQR.QueryID IN ('NUR.BP', 'NURBP', 'NURBP1', 'NUR.DBEDBP', 'NUR-05112', 'NURWT10', 'NURWT3', 'NURWTD', 'NURWTKG', 'NURWTKG1', 'NURWT(KG)', 'PCS-35179B', 'PCS-30325', 'PCS-65010C', 'PCS-65010F', 'PCS-65010G', 'PCS-65010I', 'PCS-65010L')
                )

            UNION ALL

                -- Second part, selecting from EdmPatientIntervenQueries
                SELECT
                    FABSD.VisitID,
                    DMQ.Query,
                    EPT.QueryID,
                    EPT.Response,
                    EPT.ActualDateTime
                FROM
                    FilteredABSD AS FABSD
                    LEFT JOIN EdmPatientIntervenQueries AS EPT ON FABSD.VisitID = EPT.VisitID
                    LEFT JOIN DMisQueries AS DMQ ON EPT.QueryID = DMQ.QueryID
                WHERE
                EPT.Response IS NOT NULL
                    AND (
                    (ISNUMERIC(EPT.Response) = 1 AND EPT.QueryID IN ('NUR-MAP', 'NURT', 'NURTC', 'NURP', 'NURR', 'PCS-65010E', 'PCS-65010H'))
                    OR EPT.QueryID IN ('NUR.BP', 'NURBP', 'NURBP1', 'NUR.DBEDBP', 'NUR-05112', 'NURWT10', 'NURWT3', 'NURWTD', 'NURWTKG', 'NURWTKG1', 'NURWT(KG)', 'PCS-35179B', 'PCS-30325', 'PCS-65010C', 'PCS-65010F', 'PCS-65010G', 'PCS-65010I', 'PCS-65010L')
                )
        ),
        RankedVitals
        AS
        (
            SELECT
                *,
                ROW_NUMBER() OVER (PARTITION BY QueryID ORDER BY ActualDateTime) AS RowNum
            FROM
                CombinedVitals
        )
    SELECT
        VisitID,
        Query,
        QueryID,
        Response,
        ActualDateTime
    FROM
        RankedVitals
    WHERE RowNum = 1 OR @AdmitValuesOnly = 0
    ORDER BY ActualDateTime, Query;
END
