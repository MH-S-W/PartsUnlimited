param(
  [Parameter(Mandatory=$true)] [string] $ProjectPath,
  [Parameter(Mandatory=$true)] [string] $PublishDir,
  [Parameter(Mandatory=$true)] [string] $SiteName,
  [Parameter(Mandatory=$true)] [string] $AppPoolName,
  [Parameter(Mandatory=$true)] [int] $Port
)

Write-Host "Publish project: $ProjectPath to $PublishDir"

# Ensure publish directory exists
if (-Not (Test-Path $PublishDir)) {
  New-Item -ItemType Directory -Path $PublishDir -Force | Out-Null
}

# Publish using MSBuild WebPublish (FileSystem)
$msbuildArgs = "/p:Configuration=Release /p:WebPublishMethod=FileSystem /p:publishUrl=$PublishDir /p:DeleteExistingFiles=true /t:WebPublish"

Write-Host "Running MSBuild with args: $msbuildArgs"

# Try to find msbuild in PATH
$msbuild = 'msbuild'
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path $vswhere) {
  $vsPath = & $vswhere -latest -products * -requires Microsoft.Component.MSBuild -property installationPath | Select-Object -First 1
  if ($vsPath) {
    $msbuild = Join-Path $vsPath 'MSBuild\Current\Bin\MSBuild.exe'
    if (-not (Test-Path $msbuild)) { $msbuild = 'msbuild' }
  }
}

& $msbuild $ProjectPath $msbuildArgs
if ($LASTEXITCODE -ne 0) { throw "MSBuild failed with exit code $LASTEXITCODE" }

# Import WebAdministration for IIS configuration
Import-Module WebAdministration

# Create or update app pool
if (-not (Get-WebAppPoolState -Name $AppPoolName -ErrorAction SilentlyContinue)) {
  New-WebAppPool -Name $AppPoolName
  Set-ItemProperty IIS:\AppPools\$AppPoolName -Name managedRuntimeVersion -Value "v4.0"
  Set-ItemProperty IIS:\AppPools\$AppPoolName -Name processModel.identityType -Value "ApplicationPoolIdentity"
} else {
  Write-Host "AppPool $AppPoolName already exists"
}

# Create or update site
if (-not (Get-Website -Name $SiteName -ErrorAction SilentlyContinue)) {
  New-Website -Name $SiteName -Port $Port -PhysicalPath $PublishDir -ApplicationPool $AppPoolName
} else {
  Write-Host "Site $SiteName already exists. Updating physical path and app pool."
  Set-ItemProperty "IIS:\Sites\$SiteName" -Name physicalPath -Value $PublishDir
  Set-ItemProperty "IIS:\Sites\$SiteName" -Name applicationPool -Value $AppPoolName
}

# Set folder permissions for the app pool identity
$account = "IIS AppPool\$AppPoolName"
$acl = Get-Acl $PublishDir
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule($account,"Read,ReadAndExecute,ListDirectory","ContainerInherit,ObjectInherit","None","Allow")
$acl.SetAccessRule($rule)
Set-Acl $PublishDir $acl

Write-Host "Deployment complete. Site: http://localhost:$Port/"
