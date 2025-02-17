USE [livemdb]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
*****************************************************************
Report Title:   HRH SDOH Screening
Report Author:  Brandon Henness
Creation Date:  2024/05/07
Description:
    Retrieves information for SDOH Screening measure. This measure is for patients who have been screened for social determinants of health. The report will
    show the patient's demographics, encounter information, and the screening information. The report will only show patients who have been screened for food
    insecurity, housing instability, transportation needs, utility difficulties, and interpersonal safety. The report will show the number of patients who have
    been screened for each of the social determinants of health. The report will also show the number of patients who have been screened for all five social
    determinants of health.
Modifications:
    
*****************************************************************
*/

ALTER PROCEDURE [dbo].[HRH_SDOH_Screening] (
    @StartDate DATE,
    @EndDate DATE
)
WITH
    RECOMPILE
AS
BEGIN
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

WITH
    OptimalResponse AS (
        SELECT
            VisitID,
            QueryID,
            ActivitySeqID
        FROM
            (
                SELECT
                    VisitID,
                    QueryID,
                    ActivitySeqID,
                    Response,
                    ROW_NUMBER() OVER (
                        PARTITION BY
                            VisitID,
                            QueryID
                        ORDER BY
                            CASE
                                WHEN (
                                    QueryID IN (
                                        'PCS-95160E',
                                        'PCS-95160F',
                                        'PCS-95160G',
                                        'PCS-95160H'
                                    )
                                    AND Response = 'Y'
                                )
                                OR (
                                    QueryID = 'PCS-85004'
                                    AND Response = 'N'
                                ) THEN 0
                                ELSE 1
                            END,
                            ActivitySeqID DESC
                    ) AS SeqRank
                FROM
                    NurQueryResults
                WHERE
                    QueryID IN (
                        'PCS-95160E',
                        'PCS-95160F',
                        'PCS-95160G',
                        'PCS-95160H',
                        'PCS-85004'
                    )
            ) AS RankedResponses
        WHERE
            SeqRank = 1
    ),
    FilteredResponses AS (
        SELECT
            NQR.VisitID,
            NQR.QueryID,
            NQR.Response
        FROM
            NurQueryResults NQR
            INNER JOIN OptimalResponse OptResp ON NQR.VisitID = OptResp.VisitID
            AND NQR.QueryID = OptResp.QueryID
            AND NQR.ActivitySeqID = OptResp.ActivitySeqID
    ),
    ScreenedPatients AS (
        SELECT
            ABSD.VisitID
        FROM
            AbstractData ABSD
            LEFT JOIN FilteredResponses FR ON ABSD.VisitID = FR.VisitID
        WHERE
            ABSD.AdmitDateTime BETWEEN @StartDate AND @EndDate
            AND ABSD.PtStatus = 'IN'
            AND ABSD.BirthDateTime <= DATEADD(YEAR, -18, ABSD.AdmitDateTime)
        GROUP BY
            ABSD.VisitID
        HAVING
            COUNT(DISTINCT FR.QueryID) = 5
    )
SELECT
    COUNT(DISTINCT SP.VisitID) AS [SDOH-1 Numerator & SDOH-2 Denominator],
    COUNT(DISTINCT ABSD.VisitID) AS [SDOH-1 Denominator],
    COUNT(
        DISTINCT CASE
            WHEN FR.QueryID = 'PCS-95160E'
            AND FR.Response = 'Y'
            AND SP.VisitID IS NOT NULL THEN ABSD.VisitID
        END
    ) AS [Food insecurity],
    COUNT(
        DISTINCT CASE
            WHEN FR.QueryID = 'PCS-95160F'
            AND FR.Response = 'Y'
            AND SP.VisitID IS NOT NULL THEN ABSD.VisitID
        END
    ) AS [Housing instability],
    COUNT(
        DISTINCT CASE
            WHEN FR.QueryID = 'PCS-95160G'
            AND FR.Response = 'Y'
            AND SP.VisitID IS NOT NULL THEN ABSD.VisitID
        END
    ) AS [Transportation needs],
    COUNT(
        DISTINCT CASE
            WHEN FR.QueryID = 'PCS-95160H'
            AND FR.Response = 'Y'
            AND SP.VisitID IS NOT NULL THEN ABSD.VisitID
        END
    ) AS [Utility difficulties],
    COUNT(
        DISTINCT CASE
            WHEN FR.QueryID = 'PCS-85004'
            AND FR.Response = 'N'
            AND SP.VisitID IS NOT NULL THEN ABSD.VisitID
        END
    ) AS [Interpersonal safety]
FROM
    AbstractData ABSD
    LEFT JOIN FilteredResponses FR ON ABSD.VisitID = FR.VisitID
    LEFT JOIN ScreenedPatients SP ON ABSD.VisitID = SP.VisitID
WHERE
    ABSD.AdmitDateTime BETWEEN @StartDate AND @EndDate
    AND ABSD.PtStatus = 'IN'
    AND ABSD.BirthDateTime <= DATEADD(YEAR, -18, ABSD.AdmitDateTime);


END;


