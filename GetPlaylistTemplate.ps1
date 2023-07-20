[CmdletBinding()]
param(
	[string]$Env = "LAB",
	[Parameter(Mandatory = $True)][string]$TemplateSiteUrl,
	[Parameter(Mandatory = $True)][string]$TemplatePlaylistName,
	[string]$TemplateFile = "playlist-template.xml"
)

$ScriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$TemplateFile = "$ScriptDirectory/$TemplateFile"
try {
	. ("$ScriptDirectory\_Helpers.ps1")
}
catch {
	Write-Error "Error while loading PowerShell scripts" 
	Write-Error $_.Exception.Message
}

Invoke-Start $MyInvocation.MyCommand.Name $ScriptDirectory

try {
	$config = Get-Config $Env
	$config
	
	Connect-Site $config $TemplateSiteUrl

	Write-Host "Get-PnPSiteTemplate for List '$TemplatePlaylistName' to '$TemplateFile'" -NoNewline
	Get-PnPSiteTemplate -Out $TemplateFile -Handlers Lists -ListsToExtract $TemplatePlaylistName -Force
	Write-Host -ForegroundColor Green " [OK]"

	Write-Host "Replace template list URL by a parameter" -NoNewline
	$templateContent = Get-Content -Path $TemplateFile -Encoding UTF8
	$templateContent = $templateContent.replace($TemplatePlaylistName, "{parameter:PlaylistUrl}")
	$templateContent = $templateContent.replace("[[Duration]]", "[Duration]") # To fix a bug: why there are double brackets in the formula when generating the template?
	Write-Host -ForegroundColor Green " [OK]"

	Write-Host "Add 'pnp:Parameters' node" -NoNewline
	$templateContentXml = [xml]($templateContent)

	[System.Xml.XmlNamespaceManager] $nsm = New-Object System.Xml.XmlNamespaceManager($templateContentXml.NameTable)
	$pnpUrl = 'http://schemas.dev.office.com/PnP/2022/09/ProvisioningSchema'
	$nsm.AddNamespace('pnp', $pnpUrl)

	$parameterXml = $templateContentXml.CreateElement("pnp:Parameter", $pnpUrl)
	Add-Attribute $templateContentXml $parameterXml "Key" "PlaylistUrl"
	Add-Attribute $templateContentXml $parameterXml "Required" "true"
	$parametersXml = $templateContentXml.CreateElement("pnp:Parameters", $pnpUrl)
	$parametersXml.AppendChild($parameterXml) | Out-Null
	$templateContentXml.Provisioning.Preferences.AppendChild($parametersXml) | Out-Null
	Write-Host -ForegroundColor Green " [OK]"
	
	$videoIdentifiersFieldName = "VideoIdentifiers"
	Write-Host "Add hidden field '$videoIdentifiersFieldName'" -NoNewline
	$videoIdentifiersField = Get-PnpField -List $TemplatePlaylistName -Identity $videoIdentifiersFieldName -ErrorAction SilentlyContinue
	if ($null -ne $videoIdentifiersField) {
		[xml]$videoIdentifiersNode = $videoIdentifiersField.SchemaXml
		$templateContentXml.Provisioning.Templates.ProvisioningTemplate.Lists.ListInstance.Fields.AppendChild($templateContentXml.ImportNode($videoIdentifiersNode.Field, $true)) | Out-Null
	}
	else {
		$fieldXml = $templateContentXml.CreateElement("Field")
		Add-Attribute $templateContentXml $fieldXml "ID" "{3189069f-ce6f-43cb-9a76-b61111da91e4}"
		Add-Attribute $templateContentXml $fieldXml "DisplayName" "VideoIdentifiers"
		Add-Attribute $templateContentXml $fieldXml "Description" "This field contains video identifiers deemed important for the rendering the videos in the playlist"
		Add-Attribute $templateContentXml $fieldXml "Name" "VideoIdentifiers"
		Add-Attribute $templateContentXml $fieldXml "Title" "VideoIdentifiers"
		Add-Attribute $templateContentXml $fieldXml "Type" "Note"
		Add-Attribute $templateContentXml $fieldXml "CanToggleHidden" "FALSE"
		Add-Attribute $templateContentXml $fieldXml "Hidden" "TRUE"
		Add-Attribute $templateContentXml $fieldXml "StaticName" "VideoIdentifiers"
		Add-Attribute $templateContentXml $fieldXml "ColName" "ntext3"
		Add-Attribute $templateContentXml $fieldXml "RowOrdinal" "0"
		Add-Attribute $templateContentXml $fieldXml "SourceID" "{00B44789-EB63-42F1-8A39-4982936F317B}"
		Add-Attribute $templateContentXml $fieldXml "Version" "1"
		$templateContentXml.Provisioning.Templates.ProvisioningTemplate.Lists.ListInstance.Fields.AppendChild($fieldXml) | Out-Null
	}
	Write-Host -ForegroundColor Green " [OK]"

	Write-Host "Save template file '$TemplateFile'" -NoNewline
	$templateContentXml.Save($TemplateFile)
	Write-Host -ForegroundColor Green " [OK]"
}
catch {
	Write-Error $_
}
finally {
	Invoke-Stop
}