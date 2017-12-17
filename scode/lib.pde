import java.util.NoSuchElementException;

static enum ImageKind {
    COLOR,
    GRAYSCALE,
    BINARY,
    DATA
}

static class Position {
    final int x, y;
    Position(int x, int y) {
        this.x = x;
        this.y = y;
    }

    float hypot(Position h) {
        return (float)Math.hypot(h.x - x, h.y - y);
    }

    Position add(int dx, int dy) {
        return new Position(x + dx, y + dy);
    }

    Position subtract(Position h) {
        return new Position(x - h.x, y + h.y);
    }

    Position midpoint(Position h) {
        return new Position((x + h.x)/2, (y + h.y)/2);
    }

    double atan2() {
        return Math.atan2(y, x);
    }

    String toString() {
        return String.format("(%d, %d)", x, y);
    }

    boolean equals(Object h) {
        if (h == null || !(h instanceof Position)) return false;
        Position hp = (Position)h;
        return hp.x == x && hp.y == y;
    }

    int hashCode() {
        return x << 16 | y & 0xffff;
    }

    static Position mean(Position[] hs) {
        int sx = 0, sy = 0;
        for (Position p : hs) {
            sx += p.x;
            sy += p.y;
        }
        return new Position(sx / hs.length, sy / hs.length);
    }
}

static class Line implements Iterable<Position> {
    final int width, height;
    final Position start, end;

    class LineIterator implements Iterator<Position> {
        private final int dx, dy, sx, sy;
        private int x0 = start.x, y0 = start.y;
        private boolean finished = false;
        private float error;

        private LineIterator() {
            dx = abs(end.x - x0);
            dy = abs(end.y - y0);
            sx = x0 < end.x ? 1 : -1;
            sy = y0 < end.y ? 1 : -1;
            error = (dx > dy ? dx : -dy) / 2.0;
        }

        Position next() {
            if (finished || invalid()) {
                finished = true;
                throw new NoSuchElementException();
            }

            Position r = new Position(x0, y0);
            if (x0 == end.x && y0 == end.y) {
                finished = true;
                return r;
            }

            float e2 = error;
            if (e2 > -dx) {
                error -= dy;
                x0 += sx;
            }
            if (e2 < dy) {
                error += dx;
                y0 += sy;
            }

            return r;
        }

        private boolean invalid() {
            return x0 < 0 || y0 < 0 || x0 >= width || y0 >= height;
        }

        boolean hasNext() {
            return !finished && !invalid();
        }
    }

    Line(Position start, Position end, int width, int height) {
        this.start = start;
        this.end = end;
        this.width = width;
        this.height = height;
    }

    Line(Position start, Position end) {
        this(start, end, Integer.MAX_VALUE, Integer.MAX_VALUE);
    }

    LineIterator iterator() {
        return new LineIterator();
    }

    float ratio(Position h) {
        if (start.x != end.x) {
            return (h.x - start.x) / (float)(end.x - start.x);
        }
        return (h.y - start.y) / (float)(end.y - start.y);
    }

    Position atRatio(float r) {
        return new Position((int)(start.x + (end.x - start.x)*r), (int)(start.y + (end.y - start.y)*r));
    }

    // Ripped stackoverflow.com/questions/563198
    Position intersection(Line h) {
        float p0_x = start.x, p0_y = start.y;
        float p1_x = end.x, p1_y = end.y;
        float p2_x = h.start.x, p2_y = h.start.y;
        float p3_x = h.end.x, p3_y = h.end.y;

        float s1_x = p1_x - p0_x;
        float s1_y = p1_y - p0_y;
        float s2_x = p3_x - p2_x;
        float s2_y = p3_y - p2_y;

        float s = (-s1_y * (p0_x - p2_x) + s1_x * (p0_y - p2_y)) / (-s2_x * s1_y + s1_x * s2_y);
        float t = ( s2_x * (p0_y - p2_y) - s2_y * (p0_x - p2_x)) / (-s2_x * s1_y + s1_x * s2_y);

        if (s >= 0 && s <= 1 && t >= 0 && t <= 1) {
            return new Position((int)(p0_x + (t * s1_x)), (int)(p0_y + (t * s1_y)));
        }

        return null;
    }
}


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
static boolean approxEqual(float[] ratios, Position[] buffer) {
    final float error = 0.50;
    float gap = buffer[1].hypot(buffer[0]);

    for (int i = 1; i < buffer.length - 2; i++) {
        float mgap = buffer[i + 1].hypot(buffer[i]);
        if (Math.abs(ratios[i - 1] - mgap / gap) > error) return false;
    }
    return true;
}

static class Image {
    final int[] pixels;
    final int width;
    final int height;
    ImageKind kind;

    Image(Image input) {
        this(input, input.kind);
    }

