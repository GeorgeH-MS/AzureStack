Rebalance Azure Stack Container Tool
====
Customer could attach unmanaged disks to VMs for storage. The unmanaged disks (page blob) need to be organzied within storage accounts and containers. For the best practice of creating unmanaged disks, we recommend customers place the disks in different containers for better performance and simplier management (please refer: https://docs.microsoft.com/en-us/azure/azure-stack/user/azure-stack-manage-vm-disks#use-powershell-to-add-multiple-unmanaged-disks-to-a-vm). In case customer has already created unmanaged disks with few containers and suffer from the performance bottleneck, this tool could help to rebalance the containers.
This tool include two parts:
1. Cloud operator query the problematic containers, the result would be grouped by tenant subscriptions.
2. Each impacted individual tenant subscription owner query the affected VMs. And run rebalance disk tool for each individual VM.

Detail action steps:
----
1. Login Admin PowerShell session with cloud operator account
2. Run QueryProblematicContainers.ps1, the output files would be placed in the "output_{farm name}" folder. Each tenant subscription would have a corresponding file summary the problematic containers belongs to it. The output file named with {subscription owner}+{subscription ID}
3. Send the output file in step 2 to tenant subscription owner
4. Tenant subscirption owner login Tenant PowerShell session
5. Run AnalyzeDisk.ps1 -InputFileName {inputfile}. The output would be placed in the folder "subscription_{subscription id}". The Analyze_Report summary the virtual machines which have disks placed in the problematic containers. The rest files are the data disk configuration of the impacted VMs (each file map to one particular VM).
6. To rebalance the disks of a particular VM (to move the disks out of the problematic container), deallocate the VM first, then run
RebalanceVMDisks.ps1 -ResourceGroupName {ResourceGroupName} -VMName {VMName} -StorageAccount {StorageAccountName} -InputFileName {DiskConfigFile (generated in Step 5)}
This tool would deattach all the impacted disks, copy them to newly created containers and attach the copied disks in new containers to the VM.
7. Start VM and verify if it works well. If the VM is healthy after rebalancing, run
ClearOriginalVMDisks.ps1 -ResourceGroupName {ResourceGroupName} -StorageAccount {StorageAccountName} -InputFileName {DiskConfigFile (generated in Step 5)}
This tool would remove the legacy disks in the problematic container to release storage.
If there's any issue occured during or after step 6, you could also run
RestoreOriginalVMConfig.ps1 -ResourceGroupName {ResourceGroupName} -VMName {VMName} -InputFileName {DiskConfigFile (generated in Step 5)}
This tool could recover the VM to its original state.
