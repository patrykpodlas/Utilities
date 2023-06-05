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
        File   = $_.Name
        Result = "Blob uploaded"
        SHA256 = $_.SHA256
    }
}

$Results | Select-Object -Property File, Result, SHA256 -AutoSize