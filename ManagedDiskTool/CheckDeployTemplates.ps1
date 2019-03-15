# Written by George Han, PM
# Copyright (C) 2019 Microsoft Corporation
# MIT License
# 03/2019

Param(
  [string]$InputFolder
)

$Files = Get-ChildItem $InputFolder -Recurse -Include *.json

$ErrorFiles = @()
$ExceptionMap = @{}
$ReportFileName = "ScanTemplatesResult.txt"
$ErrorActionPreference = "SilentlyContinue"
if ($Files)
{
    foreach ($InputFile in $Files)
    {
        $InputFileName = $InputFile.FullName
        #Write-Host "Reading deploy file " $InputFileName
        $scripts = Get-Content $InputFileName | ConvertFrom-Json -ErrorVariable exception
        if ($exception)
        {
            $ExceptionMap.Add($InputFileName, $exception)
        }
        $schema = $scripts.'$schema'
        if ($schema -and $schema -eq 'https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#')
        {        
            $resources = $scripts.resources
            if ($resources)
            {
                foreach ($resource in $resources)
                {
                    if ($resource.type -eq 'Microsoft.Compute/virtualMachines')
                    {
                        $storageProfile = $resource.properties.storageProfile
                        $osDisk = $storageProfile.osDisk
                        if ("vhd" -in $osDisk.PSobject.Properties.name)
                        {
                            $ErrorFiles += $InputFile
                            #Write-Host "Unmanaged Disk found in " $InputFileName
                            break
                        }            
                    }
                }
            }
        }        
    }
}

#Output scan result
$systime = [System.DateTime]::Now
Add-Content $ReportFileName ("Azure Stack deployment templates scan tool run at "+ $systime)
if ($ErrorFiles)
{
    Write-Host "Found templates with unmanaged disks scripts, please check the detailed file list in " $ReportFileName
    Add-Content $ReportFileName "Provisioning VM using unmanaged disk found in following templates:"
    foreach ($ErrorFile in $ErrorFiles)
    {
        Add-Content $ReportFileName $ErrorFile.FullName
    }
    Add-Content $ReportFileName "Please refer https://docs.microsoft.com/en-us/azure/virtual-machines/windows/using-managed-disks-template-deployments#managed-disks-template-formatting to update the templates using managed disks in provisioning VMs"
}
else
{
    Write-Host "No unmanaged disks detected"
    Add-Content $ReportFileName "No unmanaged disks detected"
}

if ($ExceptionMap -and $ExceptionMap.Keys.Count -gt 0)
{
    Write-Host "Found JSON file error, please check the detailed error in " $ReportFileName
    Add-Content $ReportFileName ("`r`rFound JSON error in following templates:")
    foreach ($key in $ExceptionMap.Keys)
    {
        Add-Content $ReportFileName ("`rReading " + $key + " return following error:`r" + $ExceptionMap[$key])
    }
}
