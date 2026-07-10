function Invoke-PasswordGeneration {
    <#
    .SYNOPSIS
        Generate a random password string.

    .DESCRIPTION
        Generate a random password string with a specified length and optional allowed characters.

    .PARAMETER Length
        Specify the length of the password to generate.

    .PARAMETER AllowedCharacters
        Specify a string containing the allowed characters for password generation. If not specified, defaults to lowercase letters, uppercase letters, digits, and symbols.

    .NOTES
        Author:      Henry Kon
        Contact:     @AptLogic
        Created:     2026-07-10
        Updated:     2026-07-10

        Version history:
        1.0.0 - (2026-07-10) Function created
    #>
    param(
        [parameter(Mandatory = $false, HelpMessage = "Specify the length of the password to generate.")]
        [ValidateRange(4, 128)]
        [int]$Length = 16,

        [parameter(Mandatory = $false, HelpMessage = "Specify a string containing the allowed characters for password generation.")]
        [ValidateNotNullOrEmpty()]
        [string]$AllowedCharacters = ''
    )
    
    Process {
        # Define default character sets
        $defaultLower  = 'abcdefghijklmnopqrstuvwxyz'
        $defaultUpper  = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
        $defaultDigits = '0123456789'
        $defaultSymbols = '!@#$%^&*()_+~-=[]{}|;:,.<>/?'

        # Split allowed characters into categories if provided, otherwise use defaults
        if ($AllowedCharacters) {
            $lower  = ($AllowedCharacters | Where-Object { $_ -match '[a-z]' }) -join ''
            $upper  = ($AllowedCharacters | Where-Object { $_ -match '[A-Z]' }) -join ''
            $digits = ($AllowedCharacters | Where-Object { $_ -match '[0-9]' }) -join ''
            $symbols = ($AllowedCharacters | Where-Object { $_ -notmatch '[a-zA-Z0-9]' }) -join ''
        } else {
            $lower  = $defaultLower
            $upper  = $defaultUpper
            $digits = $defaultDigits
            $symbols = $defaultSymbols
        }

        # Combine all characters
        $all = $lower + $upper + $digits + $symbols

        # Enforce at least one of each character type (only if that type is available)
        $password = @()
        if ($upper)  { $password += (Get-Random -InputObject $upper.ToCharArray()) }
        if ($lower)  { $password += (Get-Random -InputObject $lower.ToCharArray()) }
        if ($digits) { $password += (Get-Random -InputObject $digits.ToCharArray()) }
        if ($symbols) { $password += (Get-Random -InputObject $symbols.ToCharArray()) }

        # Fill the rest randomly
        for ($i = $password.Length; $i -lt $Length; $i++) {
            $password += (Get-Random -InputObject $all.ToCharArray())
        }

        # Shuffle the characters and output the string
        return $password | Get-Random -Count $password.Length | Join-String

    }
}