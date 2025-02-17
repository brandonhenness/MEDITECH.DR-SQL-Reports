USE [livemdb]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
*****************************************************************
Report Title:   HRH Molina SDS Labs
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

ALTER   PROCEDURE [dbo].[HRH_Molina_SDS_Labs]
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
        AI.PolicyNumber AS 'Policy Number / Medicaid Number',
        COALESCE(dbo.fn_LastName (AB.Name), '') AS 'Last Name',
        COALESCE(dbo.fn_FirstName (AB.Name), '') AS 'First Name',
        COALESCE(dbo.fn_MiddleName (AB.Name), '') AS 'Middle Name',
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

    SET @StartTime = SYSDATETIME();
    WITH LabResults AS (
        SELECT DISTINCT
            LAB.VisitID,
            LAB.TestPrintNumberID AS 'ProcedureID',
            CONVERT(VARCHAR, LAB.ResultDateTime, 101) AS 'Date of Service',
            '' AS 'CPT Code', -- TODO: Implement logic for CPT Code
            DLAB.DefaultLoincID AS 'LOINC Code',
            LAB.ResultRW AS 'Result',
            '' AS 'ResultUnits', -- TODO: Implement logic for ResultUnit
            '' AS 'POS_NEG_RESULT' -- TODO: Implement logic for POS_NEG_RESULT
            -- '' AS 'ProcedureDescription'
        FROM
            LabSpecimenTests AS LAB
            INNER JOIN #BasePopulation BP ON LAB.VisitID = BP.VisitID
            INNER JOIN DLabTest AS DLAB ON LAB.TestPrintNumberID = DLAB.PrintNumberID -- TODO: Add Microbiology tests
        WHERE
            LAB.ResultRW IS NOT NULL
            AND LAB.ResultRW NOT IN ('NP', 'TNP', 'SEE SEPERATE REPORT')
            AND DLAB.DefaultLoincID IN (
            '4548-4',  '4549-2',  '17856-6', '12773-8', '14807-2', '17052-2', '25459-9', '27129-6',
            '13457-7', '18261-8', '18262-6', '2089-1',  '32325-3', '5671-3',  '5674-7',  '77307-7',
            '49132-4', '55440-2', '14463-4', '14464-2', '44261-6', '89204-2', '2085-9',  '2093-3',
            '14467-5', '14474-1', '14513-6', '16600-9', '2571-8',  '3043-7',  '9830-1',  '10450-5',
            '21190-4', '21191-2', '21613-5', '23838-6', '1492-8',  '1494-4',  '1496-9',  '1499-3',
            '31775-0', '31777-6', '36902-5', '36903-3', '1501-6',  '1504-0',  '1507-3',  '1514-9',
            '42931-6', '43304-5', '43404-3', '43405-0', '1518-0',  '1530-5',  '1533-9',  '1554-5',
            '43406-8', '44806-8', '44807-6', '45068-4', '1557-8',  '1558-6',  '17865-7', '20436-2',
            '45069-2', '45075-9', '45076-7', '45084-1', '20437-0', '20438-8', '20440-4', '26554-6',
            '45091-6', '45095-7', '45098-1', '45100-5', '41024-1', '49134-0', '6749-6',  '9375-7',
            '47211-8', '47212-6', '49096-1', '4993-2',  '96595-4', '96259-7', '12503-9', '12504-7',
            '50387-0', '53925-4', '53926-2', '557-9',   '14563-1', '14564-9', '14565-6', '2335-8',
            '560-3',   '6349-5',  '6345-5',  '6355-2',  '27396-1', '27401-9', '27925-7', '27926-5',
            '6356-0',  '6357-8',  '80360-1', '80361-9', '29771-3', '56490-6', '56491-4', '57905-2',
            '80362-7', '91860-7', '10368-9', '10912-4', '58453-2', '80372-6', '77353-1', '77354-9'
            )
    ),
    MicroResults AS (
        SELECT
            MSPR.VisitID,
            MSPR.ProcedureID,
            MS.CollectionDateTime AS 'Date of Service',
            ISNULL(DMP.CptCode, '') AS 'CPT Code',
            CASE
                WHEN DMP.DefaultLoincID IS NULL AND MSPR.ProcedureID = '700.0860' THEN '60489-2'
                WHEN DMP.DefaultLoincID IS NULL AND MSPR.ProcedureID = '700.0912' THEN '91875-5'
                WHEN DMP.DefaultLoincID IS NULL AND MSPR.ProcedureID = '700.0875' THEN '77022-2'
                WHEN DMP.DefaultLoincID IS NULL AND MSPR.ProcedureID = '700.0812' THEN '101557-7'
                WHEN DMP.DefaultLoincID IS NULL AND MSPR.ProcedureID = '700.0895' THEN '60489-2'
                WHEN DMP.DefaultLoincID IS NULL THEN ''
                ELSE DMP.DefaultLoincID
            END AS 'LOINC Code',
            '' AS 'Result',
            '' AS 'ResultUnits',
            MSPR.ResultRW AS 'POS_NEG_RESULT'
            -- DMP.Name AS 'ProcedureDescription'
        FROM
            MicSpecimenPromptResults AS MSPR
            INNER JOIN #BasePopulation BP ON MSPR.VisitID = BP.VisitID
            INNER JOIN MicSpecimens AS MS ON MSPR.SpecimenID = MS.SpecimenID
            LEFT JOIN DMicProcs AS DMP ON MSPR.ProcedureID = DMP.ProcedureID
        WHERE
            MSPR.ResultRW = 'P' OR MSPR.ResultRW = 'N'
    )

    -- Combine LabResults and MicroResults using UNION ALL
    SELECT
        -- BP.VisitID,
        BP.[SubscriberKey / MemberKey],
        BP.[Policy Number / Medicaid Number],
        BP.[Last Name],
        BP.[First Name],
        BP.[Middle Name],
        BP.[DOB],
        BP.[Gender],
        BP.[Race],
        BP.[Ethnicity],
        BP.[Language],
        BP.[SSN],
        BP.[Provider NPI],
        LR.[Date of Service],
        LR.[CPT Code],
        LR.[LOINC Code],
        '' AS 'Snomed',
        LR.[Result],
        LR.[ResultUnits],
        LR.[POS_NEG_RESULT]
        -- LR.[ProcedureDescription],
        -- LR.[ProcedureID]
    FROM
    (
        SELECT * FROM LabResults
        UNION ALL
        SELECT * FROM MicroResults
    ) LR
    JOIN #BasePopulation BP ON BP.VisitID = LR.VisitID
    ORDER BY
        BP.VisitID;

    SET @EndTime = SYSDATETIME();
    PRINT 'Main query took: ' + CONVERT(VARCHAR, DATEDIFF(MILLISECOND, @StartTime, @EndTime)) + ' ms';

END
