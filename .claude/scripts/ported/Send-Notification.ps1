# notify-me: Send Outlook email notification with session summary
# Invoked via /notify-me skill

param(
    [Parameter(Mandatory=$true)]
    [string]$Subject,

    [Parameter(Mandatory=$true)]
    [string]$Summary,

    [Parameter(Mandatory=$false)]
    [string]$WorkingDir = (Get-Location).Path
)

$ErrorActionPreference = "Continue"

function Get-CurrentUserEmail {
    <#
    .SYNOPSIS
    Auto-detect the current user's email address using multiple fallback methods.

    .DESCRIPTION
    Tries the following methods in order:
    1. Active Directory LDAP query (most reliable for enterprise)
    2. Outlook COM to get primary account SMTP address
    3. Windows domain DNS (username@userdnsdomain)
    #>

    # 1. Active Directory (most reliable in enterprise)
    try {
        $searcher = [System.DirectoryServices.DirectorySearcher]::new()
        $searcher.Filter = "(&(objectClass=user)(sAMAccountName=$env:USERNAME))"
        $searcher.PropertiesToLoad.Add("mail") | Out-Null
        $result = $searcher.FindOne()
        if ($result -and $result.Properties["mail"].Count -gt 0) {
            $email = $result.Properties["mail"][0]
            if ($email) {
                return $email
            }
        }
    } catch {
        # AD query failed, try next method
    }

    # 2. Outlook COM (primary account)
    try {
        $outlook = New-Object -ComObject Outlook.Application
        $namespace = $outlook.GetNamespace("MAPI")
        $email = $namespace.Accounts.Item(1).SmtpAddress
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($namespace) | Out-Null
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($outlook) | Out-Null
        if ($email) {
            return $email
        }
    } catch {
        # Outlook COM failed, try next method
    }

    # 3. Windows domain DNS
    if ($env:USERDNSDOMAIN) {
        return "$env:USERNAME@$env:USERDNSDOMAIN"
    }

    throw "Could not auto-detect email address. Ensure you are on a domain-joined machine or have Outlook configured."
}


# Main execution
try {
    # Auto-detect user email
    $userEmail = Get-CurrentUserEmail

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $body = @"
$Summary

Working Directory: $WorkingDir
Timestamp: $timestamp
"@

    # Send email via Outlook COM
    $outlook = New-Object -ComObject Outlook.Application
    $mail = $outlook.CreateItem(0)  # 0 = olMailItem
    $mail.To = $userEmail
    $mail.Subject = $Subject
    $mail.Body = $body
    $mail.Send()

    # Clean up COM objects
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($mail) | Out-Null
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($outlook) | Out-Null

    Write-Host "Email notification sent to $userEmail"
    exit 0

} catch {
    # Non-blocking failure - log error but exit cleanly
    Write-Warning "Failed to send email notification: $($_.Exception.Message)"
    exit 0  # Exit 0 to not block the agent
}
