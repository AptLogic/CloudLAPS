function Write-AzureADDeviceAttributes {
    <#
    .SYNOPSIS
        (Over)Writes new device attributes to an Azure AD device record.
    
    .DESCRIPTION
        (Over)Writes new device attributes to an Azure AD device record.

    .PARAMETER DeviceID
        Specify the Device ID of an Azure AD device record.
    
    .NOTES
        Author:      Henry Kon
        Contact:     henry.kon@sas.com
        Created:     2024-10-15
    
        Version history:
        1.0.0 - (2024-10-15) Function created
        1.1.0 - (2026-07-10) Updated to use MgGraph
    #>
    param(
        [parameter(Mandatory = $true, HelpMessage = "Specify the Device ID of an Azure AD device record.")]
        [ValidateNotNullOrEmpty()]
        [string]$DeviceID,

        [parameter(Mandatory = $true, HelpMessage = "Specify the extension attribute to modify.")]
        [ValidateNotNullOrEmpty()]
        [string]$attributeName,

        [parameter(Mandatory = $true, HelpMessage = "Specify the new value for the extension attribute.")]
        [ValidateNotNullOrEmpty()]
        [string]$attributeContent
    )
    Process {
        Connect-MgGraph -NoWelcome -TenantId $env:APP_REG_TENANTID -ClientSecretCredential (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $env:APP_REG_CLIENTID, (ConvertTo-SecureString $env:APP_REG_SECRET -AsPlainText -Force))
        # Get Object ID
        $GraphURI = "v1.0/devices?`$filter=deviceId eq '$($DeviceID)'"
        $GraphResponse = (Invoke-MgGraphRequest -Method GET -Uri $GraphUri -OutputType Json -ErrorAction Stop).value
        $ObjectId = $GraphResponse.id
        $GraphURI = "v1.0/devices/{$($ObjectId)}"
        $GraphBody = @"
{
    `"extensionAttributes`": {
        `"$($attributeName)`": `"$($attributeContent)`"
    }
}
"@
        $GraphResponse = (Invoke-MgGraphRequest -Method PATCH -Uri $GraphUri -Body $GraphBody -OutputType Json -ErrorAction Stop).value
        # Handle return response
        return $GraphResponse
    }
}