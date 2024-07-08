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
}

<#
$passwordState = [passwordState]::new(@{
        apiKey  = 'asdfasdfasdfasdfasdfas'
        apiBase = 'https://pwmanager.mydomain.edu/api'
    })

$passwordRecord = $passwordState.getPasswordById(584)

#or for the same result (or unimplemented methods)
$passwordRecord = $passwordState.doAPIRequest(@{
        method = 'GET'
        url    = "/passwords/584"
    })
#>