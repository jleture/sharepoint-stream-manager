Function Invoke-Start($scriptName, $currentDir) {
    Write-Host ""
    Write-Host -ForegroundColor Green "-------------------------------------------------"
    Write-Host -ForegroundColor Green " Start script: $scriptName"
    Write-Host -ForegroundColor Green "-------------------------------------------------"

    $Global:Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    $currentDate = (Get-Date).ToString("yyyyMMdd-HHmmss")

    try {
        $logsPath = "$currentDir\Logs"
        $global:LogFilePath = [string]::Format("$logsPath\{0}_{1}.log", $currentDate, $scriptName)
        if (!(Test-Path -Path $logsPath)) {
            New-Item -ItemType directory -Path $logsPath | Out-Null
        }
    }
    catch {
        Write-Host "ERROR New-Item $logsPath" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }

    try {
        Start-Transcript $global:LogFilePath
    }
    catch {
    }

    if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"]) {
        Write-Host "Set-PnPTraceLog On Debug" -NoNewline:$True
        Set-PnPTraceLog -On -Level Debug
    }
    else {
        Write-Host "Set-PnPTraceLog Off" -NoNewline:$True
        Set-PnPTraceLog -Off
    }
    Write-Host " [OK]" -ForegroundColor Green
}

Function Invoke-Stop() {
    Disconnect-Site
    
    $Global:Stopwatch.Stop()
    $totalSecs = [Math]::Round($Global:Stopwatch.Elapsed.TotalSeconds, 0)

    try {
        Stop-Transcript
    }
    catch {
    }

    Write-Host ""
    Write-Host -ForegroundColor Green "-------------------------------------------------"
    Write-Host -ForegroundColor Green " Executing time: $totalSecs s"
    Write-Host -ForegroundColor Green "-------------------------------------------------"
}

Function Get-Config($env) {
    $configFile = "Config.$env.json"
    if (!(Test-Path -Path $configFile)) {
        throw "Configuration file [$configFile] does not exist!"
    }

    Write-Host "Get-Content $configFile" -NoNewline:$True
    $json = Get-Content $configFile | ConvertFrom-Json
    Write-Host " [OK]" -ForegroundColor Green
    return $json
}

Function Disconnect-Site() {
    $context = $null
    try {
        $context = Get-PnpContext
    }
    catch {
    }

    if ($null -ne $context) {
        Write-Host "Disconnect-PnPOnline" -NoNewline:$True
        Disconnect-PnPOnline
        Write-Host " [OK]" -ForegroundColor Green
    }
}

Function Connect-Site($config, $siteUrl, $return = $False) {
    Write-Host "Connect to site $siteUrl" -NoNewline:$True
    $connection = $null
    if ($config.CertThumb -ne "") {
        $connection = Connect-PnPOnline -ClientId $($config.ClientId) -Thumbprint $($config.CertThumb) -Url $siteUrl -Tenant $($config.TenantName) -ReturnConnection:$return
    }
    elseif ($config.PfxPath -ne "") {
        $connection = Connect-PnPOnline -ClientId $($config.ClientId) -CertificatePath $($config.PfxPath) -CertificatePassword (ConvertTo-SecureString -AsPlainText $($config.PfxPwd) -Force) -Url $siteUrl -Tenant $($config.TenantName) -ReturnConnection:$return
    }
    else {
        $connection = Connect-PnPOnline -Url $siteUrl -Interactive -ReturnConnection:$return
    }
    
    Write-Host " [OK]"  -ForegroundColor Green
    return $connection
}

Function Add-Attribute($doc, $node, $key, $value) {
    $attr = $doc.CreateAttribute($key)
    $attr.Value = $value
    $node.Attributes.Append($attr) | Out-Null
}