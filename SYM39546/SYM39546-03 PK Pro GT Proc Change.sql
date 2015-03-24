USE [Sibanye Gold Limited]
/*------------------------------------------------------------------------------------------------------------------------------------------------------
  CONFIGURATION CONTROL																																
-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
  Place code here
-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
* Modification history
* Version | Date     | By  | Description
* 1.9.01  | dd/mm/yy | ??? | Create
------------------------------------------------------------------------------------------------------------------------------------------------------*/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
/****************************************************************************************
   Main Code
****************************************************************************************/
/*------------------------------------------------------------------
	Sub section
-------------------------------------------------------------------*/
SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
GO



-------------------------------------------------------------------------------------------------------------------------------------------------------



ALTER PROCEDURE [dbo].[sp_Group_Transfer_Employee_Pro]
/*-------------------------------------------------------------------------------------
*  CONFIGURATION CONTROL
*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
* sp_Group_Transfer_Employee
*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
* Modification history
* Version | Date     | By  | Description
* 1.14.01 | 09/09/14 | PKA | SYM35973 - Add [Source] to EWH 
--------------------------------------------------------------------------------------*/
    @ResourceTag INT ,
    @Operation NVARCHAR(50) ,
    @FromOperation NVARCHAR(50) ,
    @ToSE INT ,
    @Cycle NVARCHAR(20) ,
    @Date DATETIME ,
    @Designation NVARCHAR(80) ,
    @PaymentID NVARCHAR(20)
AS 
    DECLARE @sMsg VARCHAR(4000) ,
        @Section NVARCHAR(400),
		@FromSE INT,
		@FromGrade  NVARCHAR(10),
		@ToGrade NVARCHAR(10),
		@MovementType NVARCHAR(30),

		@ToEnvironment NVARCHAR(20),
		@FromEnvironment NVARCHAR(20)
		
		SET @FromSE = (SELECT [To Structure Entity] FROM [dbo].[Emp Work History] WHERE [Resource Tag] =@ResourceTag AND [End Date] = '99991231')

	    SET @FromGrade = (SELECT [To Grade] FROM [dbo].[Emp Work History] WHERE [Resource Tag] =@ResourceTag AND [End Date] = '99991231')


		SET @ToGrade = (SELECT GDC.[Grade] FROM [dbo].[Organisation Structure] OS INNER JOIN [dbo].[Grp Designation Control] GDC ON GDC.Designation = OS.Designation
		AND GDC.Operation = OS.Operation
		AND GDC.[End Date] = '99991231'
		 WHERE OS.[Structure Entity] = @ToSE)



		 SET @ToEnvironment = (SELECT GDC.[Environment] FROM [dbo].[Organisation Structure] OS INNER JOIN [dbo].[Grp Designation Control] GDC ON GDC.Designation = OS.Designation
		AND GDC.Operation = OS.Operation
		AND GDC.[End Date] = '99991231'
		 WHERE OS.[Structure Entity] = @ToSE)

		  SET @FromEnvironment = (SELECT GDC.[Environment] FROM [dbo].[Organisation Structure] OS INNER JOIN [dbo].[Grp Designation Control] GDC ON GDC.Designation = OS.Designation
		AND GDC.Operation = OS.Operation
		AND GDC.[End Date] = '99991231'
		 WHERE OS.[Structure Entity] = @FromSE)


		 SET @MovementType = 'Promotion'
		 IF @ToGrade < @FromGrade
		 BEGIN
			SET @MovementType = 'Demontion'
         END

		  IF @ToGrade = @FromGrade
		 BEGIN
			SET @MovementType = 'Change Designation'
         END



