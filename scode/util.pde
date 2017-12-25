final static class Result<S, E> {
    final S result;
    final E error;
    Result(S result, E error) {
        this.result = result;
        this.error = error;
    }
}

// We either do this now, or we mod the heck out of indexes
// this is easier
static <T> void ringPush(T[] buf, T item) {
    for (int i = 0; i < buf.length - 1; i++) {
        buf[i] = buf[i + 1];
    }
    buf[buf.length - 1] = item;
}

// Orders corner of a polygon (atan2 style unit circle)
private static void orderCorners(Point[] corners) {
    final Point m = Point.mean(corners);
    Arrays.sort(corners, new Comparator<Point>(){
        public int compare(Point a, Point b) {
            return Double.compare(a.subtract(m).atan2(), b.subtract(m).atan2());
        }
    });
}

// buffer.length + 2 == ratios.length, not checked
static boolean approxEqual(float[] ratios, Point[] buffer) {
    final float error = 0.50;
    float gap = buffer[1].hypot(buffer[0]);

    for (int i = 1; i < buffer.length - 2; i++) {
        float mgap = buffer[i + 1].hypot(buffer[i]);
        if (Math.abs(ratios[i - 1] - mgap / gap) > error) return false;
    }
    return true;
}

static float[] rgbToHsv(int rgb) {
    float r = ((rgb >> 16) & 0xff) / 255.0;
    float g = ((rgb >> 8) & 0xff) / 255.0;
    float b = (rgb & 0xff) / 255.0;

    float max = Math.max(Math.max(r, g), b);
    float min = Math.min(Math.min(r, g), b);
    float delta = max - min;
    float hue = 0;
    float brightness = max;
    float saturation = max == 0 ? 0 : (max - min) / max;

    if (delta != 0) {
       if (r == max) {
           hue = (g - b) / delta;
       } else {
           if (g == max) {
               hue = 2 + (b - r) / delta;
           } else {
               hue = 4 + (r - g) / delta;
           }
       }
       hue *= 60;
       if (hue < 0) hue += 360;
   }

   return new float[] {hue, saturation, brightness};
}

// Ripped from eclipse http://kickjava.com/src/org/eclipse/swt/graphics/RGB.java.htm
static int hsvToRgb(float hsv[]) {
    float hue = hsv[0], saturation = hsv[1], brightness = hsv[2];
    float r, g, b;
    if (saturation == 0) {
       r = g = b = brightness;
   } else {
       if (hue == 360) hue = 0;
       hue /= 60;
       int i = (int)hue;
       float f = hue - i;
       float p = brightness * (1 - saturation);
       float q = brightness * (1 - saturation * f);
       float t = brightness * (1 - saturation * (1 - f));

       switch(i) {
           case 0:
               r = brightness;
               g = t;
               b = p;
               break;
           case 1:
               r = q;
               g = brightness;
               b = p;
               break;
           case 2:
               r = p;
               g = brightness;
               b = t;
               break;
           case 3:
               r = p;
               g = q;
               b = brightness;
               break;
           case 4:
               r = t;
               g = p;
               b = brightness;
               break;
           case 5:
           default:
               r = brightness;
               g = p;
               b = q;
               break;
       }
   }

   return ((int)(r * 255 + 0.5) << 16) | ((int)(g * 255 + 0.5) << 8) | (int)(b * 255 + 0.5);
}

static int saturate(int rgb, float factor) {
    float[] hsv = rgbToHsv(rgb);
    hsv[1] = min(hsv[1] * factor, 1.0);
    hsv[2] = hsv[2] / factor;
    return hsvToRgb(hsv);
}

private static int evenParity(int x) {
    x ^= x >> 4;
    x ^= x >> 2;
    x ^= x >> 1;
    return (~x) & 1;
}
