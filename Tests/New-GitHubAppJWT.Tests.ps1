BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' 'GitHubAppTokens.psd1'
    Import-Module (Resolve-Path $modulePath) -Force
}

Describe 'New-GitHubAppJWT' {
    BeforeAll {
        # Generate a throw-away 2048-bit RSA key for testing
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
            { New-GitHubAppJWT -AppId 0 -PrivateKeyPath $script:testPemPath } | Should -Throw
        }

        It 'Should throw when PrivateKeyPath does not exist' {
            { New-GitHubAppJWT -AppId 12345 -PrivateKeyPath '/nonexistent/path/key.pem' } | Should -Throw
        }

        It 'Should throw when ExpirationSeconds is 0' {
            { New-GitHubAppJWT -AppId 12345 -PrivateKeyPath $script:testPemPath -ExpirationSeconds 0 } | Should -Throw
        }

        It 'Should throw when ExpirationSeconds exceeds 600' {
            { New-GitHubAppJWT -AppId 12345 -PrivateKeyPath $script:testPemPath -ExpirationSeconds 601 } | Should -Throw
        }

        It 'Should throw when PrivateKeyPemBase64 is not valid base64' {
            { New-GitHubAppJWT -AppId 12345 -PrivateKeyPemBase64 'not-base64@@@' } | Should -Throw
        }
    }

    Context 'JWT structure' {
        BeforeAll {
            $script:jwt = New-GitHubAppJWT -AppId 12345 -PrivateKeyPath $script:testPemPath
        }

        It 'Should return a non-empty string' {
            $script:jwt | Should -Not -BeNullOrEmpty
            $script:jwt | Should -BeOfType [string]
        }

        It 'Should consist of exactly three dot-separated parts' {
            ($script:jwt -split '\.').Count | Should -Be 3
        }

        It 'Should not contain base64 padding characters' {
            $script:jwt | Should -Not -Match '='
        }

        It 'Should generate JWT using PrivateKeyPemBase64' {
            $jwt = New-GitHubAppJWT -AppId 12345 -PrivateKeyPemBase64 $script:testPemBase64
            $jwt | Should -Not -BeNullOrEmpty
            ($jwt -split '\.').Count | Should -Be 3
        }
    }

    Context 'JWT header' {
        It 'Should decode to alg RS256 and typ JWT' {
            $jwt = New-GitHubAppJWT -AppId 12345 -PrivateKeyPath $script:testPemPath
            $headerB64 = ($jwt -split '\.')[0]
            $padded = $headerB64.Replace('-', '+').Replace('_', '/')
            switch ($padded.Length % 4) {
                2 { $padded += '==' }
                3 { $padded += '=' }
            }
            $header = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($padded)) | ConvertFrom-Json
            $header.alg | Should -Be 'RS256'
            $header.typ | Should -Be 'JWT'
        }
    }

    Context 'JWT payload' {
        It 'Should contain correct iss claim matching AppId' {
            $appId = 99999
            $jwt = New-GitHubAppJWT -AppId $appId -PrivateKeyPath $script:testPemPath
            $payloadB64 = ($jwt -split '\.')[1]
            $padded = $payloadB64.Replace('-', '+').Replace('_', '/')
            switch ($padded.Length % 4) {
                2 { $padded += '==' }
                3 { $padded += '=' }
            }
            $payload = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($padded)) | ConvertFrom-Json
            $payload.iss | Should -Be $appId
        }

        It 'Should set iat approximately 60 seconds in the past' {
            $jwt = New-GitHubAppJWT -AppId 12345 -PrivateKeyPath $script:testPemPath
            $payloadB64 = ($jwt -split '\.')[1]
            $padded = $payloadB64.Replace('-', '+').Replace('_', '/')
            switch ($padded.Length % 4) {
                2 { $padded += '==' }
                3 { $padded += '=' }
            }
            $payload = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($padded)) | ConvertFrom-Json
            $now = [System.DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            # iat should be ~60 seconds in the past (allow ±5 s tolerance for test execution time)
            $payload.iat | Should -BeGreaterOrEqual ($now - 65)
            $payload.iat | Should -BeLessOrEqual ($now - 55)
        }

        It 'Should set exp according to ExpirationSeconds' {
            $expSeconds = 300
            $jwt = New-GitHubAppJWT -AppId 12345 -PrivateKeyPath $script:testPemPath -ExpirationSeconds $expSeconds
            $payloadB64 = ($jwt -split '\.')[1]
            $padded = $payloadB64.Replace('-', '+').Replace('_', '/')
            switch ($padded.Length % 4) {
                2 { $padded += '==' }
                3 { $padded += '=' }
            }
            $payload = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($padded)) | ConvertFrom-Json
            $now = [System.DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            # exp should be ~ExpirationSeconds from now (allow ±5 s tolerance)
            $payload.exp | Should -BeGreaterOrEqual ($now + $expSeconds - 5)
            $payload.exp | Should -BeLessOrEqual ($now + $expSeconds + 5)
        }

        It 'Should default ExpirationSeconds to 600' {
            $jwt = New-GitHubAppJWT -AppId 12345 -PrivateKeyPath $script:testPemPath
            $payloadB64 = ($jwt -split '\.')[1]
            $padded = $payloadB64.Replace('-', '+').Replace('_', '/')
            switch ($padded.Length % 4) {
                2 { $padded += '==' }
                3 { $padded += '=' }
            }
            $payload = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($padded)) | ConvertFrom-Json
            $now = [System.DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            $payload.exp | Should -BeGreaterOrEqual ($now + 595)
            $payload.exp | Should -BeLessOrEqual ($now + 605)
        }
    }

    Context 'JWT signature' {
        It 'Should produce a valid RS256 signature verifiable with the public key' {
            $jwt = New-GitHubAppJWT -AppId 12345 -PrivateKeyPath $script:testPemPath
            $parts = $jwt -split '\.'
            $signingInput = "$($parts[0]).$($parts[1])"
            $sigB64 = $parts[2].Replace('-', '+').Replace('_', '/')
            switch ($sigB64.Length % 4) {
                2 { $sigB64 += '==' }
                3 { $sigB64 += '=' }
            }
            $sigBytes = [System.Convert]::FromBase64String($sigB64)
            $inputBytes = [System.Text.Encoding]::UTF8.GetBytes($signingInput)

            $isValid = $script:testRsa.VerifyData(
                $inputBytes,
                $sigBytes,
                [System.Security.Cryptography.HashAlgorithmName]::SHA256,
                [System.Security.Cryptography.RSASignaturePadding]::Pkcs1
            )
            $isValid | Should -Be $true
        }

        It 'Should produce a different JWT on each call (due to timestamp differences)' {
            $jwt1 = New-GitHubAppJWT -AppId 12345 -PrivateKeyPath $script:testPemPath
            Start-Sleep -Seconds 1
            $jwt2 = New-GitHubAppJWT -AppId 12345 -PrivateKeyPath $script:testPemPath
            # Timestamps will differ, so payloads (and therefore signatures) should differ
            ($jwt1 -split '\.')[1] | Should -Not -Be (($jwt2 -split '\.')[1])
        }
    }
}