--- Create Personal employment details 
    PRINT 'Busy with Resource : ' + CAST(@ResourceTag AS NVARCHAR(20))
    SET @Section = 'Personal Employment Details'
    BEGIN TRY
        BEGIN TRANSACTION


		DECLARE @PI INT
  
		SET @PI = (SELECT [Period ID] FROM [dbo].[Calendar Periods] WHERE  DATEADD(dd, -1, @Date) BETWEEN [Start Date] AND [End Date] AND [Completed] = 'Yes' AND RunType = 'Normal' AND [Calendar] = @Cycle)
		      
        DECLARE @StartingPeriodID INT
        DECLARE @StartingPeriodIDNew INT
  
  
        SET @StartingPeriodID = ( SELECT    [Period ID]
                                  FROM      [dbo].[Calendar Periods]
                                  WHERE     [Start Date] = @Date
                                            AND [RunType] = 'Interim'
                                            AND Calendar = @Cycle
                                )


        SET @StartingPeriodIDNew = ( SELECT TOP 1
                                            [dbo].[Calendar Periods].[Period ID]
                                     FROM   [dbo].[Input Transactions]
                                            INNER JOIN [dbo].[Calendar Periods] ON dbo.[Input Transactions].[Period ID] = dbo.[Calendar Periods].[Period ID]
                                                              AND [RunType] = 'interim'
                                                              AND [Completed] = 'Yes'
                                                              AND [Start Date] > @Date
															  
                                     WHERE  [Resource Tag] = @ResourceTag
                                     ORDER BY [dbo].[Input Transactions].[Period ID] DESC
                                   )
        

        IF @StartingPeriodIDNew IS NOT NULL 
            BEGIN
                SET @StartingPeriodID = (SELECT TOP 1 [Period ID] FROM [dbo].[Calendar Periods] WHERE [Period ID] > @StartingPeriodIDNew  AND Calendar = @Cycle ORDER BY [Sequence])
            END	      

        DECLARE @GEngDate DATETIME

        SET @GEngDate = ( SELECT    [Group Engagement Date]
                          FROM      [dbo].[Sys Personal Employment Details]
                          WHERE     [Resource Tag] = @ResourceTag
                                    AND [Termination Date] = '99991231'
                        )

   


        UPDATE  [dbo].[Sys Personal Employment Details]
        SET     [Termination Date] = DATEADD(dd, -1, @Date)
        WHERE   [Resource Tag] = @ResourceTag
                AND [Termination Date] = '99991231'

        INSERT  INTO [dbo].[Sys Personal Employment Details]
                ( [Resource Tag] ,
                  [Company Name] ,
                  [Designation] ,
                  [Group Engagement Date] ,
                  [Engagement Date] ,
                  [Termination Date] ,
                  [Termination Reason] ,
                  [Comments] ,
                  [Last Pay Date] ,
                  [Starting Period ID] ,
                  [Leave Engagement Date]
                )
        VALUES  ( @ResourceTag , -- Resource Tag - int
                  @Operation , -- Company Name - nvarchar(50)
                  @Designation , -- Designation - nvarchar(50)
                  @GEngDate , -- Group Engagement Date - datetime
                  @Date , -- Engagement Date - datetime
                  '99991231' , -- Termination Date - datetime
                  NULL , -- Termination Reason - nvarchar(50)
                  'Group Transfer' , -- Comments - nvarchar(100)
                  '99991231' , -- Last Pay Date - datetime
                  @StartingPeriodID , -- Starting Period ID - int
                  @Date -- Leave Engagement Date - datetime
                )



---- Work History ---
        SET @Section = 'Emp Work History'

        DELETE  FROM [dbo].[Emp Work History]
        WHERE   [Resource Tag] = @ResourceTag
                AND [Start Date] >= @Date

        INSERT  INTO [dbo].[Emp Work History]
                ( [Resource Tag] ,
                  [Start Date] ,
                  [Movement Type] ,
                  [To Structure Entity] ,
                  [To Payment ID] ,
                  [Source]
         
                )
        VALUES  ( @ResourceTag , -- Resource Tag - int
                  @Date , -- Start Date - datetime
                  @MovementType , -- Movement Type - nvarchar(50)
                  @ToSE , -- To Structure Entity - int
                  @PaymentID , -- To Payment ID - nvarchar(50)
                  'sp_Group_Transfer_Employee'
                )

			IF @MovementType <> 'Change Designation'
			BEGIN
			EXEC 	sp_Emp_TA_movement @ResourceTag,@Date,@MovementType,'',@Designation,'G0395193','Operation Movement',@Cycle
			END
				
				
   
