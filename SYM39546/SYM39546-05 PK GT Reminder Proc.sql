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
GO
ALTER FUNCTION dbo.Fn_ReminderEmails
    (
      @Group_1 INT ,
      @Group_2 INT,
	  @Group_3 INT
    )
RETURNS VARCHAR(4000)
AS
    BEGIN	 

        DECLARE @Email_all NVARCHAR(4000)
        DECLARE @Email NVARCHAR(100)

        SET @Email_all = ''
        DECLARE Email1 CURSOR
        FOR
            SELECT  ISNULL([Email Address],'')
            FROM    [ARMS Reminder ARMS User Recipient Groups] AS araur
            WHERE   [Group No] = @Group_1

        OPEN Email1
        FETCH NEXT FROM Email1 INTO @Email
        WHILE ( @@FETCH_STATUS <> -1 )
            BEGIN


                SET @Email_all = @Email_all + @Email + ';'


                FETCH NEXT FROM Email1 INTO @Email

            END

        CLOSE Email1
        DEALLOCATE Email1



        DECLARE Email2 CURSOR
        FOR
            SELECT  ISNULL([Email Address],'')
            FROM    [ARMS Reminder ARMS User Recipient Groups] AS araur
            WHERE   [Group No] = @Group_2
        OPEN Email2
        FETCH NEXT FROM Email2 INTO @Email
        WHILE ( @@FETCH_STATUS <> -1 )
            BEGIN


                SET @Email_all = @Email_all + @Email + ';'


                FETCH NEXT FROM Email2 INTO @Email

            END

        CLOSE Email2
        DEALLOCATE Email2


		        DECLARE Email3 CURSOR
        FOR
            SELECT  ISNULL([Email Address],'')
            FROM    [ARMS Reminder ARMS User Recipient Groups] AS araur
            WHERE   [Group No] = @Group_3
        OPEN Email3
        FETCH NEXT FROM Email3 INTO @Email
        WHILE ( @@FETCH_STATUS <> -1 )
            BEGIN


                SET @Email_all = @Email_all + @Email + ';'


                FETCH NEXT FROM Email3 INTO @Email

            END

        CLOSE Email3
        DEALLOCATE Email3


        RETURN @Email_all

    END

GO

ALTER TABLE [dbo].[ARMS Reminder Transactions] ALTER COLUMN [Recipient Email Address] NVARCHAR(4000)

GO

SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
GO

ALTER PROCEDURE sp_SendGT_Reminder (@ResourceTag INT,

@TDate NVARCHAR(30),
@MovementType NVARCHAR(50),
@PaymentId NVARCHAR(10) ) AS


--SET @MovementType = 'Same Designation'
--SET @ResourceTag = 100364086
--SET @TDate = '2014-10-04 00:00:00.000'
--SET @PaymentId = 'COM'

DECLARE @ResourceName  NVARCHAR(100),
@LQS NVARCHAR(10),
@Sick NVARCHAR(10),
@Mine NVARCHAR(10),
@Family NVARCHAR(10),
@Annual NVARCHAR(10),
@Accum NVARCHAR(10),

@CaptureDate NVARCHAR(30),
@Operation NVARCHAR(40),
@Orgunit NVARCHAR(100),
@Designation NVARCHAR(100),
@UserId NVARCHAR(20),
@UserDetail NVARCHAR(50),
@Calendar NVARCHAR(20),
@Periodid INT,
@ReminderGroup INT,
@ReminderGroup2 INT,
@FromOperation NVARCHAR(100)


--Transfer Details

SELECT @CaptureDate = [Capture Date],
@Operation = [To Operation],
@FromOperation = [From Operation],
@Orgunit = [To Org Unit Gang],
@Designation = [To Designation],
@UserId = [User ID]
FROM [dbo].[Emp Group Transfer] EGT WHERE [Resource Tag] = @ResourceTag AND [Effective Date] = @TDate


IF @CaptureDate IS NULL
    BEGIN
        SELECT  @CaptureDate = [Capture Date] ,
                @Operation = [To Operation] ,
				@FromOperation = [From Operation],
                @Orgunit = [To Org Unit Gang] ,
                @Designation = [To Designation] ,
                @UserId = [User ID]
        FROM    [dbo].[Emp Group Transfer Pro] EGTP
        WHERE   [Resource Tag] = @ResourceTag
                AND [Effective Date] = @TDate
    END

