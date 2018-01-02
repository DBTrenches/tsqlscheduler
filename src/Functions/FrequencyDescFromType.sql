
create or alter function scheduler.FrequencyDescFromType ( 
    @frequencyType tinyint 
)
returns varchar(6)
as
begin
    return 
        case @frequencyType
            when 1 then 'Day'
            when 2 then 'Hour'
            when 3 then 'Minute'
            when 4 then 'Second'
        end;
end;
go

/* TESTING
select 
    [Type] = ss.value, 
    [Desc] = scheduler.FrequencyDescFromType(ss.value) 
from string_split('1,2,3,4',',') ss
*/