---Package

        SET @Section = 'Package'


        SELECT  *
        INTO    #Package
        FROM    [dbo].[PER REM Package] AS PRP
        WHERE   [Resource Tag] = @ResourceTag
                AND [End Date] = '99991231'

        DELETE  FROM [dbo].[PER REM Package]
        WHERE   [Resource Tag] = @ResourceTag
                AND [Start Date] >= @Date

        UPDATE  [dbo].[PER REM Package]
        SET     [End Date] = DATEADD(dd, -1, @Date)
        FROM    #Package AS P
                INNER JOIN [dbo].[PER REM Package] AS PRP ON P.[Resource Tag] = PRP.[Resource Tag]
                                                             AND P.[Start Date] = PRP.[Start Date]


        UPDATE  #Package
        SET     [Start Date] = @Date ,
                [Position Title] = @Designation ,
                [End Date] = '99991231'

        INSERT  INTO [dbo].[PER REM Package]
                ( [Resource Tag] ,
                  [Start Date] ,
                  [End Date] ,
                  [Position Title] ,
                  [Grade] ,
                  [Remuneration Method] ,
                  [Payment ID] ,
                  [Gross Remuneration Package (Minimum Rate)] ,
                  [Gross Remuneration Package (Annual)] ,
                  [Gross Remuneration Package (Monthly)] ,
                  [Service Increment Start Date] ,
                  [Service Increment Percentage] ,
                  [Service Increment] ,
                  [UIF Payment] ,
                  [Individual Gross Remuneration Package (Annual)] ,
                  [Individual Gross Remuneration Package (Monthly)] ,
                  [Pensionable Gross Remuneration Package (Annual)] ,
                  [Pensionable Gross Remuneration Package (Monthly)] ,
                  [Pensionable Emoluments Percentage of GRP] ,
                  [Pensionable Emoluments (Annual)] ,
                  [Pensionable Emoluments (Monthly)] ,
                  [Retirement Fund] ,
                  [Retirement Option] ,
                  [Risk Percentage] ,
                  [Employer Contribution Percentage] ,
                  [Employee Contribution Percentage] ,
                  [Risk Contribution] ,
                  [MEPF Risk Contribution] ,
                  [MEPF Risk Contribution Percentage] ,
                  [Employer Contribution] ,
                  [Employee Contribution] ,
                  [Permanent Underground Indicator] ,
                  [Semi Permanent Underground Indicator] ,
                  [Production Management Allowance Indicator] ,
                  [Non Production Management Allowance Indicator] ,
                  [Medical Aid Deduction] ,
                  [Medical Fund] ,
                  [Medical Fund Option] ,
                  [Medical Spouse] ,
                  [Medical Child Dependants] ,
                  [Medical Adult Dependants] ,
                  [Medical Fund Value (Annual)] ,
                  [Medical Fund Value (Monthly)] ,
                  [Additional Annual Leave Days (Annual)] ,
                  [Additional Annual Leave Days (Monthly)] ,
                  [Additional Annual Leave Value (Annual)] ,
                  [Additional Annual Leave Value (Monthly)] ,
                  [Group Personal Accident Policy] ,
                  [Car Allowance Amount (Annual)] ,
                  [Car Allowance Amount (Monthly)] ,
                  [Provision Account] ,
                  [Benefit Value Percentage of GRP] ,
                  [Benefit Value (Annual)] ,
                  [Benefit Value (Monthly)] ,
                  [Cash Component (Monthly)] ,
                  [Cash Component (Annual)] ,
                  [Employee Status] ,
                  [Clocker] ,
                  [Source] ,
                  [Reason] ,
                  [ARMS Process Status] ,
                  [ARMS Process ID] ,
                  [Medical Spouse Value] ,
                  [Medical Child Dependants Value] ,
                  [Medical Adult Dependants Value] ,
                  [Medical Member Value] ,
                  [PI Calendar] ,
                  [PI Control] ,
                  [HLA] ,
                  [HLA (Amount)] ,
                  [Service Increment (Annual)] ,
                  [Total Employer Contribution (Annual)] ,
                  [Total Employer Contribution (Monthly)] ,
                  [Total Employee Contribution (Annual)] ,
                  [Total Employee Contribution (Monthly)] ,
                  [HLA Amount (Annual)] ,
                  [GPAP (Annual)] ,
                  [GPAP (Monthly)] ,
                  [SI Increase Date] ,
                  [Hourly Rate] ,
                  [Daily Penalty Rate] ,
                  [Gross Remuneration Package (Maximum Rate)] ,
                  [MEPF Risk Contribution (Annual)] ,
                  [Risk Contribution (Annual)] ,
                  [Housing Deduction] ,
                  [HLA Percentage] ,
                  [Housing Deduction Amount] ,
                  [Housing Deduction Fringe Benefit] ,
                  [House Grade] ,
                  [Housing Deduction Amount (Annual)] ,
                  [Housing Deduction Fringe Benefit (Annual)] ,
                  [Medical Member Company Value] ,
                  [Medical Child Dependants Company Value] ,
                  [Medical Spouse Dependants Company Value]
                )
                SELECT  [Resource Tag] ,
                        [Start Date] ,
                        [End Date] ,
                        [Position Title] ,
                        [Grade] ,
                        [Remuneration Method] ,
                        [Payment ID] ,
                        [Gross Remuneration Package (Minimum Rate)] ,
                        [Gross Remuneration Package (Annual)] ,
                        [Gross Remuneration Package (Monthly)] ,
                        [Service Increment Start Date] ,
                        [Service Increment Percentage] ,
                        [Service Increment] ,
                        [UIF Payment] ,
                        [Individual Gross Remuneration Package (Annual)] ,
                        [Individual Gross Remuneration Package (Monthly)] ,
                        [Pensionable Gross Remuneration Package (Annual)] ,
                        [Pensionable Gross Remuneration Package (Monthly)] ,
                        [Pensionable Emoluments Percentage of GRP] ,
                        [Pensionable Emoluments (Annual)] ,
                        [Pensionable Emoluments (Monthly)] ,
                        [Retirement Fund] ,
                        [Retirement Option] ,
                        [Risk Percentage] ,
                        [Employer Contribution Percentage] ,
                        [Employee Contribution Percentage] ,
                        [Risk Contribution] ,
                        [MEPF Risk Contribution] ,
                        [MEPF Risk Contribution Percentage] ,
                        [Employer Contribution] ,
                        [Employee Contribution] ,
                        [Permanent Underground Indicator] ,
                        [Semi Permanent Underground Indicator] ,
                        [Production Management Allowance Indicator] ,
                        [Non Production Management Allowance Indicator] ,
                        [Medical Aid Deduction] ,
                        [Medical Fund] ,
                        [Medical Fund Option] ,
                        [Medical Spouse] ,
                        [Medical Child Dependants] ,
                        [Medical Adult Dependants] ,
                        [Medical Fund Value (Annual)] ,
                        [Medical Fund Value (Monthly)] ,
                        [Additional Annual Leave Days (Annual)] ,
                        [Additional Annual Leave Days (Monthly)] ,
                        [Additional Annual Leave Value (Annual)] ,
                        [Additional Annual Leave Value (Monthly)] ,
                        [Group Personal Accident Policy] ,
                        [Car Allowance Amount (Annual)] ,
                        [Car Allowance Amount (Monthly)] ,
                        [Provision Account] ,
                        [Benefit Value Percentage of GRP] ,
                        [Benefit Value (Annual)] ,
                        [Benefit Value (Monthly)] ,
                        [Cash Component (Monthly)] ,
                        [Cash Component (Annual)] ,
                        [Employee Status] ,
                        [Clocker] ,
                        [Source] ,
                        [Reason] ,
                        [ARMS Process Status] ,
                        [ARMS Process ID] ,
                        [Medical Spouse Value] ,
                        [Medical Child Dependants Value] ,
                        [Medical Adult Dependants Value] ,
                        [Medical Member Value] ,
                        [PI Calendar] ,
                        [PI Control] ,
                        [HLA] ,
                        [HLA (Amount)] ,
                        [Service Increment (Annual)] ,
                        [Total Employer Contribution (Annual)] ,
                        [Total Employer Contribution (Monthly)] ,
                        [Total Employee Contribution (Annual)] ,
                        [Total Employee Contribution (Monthly)] ,
                        [HLA Amount (Annual)] ,
                        [GPAP (Annual)] ,
                        [GPAP (Monthly)] ,
                        [SI Increase Date] ,
                        [Hourly Rate] ,
                        [Daily Penalty Rate] ,
                        [Gross Remuneration Package (Maximum Rate)] ,
                        [MEPF Risk Contribution (Annual)] ,
                        [Risk Contribution (Annual)] ,
                        [Housing Deduction] ,
                        [HLA Percentage] ,
                        [Housing Deduction Amount] ,
                        [Housing Deduction Fringe Benefit] ,
                        [House Grade] ,
                        [Housing Deduction Amount (Annual)] ,
                        [Housing Deduction Fringe Benefit (Annual)] ,
                        [Medical Member Company Value] ,
                        [Medical Child Dependants Company Value] ,
                        [Medical Spouse Dependants Company Value]
                FROM    #Package



