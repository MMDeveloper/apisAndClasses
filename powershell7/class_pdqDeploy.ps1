class pdqDeploy {
    hidden [PSCredential] $credential = $null
    hidden [string] $pdqDeployServer = ''

    pdqDeploy([hashtable] $methodParams) {
        $methodParams.credential ??= ''
        $methodParams.pdqDeployServer ??= ''
        
        $this.credential = $methodParams.credential
        $this.pdqDeployServer = $methodParams.pdqDeployServer
    }

    [void] sendPDQDeployPackageToComputers([hashtable] $methodParams) {
        $methodParams.computerNames ??= @()
        $methodParams.packageName ??= ''

        $computerNames = $methodParams.computerNames
        $packageName = $methodParams.packageName

        Invoke-Command -ComputerName $this.pdqDeployServer -Credential $this.credential -ScriptBlock {
            Start-Process -FilePath 'C:\Program Files (x86)\Admin Arsenal\PDQ Deploy\pdqdeploy.exe' -Wait -ArgumentList 'Deploy -Package', $using:packageName, '-Targets', $($using:computerNames -join ' ')
        }
    
    }
}
<#
$credential = Get-Credential
$pdqDeploy = [pdqDeploy]::new(@{
    credential = Get-Credential
    pdqDeployServer = 'pdqservername.fqdn.net'
})

$pdqDeploy.sendPDQDeployPackageToComputers(@{
    computerNames = @('pc0.fqdn', 'pc1.fqdn')
    packageName = 'gpupdate'
})

#>