class haveibeenpwned {
    hidden [string] $baseURL = 'https://haveibeenpwned.com/api/v3/'
    hidden [string] $apiKey = ''

    [void] configInstance([string] $apiKey) {
        $this.apiKey = $apiKey
    }

    [object] doRequest([string] $endpoint, [string] $method, [hashtable] $headers, [object] $body) {
        $headers['hibp-api-key'] = $this.apiKey
        $headers['user-agent'] = 'MF Powershell API Client'
        $uri = $this.baseURL + $endpoint

        $statusCode = ''
        $response = Invoke-RestMethod -Uri $uri -Method $method -Headers $headers -Body $body -StatusCodeVariable 'statusCode'

        return @{
            'statusCode' = $statusCode
            'response'   = $response
        }
    }

    [object] getAllBreachesForEmailAddress([string] $emailAddress) {
        $endpoint = 'breachedaccount/' + $emailAddress + '?truncateResponse=false'
        return $this.doRequest($endpoint, 'GET', @{}, $null)
    }

    [object] getAllBreachedEmailsForDomain([string] $domain) {
        $endpoint = 'breacheddomain/' + $domain
        return $this.doRequest($endpoint, 'GET', @{}, $null)
    }

    [object] getAllSubscribedDomains() {
        $endpoint = 'subscribeddomains'
        return $this.doRequest($endpoint, 'GET', @{}, $null)
    }

    [object] getAllBreachedSitesInSystem() {
        $endpoint = 'breaches'
        return $this.doRequest($endpoint, 'GET', @{}, $null)
    }

    [object] getSingleBreachSiteByName([string] $siteName) {
        $endpoint = 'breach/' + $siteName
        return $this.doRequest($endpoint, 'GET', @{}, $null)
    }

    [object] getMostRecentBreach() {
        $endpoint = 'latestbreach'
        return $this.doRequest($endpoint, 'GET', @{}, $null)
    }

    [object] getAllDataClassesInSystem() {
        $endpoint = 'dataclasses'
        return $this.doRequest($endpoint, 'GET', @{}, $null)
    }

    [object] getAllPastesForAccount([string] $emailAddress) {
        $endpoint = 'pasteaccount/' + $emailAddress
        return $this.doRequest($endpoint, 'GET', @{}, $null)
    }

    [object] getSubscriptionStatus() {
        $endpoint = 'subscription/status'
        return $this.doRequest($endpoint, 'GET', @{}, $null)
    }
}