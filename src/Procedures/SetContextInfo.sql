create or alter procedure scheduler.SetContextInfo
    @instanceIdentifier uniqueidentifier
    ,@taskId int
    ,@executionId int
as
begin
    declare @descriptor varchar(128) = 
	    '{ "i":"' + cast(@instanceId as varchar(36)) 
	    + '","t":' + cast(@taskId as varchar(12)) 
	    + ',"e":' + cast(@executionId as varchar(12)) 
	    + '}';

    declare @binaryPayload varbinary(128) = cast(@descriptor as varbinary(128));
    set context_info @binarypayload;
end