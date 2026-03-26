function Get-GitHubInstallationToken {
    <#
    .SYNOPSIS
        Gets a GitHub App installation access token.

    .DESCRIPTION
        Authenticates as a GitHub App and exchanges a short-lived JWT for an installation
        access token. The installation access token can be used to make GitHub API requests
        on behalf of the installed GitHub App (e.g., cloning repositories, creating issues).

        The token is valid for one hour.

    .PARAMETER AppId
        The numeric GitHub App ID found on the App's settings page.

    .PARAMETER InstallationId
        The numeric installation ID for the GitHub App installation. This can be found by
        calling the GitHub API: GET /app/installations (authenticated as the App using a JWT).

    .PARAMETER PrivateKeyPath
        The file system path to the GitHub App's RSA private key in PEM format (.pem file).

    .PARAMETER Permissions
        An optional hashtable of permission scopes to request for the token. If omitted,
        all permissions granted to the installation are requested. Example:
        @{ contents = 'read'; issues = 'write' }

    .EXAMPLE
        $result = Get-GitHubInstallationToken -AppId 12345 -InstallationId 67890 -PrivateKeyPath './my-github-app.pem'
        Write-Host $result.Token

        Gets a full-permission installation access token.

    .EXAMPLE
        $result = Get-GitHubInstallationToken -AppId 12345 -InstallationId 67890 -PrivateKeyPath './my-github-app.pem' -Permissions @{ contents = 'read' }
        Write-Host "Token expires at: $($result.ExpiresAt)"

        Gets a scoped installation access token with read-only access to repository contents.

    .OUTPUTS
        PSCustomObject with the following properties:
          Token     [string]  — The installation access token.
          ExpiresAt [string]  — ISO 8601 timestamp when the token expires (typically 1 hour).

    .NOTES
        Requires PowerShell 7.0 or later.
        GitHub documentation: https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/authenticating-as-a-github-app-installation
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, HelpMessage = 'The numeric GitHub App ID.')]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$AppId,

        [Parameter(Mandatory, HelpMessage = 'The numeric GitHub App installation ID.')]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$InstallationId,

        [Parameter(Mandatory, HelpMessage = 'Path to the GitHub App RSA private key (.pem) file.')]
        [ValidateScript({
            if (-not (Test-Path -Path $_ -PathType Leaf)) {
                throw "Private key file not found: $_"
            }
            return $true
        })]
        [string]$PrivateKeyPath,

        [Parameter(HelpMessage = 'Optional hashtable of permission scopes for the token.')]
        [hashtable]$Permissions
    )

    $jwt = New-GitHubAppJWT -AppId $AppId -PrivateKeyPath $PrivateKeyPath

    $uri = "https://api.github.com/app/installations/$InstallationId/access_tokens"
    $headers = @{
        Authorization        = "Bearer $jwt"
        Accept               = 'application/vnd.github+json'
        'X-GitHub-Api-Version' = '2022-11-28'
    }

    $invokeParams = @{
        Uri     = $uri
        Method  = 'POST'
        Headers = $headers
    }

    if ($Permissions -and $Permissions.Count -gt 0) {
        $invokeParams.Body        = (@{ permissions = $Permissions } | ConvertTo-Json -Compress)
        $invokeParams.ContentType = 'application/json'
    }

    $response = Invoke-RestMethod @invokeParams

    return [PSCustomObject]@{
        Token     = $response.token
        ExpiresAt = $response.expires_at
    }
}
