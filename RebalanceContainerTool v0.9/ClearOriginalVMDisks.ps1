# Use this script to rebalance the disks into different containers
Param(
  [string]$ResourceGroupName,
  [string]$StorageAccount,
  [string]$InputFileName
)

#!!! Issue warning  
#!!! print out current configuraiton 
#!!! print out new configuration
#!!! ask for confirmation 

$runAzureRM= Get-Command Get-AzureRmSubscription -ErrorAction SilentlyContinue
if(-not $runAzureRM) {
    Enable-AzureRmAlias -Scope CurrentUser
}

Write-Host "Reading original configuration from file " $InputFileName
$odisks = Get-Content $InputFileName | ConvertFrom-Json

$key = Get-AzureRmStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccount
$ctx = New-AzureStorageContext -StorageAccountName $StorageAccount -StorageAccountKey $key[0].value

foreach( $disk in $odisks )
{
   $uristr = $disk.Vhd.Uri
   $uri = [system.uri] $uristr
   $srccname = $uri.Segments[1].split("/")[0]
   $srcfname = $uri.Segments[2]
   Write-Host "Deleting blob " $uristr
   Remove-AzureStorageBlob -Blob $srcfname -Container $srccname -Context $ctx
}
