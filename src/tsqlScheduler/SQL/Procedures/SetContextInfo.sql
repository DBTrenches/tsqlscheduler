create or alter procedure scheduler.SetContextInfo
    @instanceIdentifier uniqueidentifier
    ,@taskUid uniqueidentifier
    ,@executionId int
as
begin
    declare @descriptor varchar(128) = 
	    '{ "i":"' + cast(@instanceIdentifier as varchar(36)) 
	    + '","t":' + cast(@taskUid as varchar(36)) 
	    + ',"e":' + cast(@executionId as varchar(12)) 
	    + '}';

    declare @binaryPayload varbinary(128) = cast(@descriptor as varbinary(128));
    set context_info @binarypayload;
end