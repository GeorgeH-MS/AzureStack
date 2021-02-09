# Use this script to rebalance the disks into different containers
Param(
  [string]$ResourceGroupName,
  [string]$VMName,
  [string]$StorageAccount,
  [string]$InputFileName,
  [string]$DestContainerSuffix
)

$runAzureRM= Get-Command Get-AzureRmSubscription -ErrorAction SilentlyContinue
if(-not $runAzureRM) {
    Enable-AzureRmAlias -Scope CurrentUser
}

#!!! Issue warning  
#!!! print out current configuraiton 
#!!! print out new configuration
#!!! ask for confirmation 

Write-Host "Reading original configuration from file " $InputFileName
$odisks = Get-Content $InputFileName | ConvertFrom-Json

$vm = Get-AzureRMVM -ResourceGroupName $ResourceGroupName -VMName $vmname -Status
$vmstatus = $vm.statuses | Where-Object Code -like "PowerState/deallocated"
if( $vmstatus -eq $null )
{
    Write-Warning "VM is running. Please stop the VM and retry this operation"
    exit 
}

# dettach any data disk that might be already attached
$vm = Get-AzureRMVM -ResourceGroupName $ResourceGroupName -VMName $vmname
$cdisks = $vm.StorageProfile.DataDisks
if( $cdisks.Count -gt 0 )
{
    Write-Host "Dettaching all data disks..."
    foreach( $disk in $cdisks )
    {
        Write-Host "Disk " $disk.Name " : " $disk.Vhd.Uri
    }
    $vmchanged = Remove-AzureRmVMDataDisk -VM $vm -DataDiskNames $cdisks.Name
    Write-Host "Updating the VM configuration..."
    $status = Update-AzureRmVM -VM $vm -ResourceGroupName $ResourceGroupName
    #!!! check status
}

$key = Get-AzureRmStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccount
$ctx = New-AzureStorageContext -StorageAccountName $StorageAccount -StorageAccountKey $key[0].value

$CopyObjects=@()

foreach( $disk in $odisks )
{
   $uristr = $disk.Vhd.Uri
   $uri = [system.uri] $uristr
   $srccname = $uri.Segments[1].split("/")[0]
   $srcfname = $uri.Segments[2]
   $dstcname = $srcfname.split(".")[0].ToLower() + $DestContainerSuffix
   Write-Host "Creating container " $dstcname
   New-AzureStorageContainer -Context $ctx -Name $dstcname
   Write-Host "Copying blob " $srcfname
   $job = Start-CopyAzureStorageBlob -SrcContainer $srccname -SrcBlob $srcfname -DestContainer $dstcname -Context $ctx 
   $copyObject=[PSCustomObject]@{
            "CopyJob"=$job
            "SrcContainer"=$srccname
            "SrcBlob"=$srcfname
            "DestContainer"=$dstcname
            "DestBlob"=$srcfname
        }
    $CopyObjects += $copyObject
}

#!!! Check if blob copy has completed
# Get-AzureStorageBlobCopyState -Blob $srcfname -Container $dstcname -Context $ctx

# Check copy status
	Write-Verbose "Start to check to copy blob status every 15 seconds...... "   
    $copyComplete=$false 
    while (!$copyComplete){
        $copyComplete=$true
        Start-Sleep 15 
        foreach ($copyobject in $CopyObjects){
            $status= Get-AzureStorageBlobCopyState -Blob $copyobject.DestBlob -Container $copyobject.DestContainer -Context $ctx -Verbose
			Write-Host "Status:$($status.Status) ==> SrcContainer: $($copyobject.SrcContainer) SrcBlob: $($copyobject.SrcBlob) DestContainer: $($copyobject.DestContainer) DestBlob: $($copyobject.DestBlob)"
			if($status.Status -eq "Pending" ){
                $copyComplete=$false
            }
            elseif($status.Status -eq "Failed"){
                throw "Copy failed."
            }
        }		
    }
	Write-Verbose "Copy blob succeed..."   
Read-Host -Prompt "Please double confirm the copy operations have been completed before continue with Enter"

$vm = Get-AzureRMVM -ResourceGroupName $ResourceGroupName -VMName $vmname

foreach( $disk in $odisks )
{

   $uristr = $disk.vhd.uri
   $uri = [system.uri] $uristr
   $srccname = $uri.Segments[1].split("/")[0]
   $srcfname = $uri.Segments[2]
   $dstcname = $srcfname.split(".")[0].ToLower() + $DestContainerSuffix
   $diskpath = $uri.scheme + "://" + $uri.Host + "/" + $dstcname + "/" + $srcfname
   write-host "Attaching disk " $diskpath
   $vmupdate = Add-AzureRmVMDataDisk -VM $vm -Name $disk.Name -VhdUri $diskpath -CreateOption Attach -Lun $disk.Lun -DiskSizeInGB $disk.DiskSizeGB  
}
Write-Host "Updating the VM..." 
$status = Update-AzureRmVM -VM $vm -ResourceGroupName $ResourceGroupName

Write-Host "Update VM return status: $status"
# check the status code


