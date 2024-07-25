class ellucianCloud {
    hidden [string] $apiKey = ''
    hidden [string] $bearerToken = ''
    [datetime] $nextTokenRefresh = (Get-Date)
    hidden [int] $bearerTokenRefreshMinutes = 5
    hidden [string] $apiURLBase = 'https://integrate.elluciancloud.com/'
    [string] $lastURI = ''

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
        $methodParams.headerOverrides ??= @()

        $uri = $this.apiURLBase + $methodParams.url + '?' + $methodParams.urlParams
        $this.lastURI = $uri

        $headers = @{
            'Content-Type' = 'application/json'
            Accept         = 'application/json'
            Authorization  = 'Bearer ' + $this.bearerToken
        }

        if ($methodParams.headerOverrides.Count -gt 0) {
            $methodParams.headerOverrides.GetEnumerator() | ForEach-Object {
                $headers[$_.Name] = $_.Value
            }
        }

        $returnObject = @{
            success = $false
            errors  = @()
            data    = @{}
        }

        try {
            $returnObject.success = $true
            $returnObject.data = Invoke-RestMethod -Uri $uri -Headers $headers -Body $methodParams.body -Method $methodParams.requestMethod

            return $returnObject
        }
        catch {
            $returnObject.success = $false
            $returnObject.errors += $_
            return $returnObject
        }
    }

    [string] hashtableToURLParams([hashtable] $hashTable) {
        <#return ($hashTable.GetEnumerator() | ForEach-Object { 
                "$([System.Web.HttpUtility]::UrlEncode($_.Key))=$([System.Web.HttpUtility]::UrlEncode($_.Value))"
            }) -join '&'#>
             
        return ($hashTable.GetEnumerator() | ForEach-Object { 
                "$([System.Web.HttpUtility]::UrlEncode($_.Key))=$($_.Value)"
            }) -join '&'
    }
    
    [string] getLastURI() {
        return $this.lastURI
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
                id = 'someERPUserID'
            })
    })

$ellucianCloud.doAPIRequest(@{
        url           = 'identification-email'
        requestMethod = 'Get'
        urlParams     = $ellucianCloud.hashtableToURLParams(@{
                id = 'someERPUserID'
            })
    })
    
$ellucianCloud.doAPIRequest(@{
        url           = 'employees'
        requestMethod = 'Get'
        headerOverrides = @{
                'Accept' = 'application/vnd.hedtech.integration.v12+json'
        }
        urlParams       = $ellucianCloud.hashtableToURLParams(@{
                        #limit    = 1
                        criteria = @{
                                contract = @{
                                        type = 'fullTime'
                                } 
                        } | ConvertTo-Json -Compress
                })
    })
#>