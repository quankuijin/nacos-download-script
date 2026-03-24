param(
    [string]$serverUrl = "http://localhost:8848",
    [string]$dataId = "",
    [string]$group = "DEFAULT_GROUP",
    [string]$namespace = "",
    [string]$outputDir = "",
    [string]$username = "",
    [string]$password = ""
)

$ErrorActionPreference = 'Stop'
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Get-NacosToken {
    param($serverUrl, $username, $password)
    
    if ([string]::IsNullOrEmpty($username) -or [string]::IsNullOrEmpty($password)) {
        return ''
    }
    
    try {
        $loginUrl = "$serverUrl/nacos/v1/auth/login"
        $body = "username=$([Uri]::EscapeDataString($username))&password=$([Uri]::EscapeDataString($password))"
        $response = Invoke-RestMethod -Uri $loginUrl -Method Post -Body $body -ContentType 'application/x-www-form-urlencoded' -TimeoutSec 10
        
        if ($response.AccessToken) {
            Write-Host '[INFO] 成功获取Nacos访问令牌'
            return $response.AccessToken
        }
        return ''
    } catch {
        Write-Host "[WARN] 获取Token失败: $_"
        return ''
    }
}

function Get-NacosConfig {
    param($serverUrl, $dataId, $group, $namespace, $token)
    
    $configUrl = "$serverUrl/nacos/v1/cs/configs"
    $params = @{'dataId' = $dataId; 'group' = $group}
    
    if (-not [string]::IsNullOrEmpty($namespace)) {
        $params['tenant'] = $namespace
    }
    if (-not [string]::IsNullOrEmpty($token)) {
        $params['accessToken'] = $token
    }
    
    $queryString = ($params.GetEnumerator() | ForEach-Object { 
        "$($_.Key)=$([Uri]::EscapeDataString($_.Value))" 
    }) -join '&'
    
    $fullUrl = "$configUrl?$queryString"
    
    try {
        $content = Invoke-RestMethod -Uri $fullUrl -Method Get -TimeoutSec 30
        if ($content) {
            return $content
        }
        throw '配置内容为空'
    } catch {
        throw "获取配置失败: $_"
    }
}

function Save-ConfigFile {
    param($dataId, $outputDir, $content)
    
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    
    $filePath = Join-Path $outputDir $dataId
    $content | Out-File -FilePath $filePath -Encoding UTF8 -Force
    
    return $filePath
}

try {
    Write-Host "[INFO] 拉取配置: DataId=$dataId, Group=$group, Namespace=$namespace"
    
    $token = Get-NacosToken -serverUrl $serverUrl -username $username -password $password
    $content = Get-NacosConfig -serverUrl $serverUrl -dataId $dataId -group $group -namespace $namespace -token $token
    $filePath = Save-ConfigFile -dataId $dataId -outputDir $outputDir -content $content
    
    Write-Host "[SUCCESS] 配置已保存: $filePath"
    exit 0
} catch {
    Write-Host "[ERROR] $_"
    exit 1
}
