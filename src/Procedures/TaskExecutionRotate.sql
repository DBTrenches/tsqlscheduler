create or alter  procedure scheduler.TaskExecutionRotate
    @monthsToKeep INT = 3
as
begin
	  set xact_abort on;
	  set nocount on;

    declare @now datetime2 (3) = getutcdate()
                  ,@months int=12

    if (@monthsToKeep > @months or @monthsToKeep < 0) 
    begin
        ;throw 50000, 'Invalid parameter value. Month to keep must be between 0 - 12', 1;
    end
 
    declare @currentMonth tinyint = month(@now)

    /* Start from the next partition up from current and move forward */
    declare @p int = @currentMonth
    declare @i int = 1

    while @i <= @months - @monthsToKeep
    begin 
        declare @sql nvarchar(1000) = 'Truncate table scheduler.TaskExecution with (partitions (<p>));'

        set @i += 1;
        set @p = (@p + 1) % @months

        if @p=0 set @p=@months

        set @sql = replace(@sql, '<p>', cast(@p AS nvarchar(2))) 

        exec sp_executesql @sql

    end
end
go
