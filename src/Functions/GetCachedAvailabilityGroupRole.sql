create or alter function scheduler.GetCachedAvailabilityGroupRole
(
	@availabilityGroupName nvarchar(128)
)
returns nvarchar(60)
as
begin
	declare @role nvarchar(60);

	select 	@role = rs.AvailabilityGroupRole
	from 	scheduler.ReplicaStatus as rs
	where	rs.AvailabilityGroup = @availabilityGroupName
	and		rs.HostName = host_name();

	return coalesce(@role, N'');
end
go