SET @UserDetail = (SELECT [Resource Name] FROM [dbo].[Resource] WHERE [Resource Reference] = @UserId)

SET @ResourceName = (SELECT [Resource Name] FROM [dbo].[Resource] WHERE [Resource Tag] = @ResourceTag)

SET @Calendar = (SELECT [Calendar] FROM [dbo].[Resource Calendars] WHERE [Resource Tag] =@ResourceTag AND @TDate BETWEEN [Start Date] AND [End Date])


SET  @Periodid = (SELECT MAX([Period ID]) FROM [dbo].[Calendar Periods] WHERE [Calendar] = @Calendar AND [Completed] = 'Yes' AND [RunType] = 'Normal')


---Reminder Group

SET @ReminderGroup = CASE WHEN @FromOperation IN ( 'SGWH', 'SGSS', 'SGA',
                                                   'Sibanye Gold', 'SGFP',
                                                   'SGFH', 'SGPS' ) THEN 25
                          ELSE CASE WHEN @FromOperation = 'Beatrix' THEN 27
                                    ELSE CASE WHEN @FromOperation = 'Kloof'
                                              THEN 23
                                              ELSE CASE WHEN @FromOperation = 'Driefontein'
                                                        THEN 21
														ELSE CASE WHEN @FromOperation IN ('Rand Uranium','Ezulwini')
														THEN 33
														END
                                                   END
                                         END
                               END
                     END



SET @ReminderGroup2 = CASE WHEN @Operation IN ( 'SGWH', 'SGSS', 'SGA',
                                                   'Sibanye Gold', 'SGFP',
                                                   'SGFH', 'SGPS' ) THEN 25
                          ELSE CASE WHEN @Operation = 'Beatrix' THEN 27
                                    ELSE CASE WHEN @Operation = 'Kloof'
                                              THEN 23
                                              ELSE CASE WHEN @Operation = 'Driefontein'
                                                        THEN 21

														ELSE CASE WHEN @Operation IN ('Rand Uranium','Ezulwini')
														THEN 33
														END
                                                   END
                                         END
                               END
                     END

-- Balances Details

SET @Accum = 0.00000
SET @Annual = 0.00000
SET @LQS = 0.00000
SET @Family = 0.00000
SET @Mine = 0.00000
SET @Sick = 0.00000


--SELECT * FROM [dbo].[Output Transactions] OT WHERE [Resource Tag] = 100367459 AND [Period ID] = @Periodid

IF @PaymentId = 'COM' 
BEGIN

SET @Accum = (SELECT ROUND([Output Value],2) FROM [dbo].[Output Transactions] OT WHERE [Resource Tag] =@ResourceTag AND [Period ID] = @Periodid AND [Element] = 'Accumulated Leave (Closing Balance)')
SET @Annual = (SELECT ROUND([Output Value],2) FROM [dbo].[Output Transactions] OT WHERE [Resource Tag] =@ResourceTag AND [Period ID] = @Periodid AND [Element] = 'Annual Leave (Closing Balance)')
SET @LQS = (SELECT ROUND([Output Value],0) FROM [dbo].[Output Transactions] OT WHERE [Resource Tag] =@ResourceTag AND [Period ID] = @Periodid AND [Element] = 'Leave Qualifying Shifts (YTD) (Closing Balance)')
SET @Family = (SELECT ROUND([Output Value],0) FROM [dbo].[Output Transactions] OT WHERE [Resource Tag] =@ResourceTag AND [Period ID] = @Periodid AND [Element] = 'Family Responsibility (Closing Balance)')
SET @Mine = (SELECT ROUND([Output Value],0) FROM [dbo].[Output Transactions] OT WHERE [Resource Tag] =@ResourceTag AND [Period ID] = @Periodid AND [Element] = 'Mine Accident (100%) (Closing Balance)')
SET @Sick = (SELECT ROUND([Output Value],0) FROM [dbo].[Output Transactions] OT WHERE [Resource Tag] =@ResourceTag AND [Period ID] = @Periodid AND [Element] = 'Sick (100%) (Closing Balance)')

END

IF @PaymentId <> 'COM' 
BEGIN

