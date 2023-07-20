[CmdletBinding()]
param(
	[string]$Env = "LAB",
	[Parameter(Mandatory = $True)][string]$TargetSiteUrl,
	[Parameter(Mandatory = $True)][string]$TargetPlaylistName,
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
	
	Connect-Site $config $TargetSiteUrl

	Write-Host "Get-PnPSiteTemplate '$TemplateFile'" -NoNewline
	if (-not(Test-Path -Path $TemplateFile)) {
		throw "Template file '$TemplateFile' does not exist!"
	}
	Write-Host -ForegroundColor Green " [OK]"

	Write-Host "Create a new playlist '$TargetPlaylistName' with the template file '$TemplateFile'" -NoNewline
	Invoke-PnPSiteTemplate -Path $TemplateFile -Parameters @{ "PlaylistUrl" = $TargetPlaylistName }
	Write-Host -ForegroundColor Green " [OK]"

	Write-Host "Get new playlist '$TargetPlaylistName'" -NoNewline
	$newPlaylist = Get-PnPList -Identity $TargetPlaylistName -ErrorAction SilentlyContinue
	if ($null -ne $newPlaylist) {
		Write-Host -ForegroundColor Green " [OK]"

		Write-Host "Set TemplateTypeId to playlist '$TargetPlaylistName'" -NoNewline
		$newPlaylist.TemplateTypeId = "3a867b4a-7429-0e1a-b02e-bf4b240ff1ce" # GUID of Stream playlist cf. https://learn.microsoft.com/en-us/sharepoint/control-lists#disable-built-in-list-templates
		$newPlaylist.Update()
		Invoke-PnPQuery
		Write-Host -ForegroundColor Green " [OK]"
	}
	else {
		throw "Playlist '$TargetPlaylistName' was not created!"
	}
}
catch {
	Write-Error $_
}
finally {
	Invoke-Stop
}