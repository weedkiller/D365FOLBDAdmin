function Add-D365LBDDatabaseDetailsandCert {
    <#
    .SYNOPSIS
   Adds the Encipherment Cert into the D365 Servers for the configuration of the local business data environment. 
   .DESCRIPTION
    Adds the Encipherment Cert into the D365 Servers for the configuration of the local business data environment.
    This is to help with adding additional details in the config lookup for continued automation.
   .EXAMPLE
   Add-D365LBDDataEnciphermentCertConfig -Thumbprint "1243asd234213" -DatabaseServerNames 'DatabaseServerName01'
   Will get add the thumbprint to the environments config (AX SF servers) this would be a non database clustered environment (always-on in most cases)
    .EXAMPLE
   Add-D365LBDDataEnciphermentCertConfig -Thumbprint "1243asd234213" -Clustered -DatabaseServerNames ('DatabaseServerName01','DatabaseServerName02')
   Will get add the thumbprint to the environments config (AX SF servers) this would be a non database clustered environment (always-on in most cases)
   .EXAMPLE
   Add-D365LBDDataEnciphermentCertConfig -Config $config -Thumbprint "1243asd234213" -Clustered -DatabaseServerNames ('DatabaseServerName01','DatabaseServerName02')
   Will get add the thumbprint to the environments config (AX SF servers) this would be a non database clustered environment (always-on in most cases)
   .PARAMETER ComputerName
   String
   The name of the D365 LBD Server to grab the environment details; needed if a config is not specified and will default to local machine.
    .PARAMETER Clustered
   Switch
    Turn this switch on if it is a clustered database environment.
    .PARAMETER DatabaseServerNames
    String Array
    Name of Database Server(s)
    .PARAMETER Thumbprint
    String
    Thumbprint of encryption certificate used to encrypt the database server connections
    .PARAMETER Config
    Custom PSObject
    Config Object created by either the Get-D365LBDConfig or Get-D365TestConfigData function inside this module
   #>
    [alias("Add-D365DatabaseDetailsandCert")]
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True,
            Mandatory = $false,
            HelpMessage = 'D365FO Local Business Data Server Name',
            ParameterSetName='NoConfig')]
        [PSFComputer]$ComputerName = "$env:COMPUTERNAME",
        [switch]$Clustered,
        [Parameter(Mandatory = $True)]
        [string[]]$DatabaseServerNames,
        [Parameter(Mandatory = $True)]
        [string]$Thumbprint,
        [Parameter(ParameterSetName='Config',
        ValueFromPipeline = $True)]
        [psobject]$Config
    )
    BEGIN {
    }
    PROCESS {
        if (!$Config) {
            $Config = Get-D365LBDConfig -ComputerName $ComputerName -HighLevelOnly
        }
        foreach ($server in $Config.AllAppServerList) {
            if ($Clustered) {
                if (Test-path \\$server\c$\ProgramData\SF\DatabaseDetailsandCert.txt)
                {
                    Write-PSFMessage -Level Warning -Message "\\$server\c$\ProgramData\SF\DatabaseDetailsandCert.txt already exists overwriting"
                }
                "Clustered" | Out-file \\$server\c$\ProgramData\SF\DatabaseDetailsandCert.txt -Force
                Write-PSFMessage -Level Verbose "Clustered Selected make sure you entered in all database server names in other parameter"
            }
            else {
                "NotClustered" | Out-file \\$server\c$\ProgramData\SF\DatabaseDetailsandCert.txt -Force
            }
            $Thumbprint | Out-file \\$server\c$\ProgramData\SF\DatabaseDetailsandCert.txt -append 
            foreach ($DatabaseServerName in $DatabaseServerNames){
            $DatabaseServerName | Out-file \\$server\c$\ProgramData\SF\DatabaseDetailsandCert.txt -append 
        }
            
        }
        Write-PSFMessage -Level Verbose "c:\ProgramData\SF\DatabaseDetailsandCert.txt created/updated"
    }
    END {
      
    }
}