---SYS RSA TAX Details

        SET @Section = 'RSA TAx Details'

        DECLARE @TaxRef NVARCHAR(50)

        SET @TaxRef = ( SELECT  [Income Tax Reference Number]
                        FROM    [dbo].[Sys RSA Tax Details]
                        WHERE   [Resource Tag] = @ResourceTag
                                AND [Tax End Date] = '99991231'
                      )


        UPDATE  [dbo].[Sys RSA Tax Details]
        SET     [Tax End Date] = DATEADD(dd, -1, @Date)
        WHERE   [Resource Tag] = @ResourceTag
                AND [Tax End Date] = '99991231'

        INSERT  INTO [dbo].[Sys RSA Tax Details]
                ( [Resource Tag] ,
                  [Tax Start Date] ,
                  [Tax End Date] ,
                  [Income Tax Reference Number] 
        
                )
        VALUES  ( @ResourceTag , -- Resource Tag - int
                  @Date , -- Tax Start Date - datetime
                  '99991231' , -- Tax End Date - datetime
                  @TaxRef
                )
        



--- Emp Termination

        INSERT  INTO [dbo].[Emp Termination]
                ( [Resource Tag] ,
                  [Date] ,
                  [Date of Notice] ,
                  [Last Shift Worked] ,
                  [Termination Date] ,
                  [Termination Type] ,
				  [Period ID],
				  [Status],
				  [Pay Date]
         
                )
        VALUES  ( @ResourceTag ,
                  DATEADD(dd, -1, @Date) ,
                  DATEADD(dd, -1, @Date) ,
                  DATEADD(dd, -1, @Date) ,
                  DATEADD(dd, -1, @Date) ,
                  'Transfer',
				  @PI,
				  'Authorized',
				   DATEADD(dd, -1, @Date)

                )

