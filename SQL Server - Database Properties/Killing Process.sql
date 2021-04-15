/*
KILLING SESSIONS
---------------------

One of my procedure is taking long time to complete. I want to kill my job and
re-run the procedure after incorporating HINTS.
From the v$session, I found that my session is active.
*/

select username, osuser,sid,serial#,status from v$session where sid=57;
SYS        oracle             57       6597 ACTIVE
--I killed my session with the command: 
alter system kill session '57,6597';
alter system kill session '57,6597'
*
ERROR at line 1:
ORA-00031: session marked for kill

/*
I checked the status of my session, and it says 'KILLED', but still the procedure is running.
*/
select username, osuser,sid,serial#,status from v$session where sid=57;
SYS        oracle             57       6597 KILLED
1 row selected.
/*
I want to kill the job at the os level.
*/

select c.spid , b.osuser , b.username , b.sid , b.serial# ,
a.sql_text
  from v$sqltext a, v$session b, v$process c
   where a.address    = b.sql_address
   and b.paddr      = c.addr
   and a.hash_value = b.sql_hash_value
   and b.sid = 57;


/*
I found the process id of my job and executed the kill command at os level.
*/

kill -9 159

/*
Then I wondered, why should I go through this hasle to kill my procedure.
Is there a simple way to stop my long running procedure?

I modified my procedural logic:

I created a flag_jp table with one column flg that hold either 'YES' or 'NO'.
At regular intervals, during the run of my procedure, after committing a certain
number of rows, I check the flg value from my flag_jp table.
If the flg value is 'NO' then I simply exit out of the execution of my procedure.
*/

set serverout on size 1000000


declare
v_num   number(10):=0;
v_flg   char(3);
/***********************************
create table scott.flag_jp(flg char(3));

insert into scott.flag_jp values('YES');
commit;

To exit out of the procedure run the update and commit:
update scott.flag_jp set flg='NO';
commit;
************************************/
begin
for c1 in (select rowid, .., .., from ..
) loop

begin

insert into    .. values (          
..
..
.. );


delete from .. where rowid = c1.rowid;

v_num:=v_num+1;

if (v_num >= 1000) then
commit;
v_num:=0;

select upper(flg)  into v_flg from scott.flag_jp;

if (v_flg = 'NO')  then
dbms_output.put_line('Exiting from the loop as the FLAG is set to '||v_flg);
exit;
end if;

end if;

exception
when others then
dbms_output.put_line(c1.rowid||' '||sqlerrm);
end;
end loop;
end;

/*
After every 1000 rows processed, my procedure checks the flg column value 
from the flag_jp table. If the flg value is set to 'NO', then my procedure
stops execution.

Whenever I want to stop my procedure, I just run an update statement on 
my FLAG_JP table followed by a commit.

update scott.flag_jp set flg='NO';
commit;

Remember, the procedure stops after the current 1000 rows are processed and committed.
You can change the number of rows processed, in the counter, for change of control in procedure.

You can incorporate a while loop and update the flg value during every run, if you like.


*/
 #!/usr/bin/ksh

#This script checks for the existence of stop_file in the current directory.
#As long as the file is not found. The script runs.
#When you touch a file with name stop_file, the script run stops
#touch stop_file

cd /home/oracle/jp

while [ true ]
do

date
ls -ltr

cat  fullexport.log|grep ORA-
echo "To kill this while loop run the command touch /home/oracle/jp/stop_file"

if [ -f stop_file ]; then
exit
fi
sleep 300
done
exit

/*
To stop this shell script run the command
touch /home/oracle/jp/stop_file
No need to find my script's pid
and execute a kill -9 <pid> command.
*/

--Happy scripting.


--References: http://www.oracle-base.com/articles/misc/KillingOracleSessions.php
