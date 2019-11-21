create or alter function scheduler.GetVersion()
returns table
as
return (select 2.0 as [Version]);