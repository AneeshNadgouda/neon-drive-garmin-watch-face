Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing
if (-not ('ApprovedIconRasterOps' -as [type])) {
    Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;

public static class ApprovedIconRasterOps {
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

    public static Bitmap EnhanceCrt(Bitmap source) {
        Bitmap output = new Bitmap(source.Width, source.Height,
            PixelFormat.Format32bppArgb);
        DrawTinted(source, output, -2, 1,
            Color.FromArgb(0, 210, 255), .34);
        DrawTinted(source, output, 2, -1,
            Color.FromArgb(255, 35, 18), .34);
        DrawTinted(source, output, -1, 1,
            Color.FromArgb(0, 210, 255), .72);
        DrawTinted(source, output, 1, -1,
            Color.FromArgb(255, 35, 18), .72);
        for (int y = 0; y < source.Height; y++) {
            for (int x = 0; x < source.Width; x++) {
                Color pixel = source.GetPixel(x, y);
                BlendPixel(output, x, y, pixel, pixel.A);
            }
        }
        for (int y = 1; y < output.Height; y += 2) {
            for (int x = 0; x < output.Width; x++) {
                Color pixel = output.GetPixel(x, y);
                if (pixel.A == 0) continue;
                output.SetPixel(x, y, Color.FromArgb(
                    (int)Math.Round(pixel.A * .88),
                    pixel.R, pixel.G, pixel.B));
            }
        }
        return output;
    }

    private static GraphicsPath RoundedRectangle(RectangleF rectangle,
            float radius) {
        GraphicsPath path = new GraphicsPath();
        float diameter = radius * 2;
        path.AddArc(rectangle.Left, rectangle.Top, diameter, diameter,
            180, 90);
        path.AddArc(rectangle.Right - diameter, rectangle.Top,
            diameter, diameter, 270, 90);
        path.AddArc(rectangle.Right - diameter,
            rectangle.Bottom - diameter, diameter, diameter, 0, 90);
        path.AddArc(rectangle.Left, rectangle.Bottom - diameter,
            diameter, diameter, 90, 90);
        path.CloseFigure();
        return path;
    }

    public static Bitmap CreateBatteryIcon() {
        const int scale = 4;
        Bitmap large = new Bitmap(48 * scale, 48 * scale,
            PixelFormat.Format32bppArgb);
        using (Graphics graphics = Graphics.FromImage(large)) {
            graphics.SmoothingMode = SmoothingMode.AntiAlias;
            graphics.PixelOffsetMode = PixelOffsetMode.HighQuality;
            graphics.TranslateTransform(24 * scale, 24 * scale);
            graphics.RotateTransform(31);
            using (GraphicsPath body = RoundedRectangle(
                    new RectangleF(-54, -22, 108, 44), 6))
            using (Pen outline = new Pen(Color.White, 2.5f)) {
                graphics.DrawPath(outline, body);
            }
            // The visual fill is intentionally fixed at 70%; the numeric text
            // is the only part that reflects the live battery percentage.
            using (GraphicsPath fill = RoundedRectangle(
                    new RectangleF(-50, -18, 70, 36), 5))
            using (SolidBrush brush = new SolidBrush(Color.White)) {
                graphics.FillPath(brush, fill);
            }
            using (GraphicsPath terminal = RoundedRectangle(
                    new RectangleF(53, -6, 9, 12), 3))
            using (SolidBrush brush = new SolidBrush(
                    Color.FromArgb(235, 255, 255, 255))) {
                graphics.FillPath(brush, terminal);
            }
        }

        Bitmap target = new Bitmap(48, 48, PixelFormat.Format32bppArgb);
        using (Graphics graphics = Graphics.FromImage(target)) {
            graphics.InterpolationMode = InterpolationMode.HighQualityBicubic;
            graphics.PixelOffsetMode = PixelOffsetMode.HighQuality;
            graphics.DrawImage(large, new Rectangle(0, 0, 48, 48),
                0, 0, large.Width, large.Height, GraphicsUnit.Pixel);
        }
        large.Dispose();
        Bitmap enhanced = EnhanceCrt(target);
        target.Dispose();
        return enhanced;
    }
}
'@
}

$outputDirectory = Join-Path $PSScriptRoot '..\resources\drawables'
$approvedPath = Join-Path $PSScriptRoot 'approved\hud-icons-specimen.png'
$approved = [System.Drawing.Bitmap]::new($approvedPath)

function Write-ApprovedIcon {
    param(
        [string]$Name,
        [System.Drawing.Rectangle]$SourceRectangle,
        [int]$ContentWidth,
        [int]$ContentHeight,
        [bool]$RotateClockwise = $false,
        [double]$Rotation = 0
    )

    $source = [ApprovedIconRasterOps]::KeyCrop($approved,$SourceRectangle)
    if ($RotateClockwise) {
        $source.RotateFlip([System.Drawing.RotateFlipType]::Rotate90FlipNone)
    }
    $target = [System.Drawing.Bitmap]::new(48,48,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($target)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.TranslateTransform(24,24)
    $graphics.RotateTransform($Rotation)
    $destination = [System.Drawing.Rectangle]::new(
        [Math]::Round(0-$ContentWidth/2),
        [Math]::Round(0-$ContentHeight/2),
        $ContentWidth,$ContentHeight)
    $graphics.DrawImage($source,$destination,0,0,$source.Width,$source.Height,
        [System.Drawing.GraphicsUnit]::Pixel)
    $graphics.Dispose();$source.Dispose()
    $enhanced = [ApprovedIconRasterOps]::EnhanceCrt($target)
    $target.Dispose()
    $target = $enhanced
    $target.Save((Join-Path $outputDirectory $Name),
        [System.Drawing.Imaging.ImageFormat]::Png)
    $target.Dispose()
}

# These rectangles contain the approved pixels themselves. Nothing is redrawn.
$battery = [ApprovedIconRasterOps]::CreateBatteryIcon()
$battery.Save((Join-Path $outputDirectory 'battery-hud.png'),
    [System.Drawing.Imaging.ImageFormat]::Png)
$battery.Dispose()
Write-ApprovedIcon 'steps-hud.png' ([System.Drawing.Rectangle]::new(870,70,500,570)) 22 25 $false 31
Write-ApprovedIcon 'heart-hud.png' ([System.Drawing.Rectangle]::new(1560,145,510,440)) 22 19 $false -33

$approved.Dispose()