---Emp Retirement Fund

        DECLARE @CurrentFund NVARCHAR(50)
        DECLARE @DefaultFund NVARCHAR(50)

		DECLARE @RemMethod NVARCHAR(50)

		SET @RemMethod = (SELECT [To Remuneration Method] FROM [dbo].[Emp Work History] WHERE [Resource Tag] = @ResourceTag AND [End Date] = '99991231')

        SET @CurrentFund = ( SELECT [Retirement Fund]
                             FROM   [dbo].[Emp Retirement Fund]
                             WHERE  [Resource Tag] = @ResourceTag
                                    AND @Date BETWEEN [Start Date] AND [End Date]
                           )

        IF @CurrentFund IS NULL 
            BEGIN
 
                SET @DefaultFund = ( SELECT TOP 1
                                            [Retirement Fund]
                                     FROM   [dbo].[Grp Remuneration Method Control]
                                     WHERE  [Operation] = @FromOperation
                                            AND @Date BETWEEN [Start Date] AND [End Date] AND [Remuneration Method] = @RemMethod
                                   )

                INSERT  INTO [dbo].[Emp Retirement Fund]
                        ( [Resource Tag] ,
                          [Start Date] ,
                          [End Date] ,
                          [Retirement Fund] ,
                          [Retirement Fund Status (Recog Unit) (Override)]
                        )
                VALUES  ( @ResourceTag , -- Resource Tag - int
                          @Date , -- Start Date - datetime
                          '99991231' , -- End Date - datetime
                          @DefaultFund , -- Retirement Fund - nvarchar(50)
                          NULL  -- Retirement Fund Status (Recog Unit) (Override) - varchar(50)
                        )

            END

			ELSE
            BEGIN

                UPDATE  [dbo].[Emp Retirement Fund]
                SET     [End Date] = DATEADD(dd, -1, @Date)
                WHERE   [Resource Tag] = @ResourceTag
                        AND [End Date] >= @Date
                        AND [Start Date] < @Date

                INSERT  INTO [dbo].[Emp Retirement Fund]
                        ( [Resource Tag] ,
                          [Start Date] ,
                          [End Date] ,
                          [Retirement Fund] ,
                          [Retirement Fund Status (Recog Unit) (Override)]
                        )
                VALUES  ( @ResourceTag , -- Resource Tag - int
                          @Date , -- Start Date - datetime
                          '99991231' , -- End Date - datetime
                          @CurrentFund , -- Retirement Fund - nvarchar(50)
                          NULL  -- Retirement Fund Status (Recog Unit) (Override) - varchar(50)
                        )

            END

	--- End Cost Split


        UPDATE  [dbo].[Emp Cost Split]
        SET     [End Date] = DATEADD(dd, -1, @Date)
        WHERE   [Resource Tag] = @ResourceTag
                AND [End Date] >= @Date
				AND [Start Date] < @Date



