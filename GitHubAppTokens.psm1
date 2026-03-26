# GitHubAppTokens.psm1
# Dot-sources all private helpers and public cmdlets so they are available
# when the module is imported.

$Private = @(Get-ChildItem -Path "$PSScriptRoot/Private/*.ps1" -ErrorAction SilentlyContinue)
$Public  = @(Get-ChildItem -Path "$PSScriptRoot/Public/*.ps1"  -ErrorAction SilentlyContinue)

foreach ($file in @($Private + $Public)) {
    try {
        . $file.FullName
    }
    catch {
        Write-Error "Failed to import '$($file.FullName)': $_"
    }
}

Export-ModuleMember -Function $Public.BaseName
