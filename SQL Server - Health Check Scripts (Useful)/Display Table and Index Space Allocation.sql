/*

Display Table and Index Space Allocation

This script adds to others posted on this site by formatting and displaying text information about table and index space allocation. 

*/

Set Nocount On

Create Table #Result (
    TableRows Int,
    DataSpace Int,
    IndexSpace Int)

Declare gettable 
    Insensitive Cursor For 
    Select 
        Name 
    From sysobjects
    Where type = 'U'
    Order By 
        Name
    For Read Only 
--~~~~~~~~~
OPEN gettable 
--~~~~~~~~~
DECLARE 
    @TBName varchar(50), 
    @MSG varchar(255),  
    @sqlstr varchar(254), 
    @TableRows Int,
    @TableRowsText VarChar(20),
    @DataSpace Int,
    @DataSpaceText VarChar(50),
    @DataSpaceTotal BigInt,
    @IndexSpace Int,
    @IndexSpaceText VarChar(50),
    @IndexSpaceTotal BigInt,
    @SpaceUnit VarChar(20)
--~~~~~~~~~
FETCH NEXT FROM gettable INTO @TBName 
--~~~~~~~~~~
Set @DataSpaceTotal = 0
Set @IndexSpaceTotal = 0
--~~~~~~~~~~
WHILE (@@FETCH_STATUS = 0) 
    BEGIN
    SELECT @sqlstr = 'sp_MStablespace '+ @TBName
    --    
    Insert Into #Result
    EXECUTE (@sqlstr) 
    --
    Select 
        @TableRows = TableRows,
        @DataSpace = DataSpace,
        @IndexSpace = IndexSpace
    From #Result
    --
    Truncate Table #Result    
    --
--     Print @DataSpace
--     Print @IndexSpace
    Set @DataSpaceTotal = @DataSpaceTotal + Coalesce(@DataSpace,0)
    Set @IndexSpaceTotal = @IndexSpaceTotal + Coalesce(@IndexSpace,0)
    --~~~~~~~~~~~~
    -- Format Row Count
    If Len(@TableRows) <= 3 -- No Comma's
        Set @TableRowsText = Convert(Varchar(20), @TableRows)        
    Else If Len(@TableRows) <= 6 -- One Comma
        Begin
        Set @TableRowsText = Right(Convert(Varchar(20), @TableRows),3)        
        Set @TableRowsText = ',' + @TableRowsText
        Set @TableRowsText = Left(Convert(Varchar(20), @TableRows),Len(@TableRows)-3) + @TableRowsText        
        End    
    Else -- Two Comma's
        Begin
        Set @TableRowsText = Right(Convert(Varchar(20), @TableRows),3)        
        Set @TableRowsText = ',' + @TableRowsText
        Set @TableRowsText = Right(Left(Convert(Varchar(20), @TableRows),Len(@TableRows)-3),3) + @TableRowsText                
        Set @TableRowsText = ',' + @TableRowsText
        Set @TableRowsText = Left(Convert(Varchar(20), @TableRows),Len(@TableRows)-6)  + @TableRowsText               
        End
    --~~~~~~~~~~~~
    -- Format DataSpace
    If @DataSpace < 1024
        Set @SpaceUnit = ' K'
    Else
        Begin
        Set @SpaceUnit = ' Meg'
        Set @DataSpace = @DataSpace / 1024
        End
    If Len(@DataSpace) <= 3 -- No Comma's
        Set @DataSpaceText = Convert(Varchar(20), @DataSpace)        
    Else If Len(@DataSpace) <= 6 -- One Comma
        Begin
        Set @DataSpaceText = Right(Convert(Varchar(20), @DataSpace),3)        
        Set @DataSpaceText = ',' + @DataSpaceText
        Set @DataSpaceText = Left(Convert(Varchar(20), @DataSpace),Len(@DataSpace)-3) + @DataSpaceText       
        End    
    Else -- Two Comma's
        Begin
        Set @DataSpaceText = Right(Convert(Varchar(20), @DataSpace),3)        
        Set @DataSpaceText = ',' + @DataSpaceText
        Set @DataSpaceText = Right(Left(Convert(Varchar(20), @DataSpace),Len(@DataSpace)-3),3) + @DataSpaceText       
        Set @DataSpaceText = ',' + @DataSpaceText
        Set @DataSpaceText = Left(Convert(Varchar(20), @DataSpace),Len(@DataSpace)-6) + @DataSpaceText              
        End
    Set @DataSpaceText = @DataSpaceText + @SpaceUnit 
    --~~~~~~~~~~~~
    -- Format IndexSpace
    If @IndexSpace < 1024
        Set @SpaceUnit = ' K'
    Else
        Begin
        Set @SpaceUnit = ' Meg'
        Set @IndexSpace = @IndexSpace / 1024
        End
    If Len(@IndexSpace) <= 3 -- No Comma's
        Set @IndexSpaceText = Convert(Varchar(20), @IndexSpace)        
    Else If Len(@IndexSpace) <= 6 -- One Comma
        Begin
        Set @IndexSpaceText = Right(Convert(Varchar(20), @IndexSpace),3)        
        Set @IndexSpaceText = ',' + @IndexSpaceText
        Set @IndexSpaceText = Left(Convert(Varchar(20), @IndexSpace),Len(@IndexSpace)-3) + @IndexSpaceText       
        End    
    Else -- Two Comma's
        Begin
        Set @IndexSpaceText = Right(Convert(Varchar(20), @IndexSpace),3)        
        Set @IndexSpaceText = ',' + @IndexSpaceText
        Set @IndexSpaceText = Right(Left(Convert(Varchar(20), @IndexSpace),Len(@IndexSpace)-3),3) + @IndexSpaceText              
        Set @IndexSpaceText = ',' + @IndexSpaceText
        Set @IndexSpaceText = Left(Convert(Varchar(20), @IndexSpace),Len(@IndexSpace)-6) + @IndexSpaceText               
        End
    Set @IndexSpaceText = @IndexSpaceText + @SpaceUnit 
    --~~~~~~~~~~~~
