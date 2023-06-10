Param (
    $Email,
    $GDKey,
    $GDSecret,
    $Hostname
)

$pArgs = @{
    GDKey = $GDKey
    GDSecret = (Read-Host $GDSecret -AsSecureString)
}
New-PACertificate example.com -Plugin GoDaddy -PluginArgs $pArgs -Contact $Email
