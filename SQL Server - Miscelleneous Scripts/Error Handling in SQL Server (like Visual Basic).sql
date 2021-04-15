/*
Error Handling in SQL Server (like Visual Basic)

Using this technique you can do error handling in SQL Server using the same way you do in Visual Basic (most of it). 
Just put your SQL Statement in exec('SQL Command') and make use of @@Error to get error information and put your error handling code in If block.

*/

/*
Using this, you can avoid existing from the procedure and make use of proper error handling

This is same like VB, so you put log information in other tables

Just put your SQL Statement in exec('SQL Command') and make use of @@Error to get error information and put your error handling code in If block.

*/


Print '
Code Starts
Just run the following select statement without EXEC and check the difference
So, here u will see that if u execute a statement without exec block, it will terminate if some errors occurs without executing the next statement. 

But in case of exec block, it will allow executing the next statement. 


'

exec('select top 10 * from abc --some other sql statement')
if @@Error<>0
BEGIN
	--Here this will check for error handling code. So u can replace this with ur own code
	print char(13) + 'Some error occurs. Replace this statement with your error handling code without exiting the program (Like VB)'
END
else
BEGIN
	--If executed successfully
	print 'Executed Successfully'
END

print CHAR(13) + 'END OF FIRST STATEMENT' + CHAR(13) + CHAR(13)

select top 10 * from abc
if @@Error<>0
BEGIN
	print char(13) + 'Some error occurs. Replace this statement with your error handling code without exiting the program (Like VB)'
END
else
BEGIN
	print 'Executed Successfully'
END


