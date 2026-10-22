$ErrorActionPreference = 'Stop'
$transform = [System.Xml.Xsl.XslCompiledTransform]::new()
$transform.Load((Join-Path $PSScriptRoot 'transform.xsl'))
$script:checks = 0

function Assert-Equal($actual, $expected, [string]$message) {
    if ([string]$actual -cne [string]$expected) {
        throw "${message}: expected '$expected', got '$actual'"
    }
    $script:checks++
    Write-Output "PASS: $message"
}

function Convert-TestXml([string]$source) {
    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($source))
    $buffer = [System.Text.StringBuilder]::new()
    # XML writer удобен для XPath-проверок структуры результата в памяти.
    $writer = [System.Xml.XmlWriter]::Create($buffer)
    try {
        $transform.Transform($reader, $writer)
    } finally {
        $writer.Dispose()
        $reader.Dispose()
    }
    return ,([xml]$buffer.ToString())
}

$source = Get-Content (Join-Path $PSScriptRoot 'data.xml') -Raw -Encoding utf8
$actual = Convert-TestXml $source
Assert-Equal $actual.SelectNodes('/html/body/ul/li').Count 2 'Two cities'
Assert-Equal $actual.SelectNodes('//h4').Count 6 'Six separate companies'
Assert-Equal $actual.SelectNodes('/html/body/ul/li/ul/li/ul/li').Count 14 'All product rows retained'

# Сравниваем всё содержимое body, включая вложенность, порядок, текст и счётчики.
$sample = Get-Content (Join-Path $PSScriptRoot 'tests/expected.html') -Raw -Encoding utf8
$expectedBody = [regex]::Match($sample, '(?s)<body>.*?</body>').Value
$expectedTree = [xml]$expectedBody
Assert-Equal $actual.SelectSingleNode('/html/body').OuterXml $expectedTree.DocumentElement.OuterXml 'Body matches teacher sample exactly'

# Одноимённые компании, несмежные строки и сортировка.
$edge = Convert-TestXml @'
<orgs>
  <item city="Москва" org="ООО Светлана" title="Яблоко" value="999"/>
  <item city="Петербург" org="ООО Светлана" title="Только Петербург" value="5"/>
  <item city="Москва" org="ООО Светлана" title="Арбуз" value="1"/>
  <item city="Москва" org="Другая компания" title="Другой товар" value="7"/>
</orgs>
'@
Assert-Equal $edge.SelectSingleNode('/html/body/ul/li[1]/p').InnerText 'Всего товаров: 3' 'Count rows, not sum of value'
Assert-Equal $edge.SelectSingleNode('/html/body/ul/li[1]/ul/li/p').InnerText 'Всего товаров: 2' 'Non-adjacent company rows grouped'
Assert-Equal $edge.SelectSingleNode('/html/body/ul/li[1]/ul/li/ul/li[1]').InnerText 'Арбуз' 'Alphabetical products'
Assert-Equal $edge.SelectSingleNode('/html/body/ul/li[2]/ul/li/ul/li').InnerText 'Только Петербург' 'Same name in another city isolated'
Assert-Equal $edge.SelectNodes('//h4').Count 3 'Three city-company groups'

# Составной ключ не путает пары, содержащие символ-разделитель.
$collision = Convert-TestXml @'
<orgs>
  <item city="A|B" org="C" title="first" value="1"/>
  <item city="A" org="B|C" title="second" value="2"/>
</orgs>
'@
Assert-Equal $collision.SelectNodes('//h4').Count 2 'Composite keys do not collide'

$escaped = Convert-TestXml '<orgs><item city="A &amp; B" org="&lt;company&gt;" title="&lt;script&gt;" value="1"/></orgs>'
Assert-Equal $escaped.SelectSingleNode('//h4').InnerText '<company>' 'Special characters retained as text'
Assert-Equal $escaped.SelectNodes('//script').Count 0 'Text does not become HTML markup'

$empty = Convert-TestXml '<orgs/>'
Assert-Equal $empty.SelectNodes('//h3').Count 0 'Empty input'
Assert-Equal $empty.SelectSingleNode('//h1').InnerText 'Города и компании' 'Heading on empty input'

# Статические файлы должны соответствовать актуальному преобразованию.
$buffer = [System.IO.MemoryStream]::new()
$settings = $transform.OutputSettings.Clone()
$settings.Encoding = [System.Text.UTF8Encoding]::new($false)
$writer = [System.Xml.XmlWriter]::Create($buffer, $settings)
try {
    $transform.Transform((Join-Path $PSScriptRoot 'data.xml'), $writer)
} finally {
    $writer.Dispose()
}
$generated = [System.Text.Encoding]::UTF8.GetString($buffer.ToArray())
$buffer.Dispose()
Assert-Equal (Get-Content (Join-Path $PSScriptRoot 'result.html') -Raw -Encoding utf8) $generated 'result.html is up to date'
Assert-Equal (Get-Content (Join-Path $PSScriptRoot 'index.html') -Raw -Encoding utf8) $generated 'GitHub Pages copy is up to date'
Write-Output "All $script:checks checks passed."
