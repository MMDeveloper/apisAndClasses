class passwordState {
    hidden [string] $apiKey = ''
    hidden [string] $apiBase = ''

    passwordState([hashtable] $methodParams) {
        $methodParams.apiKey ??= ''
        $methodParams.apiBase ??= ''
        
        $this.apiKey = $methodParams.apiKey
        $this.apiBase = $methodParams.apiBase
    }

    [object] doAPIRequest([hashtable] $methodParams) {
        $methodParams.method ??= ''
        $methodParams.url ??= ''
        $methodParams.body ??= $null
        $methodParams.headers ??= @{}
        $methodParams.headers.Add('APIKey', $this.apiKey)
        $methodParams.headers.Add('Content-Type', 'application/json')

        $methodParams.url = "$($this.apiBase)$($methodParams.url)"

        #Write-Host $methodParams

        $response = Invoke-RestMethod -Method $methodParams.method -Uri $methodParams.url -Header $methodParams.headers -Body $methodParams.body

        return $response
    }

    [object] getPasswordById([int] $passwordId) {
        $response = $this.doAPIRequest(@{
                method = 'GET'
                url    = "/passwords/$($passwordId)"
            })

        return $response
    }

    [object] updatePassword([int] $passwordId, [securestring] $newPassword) {
        $response = $this.doAPIRequest(@{
                method = 'PUT'
                url    = '/passwords'
                body   = @{
                    PasswordID = $passwordId
                    password   = ($newPassword | ConvertFrom-SecureString -AsPlainText)
                } | ConvertTo-Json
            })

        return $response
    }
}

<#
$passwordState = [passwordState]::new(@{
        apiKey  = 'asdfasdfasdfasdfasdfas'
        apiBase = 'https://pwmanager.mydomain.edu/api'
    })

#get password by ID
$password = $passwordState.getPasswordById(584)
#or
$result = $passwordState.doAPIRequest(@{
        method = 'GET'
        url    = "/passwords/584"
    })

#update password by id
$newPassword = 'some password' | ConvertTo-SecureString -AsPlainText -Force
$passwordState.updatePassword(585, $newPassword)
#>