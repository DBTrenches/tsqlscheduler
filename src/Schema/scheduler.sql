if schema_id('scheduler') is null
begin
	exec sp_executesql N'create schema scheduler authorization dbo;';
end
go