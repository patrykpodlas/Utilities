Param (
    [string]$ServicePrincipalSecret,
    [string]$StorageAccountResourceGroupName,
    [string]$StorageAccount
)

$NewFilesAndTheirHashes = $env:NewFilesAndTheirHashesJson | ConvertFrom-Json
Write-Output "--- Logging into storage account."
$SecurePassword = ConvertTo-SecureString -String $ServicePrincipalSecret -AsPlainText -Force
$PSCredential = New-Object System.Management.Automation.PSCredential($env:ServicePrincipalID, $SecurePassword)
Connect-AzAccount -ServicePrincipal -Credential $PSCredential -Tenant $env:TenantID
Write-Output "--- Logged into Azure."
$Context = $(Get-AzStorageAccount -ResourceGroupName $StorageAccountResourceGroupName -Name $StorageAccount).Context
# Set the hashes
foreach ($File in $NewFilesAndTheirHashes) {
    $Metadata = @{
        SHA256 = $File.SHA256
    }
    Write-Output "--- Uploading file: $($File.Name) and setting metadata with hash: $($File.SHA256)."
    Set-AzStorageBlobContent -Container $(destination-container) -File $File.Name -Metadata $Metadata -Force -Context $Context | Out-Null
    Write-Output "--- Blob uploaded."
}