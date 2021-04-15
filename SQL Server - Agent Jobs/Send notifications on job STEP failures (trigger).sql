/*
Send notifications on job STEP failures (trigger)

Have you ever wanted to have SQL note a failure on a step, yet continue running the job.  
I found it to be annoying that you have to fail (and end) a job in order to send a message to an operator. 

I have processes that run at off times, I want to know when there are failures but I need the remainder of my steps to run, period. 

This trigger makes use of xp_sendmail to send emails to someone, as well as generate an error in SQL's error log.  

I welcome any comments, suggestions and criticisms.

*/

create trigger trg_stepfailures
on sysjobhistory
for insert
as 
declare @strMsg varchar(400),
@strRecipient varchar(128)

set @strRecipient = 'ken.singer@sagepub.com'

if exists (select * from inserted where run_status = 0 and step_name <> '(job outcome)')
begin
	select 	@strMsg = 
		convert(char(10),'Server') + char(58) + @@servername +
		char(10) +
		convert(char(10),'Job') + char(58) + convert(varchar(50), sysjobs.name) + 
		char(10) +
		convert(char(10),'Step') + char(58) + convert(varchar(50), inserted.step_name)+
		char(10) +
		convert(char(10),'Message') + char(58) + convert(varchar(150), inserted.message)
	from	inserted
	join	sysjobs
	on	inserted.job_id = sysjobs.job_id
	where	inserted.run_status = 0
	
	raiserror (@strMsg, 16, 10) with log
	exec master.dbo.xp_sendmail	@recipients = @strRecipient,
					@message = @strMsg,
					@subject = 'Job Failure'
			
end


