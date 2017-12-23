import java.util.NoSuchElementException;

static enum ImageKind {
    COLOR,
    GRAYSCALE,
    BINARY,
    DATA
}

final static class Image {
    final int[] pixels;
    final int width;
    final int height;
    ImageKind kind;

    Image(Image input) {
        this(input, input.kind);
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

    int at(Point pos) {
        return pixels[pos.y*width + pos.x];
    }

    void setAt(int val, int x, int y) {
        pixels[y*width + x] = val;
    }

    void setAt(int val, Point pos) {
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

    void drawCross(int val, Point pos, int k) {
        drawLine(val, pos.add(-k, -k), pos.add(k, k));
        drawLine(val, pos.add(-k, -k + 1), pos.add(k, k + 1));
        drawLine(val, pos.add(-k, k), pos.add(k, -k));
        drawLine(val, pos.add(-k, k + 1), pos.add(k, -k + 1));
    }

    Line line(Point start, Point end) {
        return new Line(start, end, width, height);
    }

    void drawLine(int val, Line line) {
        for (Point p : line) {
            pixels[p.y*width + p.x] = val;
        }
    }

    void drawLine(int val, Point start, Point end) {
        drawLine(val, line(start, end));
    }

    void drawLine(int val, int x0, int y0, int x1, int y1) {
        drawLine(val, line(new Point(x0, y0), new Point(x1, y1)));
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

    void ensureColor() {
        assert kind == ImageKind.COLOR;
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

    String toString() {
        return String.format("%dx%d(%s)", width, height, kind);
    }
}

static Image grayscale(Image input) {
    Image result = new Image(input);
    result.grayscale();
    return result;
}