--    Print '~~~~~~~~~~~~~~~~~~~~~~~~~'
    Print '  ' 
    Print 'Table: ' + @TBName 
    Print ' - Rows: ' +  @TableRowsText
    Print ' - DataSpace: ' + @DataSpaceText     
    Print ' - IndexSpace: ' + @IndexSpaceText     
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~    
    FETCH NEXT FROM gettable   INTO @TBName 
    END  
--~~~~~~~~~~~~~~~~
-- Print @DataSpaceTotal
-- Print @IndexSpaceTotal
--~~~~~~~~~~~~
-- Format DataSpace
If @DataSpaceTotal < 1024
    Set @SpaceUnit = ' K'
Else
    Begin
    Set @SpaceUnit = ' Meg'
    Set @DataSpaceTotal = @DataSpaceTotal / 1024
    End
If Len(@DataSpaceTotal) <= 3 -- No Comma's
    Set @DataSpaceText = Convert(Varchar(20), @DataSpaceTotal)        
Else If Len(@DataSpaceTotal) <= 6 -- One Comma
    Begin
    Set @DataSpaceText = Right(Convert(Varchar(20), @DataSpaceTotal),3)         
    Set @DataSpaceText = ',' + @DataSpaceText
    Set @DataSpaceText = Left(Convert(Varchar(20), @DataSpaceTotal),Len(@DataSpaceTotal)-3) + @DataSpaceText        
    End    
Else -- Two Comma's
    Begin
    Set @DataSpaceText = Right(Convert(Varchar(20), @DataSpaceTotal),3)        
    Set @DataSpaceText = ',' + @DataSpaceText
    Set @DataSpaceText = Right(Left(Convert(Varchar(20), @DataSpaceTotal),Len(@DataSpaceTotal)-3),3) + @DataSpaceText        
    Set @DataSpaceText = ',' + @DataSpaceText
    Set @DataSpaceText = Left(Convert(Varchar(20), @DataSpaceTotal),Len(@DataSpaceTotal)-6) + @DataSpaceText        
    End
Set @DataSpaceText = @DataSpaceText + @SpaceUnit 
--~~~~~~~~~~~~
-- Format IndexSpace
If @IndexSpaceTotal < 1024
    Set @SpaceUnit = ' K'
Else
    Begin
    Set @SpaceUnit = ' Meg'
    Set @IndexSpaceTotal = @IndexSpaceTotal / 1024
    End
If Len(@IndexSpaceTotal) <= 3 -- No Comma's
    Set @IndexSpaceText = Convert(Varchar(20), @IndexSpaceTotal)        
Else If Len(@IndexSpaceTotal) <= 6 -- One Comma
    Begin
    Set @IndexSpaceText = Right(Convert(Varchar(20), @IndexSpaceTotal),3)        
    Set @IndexSpaceText = ',' + @IndexSpaceText
    Set @IndexSpaceText = Left(Convert(Varchar(20), @IndexSpaceTotal),Len(@IndexSpaceTotal)-3) + @IndexSpaceText    
    End    
Else -- Two Comma's
    Begin
    Set @IndexSpaceText = Right(Convert(Varchar(20), @IndexSpaceTotal),3)        
    Set @IndexSpaceText = ',' + @IndexSpaceText
    Set @IndexSpaceText = Right(Left(Convert(Varchar(20), @IndexSpaceTotal),Len(@IndexSpaceTotal)-3),3) + @IndexSpaceText        
    Set @IndexSpaceText = ',' + @IndexSpaceText
    Set @IndexSpaceText = Left(Convert(Varchar(20), @IndexSpaceTotal),Len(@IndexSpaceTotal)-6) + @IndexSpaceText        
    End
Set @IndexSpaceText = @IndexSpaceText + @SpaceUnit 
Print '~~~~~~~~~~~~~~~~~~~~~~~~~'
Print ' -- Total DataSpace: ' + @DataSpaceText     
Print ' -- Total IndexSpace: ' + @IndexSpaceText     
--Print '~~~~~~~~~~~~~~~~~~~~~~~~~'
--~~~~~~~~~~
CLOSE gettable 
DEALLOCATE gettable 
Drop Table #Result
