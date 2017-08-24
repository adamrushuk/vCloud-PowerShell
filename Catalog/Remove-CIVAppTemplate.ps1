# vApp Template removal
# Vars
$Org = '11-22-33-abcdef'
$CatalogName = 'Catalog01'
$vAppTemplateName = 'vApp01'

# Connect to vCloud
Connect-CIServer vcloud01

# Get Catalog and vApp Template
$Catalog = Get-Catalog -org $Org -name $CatalogName
$vAppTemplate = $Catalog | Get-CIVAppTemplate -Name $vAppTemplateName

# Remove vApp Template
$vAppTemplate | Remove-CIVAppTemplate
