/*

Flexible searching on tables


In my company's web site there are search pages for allowing users to search info on one or more tables (or in my case a select with 10 joins). Often the requirements for these search pages change over time with users either requesting additional columns to search or remove columns that are no longer useful. 

The search page that the script is based on looks like this...

Date received |______|
Area |_______|
Source of budget |______|

[Submit]

I came up with the following stored proc to grab results from the source table w/c still allows me flexibility when it came to adding or removing searchable columns.

The script will work but it heavily depends on having an identity key on the source table and it is necessary to be mindful of the no. of columns used in the table variable so as not to downgrade performance. 

At first the delete statements will seem hard to understand then when you get the hang of it you'll appreciate the flexibility the script offers and then you're gonna send me $10,000 on my birthday. 
 
 
*/



CREATE PROCEDURE get_rows

@date_received      datetime, -- always supplied
@area_code 			varchar(50) = NULL, -- can be empty
@source_of_budget 	varchar(20) = NULL -- can be empty

AS

--//
DECLARE @result TABLE
(
int_row_id 			integer,
area_code 			varchar(50),
date_received 		datetime,
budget_source 		varchar(20)
)

--//
--//
INSERT
	@result
	(
	int_row_id,
	area_code,
	date_received,
	budget_source
	)
--//
SELECT 
	int_row_id, -- identity column
	area_code,
	date_received,
        budget_source
FROM 
	dbo.source_table
WHERE 
	( CONVERT(CHAR(10),date_received,101) > CONVERT(CHAR(10),@date_received,101) )

--//
IF @area_code IS NOT NULL
BEGIN
	--//
	DELETE

	FROM 
		@result

	FROM
		@result	t1
		
		LEFT JOIN 
			(
			SELECT 
				int_row_id
			FROM 
				@result
			WHERE ( area_code = @area_code )
			) t2

		ON t1.int_row_id = t2.int_row_id

	WHERE
		t2.int_row_id IS NULL		
	--//
END

--//
IF @source_of_budget IS NOT NULL
BEGIN
	--//
	IF @source_of_budget = 'Asia'
	BEGIN
		--//

		DELETE

		FROM 
			@result
	
		FROM
			@result	t1
			
			LEFT JOIN 
				(
				SELECT 
					int_row_id
				FROM 
					@result
				WHERE ( budget_source IN ('Philippines','Korea','Japan' ) )
				) t2
	
			ON t1.int_row_id = t2.int_row_id
	
		WHERE
			t2.int_row_id IS NULL	

		--//
	END

	--//
	--//
	ELSE
	--//
	--//

	BEGIN
		--//

		DELETE

		FROM 
			@result
	
		FROM
			@result	t1
			
			LEFT JOIN 
				(
				SELECT 
					int_row_id
				FROM 
					@result
				WHERE ( budget_source = @source_of_budget )
				) t2
	
			ON t1.int_row_id = t2.int_row_id
	
		WHERE
			t2.int_row_id IS NULL	

		--//
	END

END

--//
--//
-- final select
--//
--//
SELECT
	* -- whatever you want
	--//
FROM	
	dbo.source_table source
	--//
	INNER JOIN (SELECT DISTINCT int_row_id FROM @result) result
		ON source.int_row_id = result.int_row_id
	--//
ORDER BY
	--//
	source.int_row_id


RETURN