    static Image withSize(Image template) {
        return new Image(template.width, template.height, ImageKind.GRAYSCALE);
    }

    static Image withSize(Image template, ImageKind kind) {
        return new Image(template.width, template.height, kind);
    }

    private void convertTo(ImageKind newKind) {
        assert newKind == kind || newKind != ImageKind.BINARY;
        if (newKind == ImageKind.COLOR) fullColor();
        else if (newKind == ImageKind.GRAYSCALE) grayscale();
        else if (newKind == ImageKind.DATA) this.kind = ImageKind.DATA;
    }

    Image(Image input, ImageKind newKind) {
        this(input.width, input.height, input.kind);
        arrayCopy(input.pixels, pixels);
        convertTo(newKind);
    }

    Image(PImage input, ImageKind newKind) {
        input.loadPixels();
        pixels = new int[input.width * input.height];
        arrayCopy(input.pixels, pixels);
        this.kind = ImageKind.COLOR;
        width = input.width;
        height = input.height;
        convertTo(newKind);
    }

    Image(PImage input) {
        this(input, ImageKind.COLOR);
    }

    Image(int width, int height) {
        this(width, height, ImageKind.GRAYSCALE);
    }

    Image(int width, int height, ImageKind kind) {
        assert width > 0 && height > 0;
        this.width = width;
        this.height = height;
        this.kind = kind;
        pixels = new int[width * height];
    }

    boolean invalid(int x, int y) {
        return y < 0 || x < 0 || y >= height || x >= width;
    }

    int at(int x, int y) {
        return pixels[y*width + x];
    }

    int at(Position pos) {
        return pixels[pos.y*width + pos.x];
    }

    void setAt(int val, int x, int y) {
        pixels[y*width + x] = val;
    }

    void setAt(int val, Position pos) {
        pixels[pos.y*width + pos.x] = val;
    }

    private void normalizeArray(int[] input) {
        int mx = input[0];
        int mn = input[0];
        for (int i = 1; i < input.length; i++) {
            mx = max(mx, input[i]);
            mn = min(mn, input[i]);
        }
        int d = max(1, mx - mn);
        for (int i = 0; i < input.length; i++) {
            input[i] = 0xff * (input[i] - mn) / d;
        }
    }

    void drawCross(int val, Position pos, int k) {
        drawLine(val, pos.add(-k, -k), pos.add(k, k));
        drawLine(val, pos.add(-k, -k + 1), pos.add(k, k + 1));
        drawLine(val, pos.add(-k, k), pos.add(k, -k));
        drawLine(val, pos.add(-k, k + 1), pos.add(k, -k + 1));
    }

    Line line(Position start, Position end) {
        return new Line(start, end, width, height);
    }

    void drawLine(int val, Line line) {
        for (Position p : line) {
            pixels[p.y*width + p.x] = val;
        }
    }

    void drawLine(int val, Position start, Position end) {
        drawLine(val, line(start, end));
    }

    void drawLine(int val, int x0, int y0, int x1, int y1) {
        drawLine(val, line(new Position(x0, y0), new Position(x1, y1)));
    }

    private void fullColorArray(int[] input) {
        if (kind == ImageKind.DATA) {
            normalizeArray(input);
        }

        if (kind != ImageKind.COLOR) {
            for (int i = 0; i < input.length; i++) {
                int c = input[i];
                input[i] = c | (c << 8) | (c << 16) | (0xff << 24);
            }
        }
    }

    void ensureGrayscale() {
        assert kind == ImageKind.GRAYSCALE || kind == ImageKind.BINARY;
    }

    void ensureBinary() {
        assert kind == ImageKind.BINARY;
    }

    boolean compatible(Image h) {
        return h.kind == kind ||
            (h.kind == ImageKind.GRAYSCALE && kind == ImageKind.BINARY) ||
            (kind == ImageKind.GRAYSCALE && h.kind == ImageKind.BINARY);
    }

    boolean equalSize(Image h) {
        return h.width == width && h.height == height;
    }

    void fullColor() {
        fullColorArray(pixels);
        kind = ImageKind.COLOR;
    }

    void grayscale() {
        if (kind == ImageKind.DATA) {
            normalizeArray(pixels);
        } else if (kind == ImageKind.COLOR) {
            for (int i = 0; i < pixels.length; i++) {
                color c = pixels[i];
                pixels[i] = ((c & 0xff) + ((c >> 8) & 0xff) + ((c >> 16) & 0xff)) / 3;
            }
        }
        kind = ImageKind.GRAYSCALE;
    }

    PImage get(PApplet applet) {
        PImage result = applet.createImage(width, height, RGB);
        result.loadPixels();
        arrayCopy(pixels, result.pixels);
        fullColorArray(result.pixels);
        result.updatePixels();
        return result;
    }
}
