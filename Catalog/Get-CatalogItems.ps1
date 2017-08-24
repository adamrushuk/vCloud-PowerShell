<#
Connect-Ciserver vcloud01
#>
# Variables
$Timestamp = (Get-Date -Format ("yyyy-MM-dd_HH-mm"))
$vAppTemplatePath = "$($env:TEMP)\vCloud-vAppTemplates-$($Timestamp).csv"
$MediaPath = "$($env:TEMP)\vCloud-Media-$($Timestamp).csv"
$CatalogNames = 'Catalogue', 'Windows Server 2012 R2', 'Windows Templates'

# Get Catalog items
$vAppTemplates = Get-CIVAppTemplate -Catalog $CatalogNames
$Media = Get-Media -Catalog $CatalogNames

# Export
Write-Host "Exporting vApp Templates to [$vAppTemplatePath]..."
$vAppTemplates | Export-Csv -Path $vAppTemplatePath -UseCulture -NoTypeInformation
Write-Host "Exporting Catalog Media to [$MediaPath]..."
$Media | Export-Csv -Path $MediaPath -UseCulture -NoTypeInformation