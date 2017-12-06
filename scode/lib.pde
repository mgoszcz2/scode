enum ImageKind {
    COLOR,
    GRAYSCALE,
    DATA
}

class Image {
    int[] pixels;
    int width;
    int height;
    ImageKind kind;

    Image(PImage input) {
        input.loadPixels();
        pixels = new int[input.width * input.height];
        //FIXME: All of this breaks at high density
        arrayCopy(input.pixels, pixels);
        kind = ImageKind.COLOR;
        width = input.width;
        height = input.height;
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

    private void normalizeArray(int[] input) {
        int mx = input[0];
        int mn = input[0];
        for (int i = 1; i < input.length; i++) {
            mx = max(mx, input[i]);
            mn = min(mn, input[i]);
        }
        for (int i = 0; i < input.length; i++) {
            input[i] = 0xff * (input[i] - mn) / (mx - mn);
        }
    }

    void ensureGrayscale() {
        assert kind == ImageKind.GRAYSCALE;
    }
    void ensureData() {
        assert kind == ImageKind.DATA;
    }

    void normalizeData() {
        assert kind == ImageKind.DATA;
        normalizeArray(pixels);
        kind = ImageKind.GRAYSCALE;
    }

    PImage get() {
        PImage result = createImage(width, height, RGB);
        result.loadPixels();
        arrayCopy(pixels, result.pixels);

        if (kind == ImageKind.DATA || kind == ImageKind.GRAYSCALE) {
            if (kind == ImageKind.DATA) normalizeArray(result.pixels);
            for (int i = 0; i < pixels.length; i++) {
                int c = result.pixels[i];
                result.pixels[i] = c | (c << 8) | (c << 16) | (0xff << 24);
            }
        }

        result.updatePixels();
        return result;
    }
}
