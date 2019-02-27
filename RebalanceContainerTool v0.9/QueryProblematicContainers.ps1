$farm = Get-AzsStorageFarm

$dcount = 0
$umcount = 0

$disks = Get-AzsStorageAcquisition -FarmName $farm.name
if ($disks -and ($disks.count -gt 0))
{
    $dcount = $disks.count
}
$umdisks = (Get-AzsStorageAcquisition -FarmName $farm.name | where Storageaccount -notlike 'md-*' | select Susbcriptionid, Storageaccount, Container, Blob, Acquisitionid, FilePath )
if ($umdisks -and ($umdisks.count -gt 0))
{
    $umcount = $umdisks.count
}
$pcontainers = $umdisks | group Susbcriptionid, StorageAccount, Container | where Count -gt 1

$fdcount = 0
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
            $ODisks = @()
            foreach($key1 in $SubscriptionMap[$key].Keys)
            {
                $ODisks += $SubscriptionMap[$key][$key1]
            }
            $ODisks | ConvertTo-Json | Out-File $OutputFileName
        
            $result = New-Object PSObject -Property @{
                SubscriptionOwner = $Subscription.Owner
                SubscriptionName = $Subscription.DisplayName
                SubscriptionId = $key
                ContainerCount = ($ODisks | group StorageAccount, Container).Name.Count
                VMCount = ($ODisks | group Acquisitionid).Name.Count
                DisksCount = $ODisks.Count
                DiskConfigFile = $Subscription.Owner + " " + $key + ".txt"
            }
            $resultfiles += $result
            $fdcount += $ODisks.Count
        }
    }
}

Write-Host "You have" $dcount "disks in your Azure Stack," $umcount "of which are unmanaged disks. There are" $fdcount "unmanaged disks are badly placed."
$resultfiles | select SubscriptionOwner, SubscriptionName, SubscriptionId, ContainerCount, VMCount, DisksCount, DiskConfigFile | FT | Write-Output
Write-Host "Above subscriptions have problematic containers. Configuration files for each subscription generated under folder"$folderName". Please contact the subscription owner with the configuration file, and ask owners to run the analyze disk tool for each subscription to resolve the impacted VMs. And then run rebalance disk tool to distribute the container allocation for identified disks."
