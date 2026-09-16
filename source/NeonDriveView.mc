using Toybox.ActivityMonitor;
using Toybox.Graphics;
using Toybox.Math;
using Toybox.System;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.WatchUi;

class NeonDriveView extends WatchUi.WatchFace {
    const DIM_WHITE = 0x777777;

    private var _background;
    private var _batteryIcon;
    private var _stepsIcon;
    private var _heartIcon;
    private var _dateGlyphs;
    private var _batteryGlyphs;
    private var _stepsGlyphs;
    private var _heartGlyphs;
    private var _timeGlyphs;
    private var _secondsGlyphs;
    private var _isAwake = true;

    function initialize() {
        WatchFace.initialize();
        _background = WatchUi.loadResource(Rez.Drawables.Background);
        _batteryIcon = WatchUi.loadResource(Rez.Drawables.BatteryHud);
        _stepsIcon = WatchUi.loadResource(Rez.Drawables.StepsHud);
        _heartIcon = WatchUi.loadResource(Rez.Drawables.HeartHud);
        _dateGlyphs = WatchUi.loadResource(Rez.Drawables.DateGlyphs);
        _batteryGlyphs = WatchUi.loadResource(Rez.Drawables.BatteryGlyphs);
        _stepsGlyphs = WatchUi.loadResource(Rez.Drawables.StepsGlyphs);
        _heartGlyphs = WatchUi.loadResource(Rez.Drawables.HeartGlyphs);
        _timeGlyphs = WatchUi.loadResource(Rez.Drawables.TimeGlyphs);
        _secondsGlyphs = WatchUi.loadResource(Rez.Drawables.SecondsGlyphs);
    }

    function onUpdate(dc) {
        var displayMode = System.getDisplayMode();
        _isAwake = (displayMode == System.DISPLAY_MODE_HIGH_POWER);

        if (_isAwake) {
            drawActiveFace(dc);
        } else if (displayMode == System.DISPLAY_MODE_LOW_POWER) {
            drawAlwaysOnFace(dc);
        } else {
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
            dc.clear();
        }
    }

    function onPartialUpdate(dc) {
        if (!_isAwake) {
            return;
        }

        dc.setClip(125, 374, 180, 42);
        dc.drawBitmap(0, 0, _background);
        drawTime(dc);
        dc.clearClip();
    }

    function onEnterSleep() {
        _isAwake = false;
    }

    function onExitSleep() {
        _isAwake = true;
    }

    private function drawActiveFace(dc) {
        dc.drawBitmap(0, 0, _background);

        var now = Time.now();
        var date = Gregorian.info(now, Time.FORMAT_SHORT);
        var dateText = monthLabel(date.month) + " " +
            date.day.format("%02d");
        drawArcSpriteText(dc, _dateGlyphs, 34, 37, 190.0, -121,
            1, dateText, 13);

        var battery = System.getSystemStats().battery.toNumber();
        dc.drawBitmap(247, 8, _batteryIcon);
        drawArcSpriteText(dc, _batteryGlyphs, 34, 37, 190.0, -55,
            1, battery.format("%d") + "%", 15);

        var activity = ActivityMonitor.getInfo();
        var steps = (activity.steps == null) ? 0 : activity.steps;
        dc.drawBitmap(40, 316, _stepsIcon);
        drawArcSpriteText(dc, _stepsGlyphs, 36, 38, 196.0, 125,
            -1, formatCount(steps), 14);

        var heartRate = latestHeartRate();
        dc.drawBitmap(289, 349, _heartIcon);
        drawArcSpriteText(dc, _heartGlyphs, 37, 38, 199.0, 49,
            -1,
            (heartRate == null) ? "--" : heartRate.format("%d"),
            13);

        drawTime(dc);
    }

