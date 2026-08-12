class Utilities {
    hidden [object] $colorCodes = @{
        helptexts       = @{
            unhilighted = "`e[93m"
            highlighted = "`e[31m"
        }

        errorMessageBox = @{
            title = "`e[93m"
            text  = "`e[31m"
        }

        easteregg       = @{
            color = "`e[94m"
        }

        stopColor       = "`e[0m"
    }

    [bool] resetUserPassword([object] $___methodParams) {
        $___methodParams.targetUser ??= $null
        $___methodParams.passwordLength ??= 20
        $___methodParams.elevatedCredential ??= $null
        $___methodParams.serverName ??= $null

        $password = $this.getRandomAlphaNumericString($___methodParams.passwordLength)

        if ($null -eq $___methodParams.elevatedCredential) {
            Set-ADAccountPassword -Identity $___methodParams.targetUser.ObjectGuid -Reset -NewPassword (ConvertTo-SecureString -AsPlainText $password -Force) -Server $___methodParams.serverName
        }
        else {
            Set-ADAccountPassword -Identity $___methodParams.targetUser.ObjectGuid -Reset -NewPassword (ConvertTo-SecureString -AsPlainText $password -Force) -Credential $___methodParams.elevatedCredential -Server $___methodParams.serverName
        }
        return $?
    }

    [bool] moveUserAccountToSameOUAsAnotherUser([object] $___methodParams) {
        $___methodParams.userCopyingFROM ??= $null
        $___methodParams.userCopyingTO ??= $null
        $___methodParams.elevatedCredential ??= $null
        $___methodParams.serverName ??= $null

        $ou = @()
        $tempOU = $___methodParams.userCopyingFROM.DistinguishedName.split(',')
        foreach ($string in $tempOU) {
            if ($string -like 'OU=*' -or $string -like 'DC=*') {
                $ou += $string
            }
        }
        $ou = $ou -join ','
        $ou
        Move-ADObject -Identity $___methodParams.userCopyingTO.ObjectGuid -TargetPath $ou -Credential $___methodParams.elevatedCredential -Server $___methodParams.serverName

        return $?
    }

    [bool] testCredential ([object] $___methodParams) {
        $___methodParams.Credential ??= $null
        $___methodParams.sourceDomain ??= 'domain'

        try {
            Add-Type -AssemblyName System.DirectoryServices.AccountManagement
            if (!$___methodParams.Credential) {
                $___methodParams.Credential = Get-Credential -EA Stop
            }
            if ($___methodParams.Credential.username.split('\').count -ne 2) {
                throw "You haven't entered credentials in DOMAIN\USERNAME format. Given value : $($___methodParams.Credential.Username)"
            }

            $DomainName = $___methodParams.Credential.username.Split('\')[0].ToLower()
            $UserName = $___methodParams.Credential.username.Split('\')[1]
            $Password = $___methodParams.Credential.GetNetworkCredential().Password

            $PC = $null
            switch ($___methodParams.sourceDomain) {
                'domain' {
                    $PC = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Domain, $DomainName)
                }

                'either' {
                    switch ($DomainName) {
                        { $_ -like 'admin' -or $_ -like 'admin.net' } {
                            $PC = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Domain, $DomainName)
                        }
                        default {
                            $PC = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Machine)
                        }
                    }
                }

                'machine' {
                    $PC = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Machine)                    
                }

                default {
                    $PC = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Domain, $DomainName)
                }
            }
            
            if ($PC.ValidateCredentials($UserName, $Password)) {
                Write-Verbose "Credential validation successful for $($___methodParams.Credential.Username)"
                return $True
            }
            else {
                throw "Credential validation failed for $($___methodParams.Credential.Username)"
            }
        }
        catch {
            Write-Verbose "Error occurred while performing credential validation. $_"
            return $False
        }
    }

    [object] getCredentialLoop([object] $___methodParams) {
        $___methodParams.prefixMessage ??= ''
        $___methodParams.username ??= $null
        $___methodParams.sourceDomain ??= 'domain'
        $___methodParams.doValidate ??= $true
        $getCredentialLoop_limit = 3

        $output = @{
            errorStatus  = $false
            credential   = $null
            errorMessage = ''
        }

        for ($loopIndex = 0; $loopIndex -lt $getCredentialLoop_limit; ++$loopIndex) {
            if ($___methodParams.prefixMessage -ne '') {
                Write-Host $___methodParams.prefixMessage
            }

            $promptMessage = $invalidErrorMessage = ''
            switch ($___methodParams.sourceDomain) {
                'domain' {
                    $promptMessage = "`e[91mPrefix the username with admin\`e[0m"
                    $invalidErrorMessage = 'Invalid credentials, did you prefix the username with "admin\"?'
                }

                'either' {
                    $promptMessage = "`e[91mPrefix the username with admin\ or .\ or PCNAME\`e[0m"
                    $invalidErrorMessage = 'Invalid credentials, did you prefix the username with "admin\"?'
                }

                'machine' {
                    $promptMessage = "`e[91mPrefix the username with .\ or PCNAME\`e[0m"
                    $invalidErrorMessage = 'Invalid credentials, did you prefix the username with ".\" or "PCNAME\"?'
                }

                'basic' {
                    $promptMessage = "`e[91mUsername`e[0m"
                    $invalidErrorMessage = 'Invalid credentials'
                }

                default {
                    $promptMessage = "`e[91mPrefix the username with admin\`e[0m"
                    $invalidErrorMessage = 'Invalid credentials, did you prefix the username with "admin\"?'
                }
            }

            if ($null -ne $___methodParams.username) {
                $output.credential = Get-Credential -UserName $___methodParams.username -Title "Attempt $($loopIndex + 1) of $($getCredentialLoop_limit); Elevated domain credentials to make changes." -Message $promptMessage
            }
            else {
                $output.credential = Get-Credential -Title "Attempt $($loopIndex + 1) of $($getCredentialLoop_limit); Credential Collection." -Message $promptMessage
            }

            if ($___methodParams.doValidate -eq $true) {
                if ($this.testCredential(@{Credential = $output.credential ; sourceDomain = $___methodParams.sourceDomain }) -eq $true) {
                    $output.errorStatus = $true
                    Write-Host 'Credentials Validated!' -ForegroundColor Green
                    break
                }
                else {
                    $output.credential = $null
                    Write-Host $invalidErrorMessage -ForegroundColor Red

                    if ($loopIndex -eq 2) {
                        $emoji = "`u{1F921}"
                        $helpTexts = @{
                            header   = "$($emoji)$($emoji)$($emoji) slow down and breathe $($emoji)$($emoji)$($emoji)"
                            examples = @(
                                @{
                                    message   = 'You doin okay there bud? You want to stop and think about these credentials?'
                                    formatted = "$($this.colorCodes.easteregg.color)You doin okay there bud? You want to stop and think about these credentials?$($this.colorCodes.stopColor)"
                                }
                            )
                        }
                        $this.centerLeftAlignedMenuBox($helpTexts)
                    }
                }
            }
            else {
                $output.errorStatus = $true
                break
            }
        }

        if ($null -eq $output.credential) {
            $output.errorMessage = 'Could not get valid credentials from you'
        }


        return $output
    }

    [void] successOrFail ([bool] $booleanValue) {
        if ($booleanValue -eq $true) {
            Write-Host '***Succeeded!***' -ForegroundColor Green
        }
        else {
            Write-Host '***Failed!***' -ForegroundColor Red
        }
    }

    [string] getRandomAlphaNumericString([int] $length) {
        $randomString = $this.getRandomCharacters(@{
                length           = $length 
                sourceCharacters = 'a'..'z' + 'A'..'Z' + 0..9
            })
        
        $randomString = $this.scrambleString($randomString)

        return $randomString
    }

    [string] scrambleString([string] $inputString) {
        $characterArray = $inputString.ToCharArray()
        $scrambledStringArray = $characterArray | Get-Random -Count $characterArray.Length
        $outputString = -join $scrambledStringArray
        return $outputString
    }

    [string] getRandomCharacters([object] $___methodParams) {
        $___methodParams.length ??= 30
        
        if ($null -eq $___methodParams.sourceCharacters) {
            $___methodParams.sourceCharacters = 'a'..'z' + 'A'..'z' + 0..9
        }

        if ($___methodParams.sourceCharacters -is [string]) {
            $___methodParams.sourceCharacters = $___methodParams.sourceCharacters -split ''
        }

        $randomString = ''
        while ($randomString.Length -lt $___methodParams.length) {
            $randomString += -join $(Get-Random -InputObject $___methodParams.sourceCharacters -Count $___methodParams.length)
        }

        return $randomString.substring(0, $___methodParams.length)
    }

    [string] getRandomUniqueFilename() {
        $randomString = $this.getRandomCharacters(@{
                length           = 30 
                sourceCharacters = 'a'..'z' + 'A'..'Z' + 0..9
            })
        
        $randomString = $this.scrambleString($randomString) + (Get-Date).Ticks

        return $randomString
    }

    [void] renameFile([object] $___methodParams) {
        $___methodParams.currentFile ??= $null
        $___methodParams.newName ??= $null
        $___methodParams.elevatedCredential = $null

        if ($null -ne $___methodParams.currentFile -and $null -ne $___methodParams.newName) {
            if ((Test-Path -PathType Leaf -LiteralPath $___methodParams.currentFile) -eq $true) {
                Rename-Item -LiteralPath $___methodParams.currentFile -NewName $___methodParams.newName -Credential $___methodParams.elevatedCredential
            }
        }
    }

    [object] logRotationDatum([object] $___methodParams) {
        $___methodParams.logPath ??= ''
        $___methodParams.logFilenameKey ??= 'undefined'
        $___methodParams.maxfiles ??= 10

        $___methodParams.maxfiles = ($___methodParams.maxfiles -lt 1) ? 1 : $___methodParams.maxfiles

        #remove the expired
        $currentFiles = Get-ChildItem -Path $(Join-Path -Path $___methodParams.logPath -ChildPath $("$($___methodParams.logFilenameKey).*.log")) | Sort-Object -Property CreationTime -Descending
        $currentFiles | Select-Object -Skip ($___methodParams.maxfiles - 1) | Remove-Item -Force

        #generate the new log file name
        $newFilename = $("$($___methodParams.logFilenameKey).$(Get-Date -Format 'yyyyMMdd_HHmmss_fffffff').log")
        return @{
            logFilename = $newFilename
            logFilePath = $___methodParams.logPath
            combined    = Join-Path -Path $___methodParams.logPath -ChildPath $newFilename
        }
    }

    [void] checkPSMinimumVersion([object] $___methodParams) {
        $___methodParams.minimumMajorVersion ??= 7
        $___methodParams.minimumMinorVersion ??= 0

        if ($global:PSVersionTable.PSVersion.Major -lt $___methodParams.minimumMajorVersion) {
            Write-Host "You must be running this script in a Powershell V$($___methodParams.minimumMajorVersion) or higher, you are running V$($global:PSVersionTable.PSVersion.Major)"
            exit
        }
        else {
            if ($global:PSVersionTable.PSVersion.Minor -lt $___methodParams.minimumMinorVersion) {
                Write-Host "You must be running this script in a Powershell V$($___methodParams.minimumMajorVersion).$($___methodParams.minimumMinorVersion) or higher, you are running V$($global:PSVersionTable.PSVersion.Major).$($global:PSVersionTable.PSVersion.Minor)"
                exit
            }
        }
    }

    [array] getUserGroups([object] $___methodParams) {
        $___methodParams.targetUser ??= $null
        $___methodParams.serverName ??= $null
        <#$___methodParams.searchBase ??= $false

        $user = $this.getSingleADUserByLookupString(@{
                lookupString = $___methodParams.targetUser.objectGUID
                serverName   = $___methodParams.serverName
                searchBase   = $___methodParams.searchBase
            })
        
        if ($user.successState -eq $true) {
            return @($user.data.memberOf | Get-ADGroup -Server $___methodParams.serverName -Properties *)
        }
        else {
            Write-Host $user.errorMessage
            return @()
        }#>
        
        return Get-ADPrincipalGroupMembership -Identity $___methodParams.targetUser.objectGUID -Server $___methodParams.serverName -ResourceContextServer $___methodParams.serverName | Get-ADGroup -Properties extensionAttribute1 | Sort-Object -Property Name
    }

    [object] getSingleADUserByLookupString([object] $___methodParams) {
        $___methodParams.lookupString ??= ''
        $___methodParams.serverName ??= $null
        $___methodParams.lookupStrictness ??= 'wildcard'
        $___methodParams.searchBase ??= $false

        if ([String]::IsNullOrWhiteSpace($___methodParams.lookupString) -eq $false -and [String]::IsNullOrWhiteSpace($___methodParams.serverName) -eq $false) {
            $getUserSplat = @{
                Filter         = "givenname -like '*$($___methodParams.lookupString)*' -or surname -like '*$($___methodParams.lookupString)*' -or DisplayName -like '*$($___methodParams.lookupString)*' -or samAccountName -eq '$($___methodParams.lookupString)' -or employeeID -eq '$($___methodParams.lookupString)' -or ObjectGuid -eq '$($___methodParams.lookupString)' -or SID -eq '$($___methodParams.lookupString)' -or UserPrincipalName -like '*$($___methodParams.lookupString)*'"
                ResultSetSize  = 100
                ResultPageSize = 100
                Properties     = '*'
                Server         = $___methodParams.serverName
            }

            if ($___methodParams.lookupStrictness -eq 'cimatch') {
                $getUserSplat.Filter = "givenname -like '$($___methodParams.lookupString)' -or surname -like '$($___methodParams.lookupString)' -or DisplayName -like '$($___methodParams.lookupString)' -or samAccountName -eq '$($___methodParams.lookupString)' -or employeeID -eq '$($___methodParams.lookupString)' -or ObjectGuid -eq '$($___methodParams.lookupString)' -or SID -eq '$($___methodParams.lookupString)' -or UserPrincipalName -like '$($___methodParams.lookupString)'"
            }

            if ($___methodParams.searchBase -ne $false) {
                $getUserSplat.SearchBase = $___methodParams.searchBase
            }

            $getSingleADUserByLookupString_users = Get-ADUser @getUserSplat -ErrorAction SilentlyContinue

            if ($getSingleADUserByLookupString_users.Count -gt 1) {
                $getSingleADUserByLookupString_users = $getSingleADUserByLookupString_users | Sort-Object -Property DisplayName
                Write-Host "Your search returned $($getSingleADUserByLookupString_users.Count) results with a hard limit of 100. Which one were you looking for?" -ForegroundColor Cyan
                $tmp_selection = $getSingleADUserByLookupString_users | Select-Object DisplayName, EmployeeID, SamAccountName, mail, CanonicalName, ObjectGuid | Out-ConsoleGridView -OutputMode Single -Title 'Select an Active Directory User'

                if ($null -ne $tmp_selection) {
                    $getSingleADUserByLookupString_user = $getSingleADUserByLookupString_users | Where-Object ObjectGUID -EQ $tmp_selection.ObjectGUID
                    if ($null -ne $getSingleADUserByLookupString_user) {
                        return @{
                            data         = $getSingleADUserByLookupString_user
                            successState = $true
                            errorMessage = ''
                        }
                    }
                    else {
                        return @{
                            data         = $null
                            successState = $false
                            errorMessage = 'Selected user not an option'
                        }
                    }
                }
                else {
                    return @{
                        data         = $null
                        successState = $false
                        errorMessage = 'User Selection Cancelled'
                    }
                }


            }
            elseif ($null -eq $getSingleADUserByLookupString_users) {
                return @{
                    data         = $null
                    successState = $false
                    errorMessage = 'We cannot find anyone with that lookup value'
                }
            }
            else {
                return @{
                    data         = $getSingleADUserByLookupString_users
                    successState = $true
                    errorMessage = ''
                }
            }
        }
        else {
            return @{
                data         = $null
                successState = $false
                errorMessage = 'Bro that is a garbage input string, exiting'
            }
        }
    }

    [object] getSingleADUser([object] $___methodParams) {
        $___methodParams.prefixMessage ??= ''
        $___methodParams.searchBase ??= $false
        $___methodParams.serverName ??= $null
        $___methodParams.allowBypass ??= $false

        $bypassCode = Get-Random -Minimum 100 -Maximum 999

        #https://en.wikipedia.org/wiki/ANSI_escape_code
        $helpTexts = @{
            header   = 'Active Directory User Search Routine'
            examples = @(
                @{
                    message   = 'This search can find users based on the ::highlighted:: sections of the following fields:'
                    formatted = "$($this.colorCodes.helptexts.unhilighted)This search can find users based on the $($this.colorCodes.helptexts.highlighted)::highlighted::$($this.colorCodes.stopColor)$($this.colorCodes.helptexts.unhilighted) sections of the following fields:$($this.colorCodes.stopColor)"
                }
                @{
                    message   = 'SamAccountName (username); admin\someSamAccountName'
                    formatted = "$($this.colorCodes.helptexts.unhilighted)SamAccountName (username); admin\$($this.colorCodes.stopColor)$($this.colorCodes.helptexts.highlighted)someSamAccountName$($this.colorCodes.stopColor)"
                }
                @{
                    message   = 'Surname; Thomas Edison'
                    formatted = "$($this.colorCodes.helptexts.unhilighted)Surname; Thomas$($this.colorCodes.stopColor)$($this.colorCodes.helptexts.highlighted)Edison$($this.colorCodes.stopColor)"
                }
                @{
                    message   = 'GivenName; Thomas Edison'
                    formatted = "$($this.colorCodes.helptexts.unhilighted)GivenName; $($this.colorCodes.stopColor)$($this.colorCodes.helptexts.highlighted)Thomas$($this.colorCodes.stopColor) $($this.colorCodes.helptexts.unhilighted)Edison$($this.colorCodes.stopColor)"
                }
                @{
                    message   = 'DisplayName; Edison, Thomas'
                    formatted = "$($this.colorCodes.helptexts.unhilighted)DisplayName; $($this.colorCodes.stopColor)$($this.colorCodes.helptexts.highlighted)Edison, Thomas$($this.colorCodes.stopColor)"
                }
                @{
                    message   = 'X-Number; X00777777'
                    formatted = "$($this.colorCodes.helptexts.unhilighted)X-Number;$($this.colorCodes.stopColor) $($this.colorCodes.helptexts.highlighted)X00777777$($this.colorCodes.stopColor)"
                }
                @{
                    message   = 'UserPrincipalName; thomasedison@mydomain.edu'
                    formatted = "$($this.colorCodes.helptexts.unhilighted)UserPrincipalName;$($this.colorCodes.stopColor) $($this.colorCodes.helptexts.highlighted)thomasedison$($this.colorCodes.stopColor)$($this.colorCodes.helptexts.unhilighted)@mydomain.edu$($this.colorCodes.stopColor)"
                }
                @{
                    message   = 'ObjectGUID; b5f1ab1f-809f-4faf-a73c-8f6c10b19f96'
                    formatted = "$($this.colorCodes.helptexts.unhilighted)ObjectGUID;$($this.colorCodes.stopColor) $($this.colorCodes.helptexts.highlighted)b5f1ab1f-809f-4faf-a73c-8f6c10b19f96$($this.colorCodes.stopColor)"
                }
                @{
                    message   = 'SID; S-1-5-21-57989841-1303643608-682003330-119587'
                    formatted = "$($this.colorCodes.helptexts.unhilighted)SID;$($this.colorCodes.stopColor) $($this.colorCodes.helptexts.highlighted)S-1-5-21-57989841-1303643608-682003330-119587$($this.colorCodes.stopColor)"
                }
            )
        }

        $this.centerLeftAlignedMenuBox($helpTexts)

        if ($___methodParams.prefixMessage.Length -gt 0) {
            Write-Host "`e[36m=== $($___methodParams.prefixMessage) ===$($this.colorCodes.stopColor)"
        }

        if ($___methodParams.allowBypass -eq $true) {
            $lookupString = Read-Host -Prompt "Enter the users' identifying attribute or bypass code '$bypassCode'"
        }
        else {
            $lookupString = Read-Host -Prompt "Enter the users' identifying attribute"
        }
        
        $lookupString = $lookupString.Trim()
        if ($lookupString.length -lt 1) {
            return @{
                data         = $null
                successState = $false
                errorMessage = 'Bro that is a garbage input string, exiting'
            }
        }
        elseif ($___methodParams.allowBypass -eq $true -and $lookupString -eq $bypassCode) {
            return @{
                data         = $null
                successState = $false
                errorMessage = 'Bypass code entered'
            }
        }
        else {
            return $this.getSingleADUserByLookupString(@{
                    lookupString = $lookupString
                    serverName   = $___methodParams.serverName
                    searchBase   = $___methodParams.searchBase
                })
        }
    }

    [bool] checkModuleInstalled([string] $moduleName) {
        if (Get-Module -ListAvailable -Name $moduleName) {
            return $true
        }
        else {
            return $false
        }
    }

    [int] genericUserConfirmationPrompt([object] $___methodParams) {
        $___methodParams.title ??= ''
        $___methodParams.message ??= ''
        $___methodParams.defaultChoice ??= 'No'
        $___methodParams.options ??= @('Yes', 'No')

        $options = [System.Management.Automation.Host.ChoiceDescription[]]($___methodParams.options | ForEach-Object { New-Object System.Management.Automation.Host.ChoiceDescription "&$_", $_ })

        $tmp = $___methodParams.options.Indexof($___methodParams.defaultChoice)

        if ($tmp -ge 0) {
            $___methodParams.defaultChoice = $tmp
        }
        else {
            $___methodParams.defaultChoice = ($___methodParams.options.Count) - 1
        }

        $result = $global:host.UI.PromptForChoice($___methodParams.title, $___methodParams.message, $options, $___methodParams.defaultChoice)
        return $result
    }

    [void] centerLeftAlignedMenuBox([array] $helpTexts) {
        $maxMessageLength = 0
        foreach ($helpText in $helpTexts.examples) {
            $maxMessageLength = [Math]::Max($helpText.message.length, $maxMessageLength)
        }
        $leftSpaces = [Math]::Floor([Math]::Max(0, (($global:Host.UI.RawUI.BufferSize.Width - $maxMessageLength) / 2) - 4))

        Write-Host $(' ' * $leftSpaces) -NoNewline
        Write-Host $("$($this.colorCodes.helptexts.unhilighted)*$($this.colorCodes.stopColor)" * [Math]::Floor((($maxMessageLength - $helpTexts.header.Length) / 2) + 2)) -NoNewline
        Write-Host " $($this.colorCodes.helptexts.unhilighted)$($helpTexts.header)$($this.colorCodes.stopColor) " -NoNewline
        Write-Host $("$($this.colorCodes.helptexts.unhilighted)*$($this.colorCodes.stopColor)" * [Math]::Floor((($maxMessageLength - $helpTexts.header.Length) / 2) + 1))

        foreach ($helpText in $helpTexts.examples) {
            Write-Host $(' ' * $leftSpaces) -NoNewline
            Write-Host "$($this.colorCodes.helptexts.unhilighted)* $($this.colorCodes.stopColor)" -NoNewline
            Write-Host $helpText.formatted -NoNewline
            Write-Host $(' ' * [Math]::Floor($maxMessageLength - $helpText.message.Length)) -NoNewline
            Write-Host "$($this.colorCodes.helptexts.unhilighted) *$($this.colorCodes.stopColor)"
        }
        Write-Host $(' ' * $leftSpaces) -NoNewline
        Write-Host $("$($this.colorCodes.helptexts.unhilighted)*$($this.colorCodes.stopColor)" * [Math]::Floor($maxMessageLength + 4))
    }

    [void] commonErrorMessageBox([string] $errorTitle, [string] $errorMessage) {
        $maxMessageLength = $errorMessage.length

        $leftSpaces = [Math]::Floor([Math]::Max(0, (($global:Host.UI.RawUI.BufferSize.Width - $maxMessageLength) / 2) - 4))
        $fillerCharCount = [Math]::Floor((($maxMessageLength - $errorTitle.Length) / 2) + 2)
        $fillerCharCount = ($fillerCharCount % 2 -eq 0) ? $fillerCharCount : $fillerCharCount + 1
        $totalLineLength = ($fillerCharCount * 2) + ($errorTitle.Length + 2)

        Write-Host $(' ' * $leftSpaces) -NoNewline
        Write-Host $("$($this.colorCodes.helptexts.unhilighted)-$($this.colorCodes.stopColor)" * $fillerCharCount) -NoNewline
        Write-Host "[$($this.colorCodes.errorMessageBox.title)$($errorTitle)$($this.colorCodes.stopColor)]" -NoNewline
        Write-Host $("$($this.colorCodes.helptexts.unhilighted)-$($this.colorCodes.stopColor)" * $fillerCharCount)
        
        Write-Host $(' ' * ($leftSpaces + [Math]::Ceiling(($totalLineLength - $maxMessageLength) / 2))) -NoNewline
        Write-Host "$($this.colorCodes.errorMessageBox.text)$errorMessage$($this.colorCodes.stopColor)"
        
        Write-Host $(' ' * $leftSpaces) -NoNewline
        Write-Host $("$($this.colorCodes.helptexts.unhilighted)-$($this.colorCodes.stopColor)" * $totalLineLength)
    }

    [void] progressBarTimer([object] $___methodParams) {
        $___methodParams.seconds ??= 10
        $___methodParams.milliseconds ??= 100
        $___methodParams.activity ??= ''

        if ($___methodParams.milliseconds -ge $___methodParams.seconds) {
            $___methodParams.milliseconds = 100
        }

        switch ((0..1 | Get-Random)) {
            0 {
                # percent output
                for ($i = 0; $i -lt $___methodParams.seconds; $i++) {
                    Write-Progress -Activity $___methodParams.activity -Status "$([math]::Round(($i / $___methodParams.seconds) * 100))% Complete" -PercentComplete $(($i / $___methodParams.seconds) * 100) -SecondsRemaining $($___methodParams.seconds - $i)
                    Start-Sleep -Seconds 1
                }
            }

            1 {
                #seconds countdown
                for ($i = 0; $i -lt $___methodParams.seconds; $i++) {
                    Write-Progress -Activity $___methodParams.activity -Status "$($___methodParams.seconds - $i) Seconds Remaining" -PercentComplete $(($i / $___methodParams.seconds) * 100)
                    Start-Sleep -Seconds 1
                }
            }
        }

        Write-Progress -Activity $___methodParams.activity -Status '100% Complete' -PercentComplete 100 -Completed
    }

    [object] selectFolder() {
        [System.Reflection.Assembly]::LoadWithPartialName('System.windows.forms') | Out-Null
        
        $userGoodWithInput = $false
        $out = @{
            successState    = $false
            errorMessage    = ''
            folderSelection = $null
        }
        while ($userGoodWithInput -eq $false) {
            Write-Host 'Please select a location to save any output files.' -ForegroundColor Yellow
    
            $folderSelection = New-Object System.Windows.Forms.FolderBrowserDialog
            $folderSelection.rootfolder = 'MyComputer'

            if ($folderSelection.ShowDialog() -ne 'OK') {
                Write-Host 'No folder selected. Try again or close the script to exit.' -ForegroundColor Yellow
                Write-Host ''
                Write-Host ''
                [void][System.Console]::ReadKey($true)
                $out.successState = $false
                $out.errorMessage = 'No folder selected'
            }
            else {
                $result = $this.genericUserConfirmationPrompt(@{
                        title   = 'Confirmation'
                        message = "You selected '$($folderSelection.SelectedPath)'. Is this correct?"
                    })

                if ($result -ne 0) {
                    Write-Host 'Okay, let''s try again.' -ForegroundColor Red
                    Write-Host ''
                    Write-Host ''
                    $folderSelection = $null
                }
                else {
                    $out.successState = $true
                    $out.folderSelection = $folderSelection
                    $userGoodWithInput = $true                
                }
            }
        }

        return $out
    }

    [object] selectFile([object] $___methodParams) {
        $___methodParams.InitialDirectory ??= [Environment]::GetFolderPath('MyComputer')
        $___methodParams.Filter ??= 'All files (*.*)|*.*'
        $___methodParams.FilterIndex ??= 1
        $___methodParams.MultiSelect ??= $false

        [System.Reflection.Assembly]::LoadWithPartialName('System.windows.forms') | Out-Null
        
        $userGoodWithInput = $false
        $out = @{
            successState  = $false
            errorMessage  = ''
            fileSelection = $null
        }
        while ($userGoodWithInput -eq $false) {    
            $fileSelection = New-Object System.Windows.Forms.OpenFileDialog -Property @{
                Filter      = $___methodParams.Filter
                FilterIndex = $___methodParams.FilterIndex
                MultiSelect = $___methodParams.MultiSelect
            }
        
            if ($fileSelection.ShowDialog() -ne 'OK') {
                Write-Host 'No file selected. Try again or close the script to exit.' -ForegroundColor Yellow
                Write-Host ''
                Write-Host ''
                [void][System.Console]::ReadKey($true)
                $out.successState = $false
                $out.errorMessage = 'No file selected'
            }
            else {
                $result = $this.genericUserConfirmationPrompt(@{
                        title   = 'Confirmation'
                        message = "You selected:`n   $($fileSelection.FileNames -join "`n   ")`nIs this correct?"
                    })

                if ($result -ne 0) {
                    Write-Host 'Okay, let''s try again.' -ForegroundColor Red
                    Write-Host ''
                    Write-Host ''
                    $fileSelection = $null
                }
                else {
                    $out.successState = $true
                    $out.fileSelection = $fileSelection
                    $userGoodWithInput = $true                
                }
            }
        }

        return $out
    }

    [string] makeStringLessThanEqualToLength($inputData, $desiredLength) {
        if ([string]::IsNullOrEmpty($inputData)) {
            $inputData = ''
        }
        if ($inputData.length -gt $desiredLength) {
            $inputData = $inputData.substring(0, $desiredLength)
        }

        return $inputData
    }

    [string] convertToString($value) {
        if ([string]::IsNullOrEmpty($value)) {
            return ''
        }

        return [string]$value.ToString().Trim()
    }

    [bool] checkForCmdlet([object] $___methodParams) {
        $___methodParams.cmdletName ??= $null

        if ($null -eq $___methodParams.cmdletName) {
            return $false
        }

        return [bool](Get-Command -Name $___methodParams.cmdletName -ErrorAction SilentlyContinue)
    }
}