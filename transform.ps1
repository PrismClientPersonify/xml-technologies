param(
    [string]$InputPath = (Join-Path $PSScriptRoot 'data.xml'),
    [string]$OutputPath = (Join-Path $PSScriptRoot 'result.html')
)

$ErrorActionPreference = 'Stop'
$transform = [System.Xml.Xsl.XslCompiledTransform]::new()
# Стандартные настройки запрещают скрипты и функцию document().
$transform.Load((Join-Path $PSScriptRoot 'transform.xsl'))
$settings = $transform.OutputSettings.Clone()
$settings.Encoding = [System.Text.UTF8Encoding]::new($false)
$writer = [System.Xml.XmlWriter]::Create($OutputPath, $settings)
try {
    $transform.Transform($InputPath, $writer)
} finally {
    $writer.Dispose()
}
Write-Output "Created: $OutputPath"
