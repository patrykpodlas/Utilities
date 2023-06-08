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
    $BlobPrefix = $File.RelativePath
    $Metadata = @{
        SHA256 = $File.SHA256
    }
    Set-AzStorageBlobContent -Container $DestinationContainer -File $File.RelativePath -Metadata $Metadata -Force -Context $Context | Out-Null
    $Results += New-Object PSObject -Property @{
        File   = $File.RelativePath
        Result = "Blob uploaded"
        SHA256 = $File.SHA256
    }
}

$Results | Format-Table -Property RelativePath, Result, SHA256 -AutoSize