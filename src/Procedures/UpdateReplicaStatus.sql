create or alter procedure scheduler.UpdateReplicaStatus
    @availabilityGroup nvarchar(128)
as
begin
    merge scheduler.ReplicaStatus as rs
    using (
        select		ar.replica_server_name, ars.role_desc
        from		sys.dm_hadr_availability_replica_states ars
        inner join	sys.availability_groups ag
        on			ars.group_id = ag.group_id
        join		sys.availability_replicas as ar
        on			ar.replica_id = ars.replica_id
        where		ag.name = @availabilityGroup
    ) as src
    on src.replica_server_name = rs.HostName
    and	src.role_desc = @availabilityGroup
    when matched then 
        update
            set rs.AvailabilityGroupRole = src.role_desc
    when not matched then
        insert ( AvailabilityGroup, HostName, AvailabilityGroupRole )
        values ( @availabilityGroup, src.replica_server_name, src.role_desc )
    when not matched by source
        then delete; 
end