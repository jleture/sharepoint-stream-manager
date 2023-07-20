# sharepoint-stream-manager

PowerShell scripts to export Stream playlist template, create new playlist instances and add videos

> Thanks to **Jurgen Wiersema** and his article [Microsoft Cloud Developer](http://www.msclouddeveloper.com/find-create-and-fill-a-video-playlist-in-sharepoint-online-with-powershell/) that helps me to understand the JSON structure of the `VideoIdentifiers` column.

## History

| Version | Date | Comments |
| - | - | - |
| 1.0 | 2023-07-20 | Initial release


## Files
| File | Role |
| - | - |
| **_Helpers.ps1** | Useful methods (log, connection, etc.) |
| **Config.LAB.json** | Configuration file with tenant, app registration and certificate |
| **GetPlaylistTemplate.ps1** | Script to generate the playlist template |
| **NewPlaylist.ps1** | Script to create a playlist with the template |
| **SetPlaylist.ps1** | Script to add videos in a playlist |

$~$

## Prerequisities

**Pnp PowerShell** must be installed on your computer.

To check if the module is installed, you can use the following command:

~~~powershell
Get-Module PnP.PowerShell -ListAvailable | Select-Object Name,Version | Sort-Object Version -Descending 
~~~
If not, you can install the latest version:

~~~powershell
Install-Module PnP.PowerShell 
~~~

$~$

## Configuration

Create a new configuration file based on `Config.LAB.json` or edit this one.

When executing the scripts, the code-name of the configuration should be passed as an argument:

~~~powershell
.\GetPlaylistTemplate.ps1 -Env LAB
.\GetPlaylistTemplate.ps1 -Env PROD
~~~

To connect to SharePoint, it's better to have an **Azure app registration** with **SharePoint > Sites.FullControl.All** application permission (`ClientId`). The app registration must used a certificate. This certificate can be referenced by its path and password (`PfxPath` and `PfxPwd`) or installed in your certifcates store and referenced by its thumbprint (`CertThumb`).

If no certificate with password or thumbprint is indicated in the configuration file, the connection will use your browser (interactive mode). So, if your leave blank every value in the configuration file, it should still work if you have an interactive account with SharePoint administration role.

~~~json
{
    "ClientId" : "guid-of-your-app-registration or empty",
    "CertThumb": "your-pfx-thumbprint or empty",
    "PfxPath": "C:/Temp/your-pfx.pfx or empty",
    "PfxPwd": "your-pfx-password or empty",
    "TenantName": "your-tenant.onmicrosoft.com"
}
~~~
$~$

## Create a new playlist with Stream web interface

*Note : this step is optional. You can create a playlist programmatically with the template included in this repository (`playlist-template.xml`). Having a first playlist created by the web interface helps to understand how to create a template playlist.*

To create a playlist, you must open a web browser on the `Microsoft 365 portal` and search [Stream](https://www.microsoft365.com/launch/stream?auth=2) web application.

On the `Stream portal`, click on `Playlist`.

Enter a name (*Playlist* for example) and select a site where to save it. Click on `Create`.

Congrats! Your first Stream playlist is now created and ready to use.

$~$

## Create the playlist template (GetPlaylistTemplate.ps1)

*Note : to create a playlist template file, you must have a playlist on your SharePoint environment. If you want to use the template included in this repository (`playlist-template.xml`), you can skip this step.*

The script has five steps:
1. Get the template file from a playlist created with the web interface
2. Replace the playlist URL by `{parameter:PlaylistUrl}`
3. Declare the URL parameter in the `pnp:Parameters` node
4. Inject the field definition of the hidden field `VideoIdentifiers` (not included when extracting the template)
5. Write the final version of the template (default value: `playlist-template.xml`)

~~~powershell
.\GetPlaylistTemplate.ps1 -Env LAB -TemplateSiteUrl "https://your-tenant.sharepoint.com/sites/your-site" -TemplatePlaylistName "My Playlist
~~~

You can add `-Verbose` to display more information in the terminal. Also, a log file is generated for each execution all in the `Logs` folder.

~~~powershell
.\GetPlaylistTemplate.ps1 -Env LAB -TemplateSiteUrl "https://your-tenant.sharepoint.com/sites/your-site" -TemplatePlaylistName "My Playlist" -TemplateFile "my-playlist.xml" -Verbose
~~~

## Create a new playlist with the template (NewPlaylist.ps1)

This script create a new playlist on a SharePoint website thanks to the template file generated with the previous script, or the one included in this repository.

You must specify:
- the URL of the target SharePoint site (`TargetSiteUrl`)
- the name of the target playlist (`TargetPlaylistName`)
- the file of the playlist template (`TemplateFile`, default value: `playlist-template.xml`)

~~~powershell
.\NewPlaylist.ps1 -Env LAB -TargetSiteUrl "https://your-tenant.sharepoint.com/sites/your-site" -TargetPlaylistName "Training"
~~~

You can add `-Verbose` to display more information in the terminal.

~~~powershell
.\NewPlaylist.ps1 -Env LAB -TargetSiteUrl "https://your-tenant.sharepoint.com/sites/your-site" -TargetPlaylistName "Training" -TemplateFile "playlist-template.xml" -Verbose
~~~


## Add existing videos to a playlist (SetPlaylist.ps1)

This script get videos from a SharePoint documents library and add them in a playlist created, inside the same site, or on other websites. The purpose of a Stream playlist is to **reference** and not **store** videos. Therefore, videos are only stored once, in the source SharePoint documents library, but they can be referenced on multiple sites.

You must specify:
- the URL of the source SharePoint site (`SourceSiteUrl`)
- the name of the source SharePoint documents library (`SourceLibrary`)
- the URL of the target SharePoint site (`TargetSiteUrl`)
- the name of the target playlist on the target SharePoint site (`TargetPlaylistName`)

~~~powershell
.\SetPlaylist.ps1 -Env LAB -SourceSiteUrl "https://your-tenant.sharepoint.com/sites/your-site" -SourceLibrary "Documents" -TargetSiteUrl "https://your-tenant.sharepoint.com/sites/your-training-site" -TargetPlaylistName "Training"
~~~

You can add `-Verbose` to display more information in the terminal.

~~~powershell
.\SetPlaylist.ps1 -Env LAB -Verbose
~~~

Only `.mp4` files stored in the document library will be added to the playlist.

You can change the CAML query as you wish to include other file type or filter content depending on metadata.


