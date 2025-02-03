using namespace System.Net

# Input bindings are passed in via param block.
param(
    [Parameter(Mandatory = $true)]
    $Request,

    [Parameter(Mandatory = $false)]
    $TriggerMetadata
)

# Functions
function Get-AuthToken {
    <#
    .SYNOPSIS
        Retrieve an access token for the Managed System Identity.
    
    .DESCRIPTION
        Retrieve an access token for the Managed System Identity.
    
    .NOTES
        Author:      Nickolaj Andersen
        Contact:     @NickolajA
        Created:     2021-06-07
        Updated:     2021-06-07
    
        Version history:
        1.0.0 - (2021-06-07) Function created
    #>
    Process {
        # Get Managed Service Identity details from the Azure Functions application settings
        $MSIEndpoint = $env:MSI_ENDPOINT
        $MSISecret = $env:MSI_SECRET

        # Define the required URI and token request params
        $APIVersion = "2017-09-01"
        $ResourceURI = "https://graph.microsoft.com"
        $AuthURI = $MSIEndpoint + "?resource=$($ResourceURI)&api-version=$($APIVersion)"

        # Call resource URI to retrieve access token as Managed Service Identity
        $Response = Invoke-RestMethod -Uri $AuthURI -Method "Get" -Headers @{ "Secret" = "$($MSISecret)" }

        # Construct authentication header to be returned from function
        $AuthenticationHeader = @{
            "Authorization" = "Bearer $($Response.access_token)"
            "ExpiresOn" = $Response.expires_on
        }

        # Handle return value
        return $AuthenticationHeader
    }
}

Write-Output -InputObject "Inbound request from IP: $($TriggerMetadata.'$Request'.headers.'x-forwarded-for'.Split(":")[0])"

# Retrieve authentication token
$AuthToken = Get-AuthToken

# Initate variables
$StatusCode = [HttpStatusCode]::OK
$Body = [string]::Empty
$HeaderValidation = $true

# Assign incoming request properties to variables
$DeviceID = $Request.Body.DeviceID
$SerialNumber = $Request.Body.SerialNumber
$Signature = $Request.Body.Signature
$Thumbprint = $Request.Body.Thumbprint
$ExpirationDate = $Request.Body.ExpirationDate
$FullPem = $Request.Body.FullPem

# Validate request header values
$HeaderValidationList = @(@{ "DeviceID" = $DeviceID }, @{ "SerialNumber" = $SerialNumber }, @{ "Signature" = $Signature }, @{ "Thumbprint" = $Thumbprint }, @{ "ExpirationDate" = $ExpirationDate}, @{ "FullPem" = $FullPem })
foreach ($HeaderValidationItem in $HeaderValidationList) {
    foreach ($HeaderItem in $HeaderValidationItem.Keys) {
        if ([string]::IsNullOrEmpty($HeaderValidationItem[$HeaderItem])) {
            Write-Warning -Message "Header validation for '$($HeaderItem)' failed, request will not be handled"
            $StatusCode = [HttpStatusCode]::BadRequest
            $HeaderValidation = $false
            $Body = "Header validation failed"
        }
        else {
            if ($HeaderItem -in @("Signature", "FullPem")) {
                if ($DebugLogging -eq $true) {
                    Write-Output -InputObject "Header validation succeeded for '$($HeaderItem)' with value: $($HeaderValidationItem[$HeaderItem])"
                }
                else {
                    Write-Output -InputObject "Header validation succeeded for '$($HeaderItem)' with value: <redacted>"
                }
            }
            else {
                Write-Output -InputObject "Header validation succeeded for '$($HeaderItem)' with value: $($HeaderValidationItem[$HeaderItem])"
            }
        }
    }  
}

