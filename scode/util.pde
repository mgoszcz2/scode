static class Tuple<A, B> {
    final A a;
    final B b;
    Tuple(A a, B b) {
        this.a = a;
        this.b = b;
    }
}

static <T> void ringPush(T[] buf, T item) {
    for (int i = 0; i < buf.length - 1; i++) {
        buf[i] = buf[i + 1];
    }
    buf[buf.length - 1] = item;
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

// Silly, but works well enough
static int saturate(int rgb, float factor) {
    float r = ((rgb >> 16) & 0xff) * factor;
    float g = ((rgb >> 8) & 0xff) * factor;
    float b = (rgb & 0xff) * factor;
    return (min((int)r, 255) << 16) | (min((int)g, 255) << 8) | min((int)b, 255);
}
