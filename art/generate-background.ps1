param(
    [string] $SourcePath = (Join-Path $PSScriptRoot 'synthwave-background-source.png'),
    [string] $OutputPath = (Join-Path $PSScriptRoot '..\resources\drawables\background.png'),
    [double] $Zoom = 1.05
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Zoom -lt 1.0) {
    throw 'Zoom must be at least 1.0.'
}

Add-Type -AssemblyName System.Drawing

$source = [System.Drawing.Bitmap]::FromFile((Resolve-Path -LiteralPath $SourcePath))
try {
    $outputSize = 416
    $cropWidth = [single]($source.Width / $Zoom)
    $cropHeight = [single]($source.Height / $Zoom)
    $cropX = [single](($source.Width - $cropWidth) / 2.0)

    # Anchor at the top center: crop evenly from the left and right, and only
    # from the bottom vertically.
    $sourceRect = [System.Drawing.RectangleF]::new($cropX, 0.0, $cropWidth, $cropHeight)
    $destinationRect = [System.Drawing.Rectangle]::new(0, 0, $outputSize, $outputSize)
    $output = [System.Drawing.Bitmap]::new(
        $outputSize,
        $outputSize,
        [System.Drawing.Imaging.PixelFormat]::Format24bppRgb
    )

    try {
        $output.SetResolution(96.0, 96.0)
        $graphics = [System.Drawing.Graphics]::FromImage($output)
        try {
            $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
            $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
            $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality

            $imageAttributes = [System.Drawing.Imaging.ImageAttributes]::new()
            try {
                $imageAttributes.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)
                $graphics.DrawImage(
                    $source,
                    $destinationRect,
                    $sourceRect.X,
                    $sourceRect.Y,
                    $sourceRect.Width,
                    $sourceRect.Height,
                    [System.Drawing.GraphicsUnit]::Pixel,
                    $imageAttributes
                )
            }
            finally {
                $imageAttributes.Dispose()
            }
        }
        finally {
            $graphics.Dispose()
        }

        $resolvedOutput = [System.IO.Path]::GetFullPath($OutputPath)
        $output.Save($resolvedOutput, [System.Drawing.Imaging.ImageFormat]::Png)
        Write-Output "Generated $resolvedOutput at ${Zoom}x zoom (top-center anchor)."
    }
    finally {
        $output.Dispose()
    }
}
finally {
    $source.Dispose()
}
