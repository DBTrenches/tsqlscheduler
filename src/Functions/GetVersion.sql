create or alter function scheduler.GetVersion()
returns table
as
return (select 1.1 as Version);