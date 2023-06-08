Param (
    [string]$ServicePrincipalSecret,
    [string]$StorageAccountResourceGroupName,
    [string]$StorageAccount,
    [string]$DestinationContainer
)

$NewFilesAndTheirHashes = $env:NewFilesAndTheirHashesJson | ConvertFrom-Json

$Context = $(Get-AzStorageAccount -ResourceGroupName $StorageAccountResourceGroupName -Name $StorageAccount).Context
# Upload to blob and set the hashes
$Results = @()
foreach ($File in $NewFilesAndTheirHashes) {
    $Metadata = @{
        SHA256 = $File.SHA256
    }
    Set-AzStorageBlobContent -Container $DestinationContainer -File $File.RelativePath -Blob $File.RelativePathBlob -Metadata $Metadata -Force -Context $Context | Out-Null
    $Results += New-Object PSObject -Property @{
        RelativePathBlob = $File.RelativePathBlob
        Result           = "Blob uploaded"
        SHA256           = $File.SHA256
    }
}

$Results | Format-Table -Property RelativePathBlob, Result, @{Name = "SHA256"; Expression = { $_.SHA256 | Out-String -Width 200 } } -AutoSize