class pdqDeploy {
    hidden [string] $credential = $null
    hidden [string] $pdqDeployServer = ''

    adobeManagement([hashtable] $methodParams) {
        $methodParams.credential ??= ''
        $methodParams.pdqDeployServer ??= ''
        
        $this.credential = $methodParams.credential
        $this.pdqDeployServer = $methodParams.pdqDeployServer
    }

    [void] sendPDQDeployPackageToComputers([hashtable] $methodParams) {
        $methodParams.computerNames ??= @()
        $methodParams.packageName ??= ''
        $methodParams.credential ??= $this.credential

        $computerNames = $methodParams.computerNames
        $packageName = $methodParams.packageName

        Invoke-Command -ComputerName $this.pdqDeployServer -Credential $methodParams.credential -ScriptBlock {
            Start-Process -FilePath 'C:\Program Files (x86)\Admin Arsenal\PDQ Deploy\pdqdeploy.exe' -Wait -ArgumentList 'Deploy -Package', $using:packageName, '-Targets', $($using:computerNames -join ' ')
        }
    
    }
}
<#

$pdqDeploy = [pdqDeploy]::new(@{
    credential = Get-Credential
    pdqDeployServer = 'pdqDeployServer.fqdn.net'
})

$pdqDeploy.sendPDQDeployPackageToComputers(@{
    computerNames = @('pc0.fqdn', 'pc1.fqdn')
    packageName = 'gpupdate'
})

#>