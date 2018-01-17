
if exists ( select * 
            from sys.check_constraints 
            where [name]='chk_Task_JobNamePrefacedByLocalDB'
                or (
                        parent_object_id=object_id(N'scheduler.Task',N'U') 
                    and parent_column_id=try_convert(int,columnproperty(object_id(N'scheduler.Task',N'U'),N'Identifier',N'ColumnId'))
                   )
          )
begin;
    alter table scheduler.Task drop constraint chk_Task_JobNamePrefacedByLocalDB; 
end;

alter table scheduler.Task 
with nocheck 
add constraint chk_Task_JobNamePrefacedByLocalDB 
    check (substring(Identifier,1,len(scheduler.GetDatabase()))=scheduler.GetDatabase());

if not exists ( select 1 
                from scheduler.Task t 
                where substring(Identifier,1,len(scheduler.GetDatabase()))<>scheduler.GetDatabase() ) 
begin;
    alter table scheduler.Task check constraint chk_Task_JobNamePrefacedByLocalDB;
end;

go
