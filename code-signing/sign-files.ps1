Param (
    [string]$CodeSigningCertificate
)

$ExistingFiles = $env:ExistingFilesJson | ConvertFrom-Json
$Directories = Get-ChildItem -Path "$env:AGENT_BUILDDIRECTORY/s" -Directory | Where-Object { $_.Name -ne "Utilities" } | Select-Object -ExpandProperty Name

$Files = @()
foreach ($Directory in $Directories) {
    Write-Output "--- Scanning $Directory repository for files."
    $RepositoryRoot = "$env:AGENT_BUILDDIRECTORY/s/$Directory"
    $Files += Get-ChildItem -Path $RepositoryRoot -Include '*.ps1' -Recurse | ForEach-Object {
        $RelativePath = Join-Path $Directory ($_.FullName.Substring($RepositoryRoot.Length + 1))
        $_ | Add-Member -NotePropertyName "RelativePath" -NotePropertyValue ($RelativePath.Replace('\', '/')) -PassThru
    }
}
$Files | Get-Member
$Files | Format-Table -Property Name, FullName, RelativePath

Write-Output "--- Applying checks to see if the files need to be signed."
$Results = @()
$Files = $Files | ForEach-Object {
    $FileContent = Get-Content $_ -ErrorAction Ignore
    # Check if the file has the #sign-me tag
    if ($FileContent | Select-String -Pattern '#sign-me') {
        # If it does, check if it's already signed, we do not want to sign already signed script.
        $HasBeginBlock = $FileContent | Select-String -Pattern '# SIG # Begin signature block'
        $HasEndBlock = $FileContent | Select-String -Pattern '# SIG # End signature block'
        # If it doesn't have the signature blocks then calculate the hash of the file to be signed
        if (-not ($HasBeginBlock -and $HasEndBlock)) {
            $Hash = (Get-FileHash -Path $_.FullName -Algorithm SHA256).Hash
            # Add the hash to the object property
            $_ | Add-Member -NotePropertyName "SHA256" -NotePropertyValue $Hash -PassThru | ForEach-Object {
                # Compare the hash of the file to the hash of the file inside the storage account, the hash in the storage account will have a value of pre-signed script.
                $FileName = $_.RelativePath
                $ExistingFile = $ExistingFiles | Where-Object { $_.Name -eq $FileName }
                if ($ExistingFile.SHA256 -ne $_.SHA256) {
                    $Results += New-Object PSObject -Property @{
                        File   = $FileName
                        Result = "Needs signing"
                        SHA256 = $_.SHA256
                    }
                    $_
                } else {
                    $Results += New-Object PSObject -Property @{
                        File   = $FileName
                        Result = "Already signed"
                        SHA256 = $_.SHA256
                    }
                }
            }
        } else {
            $Results += New-Object PSObject -Property @{
                File   = $_.Name
                Result = "Contains #sign-me tag, but # SIG block found"
                SHA256 = $_.SHA256
            }
        }
    } else {
        $Results += New-Object PSObject -Property @{
            File   = $_.Name
            Result = "No #sign-me tag"
            SHA256 = $_.SHA256
        }
    }
}

# Outputs a table with the results, but the $Files variables will only contain the files that need to be signed.
$Results | Format-Table -Property File, Result, SHA256 -AutoSize

#$NewFilesAndTheirHashesJson = ($Files | ConvertTo-Json -Compress)
#Write-Host "##vso[task.setvariable variable=NewFilesAndTheirHashesJson;]$NewFilesAndTheirHashesJson"

$SignedFiles = @()
if ($Files) {
    # Code signing certificate block.
    Write-Output "--- Creating the code signing certificate from Azure Key Vault."
    New-Item "$env:BUILD_STAGINGDIRECTORY\code-signing-certificate.pfx" -Value $CodeSigningCertificate | Out-Null
    if (Get-Item -Path "$env:BUILD_STAGINGDIRECTORY\code-signing-certificate.pfx") {
        Write-Output "--- Successfully created the code signing certificate."
    }

    Write-Output "--- Importing the code signing certificate to certificate store."
    $Certificate = Import-PfxCertificate -CertStoreLocation Cert:\CurrentUser\My -FilePath "$env:BUILD_STAGINGDIRECTORY\code-signing-certificate.pfx"
    # Code signing certificate block end.

    Write-Output "--- Copying files to $env:BUILD_STAGINGDIRECTORY and signing."
    # For each File in Files (that need to be signed), copy them over to their relative path in staging directory so that files can be of the same name.
    foreach ($File in $Files) {
        $RelativePath = $File.RelativePath.Replace('/', '\')
        $DestinationPath = Join-Path $env:BUILD_STAGINGDIRECTORY $RelativePath
        # Create the destination directory if it does not exist
        $DestinationDirectory = Split-Path $DestinationPath -Parent
        if (-not (Test-Path $DestinationDirectory)) {
            New-Item -ItemType Directory -Path $DestinationDirectory | Out-Null
        }
        $CopiedFile = Copy-Item -Path $File -Destination $DestinationPath -PassThru | Select-Object -ExpandProperty FullName
        $SigningResult = Set-AuthenticodeSignature -Certificate $Certificate -FilePath $CopiedFile -TimestampServer 'http://timestamp.sectigo.com' | Select-Object -ExpandProperty StatusMessage

        $SignedFiles += New-Object PSObject -Property @{
            RelativePath = $File.RelativePath
            Result       = $SigningResult
            SHA256       = $File.SHA256
        }
    }

    $SignedFiles | Format-Table RelativePath, Result -AutoSize

    $NewFilesAndTheirHashesJson = ($SignedFiles | ConvertTo-Json -Compress)
    Write-Host "##vso[task.setvariable variable=NewFilesAndTheirHashesJson;]$NewFilesAndTheirHashesJson"
    Write-Output $NewFilesAndTheirHashesJson

    Write-Output "--- Finished signing all the files."

    Write-Output "--- Removing the certificate from the certificate store."
    Write-Output "--- Looking for certificate with thumbprint: $($Certificate.Thumbprint)."
    Get-Item -Path Cert:\CurrentUser\My\$Certificate.Thumbprint | Remove-Item
    Write-Output "--- Certificate removed from store."

    Write-Output "--- Removing the certificate from the staging directory."
    Get-Item -Path $env:BUILD_STAGINGDIRECTORY\code-signing-certificate.pfx | Remove-Item
    Write-Output "--- Certificate removed from the staging directory."

    Write-Host "##vso[task.setvariable variable=Success]true"

} elseif (!$Files) {
    Write-Output "--- Nothing to sign, or the files already exist in the storage account."
    Write-Host "##vso[task.setvariable variable=Success]false"
}
