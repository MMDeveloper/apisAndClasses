class utilities {
    <#
    utilities.resetUserPassword(@{
        targetUser         = $userObject #get-aduser object
        passwordLength     = 20
        elevatedCredential = $elevatedCredential
        serverName         = 'somedc.internaldomain.tld'
    })
    #>
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

    <#
    utilities.moveUserAccountToSameOUAsAnotherUser(@{
        userCopyingFROM        = $userObject #get-aduser object of someone in the OU you want to move a user to
        userCopyingTO          = $userObject #get-aduser object of someone you want to move
        elevatedCredential     = $elevatedCredential
        serverName             = 'somedc.internaldomain.tld'
    })
    #>
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
        #$ou
        Move-ADObject -Identity $___methodParams.userCopyingTO.ObjectGuid -TargetPath $ou -Credential $___methodParams.elevatedCredential -Server $___methodParams.serverName

        return $?
    }

    <#
    utilities.getRandomCharacters(@{
        length = 30
    })
    #>
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

    <#
    utilities.getRandomCharacters(30)
    #>
    [string] getRandomAlphaNumericString([int] $length) {
        $randomString = $this.getRandomCharacters(@{
                length           = $length 
                sourceCharacters = 'a'..'z' + 'A'..'Z' + 0..9
            })
        
        $randomString = $this.scrambleString($randomString)

        return $randomString
    }

    <#
    $fileName = utilities.getRandomUniqueFilename()
    #>
    [string] getRandomUniqueFilename() {
        $randomString = $this.getRandomCharacters(@{
                length           = 30 
                sourceCharacters = 'a'..'z' + 'A'..'Z' + 0..9
            })
        
        $randomString = $this.scrambleString($randomString) + (Get-Date).Ticks

        return $randomString
    }

    <#
    utilities.scrambleString('some string')
    #>
    [string] scrambleString([string] $inputString) {
        $characterArray = $inputString.ToCharArray()
        $scrambledStringArray = $characterArray | Get-Random -Count $characterArray.Length
        $outputString = -join $scrambledStringArray
        return $outputString
    }

    <#
    utilities.genericUserConfirmationPrompt(@{
        title = 'Are you sure?'
        message = 'This action cannot be undone.'
    })
    #>
    [int] genericUserConfirmationPrompt([object] $___methodParams) {
        $___methodParams.title ??= ''
        $___methodParams.message ??= ''

        $options = [System.Management.Automation.Host.ChoiceDescription[]](
            (New-Object System.Management.Automation.Host.ChoiceDescription '&Yes', 'Yes'),
            (New-Object System.Management.Automation.Host.ChoiceDescription '&No', 'No')
        )

        $result = $global:host.UI.PromptForChoice($___methodParams.title, $___methodParams.message, $options, 1)
        return $result
    }

    <#
    utilities.progressBarTimer(@{
        seconds = 20
        activity = 'Performing A/D Replication'
    })
    #>
    [void] progressBarTimer([object] $___methodParams) {
        $___methodParams.seconds ??= 10
        $___methodParams.activity ??= ''

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

    <#
    #this is experimental and untested right now
    utilities.runProcess(@{
        filePath = 'A:\Some\Path\To\Executable.exe'
        arguments = @(
            '-w', '"some quoted string"',
            '-b', '1000',
            '--some-flag'
        )
        wait = $true
        newWindow = $false
    })
    #>
    [void] runProcess([object] $___methodParams) {
        $___methodParams.filePath ??= $null
        $___methodParams.arguments ??= @()
        $___methodParams.wait ??= $true
        $___methodParams.newWindow ??= $false

        $___splat = @{
            FilePath = $___methodParams.filePath
            ArgumentList = $___methodParams.arguments
        }

        if ($___methodParams.wait -eq $true) {
            $___splat['Wait'] = $true
        }

        if ($___methodParams.newWindow -eq $true) {
            $___splat['NoNewWindow'] = $false
        }

        if ($null -ne $___methodParams.filePath -and $___methodParams.arguments is [array]) {
            Start-Process @___splat
        }
        else {
            Write-Host -ForegroundColor Red 'Invalid parameters'
        }
    }
}