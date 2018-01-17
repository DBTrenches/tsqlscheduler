* Sub-folders in this directory must have a valid numeric name.
* Files in any sub-folder from here must be valid `.sql` patch files 
* Patch files should be entirely self-contained and independently executable in any order within any one sub-folder
* A patch folder will be applied in ascending order when the function [`scheduler.GetVersion()`](../src/Functions/GetVersion.sql) returns a numeric value _**less than**_ the name of the folder 
	* For this reason, it is important to properly increment the Version Number returned by this function appropriately.   

For example: breaking changes were made between <kbd>1.4</kbd> and <kbd>1.5</kbd>. Patch files in the folder [`/migration-scripts/1.5`](/1.5) are applied when executing `Install-SchedulerSolution` on _ANY_ installation where the solution is already installed at versions <kbd>1.0</kbd> through <kbd>1.4</kbd>. They are _NOT_ applied when version-bumping <kbd>1.5</kbd> to <kbd>1.5+</kbd>
