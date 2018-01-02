# Task Config

All non-informative/sample objects in this directory are ignored by default. You may clone your own repository to this location and provide a versioned history of tasks that may be more friendly to developers. The json config files for each task may be deployed to an installation using the following Powershell command

```powershell
$configFile = "./AG1-sample/Sample_Task.json"
$srv = Server1
$db = Utility

Publish-TaskFromConfig -config $configFile - $server $srv -Database $db
```

The config files can be generated from pre-existing rows in the database by querying the [`TaskConfig`](../../src/Views/TaskConfig.sql) view. However, extracting via this method will provide a one-line/non-prettified json blob. 

Managing your tasks in this way provides for simplified management of parity between development & production environments. For example, if you wished to deploy tasks from your production installation to a new development installation on which lesser privileged programmers have permissions to deploy so they may test scripts prior to requesting code review & promotion to production - you could do so by navigating to the `/AG1-sample` folder and executing the following... (remember to check that the requisite Operators exist on the new server)...

```powershell
$srv = "SQL-Dev-1"
$db = "Utility"
$tasks = Get-ChildItem | Select Name

foreach($t in $tasks){
	Publish-TaskFromConfig -config $t.Name -server $srv -Database $db
}
``` 

Hey presto, you've now copied all the tasks in this repo to your dev server! :grin: 
