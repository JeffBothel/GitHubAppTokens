# GitHubAppTokens

PowerShell module that has various cmdlets that are used for managing and setting up GitHub tokens that will then be used for automation and scripting of actions that use the GitHub App token as dynamic authentication to GitHub.

## Requirements

- PowerShell 7.0 or later

## Installation

```powershell
Import-Module ./GitHubAppTokens.psd1
```

## Cmdlets

### `New-GitHubAppJWT`

Generates a signed JSON Web Token (JWT) for GitHub App authentication using the App's RSA private key.

```powershell
$jwt = New-GitHubAppJWT -AppId <int> -PrivateKeyPath <string> [-ExpirationSeconds <int>]
```

| Parameter          | Required | Description                                                       |
|--------------------|----------|-------------------------------------------------------------------|
| `AppId`            | Yes      | Numeric GitHub App ID (found on the App settings page).           |
| `PrivateKeyPath`   | Yes      | Path to the `.pem` private key file downloaded from GitHub.       |
| `ExpirationSeconds`| No       | Seconds until the JWT expires. Range: 1–600. Default: **600**.    |

**Example:**

```powershell
$jwt = New-GitHubAppJWT -AppId 12345 -PrivateKeyPath './my-github-app.pem'
```

---

### `Get-GitHubInstallationToken`

Exchanges a GitHub App JWT for an installation access token. The token can be used to make GitHub API calls on behalf of the installed app and is valid for one hour.

```powershell
$result = Get-GitHubInstallationToken -AppId <int> -InstallationId <int> -PrivateKeyPath <string> [-Permissions <hashtable>]
```

| Parameter       | Required | Description                                                              |
|-----------------|----------|--------------------------------------------------------------------------|
| `AppId`         | Yes      | Numeric GitHub App ID.                                                   |
| `InstallationId`| Yes      | Numeric installation ID for the App.                                     |
| `PrivateKeyPath`| Yes      | Path to the `.pem` private key file.                                     |
| `Permissions`   | No       | Hashtable of permission scopes to restrict the token (e.g. `@{ contents = 'read' }`). |

**Returns** a `PSCustomObject` with:

| Property    | Type   | Description                                  |
|-------------|--------|----------------------------------------------|
| `Token`     | string | The installation access token.               |
| `ExpiresAt` | string | ISO 8601 expiry timestamp (typically 1 hour).|

**Example:**

```powershell
# Get a full-permission token
$result = Get-GitHubInstallationToken -AppId 12345 -InstallationId 67890 -PrivateKeyPath './my-github-app.pem'
$env:GITHUB_TOKEN = $result.Token

# Get a scoped token
$result = Get-GitHubInstallationToken -AppId 12345 -InstallationId 67890 -PrivateKeyPath './my-github-app.pem' `
    -Permissions @{ contents = 'read'; issues = 'write' }
```

## Running Tests

Tests use [Pester](https://pester.dev/) v5:

```powershell
Invoke-Pester ./Tests
```
