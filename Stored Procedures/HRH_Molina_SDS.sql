USE [livemdb]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
*****************************************************************
Report Title:   HRH Molina SDS
Report Author:  Brandon Henness
Creation Date:  2024/10/05
Description:
    This stored procedure is used to extract lab results for Molina Medicaid patients supplemental data set. The report will show the patient's demographics,
    encounter information, and the lab results. The report will only show patients who have had a lab test with a LOINC code in the list of LOINC codes defined
    by Molina Medicaid. The report will also show the provider NPI number for the ordering provider and the place of service for the lab test. The report will
    be ordered by the visit ID.
Modifications: 
    
*****************************************************************
*/

ALTER   PROCEDURE [dbo].[HRH_Molina_SDS]
	@StartDate DATETIME = NULL,
    @EndDate DATETIME = NULL
AS
DECLARE @localStartDate DATETIME, @localEndDate DATETIME
SET @localStartDate = @StartDate
SET @localEndDate = @EndDate
BEGIN

    SET NOCOUNT ON;
	SET FMTONLY OFF;

    IF @localStartDate IS NULL BEGIN
        SET @localStartDate = DATEFROMPARTS(YEAR(DATEADD(MONTH, -1, GETDATE())), MONTH(DATEADD(MONTH, -1, GETDATE())), 1)
        SET @localEndDate = EOMONTH(DATEADD(MONTH, -1, GETDATE()))
    END
    ELSE BEGIN
        SET @localEndDate = ISNULL(@localEndDate, GETDATE())
    END;

    DECLARE @StartTime DATETIME2, @EndTime DATETIME2;

    -- Step 1: Create the BasePopulation
    SET @StartTime = SYSDATETIME();
    SELECT
        AB.VisitID,
        AB.UnitNumber AS 'SubscriberKey / MemberKey',
        AI.PolicyNumber AS 'Policy Number / Medicaid_Number*',
        COALESCE(dbo.fn_LastName (AB.Name), '') AS 'LastName',
        COALESCE(dbo.fn_FirstName (AB.Name), '') AS 'FirstName',
        COALESCE(dbo.fn_MiddleName (AB.Name), '') AS 'MiddleName',
        CONVERT(VARCHAR, AB.BirthDateTime, 101) AS 'DOB',
        AB.Sex AS 'Gender',
        AB.RaceID AS 'Race',
        '' AS 'Ethnicity', --TODO: Add Ethnicity
        '' AS 'Language', --TODO: Add Language
        CASE
            WHEN AB.UniquePublicIdentifier = '000-00-0000' THEN ''
            WHEN AB.UniquePublicIdentifier IS NULL THEN ''
            ELSE AB.UniquePublicIdentifier
        END AS 'SSN',
        CASE
            WHEN DMIS.NationalProviderIdNumber IS NULL THEN ''
            ELSE CONVERT(VARCHAR, DMIS.NationalProviderIdNumber)
        END AS 'Provider NPI',
        CASE
            WHEN AB.AdmitSourceID = 'ER' THEN '21'
            WHEN AB.AdmitSourceID = 'PR' THEN '11'
            WHEN AB.AdmitSourceID = 'CR' THEN '49' -- TODO: Add more HCFAPOS mappings https://www.cms.gov/medicare/coding-billing/place-of-service-codes/code-sets
            ELSE ''
        END AS 'HCFAPOS',
        AB.AdmitSourceID AS 'POS'
        -- ARC.RevenueCodeID AS 'RevenueCode'
    INTO #BasePopulation
    FROM 
        AbstractData AB
        JOIN BarVisits BV ON AB.VisitID = BV.VisitID
        JOIN AdmProviders APROV ON APROV.VisitID = BV.VisitID
        JOIN DMisProvider DMIS ON DMIS.ProviderID = APROV.AttendID
        JOIN AbsInsurances AI ON AI.VisitID = BV.VisitID
        JOIN (
            SELECT DISTINCT BarChargeTransactions.VisitID
            FROM BarChargeTransactions
            WHERE CAST(ServiceDateTime AS DATE) BETWEEN @localStartDate AND @localEndDate
        ) BCTX ON AB.VisitID = BCTX.VisitID
    WHERE AI.InsuranceID = 'HO-MHC'; -- Molina Medicaid

    SET @EndTime = SYSDATETIME();
    PRINT 'BasePopulation query took: ' + CONVERT(VARCHAR, DATEDIFF(MILLISECOND, @StartTime, @EndTime)) + ' ms';

    -- Step 2: Pull the diagnoses, procedures, coding information, and vitals for the BasePopulation.
    SET @StartTime = SYSDATETIME();
    WITH Diagnoses AS (
        SELECT AD.VisitID,
            AD.DiagnosisSeqID,
            AD.Diagnosis
        FROM AbsDrgDiagnoses AD
            INNER JOIN #BasePopulation BP ON AD.VisitID = BP.VisitID
    ),
    Procedures AS (
        SELECT BSP.VisitID,
            BSP.SeqID,
            BSP.Code
        FROM BarSurgicalProcedures BSP
            INNER JOIN #BasePopulation BP ON BSP.VisitID = BP.VisitID
    ),
    Coding AS (
        SELECT BP.VisitID,
            SUM(BCTX.TransactionCount) AS TotalTransactionCount,
            MAX(CONVERT(VARCHAR, BCTX.ServiceDateTime, 101)) AS 'Date of Service',
            MAX(CASE WHEN LatestCodes.TypeID = 'CPT-4' THEN LatestCodes.Code ELSE NULL END) AS 'CPTCode',
            MAX( CASE WHEN LatestCodes.TypeID = 'HCPCS' THEN LEFT(LatestCodes.Code, 5) ELSE NULL END) AS 'HCPCSPX',
            MAX(CASE WHEN LatestCodes.TypeID = 'HCPCS' AND LEN(LatestCodes.Code) > 5 THEN SUBSTRING(LatestCodes.Code, 6, LEN(LatestCodes.Code)) ELSE NULL END) AS 'MCPCSMOD',
            MAX(CASE WHEN LatestCodes.TypeID = 'CPT-4' AND LEN(LatestCodes.Code) > 5 THEN SUBSTRING(LatestCodes.Code, 6, LEN(LatestCodes.Code)) ELSE NULL END) AS 'Modifier'
        FROM BarChargeTransactions BCTX
            INNER JOIN #BasePopulation BP ON BCTX.VisitID = BP.VisitID
            LEFT JOIN (
                SELECT ProcedureID,
                    SourceID,
                    TypeID,
                    Code,
                    ROW_NUMBER() OVER (
                        PARTITION BY ProcedureID,
                        TypeID
                        ORDER BY EffectiveDateTime DESC
                    ) AS rn
                FROM DBarProcAltCodeEffectDates
                WHERE TypeID IN ('CPT-4', 'HCPCS')
                    AND Code IS NOT NULL
            ) AS LatestCodes ON BCTX.TransactionProcedureID = LatestCodes.ProcedureID
            AND BCTX.SourceID = LatestCodes.SourceID
            AND LatestCodes.rn = 1
        GROUP BY BP.VisitID
        HAVING SUM(BCTX.TransactionCount) > 0
    ),
    CTE_BP AS (
        -- Pull vitals from NurQueryResults
        SELECT BP.VisitID,
            CASE
                -- Handle blood pressure QueryIDs and only process if '/' is found
                WHEN NQR.QueryID IN (
                    'NUR.BP', -- Blood Pressure
                    'NURBP', -- Blood Pressure
                    'NURBP1', -- Blood Pressure
                    'NUR.DBEDBP', -- Blood Pressure
                    'PCS-65010G' -- Blood Pressure
                ) AND CHARINDEX('/', NQR.Response) > 0 THEN TRY_CAST(
                    SUBSTRING(
                        NQR.Response,
                        1,
                        CHARINDEX('/', NQR.Response) - 1
                    ) AS INT
                )
            END AS Systolic,
            CASE
                -- Handle blood pressure QueryIDs and only process if '/' is found
                WHEN NQR.QueryID IN (
                    'NUR.BP', -- Blood Pressure
                    'NURBP', -- Blood Pressure
                    'NURBP1', -- Blood Pressure
                    'NUR.DBEDBP', -- Blood Pressure
                    'PCS-65010G' -- Blood Pressure
                ) AND CHARINDEX('/', NQR.Response) > 0 THEN TRY_CAST(
                    SUBSTRING(
                        NQR.Response,
                        CHARINDEX('/', NQR.Response) + 1,
                        LEN(NQR.Response)
                    ) AS INT
                )
            END AS Diastolic,
            CASE
                -- Handle BMI QueryIDs
                WHEN NQR.QueryID IN ('PCS-25406C', 'PCS-95406C') THEN NQR.Response
            END AS BMI,
            NQR.[DateTime]
        FROM NurQueryResults AS NQR
            INNER JOIN #BasePopulation BP ON NQR.VisitID = BP.VisitID
        WHERE NQR.Response IS NOT NULL
            AND NQR.QueryID IN (
                'NUR.BP', -- Blood Pressure
                'NURBP', -- Blood Pressure
                'NURBP1', -- Blood Pressure
                'NUR.DBEDBP', -- Blood Pressure
                'PCS-65010G', -- Blood Pressure
                'PCS-95406C', -- BMI
                'PCS-25406C' -- BMI
            )
        UNION ALL
        -- Pull vitals from EdmPatientIntervenQueries
        SELECT BP.VisitID,
            CASE
                -- Handle blood pressure QueryIDs and only process if '/' is found
                WHEN EPT.QueryID IN (
                    'NUR.BP', -- Blood Pressure
                    'NURBP', -- Blood Pressure
                    'NURBP1', -- Blood Pressure
                    'NUR.DBEDBP', -- Blood Pressure
                    'PCS-65010G' -- Blood Pressure
                ) AND CHARINDEX('/', EPT.Response) > 0 THEN TRY_CAST(
                    SUBSTRING(
                        EPT.Response,
                        1,
                        CHARINDEX('/', EPT.Response) - 1
                    ) AS INT
                )
            END AS Systolic,
            CASE
                -- Handle blood pressure QueryIDs and only process if '/' is found
                WHEN EPT.QueryID IN (
                    'NUR.BP', -- Blood Pressure
                    'NURBP', -- Blood Pressure
                    'NURBP1', -- Blood Pressure
                    'NUR.DBEDBP', -- Blood Pressure
                    'PCS-65010G' -- Blood Pressure
                ) AND CHARINDEX('/', EPT.Response) > 0 THEN TRY_CAST(
                    SUBSTRING(
                        EPT.Response,
                        CHARINDEX('/', EPT.Response) + 1,
                        LEN(EPT.Response)
                    ) AS INT
                )
            END AS Diastolic,
            CASE
                -- Handle BMI QueryIDs
                WHEN EPT.QueryID IN ('PCS-25406C', 'PCS-95406C') THEN EPT.Response
            END AS BMI,
            EPT.ActualDateTime AS [DateTime]
        FROM EdmPatientIntervenQueries AS EPT
            INNER JOIN #BasePopulation BP ON EPT.VisitID = BP.VisitID
        WHERE EPT.Response IS NOT NULL
            AND EPT.QueryID IN (
                    'NUR.BP', -- Blood Pressure
                    'NURBP', -- Blood Pressure
                    'NURBP1', -- Blood Pressure
                    'NUR.DBEDBP', -- Blood Pressure
                    'PCS-65010G', -- Blood Pressure
                    'PCS-95406C', -- BMI
                    'PCS-25406C' -- BMI
            )
    ),
    CTE_Recent_BP AS (
        SELECT CTE_BP.VisitID,
            MIN(Systolic) AS Systolic,
            MIN(Diastolic) AS Diastolic,
            MAX([DateTime]) AS [DateTime]
        FROM CTE_BP
        WHERE Systolic IS NOT NULL
            AND Diastolic IS NOT NULL
        GROUP BY VisitID
    ),
    CTE_Latest_Service AS (
        SELECT CTE_BP.VisitID,
            MAX([DateTime]) AS LatestServiceDate
        FROM CTE_BP
        GROUP BY CTE_BP.VisitID
    ),
    CTE_BMI AS (
        SELECT CTE_BP.VisitID,
            MAX([DateTime]) AS [DateTime],
            MAX(BMI) AS BMI
        FROM CTE_BP
        WHERE BMI IS NOT NULL
        GROUP BY CTE_BP.VisitID
    ),
    Vitals AS (
        SELECT DISTINCT BP.VisitID,
            ISNULL(CAST(CTE_Recent_BP.Systolic AS VARCHAR), '') AS BLOOD_PRESSURE_SYSTOLIC,
            ISNULL(CAST(CTE_Recent_BP.Diastolic AS VARCHAR), '') AS BLOOD_PRESSURE_DIASTOLIC,
            ISNULL(CAST(CTE_BMI.BMI AS VARCHAR), '') AS BMI,
            CONVERT(
                VARCHAR,
                CTE_Latest_Service.LatestServiceDate,
                101
            ) AS DATE_OF_SERVICE
        FROM #BasePopulation BP
            LEFT JOIN CTE_Latest_Service ON BP.VisitID = CTE_Latest_Service.VisitID
            LEFT JOIN CTE_Recent_BP ON BP.VisitID = CTE_Recent_BP.VisitID
            AND CTE_Recent_BP.[DateTime] = CTE_Latest_Service.LatestServiceDate
            LEFT JOIN CTE_BMI ON BP.VisitID = CTE_BMI.VisitID
            AND CTE_BMI.[DateTime] = CTE_Latest_Service.LatestServiceDate
        WHERE -- Allow for cases where either blood pressure or BMI data exists
            (
                CTE_Recent_BP.Systolic IS NOT NULL
                OR CTE_Recent_BP.Diastolic IS NOT NULL
            )
            OR CTE_BMI.BMI IS NOT NULL
    )

    -- Step 3: Create the final report
    SELECT
        -- BP.VisitID,
        BP.[SubscriberKey / MemberKey],
        ISNULL(BP.[Policy Number / Medicaid_Number*], '') AS 'Policy Number / Medicaid_Number*',
        BP.LastName,
        BP.FirstName,
        BP.MiddleName,
        BP.DOB,
        BP.Gender,
        ISNULL(BP.Race, '') AS 'Race',
        BP.Ethnicity,
        BP.Language,
        ISNULL(BP.SSN, '') AS 'SSN',
        BP.[Provider NPI],
        '' AS 'Claim Number', --TODO: Add Claim Number
        C.[Date of Service],
        ISNULL(C.CPTCode, '') AS 'CPTCode',
        ISNULL(C.HCPCSPX, '') AS 'HCPCSPX',
        ISNULL(BP.HCFAPOS, '') AS 'HCFAPOS',
        '' AS 'POA', --TODO: Add POA, Present on Admission
        ISNULL(BP.POS, '') AS 'POS',
        ISNULL(C.MCPCSMOD, '') AS 'MCPCSMOD',
        ISNULL(C.Modifier, '') AS 'Modifier',
        ISNULL(V.BLOOD_PRESSURE_SYSTOLIC, '') AS 'BPDIASTOLIC VALUE',
        ISNULL(V.BLOOD_PRESSURE_DIASTOLIC, '') AS 'BPSYSTOLIC VALUE',
        ISNULL(V.BMI, '') AS 'BMI Value',
        MAX(CASE WHEN D.DiagnosisSeqID = 1 THEN D.Diagnosis ELSE '' END) AS 'DIAGNOSISCODE1',
        MAX(CASE WHEN D.DiagnosisSeqID = 2 THEN D.Diagnosis ELSE '' END) AS 'DIAGNOSISCODE2',
        MAX(CASE WHEN D.DiagnosisSeqID = 3 THEN D.Diagnosis ELSE '' END) AS 'DIAGNOSISCODE3',
        MAX(CASE WHEN D.DiagnosisSeqID = 4 THEN D.Diagnosis ELSE '' END) AS 'DIAGNOSISCODE4',
        MAX(CASE WHEN D.DiagnosisSeqID = 5 THEN D.Diagnosis ELSE '' END) AS 'DIAGNOSISCODE5',
        MAX(CASE WHEN D.DiagnosisSeqID = 6 THEN D.Diagnosis ELSE '' END) AS 'DIAGNOSISCODE6',
        MAX(CASE WHEN D.DiagnosisSeqID = 7 THEN D.Diagnosis ELSE '' END) AS 'DIAGNOSISCODE7',
        MAX(CASE WHEN D.DiagnosisSeqID = 8 THEN D.Diagnosis ELSE '' END) AS 'DIAGNOSISCODE8',
        MAX(CASE WHEN D.DiagnosisSeqID = 9 THEN D.Diagnosis ELSE '' END) AS 'DIAGNOSISCODE9',
        MAX(CASE WHEN D.DiagnosisSeqID = 10 THEN D.Diagnosis ELSE '' END) AS 'DIAGNOSISCODE10',
        MAX(CASE WHEN D.DiagnosisSeqID = 11 THEN D.Diagnosis ELSE '' END) AS 'DIAGNOSISCODE11',
        MAX(CASE WHEN D.DiagnosisSeqID = 12 THEN D.Diagnosis ELSE '' END) AS 'DIAGNOSISCODE12',
        MAX(CASE WHEN D.DiagnosisSeqID = 13 THEN D.Diagnosis ELSE '' END) AS 'DIAGNOSISCODE13',
        MAX(CASE WHEN D.DiagnosisSeqID = 14 THEN D.Diagnosis ELSE '' END) AS 'DIAGNOSISCODE14',
        MAX(CASE WHEN D.DiagnosisSeqID = 15 THEN D.Diagnosis ELSE '' END) AS 'DIAGNOSISCODE15',
        MAX(CASE WHEN D.DiagnosisSeqID = 16 THEN D.Diagnosis ELSE '' END) AS 'DIAGNOSISCODE16',
        MAX(CASE WHEN D.DiagnosisSeqID = 17 THEN D.Diagnosis ELSE '' END) AS 'DIAGNOSISCODE17',
        MAX(CASE WHEN D.DiagnosisSeqID = 18 THEN D.Diagnosis ELSE '' END) AS 'DIAGNOSISCODE18',
        MAX(CASE WHEN D.DiagnosisSeqID = 19 THEN D.Diagnosis ELSE '' END) AS 'DIAGNOSISCODE19',
        MAX(CASE WHEN D.DiagnosisSeqID = 20 THEN D.Diagnosis ELSE '' END) AS 'DIAGNOSISCODE20',
        MAX(CASE WHEN D.DiagnosisSeqID = 21 THEN D.Diagnosis ELSE '' END) AS 'DIAGNOSISCODE21',
        MAX(CASE WHEN D.DiagnosisSeqID = 22 THEN D.Diagnosis ELSE '' END) AS 'DIAGNOSISCODE22',
        MAX(CASE WHEN D.DiagnosisSeqID = 23 THEN D.Diagnosis ELSE '' END) AS 'DIAGNOSISCODE23',
        MAX(CASE WHEN D.DiagnosisSeqID = 24 THEN D.Diagnosis ELSE '' END) AS 'DIAGNOSISCODE24',
        MAX(CASE WHEN D.DiagnosisSeqID = 25 THEN D.Diagnosis ELSE '' END) AS 'DIAGNOSISCODE25',
        '' AS 'RevenueCode', --TODO: Add RevenueCode, currently adding too many lines because of the JOIN adding multiple revenue codes.
        MAX(CASE WHEN P.SeqID = 1 THEN P.Code ELSE '' END) AS 'PROCEDURECODE1',
        MAX(CASE WHEN P.SeqID = 2 THEN P.Code ELSE '' END) AS 'PROCEDURECODE2',
        MAX(CASE WHEN P.SeqID = 3 THEN P.Code ELSE '' END) AS 'PROCEDURECODE3',
        MAX(CASE WHEN P.SeqID = 4 THEN P.Code ELSE '' END) AS 'PROCEDURECODE4',
        MAX(CASE WHEN P.SeqID = 5 THEN P.Code ELSE '' END) AS 'PROCEDURECODE5',
        MAX(CASE WHEN P.SeqID = 6 THEN P.Code ELSE '' END) AS 'PROCEDURECODE6',
        MAX(CASE WHEN P.SeqID = 7 THEN P.Code ELSE '' END) AS 'PROCEDURECODE7',
        MAX(CASE WHEN P.SeqID = 8 THEN P.Code ELSE '' END) AS 'PROCEDURECODE8',
        MAX(CASE WHEN P.SeqID = 9 THEN P.Code ELSE '' END) AS 'PROCEDURECODE9',
        MAX(CASE WHEN P.SeqID = 10 THEN P.Code ELSE '' END) AS 'PROCEDURECODE10',
        MAX(CASE WHEN P.SeqID = 11 THEN P.Code ELSE '' END) AS 'PROCEDURECODE11',
        MAX(CASE WHEN P.SeqID = 12 THEN P.Code ELSE '' END) AS 'PROCEDURECODE12',
        MAX(CASE WHEN P.SeqID = 13 THEN P.Code ELSE '' END) AS 'PROCEDURECODE13',
        MAX(CASE WHEN P.SeqID = 14 THEN P.Code ELSE '' END) AS 'PROCEDURECODE14',
        MAX(CASE WHEN P.SeqID = 15 THEN P.Code ELSE '' END) AS 'PROCEDURECODE15',
        MAX(CASE WHEN P.SeqID = 16 THEN P.Code ELSE '' END) AS 'PROCEDURECODE16',
        MAX(CASE WHEN P.SeqID = 17 THEN P.Code ELSE '' END) AS 'PROCEDURECODE17',
        MAX(CASE WHEN P.SeqID = 18 THEN P.Code ELSE '' END) AS 'PROCEDURECODE18',
        MAX(CASE WHEN P.SeqID = 19 THEN P.Code ELSE '' END) AS 'PROCEDURECODE19',
        MAX(CASE WHEN P.SeqID = 20 THEN P.Code ELSE '' END) AS 'PROCEDURECODE20',
        MAX(CASE WHEN P.SeqID = 21 THEN P.Code ELSE '' END) AS 'PROCEDURECODE21',
        MAX(CASE WHEN P.SeqID = 22 THEN P.Code ELSE '' END) AS 'PROCEDURECODE22',
        MAX(CASE WHEN P.SeqID = 23 THEN P.Code ELSE '' END) AS 'PROCEDURECODE23',
        MAX(CASE WHEN P.SeqID = 24 THEN P.Code ELSE '' END) AS 'PROCEDURECODE24',
        MAX(CASE WHEN P.SeqID = 25 THEN P.Code ELSE '' END) AS 'PROCEDURECODE25',
        '' AS 'CVX' --TODO: Add CVX
    FROM
        #BasePopulation BP
        LEFT JOIN Diagnoses D ON BP.VisitID = D.VisitID
        LEFT JOIN Procedures P ON BP.VisitID = P.VisitID
        LEFT JOIN Coding C ON BP.VisitID = C.VisitID
        LEFT JOIN Vitals V ON BP.VisitID = V.VisitID
    GROUP BY
        BP.VisitID,
        BP.[SubscriberKey / MemberKey],
        BP.[Policy Number / Medicaid_Number*],
        BP.LastName,
        BP.FirstName,
        BP.MiddleName,
        BP.DOB,
        BP.Gender,
        BP.Race,
        BP.Ethnicity,
        BP.Language,
        BP.SSN,
        BP.[Provider NPI],
        BP.HCFAPOS,
        BP.POS,
        C.[Date of Service],
        C.CPTCode,
        C.HCPCSPX,
        C.MCPCSMOD,
        C.Modifier,
        V.BLOOD_PRESSURE_SYSTOLIC,
        V.BLOOD_PRESSURE_DIASTOLIC,
        V.BMI
    ORDER BY 
        BP.VisitID;

    SET @EndTime = SYSDATETIME();
    PRINT 'Main query took: ' + CONVERT(VARCHAR, DATEDIFF(MILLISECOND, @StartTime, @EndTime)) + ' ms';

END
