$farm = Get-AzsStorageFarm
$disks = ( Get-AzsStorageAcquisition -FarmName $farm.name | where Storageaccount -notlike 'md-*' | select Susbcriptionid, Storageaccount, Container, Blob, Acquisitionid, FilePath )
$pcontainers = $disks | group Susbcriptionid, StorageAccount, Container | where Count -gt 1

if( $pcontainers.Count -gt 0 )
{
    $SubscriptionMap = @{}
    $folderName = "output_" + $farm.Name
    New-Item ($folderName) -ItemType Directory
    foreach( $container in $pcontainers )
    {
        #$SubscriptionId = $container.Name.split(",")[0]
        #if ($SubscriptionMap.ContainsKey($SubscriptionId))
        #{
        #    $SubscriptionMap.$SubscriptionId.Add($container.Name, $container.Group)
        #}
        #else
        #{
        #    $containerMap = @{$container.Name= $container.Group}
        #    $SubscriptionMap.Add($SubscriptionId, $containerMap)
        #}
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
    foreach ($key in $SubscriptionMap.Keys)
    {
        $Subscription = Get-AzsUserSubscription -SubscriptionId $key
        $OutputFileName = $folderName + "\" + $Subscription.Owner + " " + $key + ".txt"
        $Disks = @()
        foreach($key1 in $SubscriptionMap[$key].Keys)
        {
            $Disks += $SubscriptionMap[$key][$key1]
        }
        $Disks | ConvertTo-Json | Out-File $OutputFileName
        Write-Host "Add " $Subscription.DisplayName " to " $OutputFileName
    }
}

