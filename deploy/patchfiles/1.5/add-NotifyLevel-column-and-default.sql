if col_length(N'scheduler.Task',N'NotifyLevelEventlog') is null
    alter table scheduler.Task add NotifyLevelEventlog int not null constraint DF_NotifyLevelEventlog default 2
go

alter table scheduler.Task drop constraint DF_NotifyLevelEventlog;
go

alter table scheduler.Task add constraint DF_Task_NotifyLevelEventlog default (2) for NotifyLevelEventlog;
go
