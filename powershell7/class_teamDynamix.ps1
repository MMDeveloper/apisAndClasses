class teamDynamix {
    hidden [string] $BEID = ''
    hidden [string] $WebServicesKey = ''
    hidden [string] $webAPIURLBase = ''
    hidden [System.Security.SecureString] $bearerKey

    teamDynamix([hashtable]$params) {
        $this.BEID = $params.BEID
        $this.WebServicesKey = $params.WebServicesKey
        $this.webAPIURLBase = $params.webAPIURLBase
    }

    [void] refreshOAuthToken() {
        #get OAuth bearer token
        $returnedBearerKey = Invoke-RestMethod -Uri "$($this.webAPIURLBase)/auth/loginadmin" -Method 'POST' -ContentType 'application/json' -Body $(@{BEID = $this.BEID; WebServicesKey = $this.WebServicesKey } | ConvertTo-Json)

        #if request failed
        if ($? -eq $false) {
            Write-Host -ForegroundColor Red 'Cannot connect to API'
            exit
        }
        else {
            #store token
            $this.bearerKey = ConvertTo-SecureString -String $returnedBearerKey -AsPlainText -Force
        }
    }

    [object] makeCURLRequest([string]$verb = 'GET', [string]$endpoint = '', [string]$body = '', [hashtable]$extraHeaders = @{}) {
        $headers = @{}

        if ($extraHeaders -ne @{}) {
            foreach ($key in $extraHeaders.Keys) {
                $headers[$key] = $extraHeaders[$key]
            }
        }

        if ($verb -like 'GET') {
            $ret = Invoke-WebRequest -Uri "$($this.webAPIURLBase)$endpoint" -Method $verb -ContentType 'application/json' -Headers $headers -Authentication OAuth -Token $this.bearerKey
        }
        else {
            $ret = Invoke-WebRequest -Uri "$($this.webAPIURLBase)$endpoint" -Method $verb -ContentType 'application/json' -Body $body -Headers $headers -Authentication OAuth -Token $this.bearerKey
        }

        if ($ret.StatusCode -eq 200) {
            if ($ret.Headers['X-RateLimit-Remaining'] -le 1) {
                Write-Host -ForegroundColor Cyan 'Hitting API Rate Limit, 60-sec Cooldown'
                Start-Sleep -Seconds 60
            }
            else {
            }

            if ($ret.Content) {
                return $ret.Content | ConvertFrom-Json
            }
            else {
                return '{}' | ConvertFrom-Json
            }
        }
        else {
            Write-Host -ForegroundColor Red 'API Error'
            Write-Output $ret
            return $false
        }
    }

    [bool] uploadPeopleAPIFile([string]$file, [hashtable]$apiOptions = @{}) {

        if (Test-Path -PathType Leaf -LiteralPath $file) {
            $defaultAPIOptions = @{
                AllowIsActiveChanges     = 'false'
                AllowSecurityRoleChanges = 'false'
                AllowApplicationChanges  = 'false'
                NotifyEmailAddresses     = 'techs@sjrstate.edu'
            }

            if ($apiOptions -ne @{}) {
                foreach ($key in $apiOptions.Keys) {
                    $defaultAPIOptions[$key] = $apiOptions[$key]
                }
            }

            $FileStream = [System.IO.FileStream]::new($file, [System.IO.FileMode]::Open)
            $FileHeader = [System.Net.Http.Headers.ContentDispositionHeaderValue]::new('form-data')
            $FileHeader.Name = 'tdusers.xlsx'
            $FileHeader.FileName = Split-Path -Leaf $file
            $FileContent = [System.Net.Http.StreamContent]::new($FileStream)
            $FileContent.Headers.ContentDisposition = $FileHeader
            $FileContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')

            $MultipartContent = [System.Net.Http.MultipartFormDataContent]::new()
            $MultipartContent.Add($FileContent)

            try {
                return Invoke-WebRequest -Uri "$($this.webAPIURLBase)/people/import?AllowIsActiveChanges=$($defaultAPIOptions['AllowIsActiveChanges'])&AllowSecurityRoleChanges=$($defaultAPIOptions['AllowSecurityRoleChanges'])&AllowApplicationChanges=$($defaultAPIOptions['AllowApplicationChanges'])&NotifyEmailAddresses=$($defaultAPIOptions['NotifyEmailAddresses'])" -Body $MultipartContent -Method 'POST' -Authentication OAuth -Token $this.bearerKey
                return $true
            }
            catch {
                Write-Host -ForegroundColor Red 'API Error'
                Write-Output $_
                return $false
            }
        }
        else {
            Write-Host -ForegroundColor Red "$file does not exist"
            return @{}
        }
    }

    [object] get_searchUsers([string]$orgID) {
        #try active users
        $user = $this.makeCURLRequest('POST', '/people/search', $(@{'SearchText' = $orgID; 'IsActive' = $true } | ConvertTo-Json), @{})

        if ($user.Count -eq 0) {
            #try inactive users
            $user = $this.makeCURLRequest('POST', '/people/search', $(@{'SearchText' = $orgID; 'IsActive' = $false } | ConvertTo-Json), @{})
        }
        else {
        }

        return $user
    }

    [object] get_runCustomReportByID([int]$reportID) {
        return $this.makeCURLRequest('GET', "/reports/$($reportID)?withData=true", '', @{})
    }

    [object] get_getUser([string]$orgID) {
        #try active users
        return $this.makeCURLRequest('GET', "/people/{$orgID}", '', @{})
    }

    [bool] set_deactivateUser([string]$UID) {
        $this.makeCURLRequest('PUT', "/people/{$UID}/isactive?status=false", '', @{})
        
        return $?
    }

    [bool] set_activateUser([string]$UID) {
        $this.makeCURLRequest('PUT', "/people/{$UID}/isactive?status=true", '', @{})

        return $?
    }

    [bool] set_updateUser([object]$userObject) {
        $this.makeCURLRequest('POST', "/people/{$($userObject[0].UID)}", $($userObject | ConvertTo-Json), @{})

        return $?
    }
}


<#
#create instance of class
$teamDynamix = [teamDynamix]::new(@{
    BEID = '1234-4567-8901-2345'
    WebServicesKey = '6789-0123-4567'
    webAPIURLBase = 'https://tdxsub.domain.tld/TDWebApi/api'
})

#get OAuth bearer token
$teamDynamix.refreshOAuthToken()
#$teamDynamix.get_searchUsers('test')
$teamDynamix.uploadPeopleAPIFile('\\path\to\tdusers.xlsx', @{
        AllowIsActiveChanges     = 'true';
        AllowSecurityRoleChanges = 'true';
        AllowApplicationChanges  = 'true';
        NotifyEmailAddresses     = 'distributionlist@mydomain.edu';
    })
#>