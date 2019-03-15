# Written by George Han, PM
# Copyright (C) 2019 Microsoft Corporation
# MIT License
# 03/2019

Param(
  [string]$Folder,
  [String]$File
)

if ($Folder)
{
    $Files = Get-ChildItem $Folder -Recurse -Include *.ps1
}
else
{
    if ($File)
    {
        $Files = Get-Item $File -Include *.ps1
    }
}


$ErrorFiles = @{}
$ExceptionMap = @{}
$ReportFileName = "ScanPowerShellResult.txt"
$ErrorActionPreference = "SilentlyContinue"
if ($Files)
{
    foreach ($InputFile in $Files)
    {
        $InputFileName = $InputFile.FullName
        #Write-Host "Reading deploy file " $InputFileName
        $scripts = Get-Content $InputFileName -ErrorVariable exception

        if ($exception)
        {
            $ExceptionMap.Add($InputFileName, $exception)
        }
        for ($counter=0; $counter -lt $scripts.Count; $counter++)
        {
            $line = $scripts[$counter]
            if ($line -like '*Set-AzureRmVMOSDisk*')
            {
                $checkCounter = $counter
                $checkLine = $true
                while ($checkLine)
                {
                    if ($scripts[$checkCounter] -like '*-VhdUri*')
                    {
                        $ErrorFiles.Add($InputFileName, ($checkCounter+1))
                        break
                    }
                    if (($checkCounter -eq ($scripts.Count - 1)) -or (-not ($scripts[$checkCounter] -like '*``*')))
                    {
                        $checkLine = $false
                    }
                    else
                    {
                        
                        $checkCounter++
                    }
                }
            }
        }
    }
}

#Output scan result
$systime = [System.DateTime]::Now
Add-Content $ReportFileName ("Azure Stack PowerShell scan tool run at "+ $systime)
if ($ErrorFiles -and $ErrorFiles.Keys.Count -gt 0)
{
    Write-Host "Found PowerShell scripts with unmanaged disks, please check the detailed file list in " $ReportFileName
    Add-Content $ReportFileName "Provisioning VM using unmanaged disk found in following scripts:"
    foreach ($key in $ErrorFiles.Keys)
    {
        Add-Content $ReportFileName ($key + ", line " + $ErrorFiles[$key])
    }
    Add-Content $ReportFileName "Please refer https://docs.microsoft.com/en-us/azure/azure-stack/user/azure-stack-compute-overview#create-your-first-vm to update the scripts using managed disks in provisioning VMs"
}
else
{
    Write-Host "No unmanaged disks detected"
    Add-Content $ReportFileName "No unmanaged disks detected"
}

if ($ExceptionMap -and $ExceptionMap.Keys.Count -gt 0)
{
    Write-Host "Found .ps1 file error, please check the detailed error in " $ReportFileName
    Add-Content $ReportFileName ("`r`rFound .ps1 file error in following scripts:")
    foreach ($key in $ExceptionMap.Keys)
    {
        Add-Content $ReportFileName ("`rReading " + $key + " return following error:`r" + $ExceptionMap[$key])
    }
}