SET @Accum = (SELECT ROUND([Output Value],2) FROM [dbo].[Output Transactions] OT WHERE [Resource Tag] =@ResourceTag AND [Period ID] = @Periodid AND [Element] = 'Accumulated Leave (Closing Balance)')
SET @Annual = (SELECT ROUND([Output Value],2) FROM [dbo].[Output Transactions] OT WHERE [Resource Tag] =@ResourceTag AND [Period ID] = @Periodid AND [Element] = 'Occasional Leave (Closing Balance)')
--SET @LQS = 'N/A'
SET @Family = (SELECT ROUND([Output Value],0) FROM [dbo].[Output Transactions] OT WHERE [Resource Tag] =@ResourceTag AND [Period ID] = @Periodid AND [Element] = 'Family Responsibility Leave (Closing Balance)')
SET @Mine = (SELECT ROUND([Output Value],0) FROM [dbo].[Output Transactions] OT WHERE [Resource Tag] =@ResourceTag AND [Period ID] = @Periodid AND [Element] = 'Mine Accident (Closing Balance)')
SET @Sick = (SELECT ROUND([Output Value],0) FROM [dbo].[Output Transactions] OT WHERE [Resource Tag] =@ResourceTag AND [Period ID] = @Periodid AND [Element] = 'Sick Leave (Closing Balance)')

END

--SELECT @LQS


SET @Accum = ISNULL(@Accum, '0.00000')

SET @Annual = ISNULL(@Annual, '0.00000')

SET @Family = ISNULL(@Family, '0.00000')

SET @Mine = ISNULL(@Mine, '0.00000')

SET @Sick = ISNULL(@Sick, '0.00000')

SET @LQS = ISNULL(@LQS, '0.00000')


--SELECT @Accum,@Annual,@Family,@Mine,@Sick,@LQS








SET @Accum = LEFT(@Accum, LEN(@Accum) - 3)

SET @Annual = LEFT(@Annual, LEN(@Annual) - 3)

SET @Family = LEFT(@Family, LEN(@Family) - 3)

SET @Mine = LEFT(@Mine, LEN(@Mine) - 3)

SET @Sick = LEFT(@Sick, LEN(@Sick) - 3)

SET @LQS = LEFT(@LQS, LEN(@LQS) - 3)





INSERT INTO [dbo].[ARMS Reminder Transactions]
        ( [Resource Tag] ,
          [Rule No] ,
          [Schedule No] ,
          [Reminder Name] ,
          [Reminder Type] ,
          [Reminder Send As] ,
          [Creator Resource Tag] ,
          [User ID] ,
          [Creator User Name] ,
          [Recipient User ID] ,
          [Recipient User Name] ,
          [Recipient Type] ,
          [Recipient Email Address] ,
          [Recipient SMS No] ,
          [Reminder Fire Date] ,
          [Reminder Event Date] ,
          [Reminder Create Date] ,
          [Reminder From Query] ,
          [Reminder From Screen] ,
          [Reminder From Field] ,
          [Content Resource Tag] ,
          [Content Name] ,
          [Content Original Date] ,
          [Content E-mail Address] ,
          [Content SMS No] ,
          [Content Cost Centre] ,
          [Content Job Title] ,
          [Content First Name] ,
          [Content Surname] ,
          [Content Number] ,
          [Content Employee Type] ,
          [Content Message Field 1] ,
          [Content Message Field 2] ,
          [Content Message Field 3] ,
          [Content Message Field 4] ,
          [Content Message Field 5] ,
          [Content Message Field 6] ,
          [Content Message Field 7] ,
          [Content Message Field 8] ,
          [Content Message Field 9] ,
          [Content Message Field 10] ,
          [Content Message Field 11] ,
          [Content Message Field 12] ,
          [Reminder Subject] ,
          [Reminder Message] ,
          [Reminder Status] ,
          [Reminder Status Date] ,
          [Reminder Description] ,
          [Source] ,
          [Batch No]
        )
