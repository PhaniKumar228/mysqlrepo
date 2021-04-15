/*

Where_Am_I

This SP takes a string to be searched as input parameter, loops through all tables, views, Sp-s in the database and
returns the name of the object it was found and number of occurences 

*/

CREATE  procedure uspWhereAmI
@cDB varchar(255), @cString varchar(1000) AS
	set nocount on
	Select @cString = 'select substring( o.name, 1, 35 ) as Object,
count(*) as Occurences, ' +
		'case ' +
		' when o.xtype = ''D'' then ''Default'' ' +
		' when o.xtype = ''F'' then ''Foreign Key'' ' +
		' when o.xtype = ''P'' then ''Stored Procedure'' ' +
		' when o.xtype = ''PK'' then ''Primary Key'' ' +
		' when o.xtype = ''S'' then ''System Table'' ' +
		' when o.xtype = ''TR'' then ''Trigger'' ' +
		' when o.xtype = ''U'' then ''User Table'' ' +
		' when o.xtype = ''V'' then ''View'' ' +
		'end as Type ' +
		'from ' + @cDB + '.dbo.syscomments c join ' + @cDB + '.dbo.sysobjects o on c.id = o.id ' +
		'where patindex( ''%'  + @cString + '%'', c.text ) > 0 ' +
		'group by o.name, o.xtype ' +
		'order by o.xtype, o.name'

	Execute( @cString )
Return

