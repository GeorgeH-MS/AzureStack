[CmdletBinding()]
param (
    [string]$Source, 
    [string]$Destination
)

# check if $Source is sparse file
$checkSparseFlagOutput = fsutil sparse queryflag $Source
if ($checkSparseFlagOutput.Contains(" NOT ")){
    throws "Srouce file $Source is not a sparse file"
}

Write-Verbose "Copying file ..."
# copy $Source to $Destination
$Dest = Copy-Item $Source -Destination $Destination -Force -PassThru
Write-Verbose "File is copied"

# set destination to sparse
fsutil sparse setflag $Dest.FullName

# get $Source allocated ranges
$fsutilOutput = fsutil sparse queryrange $Source
$ranges = $fsutilOutput |% {
    $_ -match '.*Offset\: 0[xX](?<Offset>[0-9a-fA-F]+)\s+Length\: 0[xX](?<Length>[0-9a-fA-F]+)' | Out-Null
    New-Object -TypeName psobject -Property @{"Offset" = [convert]::ToInt64($Matches['Offset'], 16); "Length" = [convert]::ToInt64($Matches['Length'], 16)}
} | sort { $_.Offset }

# print ranges
Write-Verbose "===== Ranges ====="
$ranges |% { Write-Verbose ("Offset: 0x{0:X0}`tLength: 0x{1:X0}" -f $_.Offset,$_.Length) }
Write-Verbose "=== End Ranges ==="

Write-Verbose "Deallocating zero ranges ..."
# zero ranges
$offset = 0
foreach ($range in $ranges){
    # read a range from $Source
    $length = $range.Offset - $offset
    if ($length -gt 0){
        Write-Verbose ("Deallocate zero range. Offset: 0x{0:X0}, Length: 0x{1:X0}" -f $offset,$length)
        fsutil file setzerodata offset=$offset length=$length $Dest.FullName | Out-Null
    }
    $offset = $range.Offset + $range.Length
}
$eof = (Get-Item $Dest.FullName).Length
$length = $eof - $offset
if ($length -gt 0){
    Write-Verbose ("Deallocate zero range. Offset: 0x{0:X0}, Length: 0x{1:X0}" -f $offset,$length)
    fsutil file setzerodata offset=$offset length=$length $Dest.FullName | Out-Null
}
Write-Verbose "Copy is done"
