/*
spFindTableInfo

spFindTableInfo is a great proc for finding info about your database.  
It will accept parameters like tablename, fieldname, size, datatype.  So you can run it with no params, 
and it'll report every table, every field in those tables, and the size, datatype and whether its nullable or not.  
You can filter it by Table name and get all fields of that table.  

You can search for particular fields in a table, or data types in a field, or table.... well you get the idea.  
I used this to familiarize myself with our data structure.  A developer would ask about a field, and we'd guess the 
name and search for it, until we found the appropriate one.  Its just a great tool.  
I suggest running it in master and naming it sp_FindTableInfo so that it can be accessed in each and every db you work with.
it will work on sql server 2000, not sure about 7 or below. 

*/

/**********************************************************
  spFindTableInfo
**********************************************************/

exec spUpdateSPVersion 'spFindTableInfo', 1
go


if
  exists
  (
    select * from SysObjects
      where ID = Object_ID('spFindTableInfo')
        and ObjectProperty(ID, 'IsProcedure') = 1
  )
begin
  drop procedure spFindTableInfo
end
go

create procedure spFindTableInfo
  @TableName varchar(50) = null,
  @FieldName varchar(50) = null,
  @FieldType varchar(50) = null,
  @Size int = null,
  @No char(1) = 'F',
  @Exact char(1) = 'F'
as
  set NoCount on

  declare 
    @result int,
    @Value varchar(150)

  --try

    if @Exact = 'T' 
    begin
      if not @TableName is null
        set @TableName = @TableName
      else
        set @TableName = '%'

      if not @FieldName is null
        set @FieldName = @FieldName
      else
        set @FieldName = '%'

      if not @FieldType is null
        set @FieldType = @FieldType
      else
        set @FieldType = '%'
    end
    else
    begin
      if @No = 'F' 
      begin
        if not @TableName is null
          set @TableName = '%'+@TableName+'%'
        else
          set @TableName = '%'
  
        if not @FieldName is null
          set @FieldName = '%'+@FieldName+'%'
        else
          set @FieldName = '%'

        if not @FieldType is null
          set @FieldType = '%'+@FieldType+'%'
        else
          set @FieldType = '%'
      end
      else 
      begin
        if not @TableName is null
          set @TableName = @TableName+'%'
        else
          set @TableName = '%'

        if not @FieldName is null
          set @FieldName = @FieldName+'%'
        else
          set @FieldName = '%'

        if not @FieldType is null
          set @FieldType = @FieldType+'%'
        else
          set @FieldType = '%'

--      set @TableName = @TableName+'%'
--      set @FieldName = @FieldName+'%'
--      set @FieldType = @FieldType+'%'
      end
    end


    set @Value = 'Looking for Fields ( ' + IsNull(@FieldName,'') + ' ) ' + 
                 'in Tables ( ' + IsNull(@TableName,'') + ' ) ' + 
                 'with Types of ( ' + IsNull(@FieldType,'') + ' ) ' + 
                 'and Size of ( ' + convert(varchar,IsNull(@Size,''))  + ' ) '
    print @Value

    select 
        convert(varchar(30),O.Name) as ObjectName, 
        convert(varchar(30),L.Name) as ColumnName,
        T.name as [Type],
        L.Prec [Size],
        case 
          when l.IsNullable = 1 then 'Null'
          when l.IsNullable = 0 then 'Not Null'
        end as [Nullable]
      from 
        SysObjects O 
--        SysConstraints C on C.ID = O.ID
        left outer join SysColumns L on L.ID = O.ID 
        left outer join SysTypes T on T.usertype = L.usertype --and T.Type = L.Type 
      where ObjectProperty(O.ID, 'IsUserTable') = 1
        and O.Name like IsNull(@TableName, O.Name)
        and T.Name like IsNull(@FieldType, T.Name)
        and L.Name like @FieldName
--        and IsNull(@FieldType, '') = Case When @FieldType Is Null Then '' Else T.Name End
        and IsNull(@Size, '') = Case When @Size Is Null Then '' Else L.Prec End
--        and t.name <> 'datetime'
      order by O.Name, L.ColID


  --finally
    SuccessProc:
    return 0  /* success */

  --except
    ErrorProc:
    return 1 /* failure */
  --end
go

grant execute on spFindTableInfo to Public
go

