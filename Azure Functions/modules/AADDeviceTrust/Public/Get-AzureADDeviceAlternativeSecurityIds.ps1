function Get-AzureADDeviceAlternativeSecurityIds {
    <#
    .SYNOPSIS
        Decodes Key property of an Azure AD device record into prefix, thumbprint and publickeyhash values.
    
    .DESCRIPTION
        Decodes Key property of an Azure AD device record into prefix, thumbprint and publickeyhash values.

    .PARAMETER Key
        Specify the 'key' property of the alternativeSecurityIds property retrieved from the Get-AzureADDeviceRecord function.
    
    .NOTES
        Author:      Nickolaj Andersen
        Contact:     @NickolajA
        Created:     2021-06-07
        Updated:     2021-06-07
    
        Version history:
        1.0.0 - (2021-06-07) Function created
    #>
    param(
        [parameter(Mandatory = $true, HelpMessage = "Specify the 'key' property of the alternativeSecurityIds property retrieved from the Get-AzureADDeviceRecord function.")]
        [ValidateNotNullOrEmpty()]
        [string]$Key
    )
    Process {
        $DecodedKey = [System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String($Key))
        $SplitKey = $DecodedKey.Split(">")
        
        # Extract prefix with length check
        $Prefix = if ($DecodedKey.Length -ge 21) { $DecodedKey.SubString(0,21) } else { $DecodedKey }
        
        # Extract thumbprint and pubkeyhash with safety checks
        $Thumbprint = ""
        $PublicKeyHash = ""
        if ($SplitKey.Length -gt 1) {
            $AfterSplit = $SplitKey[1]
            $Thumbprint = if ($AfterSplit.Length -ge 40) { $AfterSplit.SubString(0,40) } else { $AfterSplit }
            $PublicKeyHash = if ($AfterSplit.Length -gt 40) { $AfterSplit.SubString(40) } else { "" }
        }
        
        $PSObject = [PSCustomObject]@{
            "Prefix" = $Prefix
            "Thumbprint" = $Thumbprint
            "PublicKeyHash" = $PublicKeyHash
            "FullKey" = $Key
        }

        # Handle return response
        return $PSObject
    }
}