VALUES  ( 100359571 , -- Resource Tag - int
          0 , -- Rule No - int
          0 , -- Schedule No - int
          'Group Transfer' , -- Reminder Name - varchar(20)
          'Query' , -- Reminder Type - varchar(20)
          'Email' , -- Reminder Send As - varchar(20)
          130000144 , -- Creator Resource Tag - int
          'G0395193' , -- User ID - varchar(50)
          'G0395193' , -- Creator User Name - varchar(50)
          'NA_1' , -- Recipient User ID - varchar(50)
          'Con-EJor-Sym' , -- Recipient User Name - varchar(50)
          'Single Recipient - External' , -- Recipient Type - varchar(50)
          dbo.Fn_ReminderEmails(29,@ReminderGroup,@ReminderGroup2) , -- Recipient Email Address - varchar(80)
          '' , -- Recipient SMS No - varchar(50)
          GETDATE() , -- Reminder Fire Date - datetime
          GETDATE() , -- Reminder Event Date - datetime
          GETDATE() , -- Reminder Create Date - datetime
          '' , -- Reminder From Query - varchar(100)
          '' , -- Reminder From Screen - varchar(100)
          '' , -- Reminder From Field - varchar(50)
          0 , -- Content Resource Tag - int
          '' , -- Content Name - varchar(50)
         NULL , -- Content Original Date - datetime
          '' , -- Content E-mail Address - varchar(50)
          '' , -- Content SMS No - varchar(50)
          '' , -- Content Cost Centre - varchar(50)
          '' , -- Content Job Title - varchar(50)
          '' , -- Content First Name - varchar(50)
          '' , -- Content Surname - varchar(50)
          '' , -- Content Number - varchar(50)
          '' , -- Content Employee Type - varchar(50)
          '' , -- Content Message Field 1 - varchar(256)
          '' , -- Content Message Field 2 - varchar(256)
          '' , -- Content Message Field 3 - varchar(256)
          '' , -- Content Message Field 4 - varchar(256)
          '' , -- Content Message Field 5 - varchar(256)
          '' , -- Content Message Field 6 - varchar(256)
          '' , -- Content Message Field 7 - varchar(256)
          '' , -- Content Message Field 8 - varchar(256)
          '' , -- Content Message Field 9 - varchar(256)
          '' , -- Content Message Field 10 - varchar(256)
          '' , -- Content Message Field 11 - varchar(256)
          '' , -- Content Message Field 12 - varchar(256)
          'Group Transfer ' +  @ResourceName , -- Reminder Subject - varchar(255)
         
' <html>

<body>
<span style="font-family: Arial Black;"><br>
</span>
<table style="text-align: left; width: 1627px; height: 41px;"
 border="0" cellpadding="2" cellspacing="2">
 <tbody>
 <tr>
 <td
 style="background-color: rgb(195, 156, 78); text-align: center;"><span
 style="font-family: Arial Black;">Sibanye Gold Transfer
Report for Employee : '+@ResourceName + ' Captured by : ' + @UserDetail +'</span></td>
</tr>
</tbody>
</table>
<span style="font-family: Arial Black;"><br>
</span><br>
<span style="font-family: Arial Black;">Transfer Details:<br>
<br>
</span>
<table style="text-align: left; width: 755px; height: 134px;"
 border="1" cellpadding="2" cellspacing="20">
<tbody>
<tr>
<td style="background-color: rgb(195, 156, 78);"><span
style="font-family: Arial;">Transfer Type :</span></td>
<td><span style="font-family: Arial;">Same
Designation</span></td>
</tr>
<tr>
<td style="width: 255px; background-color: rgb(195, 156, 78);"><span
style="font-family: Arial;">Captured Date &amp; Time :</span></td>
<td style="width: 433px;"><span
style="font-family: Arial;">' + @CaptureDate +'</span></td>
</tr>
<tr>
<td style="width: 255px; background-color: rgb(195, 156, 78);"><span
style="font-family: Arial;">Transfer Date :</span></td>
<td style="width: 433px;"><span
style="font-family: Arial;">'+@TDate+'</span></td>
</tr>
<tr>
<td style="width: 255px; background-color: rgb(195, 156, 78);"><span
style="font-family: Arial;">To Operation :</span></td>
<td style="width: 433px;"><span
style="font-family: Arial;">'+@Operation+'</span></td>
</tr>
<tr>
<td style="width: 255px; background-color: rgb(195, 156, 78);"><span
style="font-family: Arial;">To Org Unit Gang :</span></td>
<td style="width: 433px;"><span
style="font-family: Arial;">'+@Orgunit+'</span></td>
</tr>
<tr>
<td style="width: 255px; background-color: rgb(195, 156, 78);"><span
style="font-family: Arial;">To Designation :</span></td>
<td style="width: 433px;"><span
style="font-family: Arial;">'+@Designation+'</span></td>
</tr>
</tbody>
</table>
<br>
<br>
<span style="font-family: Arial Black;">Balances Details:</span><br>
<br>
<br>
<table style="text-align: left; width: 755px; height: 134px;"
 border="1" cellpadding="2" cellspacing="20">
 <tbody>
 <tr>
 <td style="background-color: rgb(195, 156, 78);"><span
 style="font-family: Arial;">Leave Qualifying Shifts:</span></td>
 <td><span style="font-family: Arial;">' + @LQS +'</span></td>
 </tr>
 <tr>
 <td style="width: 255px; background-color: rgb(195, 156, 78);"><span
 style="font-family: Arial;">Annual / Compulsary Leave:</span></td>
 <td style="width: 433px;"><span
 style="font-family: Arial;">' + @Annual +'</span></td>
 </tr>
 <tr>
<td style="width: 255px; background-color: rgb(195, 156, 78);"><span
style="font-family: Arial;">Accumalated / Occasional Leave:</span></td>
<td style="width: 433px;"><span
style="font-family: Arial;">'+@Accum+'</span></td>
</tr>
<tr>
<td style="width: 255px; background-color: rgb(195, 156, 78);"><span
style="font-family: Arial;">Sick Leave:</span></td>
<td style="width: 433px;"><span
style="font-family: Arial;">'+@Sick+'</span></td>
</tr>
<tr>
<td style="width: 255px; background-color: rgb(195, 156, 78);"><span
style="font-family: Arial;">Mine Accident Leave:</span></td>
<td style="width: 433px;"><span
style="font-family: Arial;">'+@Mine+'</span></td>
</tr>
<tr>
<td style="width: 255px; background-color: rgb(195, 156, 78);"><span
style="font-family: Arial;">Family Responsibility Leave:</span></td>
<td style="width: 433px;"><span
style="font-family: Arial;">'+@Family+'</span></td>
</tr>
</tbody>
</table>
</body>
</html>

 ', -- Reminder Message - varchar(5500)
          'Ready for Send' , -- Reminder Status - varchar(50)
         NULL , -- Reminder Status Date - datetime
          '' , -- Reminder Description - varchar(100)
          '' , -- Source - varchar(100)
          0  -- Batch No - int
        )

