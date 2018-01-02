
create or alter function scheduler.FrequencyTypeFromDesc ( 
    @frequencyTypeDesc varchar(6) 
)
returns tinyint
as
begin
    return 
        case @frequencyTypeDesc
            when 'Day'    then 1 
            when 'Hour'   then 2 
            when 'Minute' then 3 
            when 'Second' then 4 
        end;
end;
go


/* TESTING
select 
    [Type] = scheduler.FrequencyTypeFromDesc(ss.value), 
    [Desc] = ss.value
from string_split('Day,Hour,Minute,Second',',') ss
*/
