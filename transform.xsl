<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:output method="html" encoding="utf-8" indent="yes"/>

  <!-- Ключи позволяют группировать данные без полных повторных проходов по XML. -->
  <xsl:key name="items-by-city" match="item" use="@city"/>
  <xsl:key name="items-by-city-org" match="item"
    use="concat(string-length(@city), ':', @city, '|', @org)"/>

  <xsl:template match="/">
    <html lang="ru">
      <head>
        <meta charset="utf-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1"/>
        <title>Города</title>
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.45; margin: 32px; color: #1f2937; }
          h1 { margin-bottom: 28px; }
          h3 { margin-bottom: 4px; color: #2563eb; }
          h4 { margin: 12px 0 2px; }
          p { margin: 3px 0; color: #4b5563; }
          ul { margin-top: 5px; }
        </style>
      </head>
      <body>
        <h1>Города и компании</h1>
        <xsl:apply-templates select="orgs"/>
      </body>
    </html>
  </xsl:template>

  <xsl:template match="orgs">
    <!-- Группировка Мюнха: первый item для каждого уникального города. -->
    <ul>
      <xsl:for-each select="item[generate-id() = generate-id(key('items-by-city', @city)[1])]">
        <xsl:variable name="city" select="@city"/>
        <xsl:variable name="city-items" select="key('items-by-city', $city)"/>
        <li>
          <h3><xsl:value-of select="$city"/></h3>
          <p>Всего товаров: <xsl:value-of select="count($city-items)"/></p>

          <!-- В ключ компании входит город: две ООО «Светлана» не смешиваются. -->
          <xsl:for-each select="$city-items[generate-id() = generate-id(key('items-by-city-org', concat(string-length(@city), ':', @city, '|', @org))[1])]">
            <xsl:variable name="org" select="@org"/>
            <xsl:variable name="company-items"
              select="key('items-by-city-org', concat(string-length($city), ':', $city, '|', $org))"/>
            <ul>
              <li>
                <h4><xsl:value-of select="$org"/></h4>
                <p>Всего товаров: <xsl:value-of select="count($company-items)"/></p>
                <ul>
                  <xsl:for-each select="$company-items">
                    <xsl:sort select="@title" data-type="text" lang="ru"/>
                    <li><xsl:value-of select="@title"/></li>
                  </xsl:for-each>
                </ul>
              </li>
            </ul>
          </xsl:for-each>
        </li>
      </xsl:for-each>
    </ul>
  </xsl:template>

</xsl:stylesheet>
