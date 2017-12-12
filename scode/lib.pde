static enum ImageKind {
    COLOR,
    GRAYSCALE,
    BINARY,
    DATA
}

static class Position {
    int x, y;
    Position(int x, int y) {
        this.x = x;
        this.y = y;
    }

    float hypot(Position h) {
        return (float)Math.hypot(h.x - x, h.y - y);
    }

    String toString() {
        return String.format("(%d, %d)", x, y);
    }
}

static class RingBuffer {
    Position buffer[];
    int items = 0;
    RingBuffer(int size) {
        buffer = new Position[size];
    }

    void push(Position item) {
        for (int i = 0; i < buffer.length - 1; i++) {
            buffer[i] = buffer[i + 1];
        }
        buffer[buffer.length - 1] = item;
        items++;
    }
}

static class Image {
    int[] pixels;
    int width;
    int height;
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
        this.width = width;
        this.height = height;
        this.kind = kind;
        pixels = new int[width * height];
    }

    boolean invalid(int x, int y) {
        return y < 0 || x < 0 || y >= height || x >= width;
    }

    int at(Position pos) {
        return pixels[pos.y*width + pos.x];
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

    void line(int val, int x0, int y0, int x1, int y1) {
        int dx = abs(x1 - x0);
        int dy = abs(y1 - y0);
        int sx = x0 < x1 ? 1 : -1;
        int sy = y0 < y1 ? 1 : -1;
        float err = (dx > dy ? dx : -dy) / 2.0;

        for (;;) {
            if (invalid(x0, y0) || (x0 == x1 && y0 == y1)) break;
            pixels[y0*width + x0] = val;
            float e2 = err;
            if (e2 > -dx) {
                err -= dy;
                x0 += sx;
            }
            if (e2 < dy) {
                err += dx;
                y0 += sy;
            }
        }
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
