param(
    [string]$ServerUrl = "http://localhost:8848",
    [string]$DataId = "",
    [string]$Group = "DEFAULT_GROUP",
    [string]$Namespace = "",
    [string]$OutputDir = "",
    [string]$Username = "",
    [string]$Password = ""
)

$ErrorActionPreference = 'Stop'

function Show-Help {
    Write-Host ""
    Write-Host "Nacos配置拉取工具 v1.0.0"
    Write-Host ""
    Write-Host "用法: pull-nacos-config.ps1 [选项]"
    Write-Host ""
    Write-Host "选项:"
    Write-Host "  -ServerUrl     Nacos服务器地址 (默认: http://localhost:8848)"
    Write-Host "  -DataId        配置文件ID (必需)"
    Write-Host "  -Group         配置分组 (默认: DEFAULT_GROUP)"
    Write-Host "  -Namespace     命名空间ID (可选)"
    Write-Host "  -OutputDir     输出目录 (必需)"
    Write-Host "  -Username      Nacos用户名 (可选)"
    Write-Host "  -Password      Nacos密码 (可选)"
    Write-Host "  -Help          显示帮助信息"
    Write-Host ""
    Write-Host "示例:"
    Write-Host "  .\pull-nacos-config.ps1 -DataId application.yml -OutputDir ./config"
    Write-Host "  .\pull-nacos-config.ps1 -ServerUrl http://192.168.1.100:8848 -DataId app.yml -Group DEV_GROUP -OutputDir ./config"
    Write-Host "  .\pull-nacos-config.ps1 -ServerUrl http://localhost:8848 -DataId config.json -Namespace dev -OutputDir ./config -Username nacos -Password nacos"
    Write-Host ""
}

if ($Help -or $DataId -eq "" -or $OutputDir -eq "") {
    Show-Help
    exit 1
}

function Get-NacosToken([string]$serverUrl, [string]$username, [string]$password) {
    if ([string]::IsNullOrEmpty($username) -or [string]::IsNullOrEmpty($password)) { 
        return '' 
    }
    try {
        $loginUrl = "$serverUrl/nacos/v1/auth/login"
        $body = "username=$([Uri]::EscapeDataString($username))&password=$([Uri]::EscapeDataString($password))"
        $response = Invoke-RestMethod -Uri $loginUrl -Method Post -Body $body -ContentType 'application/x-www-form-urlencoded' -TimeoutSec 10 -UseBasicParsing
        if ($response.accessToken) { 
            Write-Host '[INFO] 成功获取Nacos访问令牌'
            return $response.accessToken
        }
        if ($response.token) {
            Write-Host '[INFO] 成功获取Nacos访问令牌'
            return $response.token
        }
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

function Get-NacosConfig([string]$serverUrl, [string]$dataId, [string]$group, [string]$namespace, [string]$token) {
    $configUrl = "$serverUrl/nacos/v1/cs/configs"
    $params = @{'dataId'=$dataId; 'group'=$group}
    if (-not [string]::IsNullOrEmpty($namespace)) { $params['tenant'] = $namespace }
    if (-not [string]::IsNullOrEmpty($token)) { $params['accessToken'] = $token }
    $queryParts = @()
    foreach ($key in $params.Keys) {
        $queryParts += "$key=$([Uri]::EscapeDataString($params[$key]))"
    }
    $queryString = $queryParts -join '&'
    $fullUrl = "$configUrl?$queryString"
    Write-Host "[INFO] 请求URL: $fullUrl"
    try {
        $content = Invoke-RestMethod -Uri $fullUrl -Method Get -TimeoutSec 30 -UseBasicParsing
        if ($content) { return $content }
        throw '配置内容为空'
    } catch {
        throw "获取配置失败: $_"
    }
}

function Save-ConfigFile([string]$dataId, [string]$outputDir, [string]$content) {
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        Write-Host "[INFO] 创建输出目录: $outputDir"
    }
    $safeFileName = $dataId -replace '[<>\:`"/\\|?*]', '_'
    $filePath = Join-Path $outputDir $safeFileName
    $content | Out-File -FilePath $filePath -Encoding UTF8 -Force
    return $filePath
}

Write-Host "[Nacos配置拉取工具] 开始拉取配置..."
Write-Host ""

try {
    Write-Host "[INFO] 拉取配置: DataId=$DataId, Group=$Group, Namespace=$Namespace"
    $token = Get-NacosToken -serverUrl $ServerUrl -username $Username -password $Password
    $content = Get-NacosConfig -serverUrl $ServerUrl -dataId $DataId -group $Group -namespace $Namespace -token $token
    $filePath = Save-ConfigFile -dataId $DataId -outputDir $OutputDir -content $content
    Write-Host "[SUCCESS] 配置已保存: $filePath"
    exit 0
} catch {
    Write-Host "[ERROR] $_"
    exit 1
}
