function Get-AzureADDeviceRecord {
    <#
    .SYNOPSIS
        Retrieve an Azure AD device record.
    
    .DESCRIPTION
        Retrieve an Azure AD device record.

    .PARAMETER DeviceID
        Specify the Device ID of an Azure AD device record.
    
    .NOTES
        Author:      Nickolaj Andersen
        Contact:     @NickolajA
        Created:     2021-06-07
        Updated:     2022-01-01
    
        Version history:
        1.0.0 - (2021-06-07) Function created
        1.0.1 - (2022-01-01) Added support for passing in the authentication header table to the function
        1.1.0 - (2026-07-10) Updated to use MgGraph
    #>
    param(
        [parameter(Mandatory = $true, HelpMessage = "Specify the Device ID of an Azure AD device record.")]
        [ValidateNotNullOrEmpty()]
        [string]$DeviceID
    )
    Process {
        Connect-MgGraph -NoWelcome -TenantId $env:APP_REG_TENANTID -ClientSecretCredential (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $env:APP_REG_CLIENTID, (ConvertTo-SecureString $env:APP_REG_SECRET -AsPlainText -Force))
        $GraphURI = "v1.0/devices?`$filter=deviceId eq '$($DeviceID)'"
        $GraphResponse = (Invoke-MgGraphRequest -Method GET -Uri $GraphUri -OutputType Json -ErrorAction Stop).value
        
        # Handle return response
        return $GraphResponse
    }
}