GO

DELETE FROM [dbo].[Emp Group Transfer Pro] WHERE [Resource Tag] = 2130172247
-------------------------------------------------------------------------------------------------------------------------
go

DECLARE @User VARCHAR(50), @IssueNumber VARCHAR(20), @ScriptName VARCHAR(100), @Description VARCHAR(500), @ChangeNumber VARCHAR(20)
DECLARE @IDENTITY INT, @SpecialInstructions VARCHAR(150), @DataChange Bit, @sMsg varchar(4000), @LoggedBy NVARCHAR(50), @VerifiedBy NVARCHAR(50)
Declare @tbRT ResourceTagTableType, @FunctionalArea varchar(50), @ObjectType varchar(50), @ObjectName varchar(50), @Version	varchar(50)
SET @User = 'Pieter Kitshoff'
SET @IssueNumber = 'SYM39546'
SET @ScriptName = 'SYM39546-05 PK GT Reminder Proc.sql'
SET @Description = 'Create Reminder Email Proc'
SET @DataChange = 1
SET @FunctionalArea = 'Payroll'
SET @ObjectType = 'Table' -- 'TABLE', 'VIEW', 'STORED PROC','FUNCTION', 'INDEX', 'CONSTRAINT'
SET @ObjectName = 'Emp absence request' 
SET @Version = '2.4.2'
SET @SpecialInstructions = ''
SET @LoggedBy = 'Cornel Metcalfe'
SET @VerifiedBy = 'Monika le Roux'
Set @Identity = -1

Exec SYMsp_SymplexityChangeCTRL 1, @User, @IssueNumber, @ScriptName, @Description, @DataChange, @FunctionalArea, @ObjectType, @ObjectName, @Version, @IDENTITY OUTPUT, @tbRT, @LoggedBy
GO
