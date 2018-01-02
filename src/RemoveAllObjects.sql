/*** TABLES ***/

/* If system versioning is on turn it off or the drop will fail */
if exists (
	select 1
	from sys.tables as t
	where t.temporal_type <> 0 
	and t.name = 'task'
	and t.schema_id = schema_id('scheduler')
)
begin
	alter table scheduler.task set (system_versioning = off);
end
go
drop table if exists scheduler.Task;
drop table if exists scheduler.TaskHistory;
drop table if exists scheduler.TaskExecution;
drop table if exists scheduler.ReplicaStatus;
go

/*** VIEWS ***/
declare @dropView nvarchar(max)=N'';

select @dropView+='drop view if exists scheduler.'+o.[name]+';'+char(10)
from sys.objects o 
where o.[type]=N'V'
    and o.[schema_id]=schema_id(N'scheduler');

exec sp_executesql @dropView;
go

/*** PROCEDURES ***/
declare @dropProc nvarchar(max)=N'';

select @dropProc+='drop proc if exists scheduler.'+o.[name]+';'+char(10)
from sys.objects o 
where o.[type]=N'P'
    and o.[schema_id]=schema_id(N'scheduler');

exec sp_executesql @dropProc;
go

/*** FUNCTIONS ***/
declare @dropFun nvarchar(max)=N'';

select @dropFun+='drop function if exists scheduler.'+o.[name]+';'+char(10)
from sys.objects o 
where o.[type] in (N'FN',N'IF',N'TF')
    and o.[schema_id]=schema_id(N'scheduler');

exec sp_executesql @dropFun;
go

/*** SCHEMA ***/
drop schema if exists scheduler;
go