--- Reminder Section

  EXEC dbo.sp_SendGT_Reminder @ResourceTag = @ResourceTag, -- int
            @TDate = @Date, -- nvarchar(30)
            @MovementType = @MovementType, -- nvarchar(50)
            @PaymentId = @PaymentID -- nvarchar(10)

		EXEC  ARMSsp_Reminder_Distributor





        COMMIT
    END TRY


    BEGIN CATCH
        ROLLBACK
        SET @sMsg = 'Error ' + CONVERT(VARCHAR(50), ERROR_NUMBER())
            + ' on line ' + CONVERT(VARCHAR(50), ERROR_LINE())
            + ' message text is "' + ERROR_MESSAGE() + '"'
        RAISERROR ('%s',16, 1, @sMsg)
        RAISERROR ('Transactions on Section "%s" have been rolled back.',16, 1, @Section)
    END CATCH
-------------------------------------------------------------------------------------------------------------------------

GO

-------------------------------------------------------------------------------------------------------------------------
go

DECLARE @User VARCHAR(50), @IssueNumber VARCHAR(20), @ScriptName VARCHAR(100), @Description VARCHAR(500), @ChangeNumber VARCHAR(20)
DECLARE @IDENTITY INT, @SpecialInstructions VARCHAR(150), @DataChange Bit, @sMsg varchar(4000), @LoggedBy NVARCHAR(50), @VerifiedBy NVARCHAR(50)
Declare @tbRT ResourceTagTableType, @FunctionalArea varchar(50), @ObjectType varchar(50), @ObjectName varchar(50), @Version	varchar(50)
SET @User = 'Pieter Kitshoff'
SET @IssueNumber = 'SYM39546'
SET @ScriptName = 'SYM39546-03 PK Pro GT Proc Change.sql'
SET @Description = 'Run reminder in proc'
SET @DataChange = 1
SET @FunctionalArea = 'Payroll'
SET @ObjectType = 'Table' -- 'TABLE', 'VIEW', 'STORED PROC','FUNCTION', 'INDEX', 'CONSTRAINT'
SET @ObjectName = 'Emp absence request' 
SET @Version = '2.4.2'
SET @SpecialInstructions = ''
SET @LoggedBy = 'Cornel Metcalfe'
SET @VerifiedBy = 'Karen Steenkamp'
Set @Identity = -1

Exec SYMsp_SymplexityChangeCTRL 1, @User, @IssueNumber, @ScriptName, @Description, @DataChange, @FunctionalArea, @ObjectType, @ObjectName, @Version, @IDENTITY OUTPUT, @tbRT, @LoggedBy
GO
