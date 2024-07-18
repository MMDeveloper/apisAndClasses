class cmsEncryption {

    [object] encryptString([object] $___methodParams) {
        $___methodParams.stringData ??= $null
        $___methodParams.encryptionCert ??= $null

        $out = @{
            errorState = $false
            errorMessage = ''
            data = $null
        }

        if ($null -ne $___methodParams.stringData) {
            $cert = Get-ChildItem -Path Cert:\ -recurse | Where-Object FriendlyName -eq $___methodParams.encryptionCert

            if ($null -ne $cert) {
                $out.data = Protect-CMSMessage -To $cert -Content $___methodParams.stringData -ErrorAction SilentlyContinue
                $out.errorState = $?
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
            errorState = $false
            errorMessage = ''
            data = $null
        }

        if ($null -ne $___methodParams.stringData) {
            $cert = Get-ChildItem -Path Cert:\ -recurse | Where-Object FriendlyName -eq $___methodParams.encryptionCert

            if ($null -ne $cert) {
                $out.data = Unprotect-CMSMessage -To $cert -Content $___methodParams.stringData -ErrorAction SilentlyContinue
                $out.errorState = $?
                
                if ($out.errorState -ne $false) {
                    return $out
                }
                else {
                    $out.errorMessage = "Could not decrypt data"
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
            errorState = $false
            errorMessage = ''
        }

        if ($null -ne $___methodParams.stringData -and $___methodParams.filePath -ne $null) {
            $cert = Get-ChildItem -Path Cert:\ -recurse | Where-Object FriendlyName -eq $___methodParams.encryptionCert

            if ($null -ne $cert) {
                Protect-CMSMessage -To $cert -Content $___methodParams.stringData -OutFile $___methodParams.filePath -ErrorAction SilentlyContinue
                $out.errorState = $?
                
                if ($out.errorState -ne $false) {
                    return $out
                }
                else {
                    $out.errorMessage = "Could not encrypt data"
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
            errorState   = $false
            errorMessage = ''
            data         = $null
        }

        if ($null -ne $___methodParams.filePath -and $null -ne $___methodParams.encryptionCert) {
            $cert = Get-ChildItem -LiteralPath Cert:\ -Recurse | Where-Object FriendlyName -EQ $___methodParams.encryptionCert

            if ($null -ne $cert) {
                $out.data = Unprotect-CmsMessage -To $cert -LiteralPath $___methodParams.filePath -ErrorAction SilentlyContinue
                $out.errorState = $?
                
                if ($out.errorState -ne $false) {
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
#>