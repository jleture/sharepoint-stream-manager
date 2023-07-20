[CmdletBinding()]
param(
	[string]$Env = "LAB",
	[Parameter(Mandatory = $True)][string]$SourceSiteUrl,
	[Parameter(Mandatory = $True)][string]$SourceLibrary,
	[Parameter(Mandatory = $True)][string]$TargetSiteUrl,
	[Parameter(Mandatory = $True)][string]$TargetPlaylistName
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
	
	$sharePointRootUrl = ($SourceSiteUrl -split '/')[0..2] -join '/' 
	Write-Verbose "sharePointRootUrl: $sharePointRootUrl"

	$sourceConnection = Connect-Site $config $SourceSiteUrl $True
	$sourceSite = Get-PnPSite -Includes ID -Connection $sourceConnection -ErrorAction SilentlyContinue
	if ($null -eq $sourceSite) {
		throw "Site '$SourceSiteUrl' does not exist!"
	}

	$sourceSiteId = $sourceSite.Id
	Write-Verbose "sourceSiteId: $sourceSiteId"
	
	$sourceList = Get-PnPList -Identity $SourceLibrary -Connection $sourceConnection -ErrorAction SilentlyContinue
	if ($null -eq $sourceList) {
		throw "Playlist '$SourceLibrary' does not exist on site [$SourceSiteUrl]!"
	}

	Get-PnPProperty -ClientObject $sourceList -Property 'ParentWeb'  -Connection $sourceConnection | Out-Null
	$sourceListId = $sourceList.Id
	Write-Verbose "sourceListId: $sourceListId"
	
	$sourceWebAbsoluteUrl = $sourceList.ParentWeb.Url
	Write-Verbose "sourceWebAbsoluteUrl: $sourceWebAbsoluteUrl"

	$sourceListFullUrl = $sharePointRootUrl + $sourceList.RootFolder.ServerRelativeUrl
	Write-Verbose "sourceListFullUrl: $sourceListFullUrl"
	
	Write-Host "Get-PnPListItem on list '$SourceLibrary' on site '$SourceSiteUrl'" -NoNewline

	$queryMp4 = @"
<View Scope='RecursiveAll'>
	<Query>
	  <Where>
		<Contains>
		  <FieldRef Name='File_x0020_Type'/>
		  <Value Type='text'>mp4</Value>
		</Contains>
	  </Where>
	</Query>
  </View>
"@

	$sourceItems = Get-PnPListItem -List $sourceList -Query $queryMp4 -Connection $sourceConnection
	Write-Host -ForegroundColor Green " [OK]"

	$targetConnection = Connect-Site $config $TargetSiteUrl $True

	Write-Host "New-PnPBatch for '$TargetSiteUrl'" -NoNewline
	$batch = New-PnPBatch -Connection $targetConnection
	Write-Host -ForegroundColor Green " [OK]"

	$filesCount = $sourceItems.Count
	$increment = 100 / $filesCount
	foreach ($item in $sourceItems) {
		$i += 1
		$ip = $increment * $i
			
		Get-PnPProperty -ClientObject $item -Property 'File' -Connection $sourceConnection | Out-Null
	
		$title = $item.File.Name
		$uniqueId = $item.File.UniqueId
		$id = $item.Id
		$owner = $item["Author"].Email

		Write-Progress -Activity "Uploading" -Status "$i/$filesCount | $title" -PercentComplete $ip
	
		Write-Verbose "$id`t$title`t$owner"
		
		$webDavUrl = $sharePointRootUrl + $item.File.ServerRelativeUrl
		Write-Verbose "webDavUrl: $webDavUrl"
	
		$thumbnail = "$sourceWebAbsoluteUrl/_api/v2.0/sites/$sourceSiteId/lists/$sourceListId/items/$uniqueId/driveItem/thumbnails/0/c90x150/content?prefer=noredirect"
		Write-Verbose "thumbnail: $thumbnail"

		$durationInSeconds = $item.FieldValues.MediaLengthInSeconds
		$timespan = [TimeSpan]::FromSeconds($durationInSeconds)
		$duration = $timespan.ToString("hh\:mm\:ss")
		Write-Verbose "durationInSeconds: $durationInSeconds, duration: $duration"

		$videoIdentifiers = @{
			"UniqueId"       = $uniqueId;
			"Id"             = $id;
			"WebAbsoluteUrl" = $sourceWebAbsoluteUrl;
			"ListFullUrl"    = $sourceListFullUrl;
			"WebDavUrl"      = $webDavUrl
		}
	
		$values = @{
			"Thumbnail"        = $thumbnail;
			"Title"            = $title;
			"Owner"            = $owner;
			"Duration"         = $duration;
			"VideoIdentifiers" = ConvertTo-Json -InputObject $videoIdentifiers
		}

		Add-PnPListItem -Connection $targetConnection -List $TargetPlaylistName -Values $values -Batch $batch | Out-Null
	}

	Write-Host "Invoke-PnPBatch on list '$TargetPlaylistName' on site '$TargetSiteUrl'" -NoNewline
	Invoke-PnPBatch -Batch $batch -Connection $targetConnection
	Write-Host -ForegroundColor Green " [OK]"
}
catch {
	Write-Error $_
}
finally {
	Invoke-Stop
}