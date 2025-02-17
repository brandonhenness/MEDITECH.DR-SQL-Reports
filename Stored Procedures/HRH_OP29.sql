USE [livemdb]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
*****************************************************************
Report Title:   HRH OP-29
Report Author:  Brandon Henness
Creation Date:  2024/12/15
Description:
    Retrieves information for OP-29 measure. This measure is for patients who have had a colonoscopy and have a history of polyps. The report will
    show the patient's demographics, encounter information, and the procedure information. The report will only show patients who have a diagnosis
    of Z12.11 and have had a colonoscopy with a CPT code of 44388, 45378, or G0121. The report will exclude patients who have a diagnosis of Z83.71,
    Z86.010, Z80.0, or Z85.038. The report will also show the principal diagnosis and other diagnoses for the patient. The report will show the
    provider NPI number for the surgeon and whether the CPT code has a modifier of 52, 53, 73, or 74.
Modifications: 
    2021/05/27 added INO status related to system updates/changes. -KJ
    2024/12/14 Converted date inputs to datetime instead of varchar. -BH
    2024/12/14 Changed Sex to Sex at Birth. Added Gender Identity and Sexual Orientation fields. As required by the new CMS rule. -BH
*****************************************************************
*/
ALTER   PROCEDURE [dbo].[HRH_OP29] (
    @FromDate DATE, 
    @ThruDate DATE
)
WITH RECOMPILE
AS
BEGIN
    SET NOCOUNT ON;
    SET ANSI_NULLS ON;
    SET QUOTED_IDENTIFIER ON;

    SELECT DISTINCT 
        '500031' AS 'provider-id',
        CONVERT(VARCHAR(10), AB.BirthDateTime, 110) AS 'birthdate',
        CASE 
            WHEN AB.Sex = 'F' THEN '1' -- Female
            WHEN AB.Sex = 'M' THEN '2' -- Male
            WHEN AB.Sex = 'U' THEN '4' -- None of the Above or UTD
            WHEN AB.Sex IS NULL THEN '5' -- Preferred not to Answer
            ELSE '5' -- Default to Preferred not to Answer
        END AS 'sexassignedatbirth',
        -- Gender Identity Mapping
        (
            SELECT TOP 1
                CASE 
                    WHEN Response IN ('MAN', 'M') THEN '1' -- Man
                    WHEN Response IN ('W', 'F') THEN '2' -- Woman
                    WHEN Response IN ('NB', 'B', 'DG', 'GF', 'GQ', 'AG') THEN '3' -- Non-binary
                    WHEN Response IN ('T', 'TS', 'DB') THEN '4' -- Transgender
                    ELSE '5' -- None of the Above or UTD
                END
            FROM [livemdb].[dbo].[AdmVisitQueriesMult]
            WHERE VisitID = AB.VisitID AND QueryID = 'ADM.G.ID1A'
            ORDER BY QuerySeqID
        ) AS 'genderidentity',
        -- Sexual Orientation Mapping
        (
            SELECT TOP 1
                CASE 
                    WHEN Response IN ('S') THEN '1' -- Straight
                    WHEN Response IN ('G', 'L') THEN '2' -- Gay/Lesbian
                    WHEN Response IN ('B', 'P') THEN '3' -- Bisexual/Pansexual
                    WHEN Response IN ('Q') THEN '4' -- Queer
                    ELSE '5' -- None of the Above or UTD
                END
            FROM [livemdb].[dbo].[AdmVisitQueriesMult]
            WHERE VisitID = AB.VisitID AND QueryID = 'ADM.SEX.O2'
            ORDER BY QuerySeqID
        ) AS 'sexualorientation',
        CASE 
            WHEN AB.RaceID = 'W' THEN '1' 
            WHEN AB.RaceID = 'B' THEN '2' 
            WHEN AB.RaceID = 'AM' THEN '3' 
            WHEN AB.RaceID = 'AS' THEN '4' 
            WHEN AB.RaceID = 'PI' THEN '5' 
            ELSE '7' 
        END AS 'race',
        CASE 
            WHEN RIGHT(AB.RaceID, 1) = 'H' THEN 'Y' 
            WHEN AB.RaceID = 'HIS' THEN 'Y' 
            ELSE 'N' 
        END AS 'ethnic',
        AB.PostalCode AS 'postal-code',
        CONVERT(VARCHAR(10), AB.AdmitDateTime, 110) AS 'encounter-date',
        CONVERT(VARCHAR(5), AB.AdmitDateTime, 108) AS 'arrival-time',
        AB.UnitNumber + AB.AccountNumber AS 'patient-id',
        CASE 
            WHEN AB.FinancialClassID = 'MC' THEN '1' 
            ELSE '2' 
        END AS 'PMTSRCE',
        DPROV.NationalProviderIdNumber AS 'PHYSICIAN_1',   -- This is provider NPI number
        -- This is principal diagnosis with decimal removed
        (
            SELECT REPLACE(BARDIAG.DiagnosisCodeID, '.', '')
            FROM [livemdb].[dbo].[BarDiagnoses] AS DIAG
            WHERE BARV.BillingID = DIAG.BillingID 
              AND DIAG.DiagnosisSeqID = 1
            ORDER BY DIAG.DiagnosisSeqID  
            FOR XML PATH('')
        ) AS 'prindx',
        -- Get all other diagnosis into string other than primary
        (
            SELECT REPLACE(DIAG.DiagnosisCodeID + ' | ', '.', '')
            FROM [livemdb].[dbo].[BarDiagnoses] AS DIAG
            WHERE BARV.BillingID = DIAG.BillingID 
              AND DIAG.DiagnosisSeqID > 1
            ORDER BY DIAG.DiagnosisSeqID  
            FOR XML PATH('')
        ) AS 'othrdx#',
        BARC.Code AS 'CPTCODE',
        CASE 
            WHEN BARMOD.ModifierCptID IN ('52', '53', '73', '74') THEN 'Y' 
            ELSE 'N' 
        END AS 'CPTMODIFIER'
    FROM 
        [livemdb].[dbo].[AbstractData] AS AB
        INNER JOIN [livemdb].[dbo].[BarVisits] AS BARV
            ON AB.VisitID = BARV.VisitID AND AB.SourceID = BARV.SourceID 
        INNER JOIN [livemdb].[dbo].[BarDiagnoses] AS BARDIAG
            ON BARV.BillingID = BARDIAG.BillingID    
            AND BARDIAG.DiagnosisSeqID = 1  -- Only get 1st one as principal diagnosis
        LEFT JOIN [livemdb].[dbo].[BarCptCodes] AS BARC
            ON AB.VisitID = BARC.VisitID AND AB.SourceID = BARC.SourceID 
        LEFT JOIN [livemdb].[dbo].[BarCptModifiers] AS BARMOD
            ON AB.VisitID = BARMOD.VisitID AND AB.SourceID = BARMOD.SourceID 
            AND BARC.CptSeqID = BARMOD.CptSeqID  
        LEFT JOIN [livemdb].[dbo].[DMisProvider] AS DPROV
            ON BARC.Surgeon = DPROV.ProviderID  -- Get the NPI for the surgeon
    WHERE 
        CAST(AB.AdmitDateTime AS DATE) BETWEEN @FromDate AND @ThruDate
        AND AB.PtStatus IN ('SDC', 'INO')
        AND BARDIAG.DiagnosisCodeID = 'Z12.11'  -- List all dx codes in PRINDX and OTHRDX# fields above, but only show pts that have this dx code
        AND BARC.Code IN ('44388', '45378', 'G0121') 
        AND BARDIAG.DiagnosisCodeID NOT IN ('Z83.71', 'Z86.010', 'Z80.0', 'Z85.038');

    -- ORDER BY BARC.CodeDateTime ASC  -- Commented out because we're using DISTINCT.
END
