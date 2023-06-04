Param (
    [string]$ServicePrincipalSecret,
    [string]$StorageAccountResourceGroupName,
    [string]$StorageAccount,
    [string]$DestinationContainer
)

$NewFilesAndTheirHashes = $env:NewFilesAndTheirHashesJson | ConvertFrom-Json

$Context = $(Get-AzStorageAccount -ResourceGroupName $StorageAccountResourceGroupName -Name $StorageAccount).Context
# Set the hashes
foreach ($File in $NewFilesAndTheirHashes) {
    $Metadata = @{
        SHA256 = $File.SHA256
    }
    Write-Output "--- Uploading file: $($File.Name) and setting metadata with hash: $($File.SHA256)."
    Set-AzStorageBlobContent -Container $DestinationContainer -File $File.Name -Metadata $Metadata -Force -Context $Context | Out-Null
    Write-Output "--- Blob uploaded."
}