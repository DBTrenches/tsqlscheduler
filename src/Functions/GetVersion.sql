create or alter function scheduler.GetVersion()
returns table
as
return (select 1.4 as [Version]);