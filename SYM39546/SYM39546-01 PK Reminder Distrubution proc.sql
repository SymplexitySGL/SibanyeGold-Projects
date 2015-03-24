--USE [Sibanye Gold Limited]
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


ALTER   PROCEDURE [dbo].[ARMSsp_Reminder_Distributor]
AS
BEGIN
/*

------------------------------------------------------------------------------------------------------------------------------
-- Name            : 	ARMSsp_Reminder_Distributor
--
-- Created By      : 	MC
--
-- Date Created    :	20/12/2004
--
-- Description     :	Distributes the reminder transactions depending on the type (email , inbox etc.)
--
-- Change History  :	MC	24/11/2005	Total re-write to create Transactions with Security per recipient
--
--						SP  24/04/2008  Major changes for Symplexity Version of Software.  MC Thourough Test
--
--						MC	09/03/2009	Include Distrubution for SMS at Comair
--
-------------------------------------------------------------------------------------------------------------------------------

*/

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE @sendmail_ret_code  		INT
DECLARE @sendSMS_ret_code  			INT
DECLARE @Resource_Tag				Int	
DECLARE @Transaction_No				Int	
DECLARE @Rule_No					Int
DECLARE @schedule_No				Int
DECLARE @Reminder_Send_As			nvarchar(20) 	
DECLARE @Recipient_User_id			nvarchar(50)
DECLARE @Recipient_type				nvarchar(50)	
DECLARE @Recipient_Email_Address	nvarchar(800)
DECLARE @Recipient_SMS_no			nvarchar(50)
DECLARE @Reminder_Subject			nvarchar(100)
DECLARE @Mailitemid					int
DECLARE @CSV_Message				nvarchar(4000) 		
DECLARE @Reminder_Message			varchar(max)
DECLARE @Reminder_Description		varchar(1000) --SP 20080403 add Description for CSV for Body Text	
DECLARE @SMS_Message				varchar(160)
DECLARE @SMS_No						varchar(20)
DECLARE @FilePath					Varchar(500)
DECLARE @Extension					Varchar(10)

	SELECT TOP 1 @FilePath = [Path], @Extension = [Extension] 
	FROM [Arms Reminder Paths] 
	WHERE [Short Description] = 'CSV' 
	AND GETDATE() BETWEEN [Start Date] AND [End Date]

	DECLARE  Reminder_Transactions CURSOR FOR
	SELECT  [Resource Tag],		
			[Transaction No],	
			[Reminder Send As],
			[Recipient User ID],
			[Recipient Type],	
			[Recipient Email Address],
			[Recipient SMS No],	
			[Reminder Subject], 	
			[Reminder Message],
			[Rule No], 		
			[Schedule No],
			[Reminder Description] 	
	FROM    [ARMS Reminder Transactions]
	WHERE 	[Reminder Fire Date] <= getdate()  -- all that fire today and missed ones from the past
	  AND   [Reminder Status] = 'Ready for send'

	OPEN Reminder_Transactions
	FETCH NEXT FROM Reminder_Transactions INTO @Resource_Tag, @Transaction_No, @Reminder_Send_As, @Recipient_User_ID, @Recipient_type, @Recipient_Email_Address, @Recipient_SMS_no, @Reminder_Subject, @Reminder_Message, @Rule_No, @Schedule_No, @Reminder_Description

	WHILE @@FETCH_STATUS = 0
	BEGIN
		--print @Recipient_User_ID
		--Print @Reminder_Send_As
		--print @Recipient_Email_Address
		--print @Recipient_SMS_No

		--------------------------------------------------
		-------------DISTRIBUTE EMAIL---------------------
		--------------------------------------------------
		IF @Reminder_Send_As = 'Email' 
		BEGIN 
			IF @Recipient_Email_Address <> 'Not Defined'
 			BEGIN
				IF substring(@Reminder_Message,1,21) = '***CSV File Sample***'   --CSV file attachement to be created
				BEGIN
					DECLARE @o int, @f int, @t int, @ret int, @filename varchar(100)
					
					SET @filename = @FilePath + @Recipient_User_ID + @Extension 
					
					EXEC sp_OACreate 'scripting.filesystemobject', @o out
					EXEC sp_OAMethod @o, 'createtextfile', @f out, @filename,1 --'D:\Reminders Temp\Reminder.csv', 1   --This is the dir on the DB server!!!

					--CSV Header 
					SELECT @CSV_Message = [Reminder Message]
					FROM [ARMS Reminder Transactions CSV]
					WHERE [Rule No] = @Rule_No
					AND [Schedule No] = @Schedule_No
					AND [Recipient User ID]	= 'Header for CSV File'

					EXEC @ret = sp_oamethod @f, 'writeline', NULL, @CSV_Message 

					--Rest of file
					DECLARE CSV_CURSOR CURSOR FOR
  					SELECT [Reminder Message]
					FROM [ARMS Reminder Transactions CSV]
					WHERE [Rule No] = @Rule_No
					AND [Schedule No] = @Schedule_No
					AND [Recipient User ID] = @Recipient_User_ID 

					OPEN CSV_Cursor
					FETCH NEXT FROM CSV_Cursor
					INTO @CSV_Message
				
					WHILE @@FETCH_STATUS = 0
					BEGIN
						EXEC @ret = sp_oamethod @f, 'writeline', NULL, @CSV_Message 
					
						FETCH NEXT FROM CSV_Cursor
						INTO @CSV_Message
					END
					
					EXEC sp_OADestroy @f

					CLOSE CSV_Cursor
					DEALLOCATE CSV_Cursor

					print 'Sending Mail with Attachement...'
					Set @sendmail_ret_code = 0
					exec @sendmail_ret_code = msdb.dbo.sp_send_dbmail 
											 @recipients		=  @Recipient_Email_Address, 
						  					 @body				=  @Reminder_Description,  
						    				 @subject			=  @Reminder_subject,
											 @file_attachments	=  @filename,
											 @body_format       = 'HTML',
											 @mailitem_id		=  @Mailitemid	OUT

				END
				ELSE
				BEGIN
					PRINT 'reminder'
					PRINT @Reminder_Message
					
		--			DECLARE @tmpMessage TABLE ([$02] VARCHAR(100), [$A] VARCHAR(100))
		--		 	--***********************************************************
		--	
		--			INSERT INTO @tmpMessage ([$02])
		--			SELECT * FROM [ARMSfn_Split](@Reminder_Message,'$02')	
		--
		--			Select SUBSTRING('3187-ROOS-JC. $02 05 Jan 2009 $A 3192-COETZEE-GJ. $02 04 Jan 2009 $A 3193-LOTTERING-GF. $02 12 Feb 2009 $A 3188-Bylevedt-H.',1,CHARINDEX('$02','3187-ROOS-JC. $02 05 Jan 2009 $A 3192-COETZEE-GJ. $02 04 Jan 2009 $A 3193-LOTTERING-GF. $02 12 Feb 2009 $A 3188-Bylevedt-H.'))
		--
		--
		----
		----		SELECT * FROM [ARMSfn_Split]('3187-ROOS-JC. $02 05 Jan 2009 $A 3192-COETZEE-GJ. $02 04 Jan 2009 $A 3193-LOTTERING-GF. $02 12 Feb 2009 $A 3188-Bylevedt-H. $02 27 Jan 2009 $A 3191-van der Merwe-S. $02 31 Jan 2009 $A' ,'$A')
		----			
		--			 set @Reminder_Message = REPLACE(@Reminder_Message,'$02', ' td ')
		--			
		--			DECLARE @xml NVARCHAR(MAX)
		--			DECLARE @body NVARCHAR(MAX)
		--			
		----			SET @xml = CAST((SELECT [Message] AS 'td' FROM @tmpMessage
		----							 FOR XML PATH('tr'), ELEMENTS ) AS NVARCHAR(MAX))
		--
		--			SET @xml = CAST((SELECT @Reminder_Message
		--							 FOR XML PATH('tr'), ELEMENTS ) AS NVARCHAR(MAX))
		--		
		--			SET @body ='<html><H1>Reminders Demo</H1><body bgcolor=lightblue><table border = 2><tr><th>Surname</th><th>SaleAmount</th></tr>' 
		--			SET @body = @body + @xml +'</table></body></html>'
		--		
		--			SET @Reminder_Message = @body
					
					
					
		--			SELECT * FROM [ARMS Reminder Transactions] ORDER BY [Transaction No] desc
		--			
		--			
		--			3187-ROOS-JC.  05 Jan 2009 
		--			3192-COETZEE-GJ.  04 Jan 2009 ~|~
		--			3193-LOTTERING-GF. ~|~ 12 Feb 2009 ~|~
		--			3188-Bylevedt-H. ~|~ 27 Jan 2009 ~|~
		--			3191-van der Merwe-S. ~|~ 31 Jan 2009 ~|~
				
					print 'Sending Mail without Attachment...'	
					Set @sendmail_ret_code = 0

					exec @sendmail_ret_code = msdb.dbo.sp_send_dbmail 
											@recipients			=  @Recipient_Email_Address, 
						  					@body				=  @Reminder_Message, 
						    				@subject			=  @Reminder_subject,
						    				@body_format        = 'HTML',
											@mailitem_id		=  @Mailitemid	OUT
				END
			END

			declare @sent_status tinyint

			SELECT @sent_status = sent_status 
			FROM msdb.dbo.sysmail_mailitems 
			WHERE mailitem_id =  @Mailitemid 

			--	print @Mailitemid
			--	print @sendmail_ret_code
			--	print @sent_status
			
			IF @sendmail_ret_code = 0 and @sent_status = 0 --0 is still in progress, 1 = good , 2 = fail
			BEGIN
				print  'email sent to: ' + @Recipient_Email_Address
				UPDATE [ARMS Reminder Transactions] 
				SET [Reminder Status]     	= 'Email sent',
					[Reminder Status Date] 	= getdate()
				WHERE [Transaction No] 		= @Transaction_No	
			END
			ELSE
				Print ' Email Send Error - Could not send mail.  Will resend at next run'
		END  

		--------------------------------------------------
		-------------DISTRIBUTE SMS---------------------
		--------------------------------------------------
		IF @Reminder_Send_As = 'SMS' 
		BEGIN 
			set @SMS_Message = left(@Reminder_Message,160)
			set @SMS_No = '27' + replace(substring(@Recipient_SMS_no,2,20),' ','') 
			Set @sendSMS_ret_code = 0

			--print @SMS_Message 
			--print @SMS_No
			IF len(@SMS_No) = 11
				BEGIN
					--print 'Can Send'
					exec @sendSMS_ret_code = ARMSsp_Reminder_SMS_Message @SMS_Message, 'Symplexity', @SMS_No
					IF @sendSMS_ret_code = 0 
					BEGIN
						--print  'SMS sent to: ' + @Recipient_SMS_no
						UPDATE [ARMS Reminder Transactions] 
						SET [Reminder Status]     	= 'SMS sent', --'SMS in queue',
							[Reminder Status Date] 	= getdate()
						WHERE [Transaction No] 		= @Transaction_No													
					END
					ELSE
						Print 'SMS Send Error - Could not send SMS.  Will resend at next run'
				END
			ELSE
				UPDATE [ARMS Reminder Transactions] 
				SET [Reminder Status]     	= 'Cannot Send SMS - Number incorrect',
					[Reminder Status Date] 	= getdate()
				WHERE [Transaction No] 		= @Transaction_No	
			
			--Print @sendSMS_ret_code

		END  

		--------------------------------------------------
		-------------DISTRIBUTE INBOX---------------------
		--------------------------------------------------
		--switched off
		--IF @Reminder_Send_As = 'Inbox'
		--BEGIN
		--	UPDATE 	[ARMS Reminder Transactions] 
		--	SET   	[Reminder Status]       = 'Moved to Inbox' ,
		-- 			[Reminder Status Date] 	= getdate() 
		--	WHERE 	[Transaction No] = @Transaction_No 
		--END

		------------------------------------------------------

		FETCH NEXT FROM Reminder_Transactions INTO @Resource_Tag, @Transaction_No, @Reminder_Send_As, @Recipient_User_ID, @Recipient_type, @Recipient_Email_Address, @Recipient_SMS_no, @Reminder_Subject, @Reminder_Message, @Rule_No, @Schedule_No, @Reminder_Description

	END

	CLOSE Reminder_Transactions
	DEALLOCATE Reminder_Transactions
	
	--EXEC ARMSsp_Reminder_SMS_Check_Status

	------------------------------------------------------
	--Do Cleanup
	-----------------------------------------------------

	--60 days for inboxes
	DELETE FROM [ARMS Reminder Transactions]
	WHERE [Reminder Status] = 'Moved To Inbox'
	AND [Reminder Status Date] 	< DateAdd(dd,-60, getdate())

	--5 Days for invalid Inboxes - Can change to 0
	DELETE FROM [ARMS Reminder Transactions]
	WHERE [Reminder Status]  in ( 'Moved To Inbox', 'Ready for Send')
	AND [Reminder Status Date] < DateAdd(dd,-1, getdate())
	AND [Recipient User ID] = 'NA'

	--5 Days for Email to send without Recipient email addresses
	DELETE FROM [ARMS Reminder Transactions]
	WHERE [Reminder Status]  = 'Ready for Send'
	AND [Reminder Status Date] < DateAdd(dd,-5, getdate())
	AND [Reminder Send As] in ('Email')
	AND [Recipient Email Address] = 'Not Defined'

	--5 Days for SMS to send without Recipient SMS No
	DELETE FROM [ARMS Reminder Transactions]
	WHERE [Reminder Status]  = 'Ready for Send'
	AND [Reminder Status Date] < DateAdd(dd,-5, getdate())
	AND [Reminder Send As] in ('SMS')

	--60 Days for Email Attachments
	DELETE FROM [ARMS Reminder Transactions CSV]
	WHERE Dateadd(dd,60,[Last Fire Date]) < getdate()

	--5 Days for Email Sent - Can change to 0
	DELETE FROM [ARMS Reminder Transactions]
	WHERE [Reminder Status]  in ('Email sent','SMS sent')
	AND [Reminder Status Date] < DateAdd(dd,-5, getdate())
	AND [Recipient User ID] = 'NA'

---------------------------------------------------------
END	--FIN



GO

-------------------------------------------------------------------------------------------------------------------------
go

DECLARE @User VARCHAR(50), @IssueNumber VARCHAR(20), @ScriptName VARCHAR(100), @Description VARCHAR(500), @ChangeNumber VARCHAR(20)
DECLARE @IDENTITY INT, @SpecialInstructions VARCHAR(150), @DataChange Bit, @sMsg varchar(4000), @LoggedBy NVARCHAR(50), @VerifiedBy NVARCHAR(50)
Declare @tbRT ResourceTagTableType, @FunctionalArea varchar(50), @ObjectType varchar(50), @ObjectName varchar(50), @Version	varchar(50)
SET @User = 'Pieter Kitshoff'
SET @IssueNumber = 'SYM39546'
SET @ScriptName = 'SYM39546-01 PK Reminder Distrubution proc.sql'
SET @Description = 'Change Reminder Distrobution Proc'
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
