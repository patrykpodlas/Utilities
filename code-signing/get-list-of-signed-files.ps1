Param(
    [string]$StorageAccountResourceGroupName,
    [string]$StorageAccount,
    [string]$DestinationContainer
)

Write-Output "--- Searching for existing signed files in the storage account."
$Context = $(Get-AzStorageAccount -ResourceGroupName $StorageAccountResourceGroupName -Name $StorageAccount).Context
# Getting list of files in the blob, the object will also contain the existing SHA256 metadata.
$ExistingFiles = Get-AzStorageBlob -Container $DestinationContainer -Context $Context | Select-Object -Property Name, @{Name = "RelativePath"; Expression = { $_.Name.Split('/')[-1] } }, @{Name = "SHA256"; Expression = { $_.BlobClient.GetProperties().Value.Metadata.SHA256 } }

Write-Output "--- Existing files in the storage account:"
$ExistingFiles | Format-Table Name, RelativePath, SHA256

$ExistingFilesJson = ($ExistingFiles | ConvertTo-Json -Compress)
Write-Host "##vso[task.setvariable variable=ExistingFilesJson;]$ExistingFilesJson"