Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing
if (-not ('ApprovedRasterOps' -as [type])) {
    Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;

public static class ApprovedRasterOps {
    // Recover straight-alpha pixels from artwork composited on pure black.
    public static Bitmap KeyCrop(Bitmap source, Rectangle rectangle) {
        Bitmap output = new Bitmap(rectangle.Width, rectangle.Height,
            PixelFormat.Format32bppArgb);
        for (int y = 0; y < rectangle.Height; y++) {
            for (int x = 0; x < rectangle.Width; x++) {
                Color pixel = source.GetPixel(rectangle.X + x, rectangle.Y + y);
                int alpha = Math.Max(pixel.R, Math.Max(pixel.G, pixel.B));
                if (alpha <= 2) {
                    output.SetPixel(x, y, Color.Transparent);
                    continue;
                }
                int red = Math.Min(255, (pixel.R * 255 + alpha / 2) / alpha);
                int green = Math.Min(255, (pixel.G * 255 + alpha / 2) / alpha);
                int blue = Math.Min(255, (pixel.B * 255 + alpha / 2) / alpha);
                output.SetPixel(x, y, Color.FromArgb(alpha, red, green, blue));
            }
        }
        return output;
    }

    private static void BlendPixel(Bitmap target, int x, int y,
            Color color, int alpha) {
        if (x < 0 || y < 0 || x >= target.Width || y >= target.Height ||
                alpha <= 0) return;
        Color destination = target.GetPixel(x, y);
        int inverse = 255 - alpha;
        int outputAlpha = alpha + ((destination.A * inverse + 127) / 255);
        if (outputAlpha <= 0) return;
        int destinationWeight = (destination.A * inverse + 127) / 255;
        int red = ((color.R * alpha) +
            (destination.R * destinationWeight)) / outputAlpha;
        int green = ((color.G * alpha) +
            (destination.G * destinationWeight)) / outputAlpha;
        int blue = ((color.B * alpha) +
            (destination.B * destinationWeight)) / outputAlpha;
        target.SetPixel(x, y, Color.FromArgb(outputAlpha, red, green, blue));
    }

    private static void DrawTinted(Bitmap source, Bitmap target,
            int offsetX, int offsetY, Color color, double strength) {
        for (int y = 0; y < source.Height; y++) {
            for (int x = 0; x < source.Width; x++) {
                Color pixel = source.GetPixel(x, y);
                BlendPixel(target, x + offsetX, y + offsetY, color,
                    (int)Math.Round(pixel.A * strength));
            }
        }
    }

    private static void DrawOriginal(Bitmap source, Bitmap target) {
        for (int y = 0; y < source.Height; y++) {
            for (int x = 0; x < source.Width; x++) {
                Color pixel = source.GetPixel(x, y);
                BlendPixel(target, x, y, pixel, pixel.A);
            }
        }
    }

    public static Bitmap EnhanceCrt(Bitmap source) {
        Bitmap output = new Bitmap(source.Width, source.Height,
            PixelFormat.Format32bppArgb);
        Color cyan = Color.FromArgb(0, 210, 255);
        Color red = Color.FromArgb(255, 35, 18);
        DrawTinted(source, output, -2, 1, cyan, .32);
        DrawTinted(source, output, 2, -1, red, .32);
        DrawTinted(source, output, -1, 1, cyan, .68);
        DrawTinted(source, output, 1, -1, red, .68);
        DrawOriginal(source, output);
        for (int y = 1; y < output.Height; y += 2) {
            for (int x = 0; x < output.Width; x++) {
                Color pixel = output.GetPixel(x, y);
                if (pixel.A == 0) continue;
                output.SetPixel(x, y, Color.FromArgb(
                    (int)Math.Round(pixel.A * .84),
                    pixel.R, pixel.G, pixel.B));
            }
        }
        return output;
    }

    private static double SegmentDistance(double px, double py,
            double x1, double y1, double x2, double y2) {
        double dx = x2 - x1;
        double dy = y2 - y1;
        double lengthSquared = (dx * dx) + (dy * dy);
        double amount = lengthSquared == 0 ? 0 :
            (((px - x1) * dx) + ((py - y1) * dy)) / lengthSquared;
        amount = Math.Max(0, Math.Min(1, amount));
        double sx = x1 + (amount * dx);
        double sy = y1 + (amount * dy);
        double ox = px - sx;
        double oy = py - sy;
        return (ox * ox) + (oy * oy);
    }

    // Build absent digits only from colored pixels already present in the
    // approved eight. Every pixel is assigned to its nearest stroke first,
    // which preserves complete joins without leaking fragments from a stroke
    // that the target digit does not use. Bits: top, UR, LR, bottom, LL, UL,
    // middle.
    public static Bitmap KeepSegments(Bitmap eight, int segments) {
        Bitmap output = new Bitmap(eight.Width, eight.Height,
            PixelFormat.Format32bppArgb);
        double[,] strokes = new double[,] {
            { .16, .14, .80, .14 },
            { .80, .14, .73, .50 },
            { .73, .50, .67, .86 },
            { .05, .87, .67, .87 },
            { .10, .50, .05, .87 },
            { .16, .14, .10, .50 },
            { .10, .50, .73, .50 }
        };
        for (int y = 0; y < eight.Height; y++) {
            double ny = (double)y / Math.Max(1, eight.Height - 1);
            for (int x = 0; x < eight.Width; x++) {
                Color pixel = eight.GetPixel(x, y);
                if (pixel.A == 0) continue;
                // Remove the approved face's italic shear before comparing a
                // pixel with the seven canonical stroke centerlines.
                double nx = ((double)x / Math.Max(1, eight.Width - 1)) -
                    (.17 * (1.0 - ny));
                int nearest = 0;
                double nearestDistance = Double.MaxValue;
                for (int stroke = 0; stroke < 7; stroke++) {
                    double distance = SegmentDistance(nx, ny,
                        strokes[stroke, 0], strokes[stroke, 1],
                        strokes[stroke, 2], strokes[stroke, 3]);
                    if (distance < nearestDistance) {
                        nearestDistance = distance;
                        nearest = stroke;
                    }
                }
                if ((segments & (1 << nearest)) != 0) {
                    output.SetPixel(x, y, pixel);
                }
            }
        }
        return output;
    }
}
'@
}

