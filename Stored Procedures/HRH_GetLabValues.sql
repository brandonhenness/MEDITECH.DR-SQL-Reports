USE [livemdb]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
*****************************************************************
Report Title:   HRH Get Lab Values
Report Author:  Brandon Henness
Creation Date:  2024/03/26
Description:    
    This stored procedure is used to get the lab values for a patient
    based on the patient's account number. The lab values are returned
    in a table format. 

    The stored procedure accepts the following parameters:
    - PatientAccount: The account number of the patient
    - TestPrintNumberIDList: A comma-separated list of test print number IDs
        to filter the lab values

    The stored procedure retrieves the lab values from the following
    tables: AbstractData, LabSpecimens, LabSpecimenTests, and DLabTest.
    The lab values are filtered based on the patient's account number and
    the result RW. The lab values are then joined with the corresponding
    tables to get the required information.

    The stored procedure returns the following columns:
    - VisitID: The visit ID of the patient
    - SpecimenID: The specimen ID of the lab values
    - OrderLocationID: The order location ID of the lab values
    - TestPrintNumberID: The test print number ID of the lab values
    - EmrDataName: The EMR data name of the lab values
    - ResultRW: The result RW of the lab values
    - NormalRange: The normal range of the lab values
    - AbnormalFlag: The abnormal flag of the lab values
    - ResultDateTime: The result date and time of the lab values
    - CollectionDateTime: The collection date and time of the lab values

    The stored procedure is used to retrieve lab values for a patient.

Modifications:

*****************************************************************
*/

ALTER   PROCEDURE [dbo].[HRH_GetLabValues]
    @PatientAccount VARCHAR(50),
    @TestPrintNumberIDList VARCHAR(MAX) = NULL

WITH
    RECOMPILE
AS
BEGIN
    SET NOCOUNT ON;
    SET ANSI_NULLS ON;
    SET Quoted_IDENTIFIER ON;

    SELECT
        DISTINCT
        ABSD.VisitID,
        LS.SpecimenID,
        LS.OrderLocationID,
        LST.TestPrintNumberID,
        DLT.EmrDataName,
        LST.ResultRW,
        LST.NormalRange,
        LST.AbnormalFlag,
        LST.ResultDateTime,
        LS.CollectionDateTime
    FROM
        AbstractData AS ABSD
        INNER JOIN dbo.LabSpecimens AS LS ON ABSD.VisitID = LS.VisitID
        INNER JOIN dbo.LabSpecimenTests AS LST ON LS.SourceID = LST.SourceID AND LS.SpecimenID = LST.SpecimenID
        INNER JOIN dbo.DLabTest AS DLT ON LST.TestPrintNumberID = DLT.PrintNumberID
    WHERE ABSD.AccountNumber = @PatientAccount
        AND (LST.ResultRW IS NOT NULL)
        AND (@TestPrintNumberIDList IS NULL OR LTRIM(RTRIM(@TestPrintNumberIDList)) = '' OR LST.TestPrintNumberID IN (SELECT
            value
        FROM
            STRING_SPLIT(@TestPrintNumberIDList, ',')))
    ORDER BY LS.CollectionDateTime, LST.TestPrintNumberID;
END
