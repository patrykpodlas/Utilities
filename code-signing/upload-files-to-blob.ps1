Param (
    [string]$ServicePrincipalSecret,
    [string]$StorageAccountResourceGroupName,
    [string]$StorageAccount,
    [string]$DestinationContainer
)

$NewFilesAndTheirHashes = $env:NewFilesAndTheirHashesJson | ConvertFrom-Json

$Context = $(Get-AzStorageAccount -ResourceGroupName $StorageAccountResourceGroupName -Name $StorageAccount).Context
# Set the hashes
$Results = @()
foreach ($File in $NewFilesAndTheirHashes) {
    $Metadata = @{
        SHA256 = $File.SHA256
    }
    Set-AzStorageBlobContent -Container $DestinationContainer -File $File.Name -Metadata $Metadata -Force -Context $Context | Out-Null
    $Results += New-Object PSObject -Property @{
        File   = $File.Name
        Result = "Blob uploaded"
        SHA256 = $File.SHA256
    }
}

$Results | Format-Table -Property File, Result, SHA256 -AutoSize