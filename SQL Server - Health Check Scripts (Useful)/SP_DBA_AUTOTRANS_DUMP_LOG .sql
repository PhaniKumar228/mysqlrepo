/*
    
SP_DBA_AUTOTRANS_DUMP_LOG 

Purpose : This routine will  dump the transaction logs based on the percentage on how full the transaction logs 
            are  based on parmeter from the logthres table Schedule the script within SqlAgent                                                    
           Insert into the logthres table 'database name', 'threshold value' , ' y or n (if you want to init transaction logs       
 
*/

/****  SP_DBA_AUTOTRANS_DUMP_LOG *****/
/****  Purpose : This routine will  dump the transaction logs based on the percentage on how full the transaction logs *****/
/****            are  based on parmeter from the logthres table                                                        *****/
/****            Schedule the script within SqlAgent                                                                   *****/
/****            Insert into the logthres table 'database name', 'threshold value' , ' "y" or "n" (if you want to init *****/
/****            transaction logs       

*****/

CREATE TABLE [dbo].[logthres] (
	[dbname] [char] (20) NULL ,
	[threshold] [smallint] NULL ,
	[ckinit] [char] (1) NULL 
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[logspace] (
	[dbname] [char] (30) NOT NULL ,
	[logsize] [float] NOT NULL ,
	[logspaceused] [float] NOT NULL ,
	[status] [tinyint] NOT NULL ,
	[last_update] [smalldatetime] NULL 
) ON [PRIMARY]
GO

CREATE PROCEDURE sp_dba_autotrans_dump_log
 
 AS
declare @name char(30)
declare @dmpdevice char(30) 
declare @thresh char(3)
declare @ckinit_YN char(1)
declare @dstat char(100)
declare @xshell3 char(400)
declare @hdate  char(10)
declare @htime  char(10)
declare @ctime  char(30)
declare @logmsg char(75)
declare @qresults varchar(100)
declare @dmpname char(40)


/*** create tmp table to hold the values from dbcc command ****/

CREATE TABLE  #tlogspace (
	tdbname        char (30) NOT NULL ,
	tlogsize       float NOT NULL ,
	tlogspaceused  float NOT NULL ,
	tstatus        tinyint NOT NULL
             )

insert into #tlogspace
 exec ('dbcc sqlperf(logspace)')

select @dmpdevice='_trans_dump'         /**** suffix name of the transaction log dump device *****/
select @name= ' '
select @dstat=' '

while @name is not null
begin


        select @name=(select min(tdbname)
	                from #tlogspace 
                        inner join logthres
                                on tdbname = dbname
                                where tlogspaceused > threshold
                                        and tdbname>@name 
			and tdbname not in('master','tempdb','msdb','pubs','model','NorthWind'))
		
        select @thresh = (select threshold from logthres    /*** Get the threshold value for the DB ***/
                         where dbname = @name)      
                         
        select @ckinit_YN = (select ckinit from logthres    /*** Check if set to init or noinit ****/
                             where dbname = @name) 
                              
print @thresh
	if @name is not null 
              begin  


--           set @qresults =(( 'select dbname,logsize,logspaceused from logspace where dbname = ' )+'"'+( rtrim(@name) )+'"')
	     set @logmsg =( 'Log is over ' +  @thresh + ' percent full. Dumping the log for database ' + @name)
             if @ckinit_YN = 'y'  
             set @dstat =('backup log '  + rtrim(@name)+  ' to ' +(rtrim(@name)+rtrim(@dmpdevice) +' with  init'))
             else 
             set @dstat =('backup log '  + rtrim(@name)+  ' to ' +(rtrim(@name)+rtrim(@dmpdevice) +' with  noinit'))
             exec (@dstat)                                                       /* Dump Transaction Logs */
             /* Append date and timestamp to the trans_dump file */

                  set @hdate = (convert(char(10),getdate(),110))
                  set @htime =  stuff(stuff((convert(char(10),getdate(),108)),3,1,'-'),6,1,'-')
                  set @ctime = @hdate + @htime            
                  set @dmpname =  (rtrim(@name)+rtrim(@dmpdevice) )      
                  set @xshell3 = ('ren y:\transdumps\' +rtrim(@dmpname)+ '.bak'+'   ' + (rtrim(rtrim(@dmpname) + @ctime)+'-old'))    
                print @xshell3 
               exec master..xp_cmdshell  @xshell3,no_output
 
             exec xp_logevent 50004,@logmsg,Informational /* send message to sever event log */
/*****  This has been commented out but if you want to use send mail  ***/
--           exec xp_sendmail @recipients = 'XXXX@company.com',
--           @message = 'Transaction log dumps',
--           @subject = 'Sql  Transaction Log Dumps',
--           @query = @qresults,  /* mail  query results to recipients */ 
--           @set_user = 'domain\sqlaccount',
--           @dbuse = 'master'
 	end 
	            
end
/*****   If the percentage of log space is greater than specfied parameter   *****/
/*****   let's move the data from the temp table to the perm. tab. so we can track it's usage *****/
   insert into master..logspace 
                          select distinct  tdbname,tlogsize,tlogspaceused,tstatus,getdate()   
                          from #tlogspace inner join logthres 
                          on tdbname = dbname
                          where tlogspaceused >threshold
                                     and tdbname not in('master','tempdb','msdb','pubs','model','NorthWind')

/*****   I would also like to track the size of tempdb - tempdb size will also be logged if gt 20% *****/
   insert into master..logspace 
                          select distinct  tdbname,tlogsize,tlogspaceused,tstatus,getdate()   
                          from #tlogspace 
                          where tlogspaceused > 20
                                     and tdbname ='tempdb'
/**** let clean up  drop temp table ****/
drop table #tlogspace
GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


