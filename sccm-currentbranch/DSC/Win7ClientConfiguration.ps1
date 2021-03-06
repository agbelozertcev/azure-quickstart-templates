﻿configuration Configuration
{
   param
   (
        [Parameter(Mandatory)]
        [String]$DomainName,
        [Parameter(Mandatory)]
        [String]$DCName,
        [Parameter(Mandatory)]
        [String]$ClientName,
        [Parameter(Mandatory)]
        [String]$Win7ClientName,
        [Parameter(Mandatory)]
        [String]$AADClientName,
        [Parameter(Mandatory)]
        [String]$PSName,
        [Parameter(Mandatory)]
        [String]$DNSIPAddress,
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds
    )
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Force
    Import-DscResource -ModuleName TemplateHelpDSC

    $LogFolder = "TempLog"
    $LogPath = "c:\$LogFolder"
    $DName = $DomainName.Split(".")[0]
    $DCComputerAccount = "$DName\$DCName$"
    $PSComputerAccount = "$DName\$PSName$"

    [System.Management.Automation.PSCredential]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)
    $PrimarySiteName = $PSName.split(".")[0] + "$"

    Node localhost
    {
        LocalConfigurationManager
        {
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $true
        }

        SetCustomPagingFile PagingSettings
        {
            Drive       = 'C:'
            InitialSize = '8192'
            MaximumSize = '8192'
        }

        SetWin7DNS DnsServerAddress
        {
            DNSIPAddress = $DNSIPAddress
            Ensure = "Present"
            DependsOn = "[SetCustomPagingFile]PagingSettings"
        }

        InstallFeatureForSCCM InstallFeature
        {
            Name = "Client"
            Role = "Client"
            DependsOn = "[SetCustomPagingFile]PagingSettings"
        }

        WaitForDomainReady WaitForDomain
        {
            Ensure = "Present"
            DCName = $DCName
            DependsOn = "[SetWin7DNS]DnsServerAddress"
        }

        JoinDomain JoinDomain
        {
            DomainName = $DomainName
            Credential = $DomainCreds
            DependsOn = "[WaitForDomainReady]WaitForDomain"
        }

        WaitForConfigurationFile WaitForPSJoinDomain
        {
            Role = "DC"
            MachineName = $DCName
            LogFolder = $LogFolder
            ReadNode = "PSJoinDomain"
            Ensure = "Present"
            DependsOn = "[JoinDomain]JoinDomain"
        }

        File ShareFolder
        {            
            DestinationPath = $LogPath     
            Type = 'Directory'            
            Ensure = 'Present'
            DependsOn = "[WaitForConfigurationFile]WaitForPSJoinDomain"
        }

     #   FileReadAccessShare DomainSMBShare
     #   {
     #       Name   = $LogFolder
     #       Path = $LogPath
     #       Account = $DCComputerAccount,$PSComputerAccount
     #       DependsOn = "[File]ShareFolder"
     #   }


        AddUserToLocalAdminGroup AddADUserToLocalAdminGroup {
            Name = $($Admincreds.UserName)
            DomainName = $DomainName
            DependsOn = "[JoinDomain]JoinDomain"
        }

        AddUserToLocalAdminGroup AddADComputerToLocalAdminGroup {
            Name = "$PrimarySiteName"
            DomainName = $DomainName
            DependsOn = "[JoinDomain]JoinDomain"
        }

		RequestCertificate RequestCertificate
        {
            Name = $Win7ClientName
			Role = "Windows 7 Client"
            DependsOn = "[JoinDomain]JoinDomain"
        }
    #    WriteConfigurationFile WriteClientFinished
    #    {
    #        Role = "Win7Client"
    #        LogPath = $LogPath
    #        WriteNode = "Win7ClientFinished"
    #        Status = "Passed"
    #        Ensure = "Present"
    #        DependsOn = "[AddUserToLocalAdminGroup]AddADUserToLocalAdminGroup","[AddUserToLocalAdminGroup]AddADComputerToLocalAdminGroup"
    #    }
    }
}