    private function drawAlwaysOnFace(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var clock = System.getClockTime();
        var hour = displayHour(clock.hour);
        var timeText = hour.format("%02d") + ":" +
            clock.min.format("%02d");

        dc.setColor(DIM_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(208, 170, Graphics.FONT_NUMBER_MEDIUM, timeText,
            Graphics.TEXT_JUSTIFY_CENTER);

        var date = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var dateText = monthLabel(date.month) + " " + date.day.format("%02d");
        dc.drawText(208, 246, Graphics.FONT_XTINY, dateText,
            Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawTime(dc) {
        var clock = System.getClockTime();
        var hour = displayHour(clock.hour);
        var timeText = hour.format("%02d") + ":" +
            clock.min.format("%02d");

        var secondText = clock.sec.format("%02d");
        var timeCenter = 196;
        var timeWidth = spriteTextWidth(timeText, 24);
        var secondWidth = spriteTextWidth(secondText, 14);
        var secondCenter = timeCenter + (timeWidth / 2) + 7 +
            (secondWidth / 2);
        drawStraightSpriteText(dc, _timeGlyphs, 30, 33,
            timeCenter, 395, timeText, 24);
        drawStraightSpriteText(dc, _secondsGlyphs, 24, 32,
            secondCenter, 399, secondText, 14);
    }

    private function drawStraightSpriteText(dc, atlas, cellWidth, cellHeight,
            x, y, value, advance) {
        var totalWidth = spriteTextWidth(value, advance);
        var cursor = 0 - (totalWidth / 2);

        for (var glyphIndex = 0; glyphIndex < value.length(); glyphIndex += 1) {
            var glyph = value.substring(glyphIndex, glyphIndex + 1);
            var glyphAdvance = spriteAdvance(glyph, advance);
            var glyphX = x + cursor + (glyphAdvance / 2);
            drawSpriteGlyph(dc, atlas, cellWidth, cellHeight,
                glyphX, y, glyph);
            cursor += glyphAdvance;
        }
    }

    private function drawArcSpriteText(dc, atlas, cellWidth, cellHeight,
            radius, centerAngle, direction, value, advance) {
        var totalWidth = spriteTextWidth(value, advance);
        var centerRadians = Math.toRadians(centerAngle);
        var cursor = 0 - (totalWidth / 2);

        for (var glyphIndex = 0; glyphIndex < value.length(); glyphIndex += 1) {
            var glyph = value.substring(glyphIndex, glyphIndex + 1);
            var glyphAdvance = spriteAdvance(glyph, advance);
            var offset = cursor + (glyphAdvance / 2);
            var glyphRadians = centerRadians +
                ((direction * offset) / radius);
            var glyphX = 208 + (radius * Math.cos(glyphRadians));
            var glyphY = 208 + (radius * Math.sin(glyphRadians));
            drawSpriteGlyph(dc, atlas, cellWidth, cellHeight,
                glyphX, glyphY, glyph);
            cursor += glyphAdvance;
        }
    }

    private function drawSpriteGlyph(dc, atlas, cellWidth, cellHeight,
            x, y, glyph) {
        var index = glyphIndex(glyph);
        if (index < 0) {
            return;
        }

        var column = index % 8;
        var row = (index - column) / 8;
        var bitmapX = column * cellWidth;
        var bitmapY = row * cellHeight;
        // Cropped bitmap coordinates retain their position within the source
        // atlas, so offset the atlas origin back to the requested glyph center.
        dc.drawBitmap2(x - (cellWidth / 2) - bitmapX,
            y - (cellHeight / 2) - bitmapY, atlas, {
            :bitmapX => bitmapX,
            :bitmapY => bitmapY,
            :bitmapWidth => cellWidth,
            :bitmapHeight => cellHeight
        });
    }

    private function spriteTextWidth(value, advance) {
        var width = 0;
        for (var index = 0; index < value.length(); index += 1) {
            width += spriteAdvance(value.substring(index, index + 1), advance);
        }
        return width;
    }

    private function spriteAdvance(glyph, advance) {
        if (glyph.equals(" ")) {
            return advance * 0.55;
        }
        if (glyph.equals("1")) {
            return advance * 0.50;
        }
        if (glyph.equals(":")) {
            return advance * 0.35;
        }
        if (glyph.equals(",")) {
            return advance * 0.35;
        }
        if (glyph.equals("%")) {
            return advance * 1.15;
        }
        return advance;
    }

    private function glyphIndex(glyph) {
        switch (glyph) {
            case " ": return 0;
            case "A": return 1;
            case "B": return 2;
            case "C": return 3;
            case "D": return 4;
            case "E": return 5;
            case "F": return 6;
            case "G": return 7;
            case "H": return 8;
            case "I": return 9;
            case "J": return 10;
            case "K": return 11;
            case "L": return 12;
            case "M": return 13;
            case "N": return 14;
            case "O": return 15;
            case "P": return 16;
            case "Q": return 17;
            case "R": return 18;
            case "S": return 19;
            case "T": return 20;
            case "U": return 21;
            case "V": return 22;
            case "W": return 23;
            case "X": return 24;
            case "Y": return 25;
            case "Z": return 26;
            case "0": return 27;
            case "1": return 28;
            case "2": return 29;
            case "3": return 30;
            case "4": return 31;
            case "5": return 32;
            case "6": return 33;
            case "7": return 34;
            case "8": return 35;
            case "9": return 36;
            case ":": return 37;
            case "%": return 38;
            case ",": return 39;
            case "-": return 40;
        }
        return -1;
    }

    private function displayHour(hour) {
        if (System.getDeviceSettings().is24Hour) {
            return hour;
        }

        var twelveHour = hour % 12;
        return (twelveHour == 0) ? 12 : twelveHour;
    }

    private function latestHeartRate() {
        try {
            var iterator = ActivityMonitor.getHeartRateHistory(1, true);
            if (iterator != null) {
                var sample = iterator.next();
                if ((sample != null) &&
                    (sample.heartRate != ActivityMonitor.INVALID_HR_SAMPLE)) {
                    return sample.heartRate;
                }
            }
        } catch (error) {
            // A valid sample may not exist yet, for example just after boot.
        }

        return null;
    }

    private function formatCount(value) {
        var remaining = value.format("%d");
        var grouped = "";
        while (remaining.length() > 3) {
            var split = remaining.length() - 3;
            grouped = "," + remaining.substring(split, remaining.length()) +
                grouped;
            remaining = remaining.substring(0, split);
        }
        return remaining + grouped;
    }

    private function monthLabel(month) {
        switch (month) {
            case 1: return "JAN";
            case 2: return "FEB";
            case 3: return "MAR";
            case 4: return "APR";
            case 5: return "MAY";
            case 6: return "JUN";
            case 7: return "JUL";
            case 8: return "AUG";
            case 9: return "SEP";
            case 10: return "OCT";
            case 11: return "NOV";
            case 12: return "DEC";
        }

        return "---";
    }
}
