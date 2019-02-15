$farm = Get-AzsStorageFarm
$disks = ( Get-AzsStorageAcquisition -FarmName $farm.name | where Storageaccount -notlike 'md-*' | select Susbcriptionid, Storageaccount, Container, Blob, Acquisitionid, FilePath )
$pcontainers = $disks | group Susbcriptionid, StorageAccount, Container | where Count -gt 1

if( $pcontainers.Count -gt 0 )
{
    $SubscriptionMap = @{}
    $folderName = "output_" + $farm.Name
    if (!(Test-Path -Path $folderName))
    {
        New-Item ($folderName) -ItemType Directory | Out-Null
    }
    foreach( $container in $pcontainers )
    {
        foreach( $disk in $container.Group )
        {
            $SubscriptionId = $disk.Susbcriptionid
            if ($SubscriptionMap.ContainsKey($SubscriptionId))
            {
                $SubscriptionMap.$SubscriptionId.Add($disk.FilePath, $disk)
            }
            else
            {
                $diskMap = @{$disk.FilePath = $disk}
                $SubscriptionMap.Add($SubscriptionId, $diskMap)
            }
        }
    }
    $resultfiles = @()
    foreach ($key in $SubscriptionMap.Keys)
    {
        $Subscription = Get-AzsUserSubscription -SubscriptionId $key
        if (-not ($Subscription.RoutingResourceManagerType -eq "Admin"))
        {
            $OutputFileName = $folderName + "\" + $Subscription.Owner + " " + $key + ".txt"
            $Disks = @()
            foreach($key1 in $SubscriptionMap[$key].Keys)
            {
                $Disks += $SubscriptionMap[$key][$key1]
            }
            $Disks | ConvertTo-Json | Out-File $OutputFileName
        
            $result = New-Object PSObject -Property @{
                SubscriptionOwner = $Subscription.Owner
                SubscriptionName = $Subscription.DisplayName
                SubscriptionId = $key
                VMCount = ($disks | group Acquisitionid).Count
                DisksCount = $disks.Count
                DiskConfigFile = $Subscription.Owner + " " + $key + ".txt"
            }
            $resultfiles += $result
        }
    }
}

$resultfiles | select SubscriptionOwner, SubscriptionName, SubscriptionId, VMCount, DisksCount, DiskConfigFile | FT | Write-Output
Write-Host "Above subscriptions have problematic containers. Configuration files for each subscription generated under folder "$folderName". Please contact the subscription owner with the configuration file, and ask owners to run the analyze disk tool for each subscription to resolve the impacted VMs. And then run rebalance disk tool to distribute the container allocation for identified disks."
