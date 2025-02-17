USE [livemdb]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
*****************************************************************
Report Title:   HRH Get Location Info
Report Author:  Brandon Henness
Creation Date:  2024/03/26
Description:
    This stored procedure is used to get the location information for a patient
    based on the patient's account number. The location information is returned
    in a table format.

    The stored procedure accepts the following parameters:
    - PatientAccount: The account number of the patient

    The stored procedure retrieves the location information from the following
    tables: AbstractData and AbsLocationsAndScus. The location information is
    filtered based on the patient's account number and the visit ID. The location
    information is then joined with the corresponding tables to get the
    required information.

    The stored procedure returns the following columns:
    - AccountNumber: The account number of the patient
    - VisitID: The visit ID of the patient
    - LocationID: The location ID of the patient
    - StartDateTime: The start date and time of the location
    - EndDateTime: The end date and time of the location

    The stored procedure is used to retrieve location information for a patient.

Modifications:

*****************************************************************
*/

ALTER   PROCEDURE [dbo].[HRH_GetLocationInfo]
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
        ALS.VisitID,
        ALS.LocationID,
        ALS.StartDateTime,
        ALS.EndDateTime
    FROM
        FilteredAbstractData AS FAD
        LEFT JOIN AbsLocationsAndScus AS ALS ON FAD.VisitID = ALS.VisitID
    ORDER BY
        StartDateTime

END
