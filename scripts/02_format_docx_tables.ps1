param(
  [string]$DocxPath = "outputs/manuscript/manuscript.docx",
  [int]$TableFontHalfPoints = 16
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $DocxPath)) {
  throw "DOCX not found: $DocxPath"
}

$resolvedDocx = (Resolve-Path -LiteralPath $DocxPath).Path
$workDir = Join-Path ([System.IO.Path]::GetTempPath()) ("fixture_docx_" + [System.Guid]::NewGuid().ToString("N"))
$zipPath = Join-Path $workDir "document.zip"
$unzipDir = Join-Path $workDir "unzipped"

New-Item -ItemType Directory -Path $workDir | Out-Null

try {
  Copy-Item -LiteralPath $resolvedDocx -Destination $zipPath
  Expand-Archive -LiteralPath $zipPath -DestinationPath $unzipDir -Force

  $documentPath = Join-Path $unzipDir "word/document.xml"
  $doc = [xml](Get-Content -LiteralPath $documentPath -Raw)
  $ns = New-Object System.Xml.XmlNamespaceManager($doc.NameTable)
  $ns.AddNamespace("w", "http://schemas.openxmlformats.org/wordprocessingml/2006/main")

  $tables = $doc.SelectNodes("//w:tbl", $ns)
  foreach ($table in $tables) {
    $tblPr = $table.SelectSingleNode("./w:tblPr", $ns)
    if ($null -eq $tblPr) {
      $tblPr = $doc.CreateElement("w", "tblPr", $ns.LookupNamespace("w"))
      [void]$table.PrependChild($tblPr)
    }

    $tblW = $tblPr.SelectSingleNode("./w:tblW", $ns)
    if ($null -eq $tblW) {
      $tblW = $doc.CreateElement("w", "tblW", $ns.LookupNamespace("w"))
      [void]$tblPr.AppendChild($tblW)
    }
    [void]$tblW.SetAttribute("type", $ns.LookupNamespace("w"), "pct")
    [void]$tblW.SetAttribute("w", $ns.LookupNamespace("w"), "5000")

    $tblLayout = $tblPr.SelectSingleNode("./w:tblLayout", $ns)
    if ($null -eq $tblLayout) {
      $tblLayout = $doc.CreateElement("w", "tblLayout", $ns.LookupNamespace("w"))
      [void]$tblPr.AppendChild($tblLayout)
    }
    [void]$tblLayout.SetAttribute("type", $ns.LookupNamespace("w"), "autofit")

    $shadingNodes = @($table.SelectNodes(".//w:shd", $ns))
    foreach ($shd in $shadingNodes) {
      [void]$shd.ParentNode.RemoveChild($shd)
    }

    $runs = $table.SelectNodes(".//w:r", $ns)
    foreach ($run in $runs) {
      $rPr = $run.SelectSingleNode("./w:rPr", $ns)
      if ($null -eq $rPr) {
        $rPr = $doc.CreateElement("w", "rPr", $ns.LookupNamespace("w"))
        [void]$run.PrependChild($rPr)
      }

      foreach ($sizeElementName in @("sz", "szCs")) {
        $sizeNode = $rPr.SelectSingleNode("./w:$sizeElementName", $ns)
        if ($null -eq $sizeNode) {
          $sizeNode = $doc.CreateElement("w", $sizeElementName, $ns.LookupNamespace("w"))
          [void]$rPr.AppendChild($sizeNode)
        }
        [void]$sizeNode.SetAttribute("val", $ns.LookupNamespace("w"), [string]$TableFontHalfPoints)
      }
    }
  }

  $doc.Save($documentPath)

  $formattedZip = Join-Path $workDir "formatted.zip"
  Compress-Archive -Path (Join-Path $unzipDir "*") -DestinationPath $formattedZip -Force
  Copy-Item -LiteralPath $formattedZip -Destination $resolvedDocx -Force

  Write-Host "Formatted $($tables.Count) tables in $resolvedDocx"
}
finally {
  if (Test-Path -LiteralPath $workDir) {
    Remove-Item -LiteralPath $workDir -Recurse -Force
  }
}
