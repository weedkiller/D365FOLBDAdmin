function Set-D365LBDOptions {
    <#
   .SYNOPSIS
  Uses switches to set different deployment options
  .DESCRIPTION

  .EXAMPLE
  Set-D365LBDOptions -RemoveMR

  .EXAMPLE

  #>
    [alias("Set-D365Options")]
    param
    (
        [PSFComputer]$ComputerName = "$env:COMPUTERNAME",
        [Parameter(ParameterSetName = 'Config',
            ValueFromPipeline = $True)]
        [psobject]$Config,
        [switch]$PreDeployment,
        [switch]$PostDeployment,
        [switch]$RemoveMR,
        [switch]$MaintenanceModeOn,
        [switch]$MaintenanceModeOff,
        [string]$MSTeamsURI,
        [string]$MSTeamsExtraDetailsURI,
        [string]$MSTeamsExtraDetails,
        [string]$MSTeamsBuildName,
        [string]$MSTeamsCustomStatus,
        [string]$SQLQueryToRun

    )
    BEGIN {
    }
    PROCESS {
        if (!$Config) {
            $Config = Get-D365LBDConfig -ComputerName $ComputerName -HighLevelOnly   
        }
        if ($PreDeployment)
        {
            Write-PSFMessage -Level Verbose -Message "PreDeployment Selected"
        }
        if ($PostDeployment)
        {
            Write-PSFMessage -Level Verbose -Message "PostDeployment Selected"
        }
        if ($Config) {
            $agentsharelocation = $Config.AgentShareLocation
            $AXDatabaseServer = $Config.AXDatabaseServer
            $AXDatabaseName = $Config.AXDatabaseName
            $LCSEnvironmentName = $Config.LCSEnvironmentName
            $clienturl = $Config.clienturl
        }
        if ($RemoveMR) {
            
            Write-PSFMessage -Level Verbose -Message "Attempting to Remove MR"
            if ($PreDeployment -eq $True) {
                $JsonLocation = Get-ChildItem $AgentShareLocation\wp\*\StandaloneSetup-*\SetupModules.json | Sort-Object { $_.CreationTime }  | Select-Object -First 1 
                $JsonLocationRoot = Get-ChildItem $AgentShareLocation\wp\*\StandaloneSetup-*\
                copy-item $JsonLocation.fullName -Destination $AgentShareLocation\OriginalSetupModules.json
                $json = Get-Content $JsonLocation.FullName -Raw | ConvertFrom-Json
                $json.components = $json.components | Where-Object { $_.name -ne 'financialreporting' }
                $json | ConvertTo-Json -Depth 100 | Out-File $JsonLocationRoot\Setupmodules.json -Force -Verbose
            }
            else {
                Write-PSFMessage -Message "Error: Can't remove MR during anything other than PreDeployment" -Level VeryVerbose
            }
        }
        function Invoke-SQL {
            param(
                [string] $dataSource = ".\SQLEXPRESS",
                [string] $database = "MasterData",
                [string] $sqlCommand = $(throw "Please specify a query.")
            )

            $connectionString = "Data Source=$dataSource; " +
            "Integrated Security=SSPI; " +
            "Initial Catalog=$database"

            $connection = new-object system.data.SqlClient.SQLConnection($connectionString)
            $command = new-object system.data.sqlclient.sqlcommand($sqlCommand, $connection)
            $connection.Open()

            $adapter = New-Object System.Data.sqlclient.sqlDataAdapter $command
            $dataset = New-Object System.Data.DataSet
            $adapter.Fill($dataSet) | Out-Null

            $connection.Close()
            $dataSet.Tables

        }
        if ($MaintenanceModeOn) {
            Write-PSFMessage -Message "Turning On Maintenance Mode" -Level Verbose
            $SQLQuery = "update SQLSYSTEMVARIABLES SET VALUE = 1 Where PARM = 'CONFIGURATIONMODE'"
            $Sqlresults = invoke-sql -datasource $AXDatabaseServer -database $AXDatabaseName -sqlcommand $SQLQuery
            if (!$PostDeployment -or !$PreDeployment) {
                foreach ($AXSFServer in $config.AXSFServerNames) {
                    Restart-Computer -ComputerName $AXSFServer -Force
                }
            }
            Write-PSFMessage -Message "$SQLresults" -Level VeryVerbose

        }
        if ($MaintenanceModeOff) {
            Write-PSFMessage -Message "Turning Off Maintenance Mode" -Level Verbose
            $SQLQuery = "update SQLSYSTEMVARIABLES SET VALUE = 0 Where PARM = 'CONFIGURATIONMODE'"
            $Sqlresults = invoke-sql -datasource $AXDatabaseServer -database $AXDatabaseName -sqlcommand $SQLQuery
            if ($PostDeployment -eq $false -or $PreDeployment -eq $false) {
                foreach ($AXSFServer in $config.AXSFServerNames) {
                    Restart-Computer -ComputerName $AXSFServer -Force
                }
            }
            Write-PSFMessage -Message "$SQLresults" -Level VeryVerbose
        }
        if ($EnableUserid) {

            ##Trim 8 characters
            $EnableUserid = $EnableUserid.SubString(0,8)
            Write-PSFMessage -Message "Enabling $EnableUserid. Note: User must already exist in system" -Level Verbose
            $SQLQuery = "update userinfo SET Enable = 1 Where id = '$EnableUserid'"
            $Sqlresults = invoke-sql -datasource $AXDatabaseServer -database $AXDatabaseName -sqlcommand $SQLQuery
            
            Write-PSFMessage -Message "$SQLresults" -Level VeryVerbose

        }
        if ($DisableUserid) {
            $DisableUserid = $DisableUserid.SubString(0,8)
            Write-PSFMessage -Message "Disabling $DisableUserid. Note: User must already exist in system" -Level Verbose
            $SQLQuery = "update userinfo SET Enable = 1 Where id = '$DisableUserid'"
            $Sqlresults = invoke-sql -datasource $AXDatabaseServer -database $AXDatabaseName -sqlcommand $SQLQuery
            
            Write-PSFMessage -Message "$SQLresults" -Level VeryVerbose

        }
        if ($SQLQueryToRun) {
            $Sqlresults = invoke-sql -datasource $AXDatabaseServer -database $AXDatabaseName -sqlcommand $SQLQuery
            Write-PSFMessage -Message "$SQLresults" -Level VeryVerbose
        }
        if ($MSTeamsURI) {
            if ($PreDeployment) {
                $status = 'PreDeployment Started'
            }
            if ($PostDeployment) {
                $status = 'Deployment Finished. PostDeployment Started'
            }
            if ($MSTeamsCustomStatus) {
                $status = "$MSTeamsCustomStatus"
            }
            $bodyjson = @"
{
    "@type": "MessageCard",
    "@context": "http://schema.org/extensions",
    "themeColor": "ff0000",
    "title": "D365 $LCSEnvironmentName $status",
    "summary": "D365 $LCSEnvironmentName $status",
    "sections": [{
        "facts": [{
            "name": "Environment",
            "value": "[$LCSEnvironmentName]($clienturl)"
        },{
            "name": "Build Version/Name",
            "value": "$MSTeamsBuildName"
        },{
            "name": "Status",
            "value": "$status"
        }],
        "markdown": true
    }]
}            
"@
            if ($MSTeamsExtraDetails) {
                $bodyjson = @"
{
    "@type": "MessageCard",
    "@context": "http://schema.org/extensions",
    "themeColor": "ff0000",
    "title": "D365 $LCSEnvironmentName $status",
    "summary": "D365 $LCSEnvironmentName $status",
    "sections": [{
        "facts": [{
            "name": "Environment",
            "value": "[$LCSEnvironmentName]($clienturl)"
        },{
            "name": "Build Version",
            "value": "$MSTeamsBuildName"
        },{
            "name": "Details",
            "value": "[$MSTeamsExtraDetails]($MSTeamsExtraDetailsURI)"
        },{
            "name": "Status",
            "value": "$status"
        }],
        "markdown": true
    }]
}            
"@
            }
            Write-PSFMessage -Message "Calling $MSTeamsURI with Post of $bodyjson " -Level VeryVerbose
            $WebRequestResults = Invoke-WebRequest -uri $MSTeamsURI -ContentType 'application/json' -Body $bodyjson -UseBasicParsing -Method Post -Verbose
            Write-PSFMessage -Message "$WebRequestResults" -Level VeryVerbose
        }
    }
    END {
    }
}
