function New-GitHubAppJWT {
    <#
    .SYNOPSIS
        Generates a JSON Web Token (JWT) for GitHub App authentication.

    .DESCRIPTION
        Creates a signed JWT using the GitHub App's RSA private key (.pem file) and App ID.
        The resulting JWT can be used to authenticate as the GitHub App when making GitHub API
        requests, or to exchange for an installation access token via Get-GitHubInstallationToken.

        The JWT is signed using RS256 (RSA with SHA-256) and is valid for the specified number
        of seconds (maximum 600 seconds / 10 minutes, as required by GitHub).

        The issued-at time (iat) is set 60 seconds in the past to account for clock skew
        between the local machine and GitHub's servers.

    .PARAMETER AppId
        The numeric GitHub App ID found on the App's settings page.

    .PARAMETER PrivateKeyPath
        The file system path to the GitHub App's RSA private key in PEM format (.pem file).

    .PARAMETER ExpirationSeconds
        The number of seconds from now until the JWT expires. Must be between 1 and 600
        (10 minutes). Defaults to 600.

    .EXAMPLE
        $jwt = New-GitHubAppJWT -AppId 12345 -PrivateKeyPath './my-github-app.pem'

        Generates a JWT for GitHub App ID 12345 using the specified private key with
        the default 10-minute expiration.

    .EXAMPLE
        $jwt = New-GitHubAppJWT -AppId 12345 -PrivateKeyPath './my-github-app.pem' -ExpirationSeconds 300

        Generates a JWT that expires in 5 minutes.

    .OUTPUTS
        System.String
        Returns the JWT as a dot-separated base64url string: <header>.<payload>.<signature>

    .NOTES
        Requires PowerShell 7.0 or later.
        GitHub documentation: https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-json-web-token-jwt-for-a-github-app
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, HelpMessage = 'The numeric GitHub App ID.')]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$AppId,

        [Parameter(Mandatory, HelpMessage = 'Path to the GitHub App RSA private key (.pem) file.')]
        [ValidateScript({
            if (-not (Test-Path -Path $_ -PathType Leaf)) {
                throw "Private key file not found: $_"
            }
            return $true
        })]
        [string]$PrivateKeyPath,

        [Parameter(HelpMessage = 'Seconds until JWT expiration (1-600). Defaults to 600.')]
        [ValidateRange(1, 600)]
        [int]$ExpirationSeconds = 600
    )

    if ($PSVersionTable.PSVersion.Major -lt 7) {
        throw 'New-GitHubAppJWT requires PowerShell 7.0 or later.'
    }

    $pemContent = Get-Content -Path $PrivateKeyPath -Raw

    $rsa = [System.Security.Cryptography.RSA]::Create()
    try {
        $rsa.ImportFromPem($pemContent)
    }
    catch {
        throw "Failed to import private key from '$PrivateKeyPath': $_"
    }

    # JWT Header
    $headerJson = '{"alg":"RS256","typ":"JWT"}'
    $headerEncoded = ConvertTo-Base64Url -Bytes ([System.Text.Encoding]::UTF8.GetBytes($headerJson))

    # JWT Payload — iat is 60 seconds in the past to handle clock drift
    $now = [System.DateTimeOffset]::UtcNow
    $iat = $now.ToUnixTimeSeconds() - 60
    $exp = $now.ToUnixTimeSeconds() + $ExpirationSeconds
    $payloadJson = "{`"iat`":$iat,`"exp`":$exp,`"iss`":$AppId}"
    $payloadEncoded = ConvertTo-Base64Url -Bytes ([System.Text.Encoding]::UTF8.GetBytes($payloadJson))

    # Signature
    $signingInput = "$headerEncoded.$payloadEncoded"
    $signingInputBytes = [System.Text.Encoding]::UTF8.GetBytes($signingInput)
    $signature = $rsa.SignData(
        $signingInputBytes,
        [System.Security.Cryptography.HashAlgorithmName]::SHA256,
        [System.Security.Cryptography.RSASignaturePadding]::Pkcs1
    )
    $signatureEncoded = ConvertTo-Base64Url -Bytes $signature

    return "$signingInput.$signatureEncoded"
}
