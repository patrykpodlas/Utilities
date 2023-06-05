# Code signing

## Introduction

Signs files and uploads them to storage account as blobs.

## Process

Scans files in checked out repositories, and applies checks in order:

1. Checks for '#sign-me' tag in the file content.
2. Checks for '# SIG # Begin signature block' and '# SIG # End signature block' in the file content.
3. If both above checks pass, it generates SHA256 hash of the file in repository and compares it to the hash of the blob in the storage account.
4. If the hash doesn't match, it uploads or re-uploads the file to the storage account, along with the new SHA256 hash.

## Requirements

1. Service connection to connect to GitHub.
2. Service connection to connect to Azure Resource Manager, the service principal generated automatically is sufficient.
3. Storage Account, Blob Container.
   1. Role assignment for the service principal:
      * Contributor
      * Storage Blob Data Contributor
4. Key Vault
   1. Role assingment for the service principal:
      * Key Vault Secret User
   2. Secrets
      * destination-container
      * storage-account
      * storage-account-resource-group-name
   3. Certificates
      * code-signing-certificate - Certificate must support code signing, you can generate this certificate in the key vault by adding additional purpose: Code Signing ( 1.3.6.1.5.5.7.3.3 ).
5. Variable Group
    1. Name: Code Signing
    2. Link secrets from an Azure key vault as variables.
    3. Add the secrets and certificate to the list of variables.