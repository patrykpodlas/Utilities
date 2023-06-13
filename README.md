# Code signing

## Introduction

Signs files and uploads them to storage account as blobs.

The pipeline uses cloud agent to perform the task, but a self-hosted agent can also be used.

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
      * executables-container
      * destination-container
      * storage-account
      * storage-account-resource-group-name
   3. Certificates
      * code-signing-certificate - Certificate must support code signing, you can generate this certificate in the key vault by adding additional purpose: Code Signing ( 1.3.6.1.5.5.7.3.3 ).
5. Variable Group
    1. Name: Code Signing
    2. Link secrets from an Azure key vault as variables.
    3. Add the secrets and certificate to the list of variables.

## Optional: WebHook

To trigger the pipeline on files added to other repositories that are checked out, you can create a WebHook, this is required if you're not using Azure Repos, if you are using Azure Repos the triggering of the pipeline is supported without a WebHook.

In GitHub
1. Payload URL: `https://dev.azure.com/<"OrgName">/_apis/public/distributedtask/webhooks/<"WebHookName">?api-version=6.0-preview`, replace <"">.
2. Content type: `application/json`
3. Secret: Generate a secret to secure the payload, this corresponds to the secret in Azure DevOps service connection.
4. Events to trigger the webhook: For the purpose of this tool, to not generate too many triggers, a pull requests trigger is sufficient.

In Azure DevOps
1. Create Incoming WebHook service connection.
   1. WebHook Name: Name corresponding to the name in Payload URL in GitHub
   2. Secret (optional): Secret generated and entered into GitHub payload.
   3. Service connection name: Name of the service connection, e.g. Trigger-Utilities, or Trigger-Code-Signing (if this trigger is only for code signing)

In pipeline YAML
1. Configure appopriate WebHook resource:
   1. webook: This is an alias
   2. connection: This is the service connection name.
   3. filters: These are the filters you wish to filter the payload with for events, in the example below the pipeline is listening for payloads with path: action and value: closed (will trigger when the pull request has been closed).

``` YAML
  webhooks:
    - webhook: MyTrigger
    connection: Trigger-Utilities
    filters:
    - path: action
      value: closed
```