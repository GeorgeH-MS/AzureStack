Param(
  [string]$InputFileName
)


Write-Host "Reading container list from file " $InputFileName
$blobs = Get-Content $InputFileName | ConvertFrom-Json

$vms = Get-AzureRmVM
$VMMap = @{}
$ConfigFileMap = @{}
$ContainerMap = @{}
$SubscriptionId = ""

foreach ( $vm in $vms )
{
    $VMID = $vm.ResourceGroupName + "\" + $vm.Name
    if ($SubscriptionId -eq "")
    {
        $SubscriptionId = $vm.Id.Split('/')[2]
    }
    Write-Host "query VM " $VMID
    $StorageProfile = $vm.StorageProfile
    $uristr = $StorageProfile.OsDisk.vhd.Uri
    if ($uristr)
    {        
        $uri = [system.uri] $uristr
        $DiskSN = $uri.Host.Split(".")[0]
        $DiskCN = $uri.Segments[1].split("/")[0]
        $DiskFN = $uri.Segments[2]
        foreach( $blob in $blobs)
        {
            if( ($blob.Storageaccount -eq $DiskSN) -and ($blob.Container -eq $DiskCN) -and ($blob.Blob -eq $DiskFN))
            {
            
                if ($VMMap.ContainsKey($VMID))
                {
                    $VMMap.$VMID.Add($blob.FilePath, $blob)
                }
                else
                {
                    $blobMap = @{$blob.FilePath = $blob}
                    $VMMap.Add($VMID, $blobMap)
                }
                $ContainerKey = $blob.Storageaccount + "/" + $blob.Container
                if ($ContainerMap.ContainsKey($ContainerKey))
                {
                    if ($ContainerMap.$ContainerKey.ContainsKey($VMID))
                    {
                        $diskCount = $ContainerMap.$ContainerKey.$VMID
                        $ContainerMap.$ContainerKey.$VMID += 1
                    }
                    else
                    {
                        $ContainerMap.$ContainerKey.Add($VMID, 1)
                    }
                }
                else
                {
                    $ContainerMap.Add($ContainerKey, @{$VMID = 1})
                }
                break
            }
        }
    }
    $DataDisks = $StorageProfile.DataDisks
    if ($DataDisks.Count -gt 0)
    {
        foreach($DataDisk in $DataDisks)
        {
                $uristr = $DataDisk.vhd.Uri
                if ($uristr)
                {
                    $uri = [system.uri] $uristr
                    $DiskSN = $uri.Host.Split(".")[0]
                    $DiskCN = $uri.Segments[1].split("/")[0]
                    $DiskFN = $uri.Segments[2]
                    foreach( $blob in $blobs)
                    {
                        if( ($blob.Storageaccount -eq $DiskSN) -and ($blob.Container -eq $DiskCN) -and ($blob.Blob -eq $DiskFN))
                        {
                            if ($VMMap.ContainsKey($VMID))
                            {
                                $VMMap.$VMID.Add($blob.FilePath, $blob)
                            }
                            else
                            {
                                $blobMap = @{$blob.FilePath = $blob}
                                $VMMap.Add($VMID, $blobMap)
                            }
                            if ($ConfigFileMap.ContainsKey($VMID))
                            {
                                $ConfigFileMap.$VMID.Add($DataDisk.Vhd, $DataDisk)
                            }
                            else
                            {
                                $DDisks = @{$DataDisk.Vhd = $DataDisk}
                                $ConfigFileMap.Add($VMID, $DDisks)
                            }
                            $ContainerKey = $blob.Storageaccount + "/" + $blob.Container
                            if ($ContainerMap.ContainsKey($ContainerKey))
                            {
                                if ($ContainerMap.$ContainerKey.ContainsKey($VMID))
                                {
                                    $diskCount = $ContainerMap.$ContainerKey.$VMID
                                    $ContainerMap.$ContainerKey.$VMID += 1
                                }
                                else
                                {
                                    $ContainerMap.$ContainerKey.Add($VMID, 1)
                                }
                            }
                            else
                            {
                                $ContainerMap.Add($ContainerKey, @{$VMID = 1})
                            }
                            break
                        }
                    }
                }
        }
    }
}

$folderName = "subscription_" + $SubscriptionId
New-Item ($folderName) -ItemType Directory
$ReportFileName = $folderName + "\" + "Analyze_Report.txt"

Add-Content $ReportFileName "#################### Impacted Virtual Machines ####################"
foreach($key1 in $ContainerMap.Keys)
{
    $ContainerVM = $ContainerMap[$key1]
    Add-Content $ReportFileName ("Following VMs have disks in problematic container ['" + $key1 + "']:")
    foreach($key2 in $ContainerVM.Keys)
    {
        $DiskCount = $ContainerVM[$key2]
        Add-Content $ReportFileName ($key2 + " has " + $DiskCount + " disks")
    }
}
Add-Content $ReportFileName "`rTo rebalance the disks in above containers, please work with the owner of above VMs to plan maintenance window (VM must be deallocated before disk rebalancing)"   

Add-Content $ReportFileName "`r`r`r#################### Disk Rebalancing Actions ####################"
#hard to read actual size from blob since no resource group information of storage account fetched
foreach($key1 in $VMMap.Keys)
{
    $ResourceGroupName = $key1.Split('\')[0]
    $VMName = $key1.Split('\')[1]
    Add-Content $ReportFileName ("VM[" + $key1 + "] has following disks placed in the problematic containers:")
    foreach($key2 in $VMMap.$key1.Keys)
    {
        $blob = $VMMap.$key1.$key2
        Add-Content $ReportFileName ("Disk[" + $blob.Blob + "] placed in Storage Account[" + $blob.Storageaccount + "]/Container[" + $blob.Container + "]")
        #Share information: Write-Host $blob.FilePath.Split('\')[2]
    }
    $DDisks = @()
    foreach($key2 in $ConfigFileMap[$key1].Keys)
    {
        $DDisks += $ConfigFileMap[$key1][$key2]
    }
    
    $OutputFileName = $folderName + "\" + $ResourceGroupName + " " + $VMName + ".txt"
    $DDisks | ConvertTo-Json | Out-File $OutputFileName
    Add-Content $ReportFileName ("Data disks configuration saved in " + $OutputFileName + "`r")
}
Add-Content $ReportFileName ("Data disks could be rebalanced using RebalanceVMDisks tool with disk configuration file as input")

Write-Host "Analyze complete, please check the report " $ReportFileName