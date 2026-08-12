class cmsEncryption {

    [object] encryptString([object] $___methodParams) {
        $___methodParams.stringData ??= $null
        $___methodParams.encryptionCert ??= $null

        $out = @{
            successState   = $false
            errorMessage = ''
            data         = $null
        }

        if ($null -ne $___methodParams.stringData) {
            $cert = Get-ChildItem -Path Cert:\ -Recurse | Where-Object FriendlyName -EQ $___methodParams.encryptionCert

            if ($null -ne $cert) {
                $out.data = Protect-CmsMessage -To $cert -Content $___methodParams.stringData -ErrorAction SilentlyContinue
                $out.successState = $?
                return $out
            }
            else {
                $out.errorMessage = "Could not get certificate $($___methodParams.encryptionCert)"
                return $out
            }
        }
        else {
            $out.errorMessage = 'Invalid Parameters'
            return $out
        }
    }

    [object] decryptString([object] $___methodParams) {
        $___methodParams.stringData ??= $null
        $___methodParams.encryptionCert ??= $null

        $out = @{
            successState   = $false
            errorMessage = ''
            data         = $null
        }

        if ($null -ne $___methodParams.stringData) {
            $cert = Get-ChildItem -Path Cert:\ -Recurse | Where-Object FriendlyName -EQ $___methodParams.encryptionCert

            if ($null -ne $cert) {
                $out.data = Unprotect-CmsMessage -To $cert -Content $___methodParams.stringData -ErrorAction SilentlyContinue
                $out.successState = $?
                
                if ($out.successState -ne $false) {
                    return $out
                }
                else {
                    $out.errorMessage = 'Could not decrypt data'
                    return $out
                }
            }
            else {
                $out.errorMessage = "Could not get certificate $($___methodParams.encryptionCert)"
                return $out
            }
        }
        else {
            $out.errorMessage = 'Invalid Parameters'
            return $out
        }
    }

    [object] encryptStringToFile([object] $___methodParams) {
        $___methodParams.stringData ??= $null
        $___methodParams.filePath ??= $null
        $___methodParams.encryptionCert ??= $null

        $out = @{
            successState   = $false
            errorMessage = ''
        }

        if ($null -ne $___methodParams.stringData -and $null -ne $___methodParams.filePath) {
            $cert = Get-ChildItem -Path Cert:\ -Recurse | Where-Object FriendlyName -EQ $___methodParams.encryptionCert

            if ($null -ne $cert) {
                New-Item -Path $___methodParams.filePath -ItemType File -Force | Out-Null
                Protect-CmsMessage -To $cert -Content $___methodParams.stringData -OutFile $___methodParams.filePath -ErrorAction SilentlyContinue
                $out.successState = $?
                
                if ($out.successState -ne $false) {
                    return $out
                }
                else {
                    $out.errorMessage = 'Could not encrypt data'
                    return $out
                }
            }
            else {
                $out.errorMessage = "Could not get certificate $($___methodParams.encryptionCert)"
                return $out
            }
        }
        else {
            $out.errorMessage = 'Invalid Parameters'
            return $out
        }
    }

    [object] decryptStringFromFile([object] $___methodParams) {
        $___methodParams.filePath ??= $null
        $___methodParams.encryptionCert ??= $null

        $out = @{
            successState   = $false
            errorMessage = ''
            data         = $null
        }

        if ($null -ne $___methodParams.filePath -and $null -ne $___methodParams.encryptionCert) {
            $cert = Get-ChildItem -LiteralPath Cert:\ -Recurse | Where-Object FriendlyName -EQ $___methodParams.encryptionCert

            if ($null -ne $cert) {
                $out.data = Unprotect-CmsMessage -To $cert -LiteralPath $___methodParams.filePath -ErrorAction SilentlyContinue
                $out.successState = $?
                
                if ($out.successState -ne $false) {
                    return $out
                }
                else {
                    $out.errorMessage = 'Could not decrypt data'
                    return $out
                }
            }
            else {
                $out.errorMessage = "Could not get certificate $($___methodParams.encryptionCert)"
                return $out
            }
        }
        else {
            $out.errorMessage = 'Invalid Parameters'
            return $out
        }
    }
}

<#
$cmsEncryption = [cmsEncryption]::new()

#encrypt string to variable
$encstring = $cmsEncryption.encryptString(@{
    stringData = 'sample string'
    encryptionCert = 'cert_FriendlyName'
})

#save encrypted string to file
$cmsEncryption.encryptStringToFile(@{
    stringData = 'sample string'
    encryptionCert = 'cert_FriendlyName'
    filePath = 'D:\encflags\somefilename.enc'
})


#save encrypted data structure to file and read it back
$data = @{
    hostname = 'somehostname.domain.com'
    username = 'some username'
    password = 'some password'
    port     = 22
    otherProperties = @{
        prop1 = 'value1'
        prop2 = 'value2'
    }
}

$cmsEncryption.encryptStringToFile(@{
    stringData = $($data | ConvertTo-Json)
    encryptionCert = 'cert_FriendlyName'
    filePath = 'D:\encflags\somefilename.enc'
})



$encData = $cmsEncryption.decryptStringFromFile(@{
        filePath       = 'D:\encflags\somefilename.enc'
        encryptionCert = 'cert_FriendlyName'
    })

if ($encData.successState -eq $true) {
    $decryptedData = $encData.data | ConvertFrom-Json
}
else {
    Write-Host $encData.errorMessage -ForegroundColor Red
    exit
}
#>