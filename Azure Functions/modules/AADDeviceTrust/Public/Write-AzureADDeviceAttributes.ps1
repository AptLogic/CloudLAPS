function Write-AzureADDeviceAttributes {
    <#
    .SYNOPSIS
        (Over)Writes new device attributes to an Azure AD device record.
    
    .DESCRIPTION
        (Over)Writes new device attributes to an Azure AD device record.

    .PARAMETER DeviceID
        Specify the Device ID of an Azure AD device record.

    .PARAMETER AuthToken
        Specify a hash table consisting of the authentication headers.
    
    .NOTES
        Author:      Henry Kon
        Contact:     henry.kon@sas.com
        Created:     2024-10-15
    
        Version history:
        1.0.0 - (2024-10-15) Function created
    #>
    param(
        [parameter(Mandatory = $true, HelpMessage = "Specify the Device ID of an Azure AD device record.")]
        [ValidateNotNullOrEmpty()]
        [string]$DeviceID,

        [parameter(Mandatory = $true, HelpMessage = "Specify a hash table consisting of the authentication headers.")]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Hashtable]$AuthToken,

        [parameter(Mandatory = $true, HelpMessage = "Specify the extension attribute to modify.")]
        [ValidateNotNullOrEmpty()]
        [string]$attributeName,

        [parameter(Mandatory = $true, HelpMessage = "Specify the new value for the extension attribute.")]
        [ValidateNotNullOrEmpty()]
        [string]$attributeContent
    )
    Process {
        # Get Object ID
        $GraphURI = "https://graph.microsoft.com/v1.0/devices?`$filter=deviceId eq '$($DeviceID)'"
        $GraphResponse = (Invoke-RestMethod -Method "Get" -Uri $GraphURI -ContentType "application/json" -Headers $AuthToken -ErrorAction Stop).value
        $ObjectId = $GraphResponse.id
        $GraphURI = "https://graph.microsoft.com/v1.0/devices/{$($ObjectId)}"
        $GraphBody = @"
{
    `"extensionAttributes`": {
        `"$($attributeName)`": `"$($attributeContent)`"
    }
}
"@
        $GraphResponse = (Invoke-RestMethod -Method "PATCH" -Uri $GraphURI -ContentType "application/json" -Headers $AuthToken -Body $GraphBody -ErrorAction Stop).value
        # Handle return response
        return $GraphResponse
    }
}