class ellucianCloud {
    hidden [string] $apiKey = ''
    hidden [string] $bearerToken = ''
    [datetime] $nextTokenRefresh = (Get-Date)
    [int] $bearerTokenRefreshMinutes = 5

    [string] $apiURLBase = 'https://integrate.elluciancloud.com/'

    ellucianCloud([hashtable] $methodParams) {
        $methodParams.apikey ??= ''
        $this.apiKey = $methodParams.apikey
    }

    [void] refreshTokenIfNeeded() {
        if ($this.bearerToken -eq '' -or (Get-Date) -gt $this.nextTokenRefresh) {
            try {
                $this.bearerToken = Invoke-RestMethod -Uri ($this.apiURLBase + 'auth?expirationMinutes=10') -Headers @{
                    Authorization = 'Bearer ' + $this.apiKey
                    Accept        = 'application/json'
                } -Method Post

                $this.nextTokenRefresh = (Get-Date).AddMinutes($this.bearerTokenRefreshMinutes)
            }
            catch {
                Write-Host "Error: $_"
            }
        }
    }

    [object] doAPIRequest([hashtable] $methodParams) {
        $this.refreshTokenIfNeeded()
        $methodParams.url ??= ''
        $methodParams.requestMethod ??= ''
        $methodParams.body ??= ''
        $methodParams.urlParams ??= ''

        $uri = $this.apiURLBase + 'api/' + $methodParams.url + '?' + $methodParams.urlParams

        $headers = @{
            'Content-Type' = 'application/json'
            Accept         = 'application/json'
            Authorization  = 'Bearer ' + $this.bearerToken
        }

        return Invoke-RestMethod -Uri $uri -Headers $headers -Body $methodParams.body -Method $methodParams.requestMethod
    }

    [string] hashtableToURLParams([hashtable] $hashTable) {
        return ($hashTable.GetEnumerator() | ForEach-Object { "$([System.Web.HttpUtility]::UrlEncode($_.Key))=$([System.Web.HttpUtility]::UrlEncode($_.Value))" }) -join '&'
    }
}


<#
$ellucianCloud = [ellucianCloud]::new(@{
        apikey = 'api-guid-key-here'
    })

$ellucianCloud.doAPIRequest(@{
        url           = 'identification-biographical'
        requestMethod = 'Get'
        urlParams     = $ellucianCloud.hashtableToURLParams(@{
                id = 'User-Id-Here'
            })
    })

$ellucianCloud.doAPIRequest(@{
        url           = 'identification-email'
        requestMethod = 'Get'
        urlParams     = $ellucianCloud.hashtableToURLParams(@{
                id = 'User-Id-Here'
            })
    })
    
$ellucianCloud.doAPIRequest(@{
        url           = 'employees'
        requestMethod = 'Get'
        urlParams     = $ellucianCloud.hashtableToURLParams(@{
                criteria = (@{ 'status' = 'terminated' } | ConvertTo-Json -Compress)
            })
    })
#>