$glyphOrder = ' ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789:%,-'
$columns = 8
$outputDirectory = Join-Path $PSScriptRoot '..\resources\drawables'
$approvedPath = Join-Path $PSScriptRoot 'approved\hud-font-specimen.png'
$completePath = Join-Path $PSScriptRoot 'approved\hud-font-complete.png'
$approved = [System.Drawing.Bitmap]::new($approvedPath)
$complete = [System.Drawing.Bitmap]::new($completePath)

function Get-ApprovedFrame {
    param([int]$X,[int]$Y,[int]$Width,[int]$Height)
    return [ApprovedRasterOps]::KeyCrop($approved,
        [System.Drawing.Rectangle]::new($X,$Y,$Width,$Height))
}

function Get-CompleteMainFrame {
    param([int]$X,[int]$Width,[int]$TargetWidth)

    $source = [ApprovedRasterOps]::KeyCrop($complete,
        [System.Drawing.Rectangle]::new($X,440,$Width,180))
    $frame = [System.Drawing.Bitmap]::new($TargetWidth,290,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($frame)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.DrawImage($source,
        [System.Drawing.Rectangle]::new(0,0,$TargetWidth,290),
        0,0,$source.Width,$source.Height,[System.Drawing.GraphicsUnit]::Pixel)
    $graphics.Dispose();$source.Dispose()
    return $frame
}

function Get-CompleteThinFrame {
    param([int]$X,[int]$Width,[int]$TargetWidth)

    $source = [ApprovedRasterOps]::KeyCrop($complete,
        [System.Drawing.Rectangle]::new($X,620,$Width,90))
    $frame = [System.Drawing.Bitmap]::new($TargetWidth,135,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($frame)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.DrawImage($source,
        [System.Drawing.Rectangle]::new(0,0,$TargetWidth,135),
        0,0,$source.Width,$source.Height,[System.Drawing.GraphicsUnit]::Pixel)
    $graphics.Dispose();$source.Dispose()
    return $frame
}

function New-FallbackThinFrame {
    param([char]$Character)

    $frame = [System.Drawing.Bitmap]::new(88,135,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($frame)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $font = [System.Drawing.Font]::new('Bahnschrift Light Condensed',86,
        [System.Drawing.FontStyle]::Italic,[System.Drawing.GraphicsUnit]::Pixel)
    $format = [System.Drawing.StringFormat]::new()
    $format.Alignment = [System.Drawing.StringAlignment]::Center
    $format.LineAlignment = [System.Drawing.StringAlignment]::Center
    $rectangle = [System.Drawing.RectangleF]::new(0,2,88,131)
    foreach ($pass in @(
        @{ X = 3; Y = -1; Color = [System.Drawing.Color]::FromArgb(255,32,24) },
        @{ X = -3; Y = 1; Color = [System.Drawing.Color]::FromArgb(0,198,255) },
        @{ X = 0; Y = 0; Color = [System.Drawing.Color]::FromArgb(255,244,214) }
    )) {
        $brush = [System.Drawing.SolidBrush]::new($pass.Color)
        $shifted = [System.Drawing.RectangleF]::new(
            $rectangle.X+$pass.X,$rectangle.Y+$pass.Y,
            $rectangle.Width,$rectangle.Height)
        $graphics.DrawString($Character.ToString(),$font,$brush,$shifted,$format)
        $brush.Dispose()
    }
    $format.Dispose();$font.Dispose();$graphics.Dispose()
    return $frame
}

# Direct frames retain a common vertical coordinate system, preserving the
# approved baseline, counters, CRT texture, bloom and color convergence.
$main = @{}
$main['1'] = Get-ApprovedFrame 267 180 125 290
$main['0'] = Get-ApprovedFrame 390 180 255 290
$main[':'] = Get-ApprovedFrame 644 180 88 290
$main['2'] = Get-ApprovedFrame 734 180 250 290
$main['8'] = Get-ApprovedFrame 982 180 260 290
$main['3'] = Get-CompleteMainFrame 605 180 250
$main['4'] = Get-CompleteMainFrame 815 170 235
$main['5'] = Get-CompleteMainFrame 1015 180 250
$main['6'] = Get-CompleteMainFrame 1225 180 255
$main['7'] = Get-CompleteMainFrame 1435 160 230
$main['9'] = Get-CompleteMainFrame 1815 190 255

$thin = @{}
$thin['S'] = Get-ApprovedFrame 92 580 80 135
$thin['E'] = Get-ApprovedFrame 173 580 72 135
$thin['P'] = Get-ApprovedFrame 245 580 77 135
$thin['1'] = Get-ApprovedFrame 610 580 40 135
$thin['0'] = Get-ApprovedFrame 653 580 82 135
$thin['%'] = Get-ApprovedFrame 815 580 96 135
$thin[','] = Get-ApprovedFrame 1116 580 24 135
$thin['3'] = Get-ApprovedFrame 1140 580 68 135
$thin['4'] = Get-ApprovedFrame 1210 580 78 135
$thin['2'] = Get-ApprovedFrame 1290 580 91 135
$thin['6'] = Get-ApprovedFrame 1519 580 84 135
$thin['8'] = Get-ApprovedFrame 1606 580 84 135
$thin['5'] = Get-CompleteThinFrame 875 80 84
$thin['7'] = Get-CompleteThinFrame 1205 80 76
$thin['9'] = Get-CompleteThinFrame 1535 85 84
$thin[':'] = [ApprovedRasterOps]::KeepSegments($thin['8'],64)
$thin['-'] = Get-CompleteThinFrame 2025 65 68

foreach ($letter in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.ToCharArray()) {
    if (-not $thin.ContainsKey($letter.ToString())) {
        $thin[$letter.ToString()] = New-FallbackThinFrame $letter
    }
}

function New-Atlas {
    param(
        [string]$Name,
        [hashtable]$Frames,
        [int]$SourceFrameHeight,
        [int]$TargetFrameHeight,
        [double]$Angle,
        [bool]$EnhanceCrt = $false
    )

    $maximumWidth = 1
    foreach ($frame in $Frames.Values) {
        $scaledWidth = [Math]::Ceiling(
            $frame.Width*$TargetFrameHeight/$SourceFrameHeight)
        if ($scaledWidth -gt $maximumWidth) { $maximumWidth = $scaledWidth }
    }
    $radians = [Math]::PI*$Angle/180.0
    $cellWidth = [Math]::Ceiling(
        [Math]::Abs([Math]::Cos($radians))*$maximumWidth +
        [Math]::Abs([Math]::Sin($radians))*$TargetFrameHeight) + 4
    $cellHeight = [Math]::Ceiling(
        [Math]::Abs([Math]::Sin($radians))*$maximumWidth +
        [Math]::Abs([Math]::Cos($radians))*$TargetFrameHeight) + 4
    $rows = [Math]::Ceiling($glyphOrder.Length/$columns)
    $atlas = [System.Drawing.Bitmap]::new($cellWidth*$columns,$cellHeight*$rows,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($atlas)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

    for ($index = 0; $index -lt $glyphOrder.Length; $index += 1) {
        $glyph = $glyphOrder.Substring($index,1)
        if (($glyph -eq ' ') -or (-not $Frames.ContainsKey($glyph))) { continue }
        $frame = $Frames[$glyph]
        $drawWidth = [Math]::Round(
            $frame.Width*$TargetFrameHeight/$SourceFrameHeight)
        $centerX = (($index % $columns)*$cellWidth)+($cellWidth/2)
        $centerY = ([Math]::Floor($index/$columns)*$cellHeight)+($cellHeight/2)
        $state = $graphics.Save()
        $graphics.TranslateTransform($centerX,$centerY)
        $graphics.RotateTransform(0-$Angle)
        $graphics.DrawImage($frame,
            [System.Drawing.Rectangle]::new(
                [Math]::Round(0-$drawWidth/2),
                [Math]::Round(0-$TargetFrameHeight/2),
                $drawWidth,$TargetFrameHeight),
            0,0,$frame.Width,$frame.Height,[System.Drawing.GraphicsUnit]::Pixel)
        $graphics.Restore($state)
    }
    $graphics.Dispose()
    if ($EnhanceCrt) {
        $enhanced = [ApprovedRasterOps]::EnhanceCrt($atlas)
        $atlas.Dispose()
        $atlas = $enhanced
    }
    $atlas.Save((Join-Path $outputDirectory "glyphs-$Name.png"),
        [System.Drawing.Imaging.ImageFormat]::Png)
    $atlas.Dispose()
    Write-Output "$Name $cellWidth x $cellHeight"
}

New-Atlas 'date' $thin 135 26 30
New-Atlas 'battery' $thin 135 26 -30
New-Atlas 'steps' $thin 135 27 -32
New-Atlas 'heart' $thin 135 27 40
New-Atlas 'time' $main 290 29 0 $true
New-Atlas 'seconds' $thin 135 28 0

foreach ($frame in $main.Values) { $frame.Dispose() }
foreach ($frame in $thin.Values) { $frame.Dispose() }
$approved.Dispose()
$complete.Dispose()
