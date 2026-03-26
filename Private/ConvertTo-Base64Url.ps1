# Private helper used by public functions

function ConvertTo-Base64Url {
    <#
    .SYNOPSIS
        Converts a byte array to a base64url-encoded string (RFC 4648 §5).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [byte[]]$Bytes
    )

    return [System.Convert]::ToBase64String($Bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
}
