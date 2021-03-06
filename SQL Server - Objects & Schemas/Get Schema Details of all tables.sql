--> first build a sub function
create function infFKfrom(@tbID int, @colID smallint)
returns varchar(2000)
as 

begin
   declare @r varchar(2000), @a varchar(200)
   select @r='', @a=''

   DECLARE cs CURSOR FOR

      select FKfrom=convert(varchar(200),object_name(rkeyid)+'.'+r.[name])
      from sysforeignkeys c
      join syscolumns f on c.fkeyid=f.[id] and c.fkey=f.colID
      join syscolumns r on c.rkeyid=r.[id] and c.rkey=r.colID
      where fkeyID=@tbID and fkey=@colID
      order by keyNo

   OPEN cs
   FETCH NEXT FROM cs INTO @a
   WHILE @@FETCH_STATUS = 0 BEGIN
      select @r=@r+case when len(@r)>0 then ', ' else '' end+@a
      FETCH NEXT FROM cs INTO @a
   END
   CLOSE cs
   DEALLOCATE cs

   return(@r)
end
GO

--> then build a main one
create function infTB (@tbLIKE varchar(1000))
returns @inf table
   (
   owner varchar(100) --> schema: table owner
   , tbName varchar(100)
   , colName varchar(100)
   , shortType varchar(50) --> column short type e.g. varchar(10) or smalldatetime
   , type varchar(50) --> column type
   , [size] int --> length of column
   , isPK char(1) --> is this column a primary key
   , isID char(1) --> is this column is an identity column
   , isNullable char(1) --> can this column be null
   , defaultValue varchar(100) --> this column's default value
   , colDesc varchar(2000) --> คำอธิบายรายละเอียดของคอลัมน์ (ถ้ามี)
   , pkDesc varchar(2000) --> ชื่อ primary key
   , fkDesc varchar(2000) --> ชื่อ ตาราง.คอลัมน์ ที่มี relationship(s) ด้วย
   , tbID int --> id of table
   , colID int --> column ID
   )
as 
-- developed by Boonchoo Chatsrinopkun
begin

   --> initial data
   insert into @inf(owner,tbName,colName,tbID,colID,isPK,pkDesc,shortType,type,[size],isID,isNullable,colDesc,defaultValue,fkDesc)
   select 
        owner=user_name(t.uid), tb=object_name(t.[id]), col=c.[name]
      , t.[id], c.colID, isPK=case when pk.colID is null then '' else 'Y' end
      , pkDesc=case when pk.pkDesc is null then '' else pkDesc end
      , shortType=case when patindex('%char%',ty.[name])>0 then ty.[name]+'('+convert(varchar(5),c.length)+')' else ty.[name] end
      , type=ty.[name]
      , [size]=c.length
      , isID=case when c.status&128=0 then '' else 'Y' end
      , isNullable=case when c.isnullable=0 then '' else 'Y' end
      , colDesc=isnull(convert(varchar(2000),rem.value),'')
      , defaultValue=case 
            when def.[text] is null then '' 
            when def.[text] like 'create default %' then substring(convert(varchar(2000),def.[text]),patindex('% as %',convert(varchar(2000),def.[text]))+4,len(convert(varchar(2000),def.[text])))
            else substring(convert(varchar(2000),def.[text]),2,len(convert(varchar(2000),def.[text]))-2) end
      , fkDesc=dbo.infFKfrom(t.[id],c.colID)
   from dbo.sysobjects t
   join dbo.syscolumns c on t.[id]=c.[id]
   join dbo.systypes ty on c.xusertype=ty.xusertype
   left join 
        (--PK data
         select tbID=o.parent_obj, pkDesc=i.[name], k.colID
         from sysobjects o
         join sysindexes i on o.parent_obj=i.[id] and o.[name]=i.[name]
         join sysindexkeys k on i.[id]=k.[id] and i.indid=k.indid
         where objectproperty(o.[id],'isprimarykey')=1 and objectproperty(o.[id],'isMSShipped')=0
         )pk on t.[id]=pk.tbID and c.colID=pk.colID
   left join sysproperties rem on t.[id]=rem.[id] and c.colID=rem.smallid
   left join syscomments def on c.cdefault=def.[id] and def.colID=1

   where objectproperty(t.id,'isTable')=1 
     and objectproperty(t.id,'isMSShipped')=0
     and object_name(t.[id]) like @tbLIKE
     and isnull(rem.type,4)=4

   return
end
GO

select * from infTB('%') --> to get all info of user tables
select * from infTB('%some%table%') --> to get some
