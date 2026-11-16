<#
.SYNOPSIS
    Crée les 10 salariés « locaux » de Nordelia dans l'Active Directory nordelia.local.

.DESCRIPTION
    Lab Nordelia, module 8, étape 8.3. À exécuter sur NOR-DC01 (PowerShell administrateur).
    Ces salariés sont de NOUVELLES personnes, absentes du tenant : aucun UPN ne doit
    correspondre à un compte cloud existant, sinon Entra fusionnerait les deux (soft match).
    UPN en @nordelia.onmicrosoft.com (suffixe UPN ajouté en 8.2), attribut mail identique.
    Idempotent : un compte qui existe déjà (ex. créé à la main) est ignoré.
    Le mot de passe initial est demandé une fois et n'est stocké nulle part.

.EXAMPLE
    .\New-NordeliaADUsers.ps1 -Simulation   # affiche ce qui serait créé
    .\New-NordeliaADUsers.ps1
#>
[CmdletBinding()]
param([switch]$Simulation)
$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory

$suffixe = 'nordelia.onmicrosoft.com'
$base    = 'OU=Nordelia,DC=nordelia,DC=local'

#            Prénom      Nom         Poste                          Département             Site    Pays
$salaries = @(
    @('Camille', 'Rousseau', 'Juriste',                         'Juridique',            'Paris', 'FR'),
    @('Antoine', 'Mercier',  'Acheteur',                        'Achats',               'Paris', 'FR'),
    @('Julie',   'Bernard',  'Assistante de direction',         'Direction',            'Paris', 'FR'),
    @('Lucas',   'Fournier', 'Développeur',                     'Informatique',         'Paris', 'FR'),
    @('Chloe',   'Lambert',  'Chargée de communication',        'Communication',        'Paris', 'FR'),
    @('Seydou',  'Kane',     'Comptable',                       'Finance',              'Dakar', 'SN'),
    @('Aissatou','Ndour',    'Chargée RH',                      'Ressources humaines',  'Dakar', 'SN'),
    @('Babacar', 'Sy',       'Consultant',                      'Consultants',          'Dakar', 'SN'),
    @('Ndeye',   'Thiam',    'Consultante',                     'Consultants',          'Dakar', 'SN'),
    @('Mamadou', 'Kouyate',  'Technicien support',              'Informatique',         'Dakar', 'SN')
)

if (-not $Simulation) {
    $mdp = Read-Host -AsSecureString "Mot de passe initial des comptes (propre au lab)"
}

$crees = 0; $ignores = 0
foreach ($s in $salaries) {
    $prenom, $nom, $poste, $dept, $site, $pays = $s
    $sam = "$($prenom.ToLower()).$($nom.ToLower())"
    $upn = "$sam@$suffixe"
    $ou  = "OU=$site,$base"

    if (Get-ADUser -Filter "UserPrincipalName -eq '$upn' -or SamAccountName -eq '$sam'") {
        Write-Host "Existe déjà : $upn" -ForegroundColor Yellow; $ignores++; continue
    }
    if ($Simulation) { Write-Host "[Simulation] $prenom $nom -> $upn ($ou)"; continue }

    New-ADUser -Name "$prenom $nom" -GivenName $prenom -Surname $nom -DisplayName "$prenom $nom" `
        -SamAccountName $sam -UserPrincipalName $upn -EmailAddress $upn `
        -Title $poste -Department $dept -Company 'Nordelia' -Office $site -City $site -Country $pays `
        -Path $ou -AccountPassword $mdp -Enabled $true -ChangePasswordAtLogon $false
    Write-Host "Créé : $upn ($site)" -ForegroundColor Green; $crees++
}

Write-Host "`n$crees créé(s), $ignores ignoré(s)." -ForegroundColor Cyan
Get-ADUser -Filter * -SearchBase $base -Properties Title, Department, Office |
    Sort-Object Office, Name | Format-Table Name, UserPrincipalName, Title, Department, Office -AutoSize
