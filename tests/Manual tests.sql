exec scheduler.CreateAgentJob	@jobName = N'Every Hour'
								,@command = N'select @@servername'
								,@frequencyType = 'hour'
								,@frequencyInterval = 1
								,@startTime = '00:00'
								,@notifyOperator = 'Test Operator'
								,@overwriteExisting = 1;

exec scheduler.CreateAgentJob	@jobName = N'Every Other Hour'
								,@command = N'select @@servername'
								,@frequencyType = 'hour'
								,@frequencyInterval = 2
								,@startTime = '00:00'
								,@notifyOperator = 'Test Operator'
								,@overwriteExisting = 1;

exec scheduler.CreateAgentJob	@jobName = N'Every Day'
								,@command = N'select @@servername'
								,@frequencyType = 'day'
								,@frequencyInterval = 0
								,@startTime = '00:00'
								,@notifyOperator = 'Test Operator'
								,@overwriteExisting = 1;

exec scheduler.CreateAgentJob	@jobName = N'Every 5 Minutes'
								,@command = N'select @@servername'
								,@frequencyType = 'minute'
								,@frequencyInterval = 5
								,@startTime = '00:00'
								,@notifyOperator = 'Test Operator'
								,@overwriteExisting = 1;

exec scheduler.CreateAgentJob	@jobName = N'Every 30 Minutes from Midday'
								,@command = N'select @@servername'
								,@frequencyType = 'minute'
								,@frequencyInterval = 30
								,@startTime = '12:00'
								,@notifyOperator = 'Test Operator'
								,@overwriteExisting = 1;
