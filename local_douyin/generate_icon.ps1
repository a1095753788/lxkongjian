$csCode = @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;

public class IconGenerator
{
    public static void Generate(string outPath, int size, bool isForeground = false)
    {
        var bmp = new Bitmap(size, size);
        using (var g = Graphics.FromImage(bmp))
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;

            // 自适应图标前景需要透明背景，传统图标用黑色背景
            if (isForeground)
            {
                g.Clear(Color.Transparent);
            }
            else
            {
                g.Clear(Color.FromArgb(0, 0, 0));
            }

            // 标准化坐标系：以 1024x1024 为基准设计，自适应图标前景需在中心 72% 安全区域内
            float s = size / 1024f;

            // 抖音经典配色
            Color pink = Color.FromArgb(254, 44, 85);
            Color cyan = Color.FromArgb(37, 244, 238);
            Color white = Color.FromArgb(255, 255, 255);

            // 偏移量（控制粉青错位效果）
            float offset = 35f * s;

            // 构建音符路径（闭合多边形，确保可正确填充）
            var path = BuildNotePath(s);

            // 1. 青色阴影（向左偏移）
            g.TranslateTransform(-offset, 0);
            using (var cyanBrush = new SolidBrush(cyan))
                g.FillPath(cyanBrush, path);
            g.ResetTransform();

            // 2. 粉红色主体（向右偏移）
            g.TranslateTransform(offset, 0);
            using (var pinkBrush = new SolidBrush(pink))
                g.FillPath(pinkBrush, path);
            g.ResetTransform();

            // 3. 白色主体（居中，最上层）
            using (var whiteBrush = new SolidBrush(white))
                g.FillPath(whiteBrush, path);
        }

        // 使用高质量 PNG 编码保存
        var encoder = GetPngEncoder();
        if (encoder != null)
        {
            var parms = new System.Drawing.Imaging.EncoderParameters(1);
            parms.Param[0] = new System.Drawing.Imaging.EncoderParameter(
                System.Drawing.Imaging.Encoder.Quality, 100L);
            bmp.Save(outPath, encoder, parms);
        }
        else
        {
            bmp.Save(outPath, System.Drawing.Imaging.ImageFormat.Png);
        }
        bmp.Dispose();
    }

    static System.Drawing.Imaging.ImageCodecInfo GetPngEncoder()
    {
        var codecs = System.Drawing.Imaging.ImageCodecInfo.GetImageEncoders();
        foreach (var c in codecs)
        {
            if (c.FormatID == System.Drawing.Imaging.ImageFormat.Png.Guid)
                return c;
        }
        return null;
    }

    /// <summary>
    /// 构建抖音风格音符路径（闭合形状）
    /// 设计基准：1024x1024 画布
    /// 音符整体居中，包含：符头（倾斜椭圆）+ 符干 + 符尾旗子
    /// </summary>
    static GraphicsPath BuildNotePath(float s)
    {
        var path = new GraphicsPath();

        // === 符头：倾斜椭圆（旋转 -20 度） ===
        // 椭圆中心 (380, 680), 宽 280, 高 220
        float headCx = 380f * s;
        float headCy = 680f * s;
        float headW = 280f * s;
        float headH = 220f * s;

        var headPath = new GraphicsPath();
        headPath.AddEllipse(-(headW / 2), -(headH / 2), headW, headH);

        // 旋转并平移到符头位置
        var headMatrix = new Matrix();
        headMatrix.Rotate(-20f);
        headMatrix.Translate(headCx, headCy);
        headPath.Transform(headMatrix);
        path.AddPath(headPath, false);

        // === 符干：从符头右上方向上的竖线 ===
        // 起点在符头右上 (约 510, 580), 顶部约 (510, 200)
        float stemW = 50f * s;
        float stemX = 500f * s;
        float stemTop = 200f * s;
        float stemBottom = 600f * s;
        path.AddRectangle(new RectangleF(stemX, stemTop, stemW, stemBottom - stemTop));

        // === 符尾旗子：从符干顶部向右弯曲的闭合多边形 ===
        // 用闭合多边形近似抖音音符的旗子形状
        float cx = stemX + stemW * 0.5f;  // 符干中心 X
        float cy = stemTop;               // 符干顶部 Y

        var flagPoints = new PointF[]
        {
            // 旗子起点（符干顶部左侧）
            new PointF(cx - stemW * 0.5f, cy + 10f * s),
            // 旗子向右上延伸
            new PointF(cx + 60f * s, cy - 20f * s),
            new PointF(cx + 180f * s, cy + 30f * s),
            new PointF(cx + 260f * s, cy + 120f * s),
            // 旗子最右点
            new PointF(cx + 290f * s, cy + 240f * s),
            // 旗子向下弯曲
            new PointF(cx + 250f * s, cy + 340f * s),
            new PointF(cx + 180f * s, cy + 380f * s),
            // 旗子下沿返回
            new PointF(cx + 120f * s, cy + 340f * s),
            new PointF(cx + 160f * s, cy + 280f * s),
            new PointF(cx + 200f * s, cy + 220f * s),
            new PointF(cx + 190f * s, cy + 140f * s),
            new PointF(cx + 120f * s, cy + 90f * s),
            // 返回起点（符干顶部右侧）
            new PointF(cx + stemW * 0.5f, cy + 10f * s)
        };
        path.AddPolygon(flagPoints);

        return path;
    }
}
'@

# 删除已加载的类型（如果存在），避免重复加载报错
try {
    [IconGenerator] | Out-Null
} catch {
    Add-Type -TypeDefinition $csCode -ReferencedAssemblies System.Drawing
}

$base = "c:\Users\ZhuanZ\Documents\0\local_douyin\android\app\src\main\res"

# 传统 PNG 图标尺寸
$sizes = @{
    "mipmap-mdpi"    = 48
    "mipmap-hdpi"    = 72
    "mipmap-xhdpi"   = 96
    "mipmap-xxhdpi"  = 144
    "mipmap-xxxhdpi" = 192
}

# 自适应图标前景图尺寸（108dp，安全区域为中心 72dp）
$foregroundSizes = @{
    "mipmap-mdpi"    = 108
    "mipmap-hdpi"    = 162
    "mipmap-xhdpi"   = 216
    "mipmap-xxhdpi"  = 324
    "mipmap-xxxhdpi" = 432
}

Write-Host "=== 生成传统 PNG 图标 ==="
foreach ($entry in $sizes.GetEnumerator()) {
    $dir = $entry.Key
    $size = $entry.Value
    $outPath = "$base\$dir\ic_launcher.png"
    [IconGenerator]::Generate($outPath, $size, $false)
    $fileSize = (Get-Item $outPath).Length
    Write-Host "$dir -> ${size}x${size} ($fileSize bytes)"
}

Write-Host ""
Write-Host "=== 生成自适应图标前景图 ==="
foreach ($entry in $foregroundSizes.GetEnumerator()) {
    $dir = $entry.Key
    $size = $entry.Value
    $outPath = "$base\$dir\ic_launcher_foreground.png"
    [IconGenerator]::Generate($outPath, $size, $true)
    $fileSize = (Get-Item $outPath).Length
    Write-Host "$dir -> ${size}x${size} ($fileSize bytes)"
}

Write-Host ""
Write-Host "=== Done ==="