if ($HeaderValidation -eq $true) {
    # Initiate request handling
    Write-Output -InputObject "Initiating request handling for device named as '$($DeviceName)' with identifier: $($DeviceID)"

    $AzureADDeviceRecord = Get-AzureADDeviceRecord -DeviceID $DeviceID -AuthToken $AuthToken
    if ($null -ne $AzureADDeviceRecord) {
        Write-Output -InputObject "Found trusted Azure AD device record with object identifier: $($AzureADDeviceRecord.id)"
        # Verify device platform is MacOS
        if($AzureADDeviceRecord.operatingSystem -eq "MacMDM") {
            # Validate existing validation data is expired or empty.
            if($null -eq $AzureADDeviceRecord.ExtensionAttributes.extensionAttribute11 -or ([dateTime]::ParseExact($AzureADDeviceRecord.ExtensionAttributes.extensionAttribute12, 'yyyy-MM-dd', $null) -le [dateTime]::ParseExact($ExpirationDate, 'yyyy-MM-dd', $null))) {
                # OK, continue to validate expiration date
                if(($null -eq $AzureADDeviceRecord.ExtensionAttributes.extensionAttribute12) -or ([dateTime]::ParseExact($AzureADDeviceRecord.ExtensionAttributes.extensionAttribute12, 'yyyy-MM-dd', $null) -le [dateTime]::ParseExact($ExpirationDate, 'yyyy-MM-dd', $null))) {
                    Write-Output -InputObject "Successfully validated expiration dates for security ID rewrite"
                    # OK, continue to validate thumbprint
                    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2(,[Convert]::FromBase64String($FullPem))
                    $ComputeThumb = $cert.Thumbprint
                    if($Thumbprint -match $ComputeThumb) {
                        Write-Output -InputObject "Successfully validated certificate thumbprint from inbound request"
                        #OK, continue to verify signature
                        $pkey = $cert.PublicKey.EncodedKeyValue.RawData
                        $pkey64 = [System.Convert]::ToBase64String($pkey)
                        $EncryptionVerification = Test-Encryption -PublicKeyEncoded $pkey64 -Signature $Signature -Content $AzureADDeviceRecord.deviceId
                        if ($EncryptionVerification -eq $true) {
                            Write-Output -InputObject "Successfully validated inbound request came from a trusted Azure AD device record"
                            # Validate that the inbound request came from a trusted device that's not disabled
                            if ($AzureADDeviceRecord.accountEnabled -eq $true) { 
                                Write-Output -InputObject "Azure AD device record was validated as enabled"
                                # OK, Encode and store new attributes
                                $SHA256Managed = New-Object System.Security.Cryptography.SHA256Managed
                                $PubKeyHash256 = $SHA256Managed.ComputeHash($cert.PublicKey.EncodedKeyValue.RawData)
                                $PubKeyHash256String = [System.Convert]::ToBase64String($PubKeyHash256)
                                $NewDeviceSecurityId = [System.Text.Encoding]::Unicode.GetBytes("X509:<SHA1-TP-PUBKEY>$($Thumbprint)$($PubKeyHash256String)")
                                $B64DeviceSecurityId = [System.Convert]::ToBase64String($NewDeviceSecurityId)
                                $NewDeviceSecurityIdExpirationDate = $ExpirationDate
                                Write-Output "Writing new security objects..."
                                Write-AzureADDeviceAttributes -DeviceID $DeviceID -AuthToken $AuthToken -attributeName "extensionAttribute11" -attributeContent $B64DeviceSecurityId
                                Write-AzureADDeviceAttributes -DeviceID $DeviceID -AuthToken $AuthToken -attributeName "extensionAttribute12" -attributeContent $NewDeviceSecurityIdExpirationDate
                                Write-Output "Complete."
                                # Done!
                                $StatusCode = [HttpStatusCode]::OK
                                $Body = ""
                            } else {
                                Write-Output -InputObject "Trusted Azure AD device record validation for inbound request failed, record with deviceId '$($DeviceID)' is disabled"
                                $StatusCode = [HttpStatusCode]::Forbidden
                                $Body = "Disabled device record"
                            }
                        }
                        else {
                            Write-Warning -Message "Trusted Azure AD device record validation for inbound request failed, could not validate signed content from client"
                            $StatusCode = [HttpStatusCode]::Forbidden
                            $Body = "Untrusted request"
                        }
                    } else {
                        Write-Warning -Message "Trusted Azure AD device record validation for inbound request failed, given thumbprint does not match given public key"
                        $StatusCode = [HttpStatusCode]::BadRequest
                        $Body = "Invalid Request"
                    }
                } else {
                    Write-Warning -Message "Trusted Azure AD device record validation for inbound request failed, security identifier for $($DeviceID) is not expired"
                    $StatusCode = [HttpStatusCode]::BadRequest
                    $Body = "Invalid Request"
                }
            } else {
                Write-Warning -Message "Trusted Azure AD device record validation for inbound request failed, security identifier for $($DeviceID) is populated"
                $StatusCode = [HttpStatusCode]::BadRequest
                $Body = "Invalid Request"
            }
        } else {
            Write-Warning -Message "Trusted Azure AD device record validation for inbound request failed, device platform for $($DeviceID) does not support this function"
            $StatusCode = [HttpStatusCode]::BadRequest
            $Body = "Invalid Request"
        }
    }
    else {
        Write-Warning -Message "Trusted Azure AD device record validation for inbound request failed, could not find device with deviceId: $($DeviceID)"
        $StatusCode = [HttpStatusCode]::Forbidden
        $Body = "Untrusted request"
    }
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $StatusCode
    Body = $Body
})