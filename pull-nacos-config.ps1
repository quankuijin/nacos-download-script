param(
    [string]$server = "http://localhost:8848",
    [string]$dataId = "",
    [string]$group = "DEFAULT_GROUP",
    [string]$namespace = "",
    [string]$output = "",
    [string]$username = "",
    [string]$password = "",
    [switch]$help
)

$ErrorActionPreference = "Stop"

# 设置TLS版本以支持HTTPS
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12, [Net.SecurityProtocolType]::Tls11, [Net.SecurityProtocolType]::Tls

# 忽略SSL证书验证问题（用于自签名证书的环境）
Add-Type @"
    using System.Net;
    using System.Net.Security;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertificatesPolicy : ICertificatePolicy {
        public bool CheckValidationResult(ServicePoint srvPoint, X509Certificate certificate, WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertificatesPolicy

# 禁用系统默认代理
[System.Net.WebRequest]::DefaultWebProxy = New-Object System.Net.WebProxy($null)
[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials

# 清理所有输入参数，移除特殊字符
function Clean-InputString([string]$inputStr) {
    if ([string]::IsNullOrEmpty($inputStr)) { return "" }
    # 循环清理直到没有更多需要清理的字符
    $cleanStr = $inputStr
    do {
        $oldStr = $cleanStr
        $cleanStr = $cleanStr.Trim('"', "'", '`', ' ', "`t", "`n", "`r")
    } while ($cleanStr -ne $oldStr)
    # 移除URL协议前缀前后的多余字符
    if ($cleanStr -match '^.*?(https?://.*)$') {
        $cleanStr = $matches[1]
    }
    return $cleanStr
}

$server = Clean-InputString $server
$dataId = Clean-InputString $dataId
$group = Clean-InputString $group
$namespace = Clean-InputString $namespace
$output = Clean-InputString $output
$username = Clean-InputString $username
$password = Clean-InputString $password

function Show-Help {
    Write-Host ""
    Write-Host "Nacos配置拉取工具 v1.0.0"
    Write-Host ""
    Write-Host "用法: pull-nacos-config.ps1 [选项]"
    Write-Host ""
    Write-Host "选项:"
    Write-Host "  --server     Nacos服务器地址 (默认: http://localhost:8848)"
    Write-Host "  --dataId     配置文件ID (必需)"
    Write-Host "  --group      配置分组 (默认: DEFAULT_GROUP)"
    Write-Host "  --namespace  命名空间ID (可选)"
    Write-Host "  --output     输出目录 (必需)"
    Write-Host "  --username   Nacos用户名 (可选)"
    Write-Host "  --password   Nacos密码 (可选)"
    Write-Host "  --help       显示帮助信息"
    Write-Host ""
    Write-Host "示例:"
    Write-Host "  .\pull-nacos-config.ps1 --dataId application.yml --output ./config"
    Write-Host "  .\pull-nacos-config.ps1 --server http://192.168.1.100:8848 --dataId app.yml --group DEV_GROUP --output ./config"
    Write-Host "  .\pull-nacos-config.ps1 --server http://localhost:8848 --dataId config.json --namespace dev --output ./config --username nacos --password nacos"
    Write-Host ""
}

function Get-NacosToken {
    param([string]$serverUrl, [string]$username, [string]$password)
    
    if ([string]::IsNullOrEmpty($username) -or [string]::IsNullOrEmpty($password)) {
        return ""
    }
    
    try {
        $serverUrl = Clean-InputString $serverUrl
        $serverUrl = $serverUrl.TrimEnd('/')
        $loginUrl = "$serverUrl/nacos/v1/auth/login"
        
        $body = "username=$([Uri]::EscapeDataString($username))&password=$([Uri]::EscapeDataString($password))"
        $response = Invoke-RestMethod -Uri $loginUrl -Method Post -Body $body -ContentType "application/x-www-form-urlencoded" -TimeoutSec 10
        
        if ($response.AccessToken) {
            Write-Host "[INFO] Success to get access token"
            return $response.AccessToken
        }
        return ""
    }
    catch {
        Write-Host "[WARN] Fail to get token: $_`nLogin URL: $loginUrl"
        return ""
    }
}

function Get-NacosConfig {
    param([string]$serverUrl, [string]$dataId, [string]$group, [string]$namespace, [string]$token)
    
    try {
        $serverUrl = Clean-InputString $serverUrl
        
        if ([string]::IsNullOrEmpty($serverUrl)) {
            throw "服务器地址无效，请检查 --server 参数"
        }
        
        # 确保serverUrl没有 trailing slash
        $serverUrl = $serverUrl.TrimEnd('/')
        
        $configUrl = "$serverUrl/nacos/v1/cs/configs"
        
        $params = @{ "dataId" = $dataId; "group" = $group }
        
        if (-not [string]::IsNullOrEmpty($namespace)) { $params["tenant"] = $namespace }
        if (-not [string]::IsNullOrEmpty($token)) { $params["accessToken"] = $token }
        
        $queryString = ($params.GetEnumerator() | ForEach-Object { "$($_.Key)=$([Uri]::EscapeDataString($_.Value))" }) -join "&"
        $fullUrl = "$configUrl?$queryString"
        
        $content = Invoke-RestMethod -Uri $fullUrl -Method Get -TimeoutSec 30
        
        if ($content) {
            return $content
        }
        throw "配置内容为空"
    }
    catch {
        throw "获取配置失败: $_`nServer: '$serverUrl'`nURL: $fullUrl"
    }
}

function Save-ConfigFile {
    param([string]$dataId, [string]$outputDir, [string]$content)
    
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    
    $filePath = Join-Path $outputDir $dataId
    $content | Out-File -FilePath $filePath -Encoding UTF8 -Force
    
    return $filePath
}

# 主逻辑
try {
    if ($help) {
        Show-Help
        exit 0
    }
    
    if ([string]::IsNullOrEmpty($dataId)) {
        Write-Host "[ERROR] Error: DataId is required --dataId"
        Show-Help
        exit 1
    }
    
    if ([string]::IsNullOrEmpty($output)) {
        Write-Host "[ERROR] Error: Output directory is required --output"
        Show-Help
        exit 1
    }
    
    Write-Host "[Nacos Config Tool] Start to pull config..."
    Write-Host ""
    Write-Host "[INFO] Server: $server"
    Write-Host "[INFO] Pulling: DataId=$dataId, Group=$group, Namespace=$namespace"
    Write-Host "[INFO] Username: $username"
    Write-Host "[INFO] Output: $output"
    
    $token = Get-NacosToken -serverUrl $server -username $username -password $password
    $content = Get-NacosConfig -serverUrl $server -dataId $dataId -group $group -namespace $namespace -token $token
    $filePath = Save-ConfigFile -dataId $dataId -outputDir $output -content $content
    
    Write-Host "[SUCCESS] Config saved to: $filePath"
    exit 0
}
catch {
    Write-Host "[ERROR] $_"
    exit 1
}
