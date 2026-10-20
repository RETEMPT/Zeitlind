# Render the code-owned geometric Zeitlind mark into platform launcher assets.
Add-Type -AssemblyName System.Drawing
$projectRoot = Split-Path -Parent $PSScriptRoot
$brandBitmap = [System.Drawing.Bitmap]::new(1024, 1024)
$brandGraphics = [System.Drawing.Graphics]::FromImage($brandBitmap)
$brandGraphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$brandGraphics.Clear([System.Drawing.ColorTranslator]::FromHtml('#426A5A'))
$brandBrush = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#F6F3DF'))
$brandPoints = [System.Drawing.PointF[]]@(
  [System.Drawing.PointF]::new(280,256), [System.Drawing.PointF]::new(744,256),
  [System.Drawing.PointF]::new(744,346), [System.Drawing.PointF]::new(408,676),
  [System.Drawing.PointF]::new(744,676), [System.Drawing.PointF]::new(744,768),
  [System.Drawing.PointF]::new(280,768), [System.Drawing.PointF]::new(280,680),
  [System.Drawing.PointF]::new(616,348), [System.Drawing.PointF]::new(280,348)
)
$brandGraphics.FillPolygon($brandBrush, $brandPoints)
$brandGraphics.Dispose()
$brandBrush.Dispose()

function Save-BrandIcon([string]$Destination, [int]$Size) {
  $iconBitmap = [System.Drawing.Bitmap]::new($Size, $Size)
  $iconGraphics = [System.Drawing.Graphics]::FromImage($iconBitmap)
  $iconGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $iconGraphics.DrawImage($brandBitmap, 0, 0, $Size, $Size)
  $iconGraphics.Dispose()
  $iconBitmap.Save($Destination, [System.Drawing.Imaging.ImageFormat]::Png)
  $iconBitmap.Dispose()
}

Save-BrandIcon (Join-Path $projectRoot 'assets/app_icon.png') 512
Save-BrandIcon (Join-Path $projectRoot 'debian/gui/zeitlind.png') 256
$densitySizes = @{mdpi=48; hdpi=72; xhdpi=96; xxhdpi=144; xxxhdpi=192}
foreach ($densityName in $densitySizes.Keys) {
  Save-BrandIcon (Join-Path $projectRoot "android/app/src/main/res/mipmap-$densityName/ic_launcher.png") $densitySizes[$densityName]
}
foreach ($assetFolder in @('ios/Runner/Assets.xcassets/AppIcon.appiconset','macos/Runner/Assets.xcassets/AppIcon.appiconset')) {
  $assetPath = Join-Path $projectRoot $assetFolder
  $iconContents = Get-Content -LiteralPath (Join-Path $assetPath 'Contents.json') -Raw | ConvertFrom-Json
  foreach ($iconEntry in $iconContents.images) {
    if ($iconEntry.filename) {
      $iconSize = [double]($iconEntry.size.Split('x')[0]) * [double]($iconEntry.scale.TrimEnd('x'))
      Save-BrandIcon (Join-Path $assetPath $iconEntry.filename) ([int]$iconSize)
    }
  }
}
# A PNG-backed ICO keeps the same vector-derived design on Windows.
$iconStream = [System.IO.MemoryStream]::new()
$icoFile = Join-Path $projectRoot 'windows/runner/resources/app_icon.ico'
$icoPng = [System.Drawing.Bitmap]::new($brandBitmap, 256, 256)
$icoPng.Save($iconStream, [System.Drawing.Imaging.ImageFormat]::Png)
$pngBytes = $iconStream.ToArray()
$icoWriter = [System.IO.BinaryWriter]::new([System.IO.File]::Create($icoFile))
$icoWriter.Write([uint16]0); $icoWriter.Write([uint16]1); $icoWriter.Write([uint16]1)
$icoWriter.Write([byte]0); $icoWriter.Write([byte]0); $icoWriter.Write([byte]0); $icoWriter.Write([byte]0)
$icoWriter.Write([uint16]1); $icoWriter.Write([uint16]32)
$icoWriter.Write([uint32]$pngBytes.Length); $icoWriter.Write([uint32]22); $icoWriter.Write($pngBytes)
$icoWriter.Dispose(); $icoPng.Dispose(); $iconStream.Dispose(); $brandBitmap.Dispose()
Write-Output 'Zeitlind launcher assets generated.'
