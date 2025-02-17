USE [livemdb]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
*****************************************************************
Report Title:   HRH Get Insurance Info
Report Author:  Brandon Henness
Creation Date:  2024/03/26
Description:
    This stored procedure is used to get the insurance information for a patient
    based on the patient's account number. The insurance information is returned
    in a table format.

    The stored procedure accepts the following parameters:
    - PatientAccount: The account number of the patient

    The stored procedure retrieves the insurance information from the following
    tables: AbstractData, AbsInsurances, and DMisInsurance. The insurance information
    is filtered based on the patient's account number and the visit ID. The insurance
    information is then joined with the corresponding tables to get the
    required information.

    The stored procedure returns the following columns:
    - AccountNumber: The account number of the patient
    - VisitID: The visit ID of the patient
    - InsuranceSeqID: The insurance sequence ID of the patient
    - InsuranceID: The insurance ID of the patient
    - PolicyNumber: The policy number of the patient
    - Name: The name of the insurance

    The stored procedure is used to retrieve insurance information for a patient.

Modifications:

*****************************************************************
*/

ALTER   PROCEDURE [dbo].[HRH_GetInsuranceInfo]
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
        FAD.AccountNumber,
        AI.VisitID,
		AI.InsuranceSeqID,
        AI.InsuranceID,
        AI.PolicyNumber,
        DMI.Name
    FROM
        FilteredAbstractData AS FAD
        LEFT JOIN AbsInsurances AS AI ON FAD.VisitID = AI.VisitID
        LEFT JOIN DMisInsurance AS DMI ON AI.InsuranceID = DMI.InsuranceID
    ORDER BY
        InsuranceSeqID

END
