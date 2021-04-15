/*
Get the entire directory structure in T-SQL

there are 2 extended STORED PROCEDURES 
xp_dirtree will get the directory name and nesting level
from a given parameter root directory 

xp_subdirs will get the directories list in the first sub 
level from a given parameter root directory 

*/

EXEC master..xp_dirtree 'c:\'
EXEC master..xp_subdirs 'D:\'
