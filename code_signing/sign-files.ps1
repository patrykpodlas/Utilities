Param (
    [string]$CodeSigningCertificate
)

$ExistingFiles = $env:ExistingFilesJson | ConvertFrom-Json
$Directories = Get-ChildItem -Path "$env:AGENT_BUILDDIRECTORY/s" -Directory | Select-Object -ExpandProperty Name
$Files = @()
foreach ($Directory in $Directories) {
    Write-Output "--- Scanning $Directory repository for files."
    $Files += Get-ChildItem -Path "$env:AGENT_BUILDDIRECTORY/s/$Directory" -Include '*.ps1' -Recurse
}

Write-Output "--- Applying checks to see if the files need to be signed."
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
                $FileName = $_.Name
                $ExistingFile = $ExistingFiles | Where-Object { $_.Name -eq $FileName }
                if ($ExistingFile.SHA256 -ne $_.SHA256) {
                    Write-Host "File: $($ExistingFile.Name) in storage account has a different hash than $FileName to be uploaded."
                    $_
                } else { Write-Host "File: $FileName already exists with the same hash in the storage account." }
            }
        }
    }
}

$NewFilesAndTheirHashesJson = ($Files | ConvertTo-Json -Compress)
Write-Host "##vso[task.setvariable variable=NewFilesAndTheirHashesJson;]$NewFilesAndTheirHashesJson"

$FilteredFiles = $Files #| Where-Object {$ExistingFiles.Name -notcontains $_.Name}

if ($FilteredFiles) {
    Write-Output "--- Creating the code signing certificate from Azure Key Vault."
    New-Item "$env:BUILD_STAGINGDIRECTORY\code_signing_certificate.pfx" -Value $CodeSigningCertificate | Out-Null
    if (Get-Item -Path "$env:BUILD_STAGINGDIRECTORY\code_signing_certificate.pfx") {
        Write-Output "--- Successfully created the code signing certificate."
    }

    Write-Output "--- Importing the code signing certificate to certificate store."
    $Certificate = Import-PfxCertificate -CertStoreLocation Cert:\CurrentUser\My -FilePath "$env:BUILD_STAGINGDIRECTORY\code_signing_certificate.pfx"

    Write-Output "--- Files to be signed:"
    foreach ($File in $FilteredFiles) {
        Write-Output $File.Name
    }

    Write-Output "--- Copying files to $env:BUILD_STAGINGDIRECTORY and signing."
    foreach ($File in $FilteredFiles) {
        $CopiedFile = Copy-Item -Path $File -Destination $env:BUILD_STAGINGDIRECTORY -PassThru | Select-Object -ExpandProperty FullName
        Write-Output "Signing: $($File.Name), Result: $(Set-AuthenticodeSignature -Certificate $Certificate -FilePath $CopiedFile -TimestampServer 'http://timestamp.sectigo.com' | Select-Object -ExpandProperty StatusMessage)"
    }

    Write-Output "--- Finished signing all the files."

    Write-Output "--- Removing the certificate from the certificate store."
    Write-Output "--- Looking for certificate with thumbprint: $($Certificate.Thumbprint)."
    Get-Item -Path Cert:\CurrentUser\My\$Certificate.Thumbprint | Remove-Item
    Write-Output "--- Certificate removed from store."

    Write-Output "--- Removing the certificate from the staging directory."
    Get-Item -Path $env:BUILD_STAGINGDIRECTORY\code_signing_certificate.pfx | Remove-Item
    Write-Output "--- Certificate removed from the staging directory."

    Write-Host "##vso[task.setvariable variable=Success]true"

} elseif (!$FilteredFiles) {
    Write-Output "--- Nothing to sign, or the files already exist in the storage account."
    Write-Host "##vso[task.setvariable variable=Success]false"
}
