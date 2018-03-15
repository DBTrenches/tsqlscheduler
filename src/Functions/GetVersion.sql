create or alter function scheduler.GetVersion()
returns table
as
return (select 1.6 as [Version]);
