BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' 'GitHubAppTokens.psd1'
    Import-Module (Resolve-Path $modulePath) -Force
}

Describe 'Get-GitHubInstallationToken' {
    BeforeAll {
        $script:testRsa = [System.Security.Cryptography.RSA]::Create(2048)
        $script:testPemPath = Join-Path $TestDrive 'test-key.pem'
        $script:testPem = $script:testRsa.ExportRSAPrivateKeyPem()
        Set-Content -Path $script:testPemPath -Value $script:testPem -NoNewline
        $script:testPemBase64 = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($script:testPem))
    }

    AfterAll {
        if ($script:testRsa) { $script:testRsa.Dispose() }
    }

    Context 'Parameter validation' {
        It 'Should throw when AppId is less than 1' {
            { Get-GitHubInstallationToken -AppId 0 -InstallationId 1 -PrivateKeyPath $script:testPemPath } | Should -Throw
        }

        It 'Should throw when InstallationId is less than 1' {
            { Get-GitHubInstallationToken -AppId 1 -InstallationId 0 -PrivateKeyPath $script:testPemPath } | Should -Throw
        }

        It 'Should throw when PrivateKeyPath does not exist' {
            { Get-GitHubInstallationToken -AppId 1 -InstallationId 1 -PrivateKeyPath '/nonexistent/key.pem' } | Should -Throw
        }

        It 'Should throw when PrivateKeyPemBase64 is not valid base64' {
            { Get-GitHubInstallationToken -AppId 1 -InstallationId 1 -PrivateKeyPemBase64 'not-base64@@@' } | Should -Throw
        }
    }

    Context 'API call behaviour (mocked)' {
        BeforeAll {
            # Mock Invoke-RestMethod so no real network call is made
            Mock -CommandName Invoke-RestMethod -ModuleName GitHubAppTokens -MockWith {
                return [PSCustomObject]@{
                    token      = 'ghs_mocktoken1234567890'
                    expires_at = '2099-01-01T00:00:00Z'
                }
            }
        }

        It 'Should return a PSCustomObject with Token and ExpiresAt properties' {
            $result = Get-GitHubInstallationToken -AppId 12345 -InstallationId 67890 -PrivateKeyPath $script:testPemPath
            $result | Should -Not -BeNullOrEmpty
            $result.Token     | Should -Be 'ghs_mocktoken1234567890'
            $result.ExpiresAt | Should -Be '2099-01-01T00:00:00Z'
        }

        It 'Should support PrivateKeyPemBase64 for authentication' {
            $result = Get-GitHubInstallationToken -AppId 12345 -InstallationId 67890 -PrivateKeyPemBase64 $script:testPemBase64
            $result | Should -Not -BeNullOrEmpty
            $result.Token | Should -Be 'ghs_mocktoken1234567890'
        }

        It 'Should call Invoke-RestMethod with a Bearer JWT Authorization header' {
            Get-GitHubInstallationToken -AppId 12345 -InstallationId 67890 -PrivateKeyPath $script:testPemPath
            Should -Invoke Invoke-RestMethod -ModuleName GitHubAppTokens -ParameterFilter {
                $Headers.Authorization -like 'Bearer *.*.*'
            }
        }

        It 'Should call the correct GitHub API endpoint' {
            Get-GitHubInstallationToken -AppId 12345 -InstallationId 67890 -PrivateKeyPath $script:testPemPath
            Should -Invoke Invoke-RestMethod -ModuleName GitHubAppTokens -ParameterFilter {
                $Uri -eq 'https://api.github.com/app/installations/67890/access_tokens'
            }
        }

        It 'Should send a POST request' {
            Get-GitHubInstallationToken -AppId 12345 -InstallationId 67890 -PrivateKeyPath $script:testPemPath
            Should -Invoke Invoke-RestMethod -ModuleName GitHubAppTokens -ParameterFilter {
                $Method -eq 'POST'
            }
        }

        It 'Should include permissions in body when Permissions parameter is supplied' {
            Get-GitHubInstallationToken -AppId 12345 -InstallationId 67890 -PrivateKeyPath $script:testPemPath -Permissions @{ contents = 'read' }
            Should -Invoke Invoke-RestMethod -ModuleName GitHubAppTokens -ParameterFilter {
                $Body -ne $null -and ($Body | ConvertFrom-Json).permissions.contents -eq 'read'
            }
        }

        It 'Should omit body when Permissions parameter is not supplied' {
            Get-GitHubInstallationToken -AppId 12345 -InstallationId 67890 -PrivateKeyPath $script:testPemPath
            Should -Invoke Invoke-RestMethod -ModuleName GitHubAppTokens -ParameterFilter {
                $null -eq $Body
            }
        }
    }
}
