-- 	List all user permissions of all Database objects
	sp_helprotect					  

-- 	List all user permissions of tblSalary
	sp_helprotect 'dbo.tblSalary'	  

-- 	List all user permissions of sp_Get_Salary
	sp_helprotect 'dbo.sp_Get_Salary' 

-- 	List all user permissions of sp_Get_Salary
	sp_helprotect 'dbo.sp_Get_Salary', 'emp_user' 

-- 	List all user permissions of sp_Get_Salary provided by dbo
	sp_helprotect 'dbo.sp_Get_Salary', null,'dbo'

-- 	List all Object type user permissions
	sp_helprotect null, null,null,'o'

-- 	List all statement type user permissions 
	sp_helprotect null, null,null,'s'