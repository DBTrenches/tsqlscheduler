create table scheduler.ReplicaStatus
(
    AvailabilityGroup nvarchar(128) not null
    ,HostName nvarchar(128) not null
    ,AvailabilityGroupRole nvarchar(128) not null
    ,constraint PK_ReplicaStatus primary key clustered (AvailabilityGroup, HostName)
);