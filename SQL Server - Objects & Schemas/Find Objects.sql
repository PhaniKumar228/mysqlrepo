CREATE Procedure sp_existeem
	@Objeto				char(255) = NULL,
	@StoreProcedure		BIT = 1,
	@View				BIT = 1,
	@Tabela				BIT = 1,
	@Trigger			BIT = 1,
	@Funcao				BIT = 1,
	@Outros				BIT = 1
	
As

IF ISNULL(@Objeto, '') = ''
BEGIN
	SET NOCOUNT ON
	PRINT	'DECLARE @Obj VARCHAR(255)' + CHAR(10) +
		'DECLARE @STR BIT, @VIEW BIT, @TAB BIT, @TRG BIT, @FUNC BIT, @OUT BIT' + CHAR(10) +
		'SET @Obj = ''Objeto''' + CHAR(10) +
		'SELECT @STR = 1, @VIEW = 1, @TAB = 1, @TRG = 1, @FUNC = 1, @OUT = 1' + CHAR(10) + CHAR(10) +
		'Exec sp_ExisteEm @Obj, @STR, @VIEW, @TAB, @TRG, @FUNC, @OUT'

	SET NOCOUNT OFF
	RETURN
END

Declare @UltID  int

Declare @TipEst	Char(20)
Declare @NomEst	Char(255)

Declare @Segue	Char(1)

Declare @ID	int
Declare @ColID	smallint
Declare @Text	varchar(8000)

Declare @Prim	Bit
Declare @AuxT	char(255)

Declare @Nada	int

CREATE TABLE #Auxiliar (
	Estrutura	varchar(510),
	ID		int
)

SET NOCOUNT ON

Select 	Case
		WHEN (sysobjects.xtype = 'P')  THEN 'Stored Procedure'
		WHEN (sysobjects.xtype = 'V')  THEN 'View'
		WHEN (sysobjects.xType = 'TR') THEN 'Trigger'
		WHEN (sysobjects.xType = 'FN') THEN 'Função'
		WHEN (sysobjects.xType = 'U')  THEN 'Tabela'
		ELSE 'Outros'
       	END TipoEstrutura,
	sysobjects.Name Nome
Into #Estrutura
From sysobjects (nolock)
Inner join syscolumns (nolock)
On sysobjects.ID = syscolumns.ID
Where (syscolumns.name like '%' + RTRIM(@Objeto) + '%' OR sysobjects.name like '%' + RTRIM(@Objeto) + '%') And
	((@StoreProcedure = 1 And sysobjects.xtype = 'P') OR (@View = 1 And sysobjects.xtype = 'V') OR
	 (@Tabela = 1 And sysobjects.xtype = 'U') OR (@Trigger = 1 And sysobjects.xtype = 'TR') OR
	 (@Funcao = 1 And sysobjects.xtype = 'FN') OR (@Outros = 1 And sysobjects.xtype Not In ('P', 'V', 'U', 'TR', 'FN')))

Insert Into #Estrutura
	(TipoEstrutura, Nome)
Select 	Case
		WHEN (sysobjects.xtype = 'P')  THEN 'Stored Procedure'
		WHEN (sysobjects.xtype = 'V')  THEN 'View'
		WHEN (sysobjects.xType = 'TR') THEN 'Trigger'
		WHEN (sysobjects.xType = 'FN') THEN 'Função'
		ELSE 'Outros'
       	END TipoEstrutura,
	sysobjects.Name Nome
From syscomments (nolock)
Inner Join sysobjects (nolock)
On sysobjects.ID = syscomments.ID
Where syscomments.text like '%' + RTRIM(@Objeto) + '%' And
	(sysobjects.Name Not In (Select Nome From #Estrutura)) And
	((@StoreProcedure = 1 And sysobjects.xtype = 'P') OR (@View = 1 And sysobjects.xtype = 'V') OR
	 (@Tabela = 1 And sysobjects.xtype = 'U') OR (@Trigger = 1 And sysobjects.xtype = 'TR') OR
	 (@Funcao = 1 And sysobjects.xtype = 'FN') OR (@Outros = 1 And sysobjects.xtype Not In ('P', 'V', 'U', 'TR', 'FN')))

Declare C_ListaID Cursor For
	Select ID, Count(ID)
	From sysobjects (nolock)
	Where (Name Not In (Select Nome From #Estrutura)) And
	((@StoreProcedure = 1 And sysobjects.xtype = 'P') OR (@View = 1 And sysobjects.xtype = 'V') OR
	 (@Tabela = 1 And sysobjects.xtype = 'U') OR (@Trigger = 1 And sysobjects.xtype = 'TR') OR
	 (@Funcao = 1 And sysobjects.xtype = 'FN') OR (@Outros = 1 And sysobjects.xtype Not In ('P', 'V', 'U', 'TR', 'FN')))
	Group By ID
	Having Count(ID) > 1

Open C_ListaID
FETCH NEXT FROM C_ListaID INTO @ID, @Nada
WHILE @@Fetch_Status = 0
BEGIN
	SET @Prim = 1
	Declare C_Dados Cursor For
		Select ColID, Text
		From syscomments
		Where ID = @ID
		Order By ColID
	Open C_Dados
	FETCH NEXT FROM C_Dados INTO @ColID, @Text
	WHILE @@Fetch_Status = 0
	BEGIN
		IF @Prim = 0
			Insert Into #Auxiliar VALUES (@AuxT + LEFT(@Text,255), @ID)
		ELSE
			SET @Prim = 1
		IF LEN(@Text) = 8000
			SET @AuxT = RIGHT(@Text,255)

		FETCH NEXT FROM C_Dados INTO @ColID, @Text
	END
	
	Close C_Dados
	DeAllocate C_Dados

	FETCH NEXT FROM C_ListaID INTO @ID
END	

Close C_ListaID
DeAllocate C_ListaID

Insert Into #Estrutura 
	Select Case
			WHEN (sysobjects.xtype = 'P')  THEN 'Stored Procedure'
			WHEN (sysobjects.xtype = 'V')  THEN 'View'
			WHEN (sysobjects.xType = 'TR') THEN 'Trigger'
			WHEN (sysobjects.xType = 'FN') THEN 'Função'
			WHEN (sysobjects.xType = 'U')  THEN 'Tabela'
			ELSE 'Outros'
		END TipoEstrutura,
		sysobjects.Name Nome
	From sysobjects (nolock)
	Inner Join #Auxiliar
	On sysobjects.ID = #Auxiliar.ID
	Where #Auxiliar.Estrutura Like '%' + RTRIM(@Objeto) + '%'

Drop Table #Auxiliar

SET NOCOUNT OFF

Select DISTINCT * From #Estrutura (nolock)

