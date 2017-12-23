import java.util.*;

static void maskCombineInPlace(Image bg, Image fg, Image mask) {
    assert bg.compatible(fg);
    assert bg.equalSize(fg) && fg.equalSize(mask);
    mask.ensureGrayscale();
    for (int i = 0; i < mask.pixels.length; i++) {
        if (mask.pixels[i] > 0) {
            bg.pixels[i] = fg.pixels[i];
        }
    }
}

static Image mean(Image input, int k) {
    Image result = new Image(input);
    meanInPlace(result, k);
    return result;
}

static void meanInPlace(Image image, int k) {
    // No blur
    if (k == 0) return;

    image.ensureGrayscale();
    int[] summed = new int[image.height * image.width];
    summed[0] = image.pixels[0] & 0xff;
    for (int x = 1; x < image.width; x++) {
        summed[x] = summed[x - 1] + (image.pixels[x] & 0xff);
    }
    for (int y = 1; y < image.height; y++) {
        summed[y*image.width] = summed[(y - 1)*image.width] + (image.pixels[y*image.width] & 0xff);
        for (int x = 1; x < image.width; x++) {
            int ix = y*image.width + x;
            summed[ix] = summed[ix - image.width] + summed[ix - 1] - summed[ix - image.width - 1] + (image.pixels[ix] & 0xff);
        }
    }

    for (int y = 0; y < image.height; y++) {
        int kt = min(k, y);
        int kb = min(y + k, image.height - 1) - y;

        for (int x = 0; x < image.width; x++) {
            int kl = min(k, x);
            int kr = min(x + k, image.width - 1) - x;

            int window = (kl + kr) * (kt + kb);
            int ix = y*image.width + x;
            int t0 = summed[ix + kb*image.width + kr];
            int t1 = summed[ix + kb*image.width - kl];
            int t2 = summed[ix - kt*image.width + kr];
            int t3 = summed[ix - kt*image.width - kl];

            image.pixels[y * image.width + x] = (t0 - t1 - t2 + t3) / window;
        }
    }
}

// Negtaive nudge makes more white
static Image binarize(Image image, Image values, float treshold) {
    image.ensureGrayscale();
    values.ensureGrayscale();
    assert image.equalSize(values);
    Image result = Image.withSize(image, ImageKind.GRAYSCALE);
    for (int i = 0; i < image.pixels.length; i++) {
        result.pixels[i] = image.pixels[i] / (0.01 + values.pixels[i]) < treshold ? 0 : 255;
    }
    result.kind = ImageKind.BINARY;
    return result;
}

private static void flood(boolean[] result, Image input, int x, int y) {
    int ix = y*input.width + x;
    if (input.invalid(x, y) || result[ix] || input.pixels[ix] == 0) {
        return;
    }
    result[y*input.width + x] = true;
    flood(result, input, x + 1, y);
    flood(result, input, x - 1, y);
    flood(result, input, x, y + 1);
    flood(result, input, x, y - 1);
}

static Point[] components(Image bg, Image input) {
    input.ensureGrayscale();
    boolean[] store = new boolean[input.width * input.height];
    Point[] result = new Point[4];
    int component = 0;

    for (int y = 0; y < input.height; y++) {
        for (int x = 0; x < input.width; x++) {
            int ix = y*input.width + x;
            if (!store[ix] && input.pixels[ix] > 0) {
                flood(store, input, x, y);
                if (component >= 4) return null;
                result[component++] = new Point(x, y);
            }
        }
    }
    return component == 4 ? result : null;
}

static Image resize(Image image, float ratio) {
    return resize(image, round(image.width * ratio), round(image.height * ratio));
}

static Image resize(Image image, int width, int height) {
    Image result = new Image(width, height, image.kind);
    float xratio = (image.width - 1)/(float)width;
    float yratio = (image.height - 1)/(float)height;

    if (image.kind == ImageKind.GRAYSCALE) {
        for (int y = 0; y < result.height; y++) {
            for (int x = 0; x < result.width; x++) {
                int px = (int)(x*xratio);
                int py = (int)(y*yratio);
                float dx = x*xratio - px;
                float dy = y*yratio - py;

                int ix = py * image.width + px;
                int a = image.pixels[ix];
                int b = image.pixels[ix + 1];
                int c = image.pixels[ix + image.width];
                int d = image.pixels[ix + image.width + 1];
                int gray = (int)(a*(1-dx)*(1-dy) +  b*dx*(1-dy) + c*dy*(1-dx) + d*dx*dy);
                result.pixels[y*result.width + x] = gray;
            }
        }

    } else if (image.kind == ImageKind.COLOR) {
        for (int y = 0; y < result.height; y++) {
            for (int x = 0; x < result.width; x++) {
                int px = (int)(x*xratio);
                int py = (int)(y*yratio);
                float dx = x*xratio - px;
                float dy = y*yratio - py;

                int ix = py * image.width + px;
                int a = image.pixels[ix];
                int b = image.pixels[ix + 1];
                int c = image.pixels[ix + image.width];
                int d = image.pixels[ix + image.width + 1];

                float am = (1 - dx)*(1 - dy);
                float bm = dx*(1 - dy);
                float cm = (1 - dx)*dy;
                float dm = dx*dy;

                float cb = (a & 0xff)*am
                         + (b & 0xff)*bm
                         + (c & 0xff)*cm
                         + (d & 0xff)*dm;

                float cg = ((a >> 8) & 0xff)*am
                         + ((b >> 8) & 0xff)*bm
                         + ((c >> 8) & 0xff)*cm
                         + ((d >> 8) & 0xff)*dm;

                float cr = ((a >> 16) & 0xff)*am
                         + ((b >> 16) & 0xff)*bm
                         + ((c >> 16) & 0xff)*cm
                         + ((d >> 16) & 0xff)*dm;

                result.pixels[y*result.width + x] = ((int)cr << 16) | ((int)cg << 8) | (int)cb;
            }
        }
    }
    return result;
}

static Image evenCrop(Image input, int width, int height) {
    Image result = new Image(width, height, input.kind);
    int d = (input.width - width)/2 + ((input.height - height)/2)*input.width;
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            result.pixels[y*width + x] = input.pixels[y*input.width + x + d];
        }
    }
    return result;
}

static Image combine(Image[] channels) {
    assert channels.length == 3;
    channels[0].ensureGrayscale();
    channels[1].ensureGrayscale();
    channels[2].ensureGrayscale();
    assert channels[0].equalSize(channels[1]) && channels[1].equalSize(channels[2]);

    Image result = Image.withSize(channels[0], ImageKind.COLOR);
    for (int i = 0; i < result.pixels.length; i++) {
        result.pixels[i] = (channels[0].pixels[i] << 16) | (channels[1].pixels[i] << 8) | channels[2].pixels[i];
    }
    return result;
}

static Image[] separate(Image input) {
    assert input.kind == ImageKind.COLOR;

    Image[] result = new Image[3];
    for (int i = 0; i < 3; i++) {
        result[i] = Image.withSize(input, ImageKind.GRAYSCALE);
    }

    for (int i = 0; i < input.pixels.length; i++) {
        result[0].pixels[i] = (input.pixels[i] >> 16) & 0xff;
        result[1].pixels[i] = (input.pixels[i] >> 8) & 0xff;
        result[2].pixels[i] = input.pixels[i] & 0xff;
    }
    return result;
}

static void saturateInPlace(Image input, float factor) {
    input.ensureColor();
    for (int i = 0; i < input.pixels.length; i++) {
        input.pixels[i] = saturate(input.pixels[i], factor);
    }
}

// Blur 0.0-1.0, saturation 1.0-1.5 realesticly (255 reasonable max)
static Image vibrantBlur(Image input, float blur, float saturation, int width, int height) {
    // We resize down, blur it a lot and resize it back
    final int resolution = input.width / 2;
    float ratio = resolution/(float)input.width;
    Image[] channels = separate(resize(input, ratio));
    for (int i = 0; i < 3; i++) {
        meanInPlace(channels[i], (int)(blur * resolution * 0.08));
        meanInPlace(channels[i], (int)(blur * resolution * 0.04));
    }
    Image combined = combine(channels);
    saturateInPlace(combined, saturation);
    return resize(combined, width, height);
}

static Image gaussian(Image input, float sigma) {
    input.ensureGrayscale();
    float[] kernel = new float[ceil(sigma) * 6 + 1];
    Image store = new Image(input.width - kernel.length + 1, input.height - kernel.length + 1, ImageKind.GRAYSCALE);
    int[] convoluted = new int[store.width * input.height];

    float gsum = 0;
    for(int i = 0; i < kernel.length; i++) {
        float x = i - (kernel.length-1)/2;
        float g = exp(-(x*x) / (2*sigma*sigma));
        gsum += g;
        kernel[i] = g;
    }
    for(int i = 0; i < kernel.length; i++) {
        kernel[i] /= gsum;
    }

    int h = kernel.length / 2;
    for (int y = 0; y < input.height; y++) {
        for (int x = h; x < input.width - h; x++) {
            int ix = y*input.width + x;
            float sum = 0;
            for (int i = 0; i < kernel.length; i++) {
                sum += (input.pixels[ix - h + i] & 0xff) * kernel[i];
            }
            convoluted[y*store.width + x - h] = (int)sum;
        }
    }

    for (int y = h; y < input.height - h; y++) {
        for (int x = 0; x < store.width; x++) {
            int ix = y*store.width + x;
            float sum = 0;
            for (int i = 0; i < kernel.length; i++) {
                sum += (convoluted[ix - (h - i)*store.width] & 0xff) * kernel[i];
            }
            store.pixels[(y - h)*store.width + x] = (int)sum;
        }
    }
    return store;
}

static Image morph(Image input, int k, boolean dilute) {
    input.ensureBinary();
    Image result = Image.withSize(input, ImageKind.BINARY);
    for (int y = k; y < input.height - k - 1; y++) {
        for (int x = k; x < input.width - k - 1; x++) {
            boolean r = dilute;
            for (int dy = -k; dy <= k; dy++) {
                for (int dx = -k - dy; dx <= k - dy; dx++) {
                    if (dilute) {
                        r &= input.pixels[(y + dy)*input.width + x + dx] > 0;
                    } else {
                        r |= input.pixels[(y + dy)*input.width + x + dx] > 0;
                    }
                }
            }
            result.pixels[y*input.width + x] = r ? 255 : 0;
        }
    }
    return result;
}

static Image combine(Image a, Image b, boolean both) {
    assert a.equalSize(b) && a.compatible(b);
    Image result = new Image(a.width, a.height, a.kind);
    for (int i = 0; i < a.pixels.length; i++) {
        result.pixels[i] = both ? a.pixels[i] & b.pixels[i] : a.pixels[i] | b.pixels[i];
    }
    return result;
}

static void drawBin(PGraphics result, color cl, int[] bin, int height, int mb) {
    result.beginShape();
    result.stroke(cl);
    result.fill(cl, 128);
    result.strokeWeight(1);
    for (int i = 1; i < 255; i++) {
        // Plus 1 important on high density displays
        result.vertex(i - 1, height + 1 - height * min(mb, bin[i]) / mb);
    }
    result.vertex(253, height + 2);
    result.vertex(0, height + 2);
    result.endShape();
}

// Can return null
PImage histogram(Image image, int height) {
    int[][] bins = new int[3][256];
    for (int i = 0; i < image.pixels.length; i++) {
        color c = image.pixels[i];
        bins[0][c & 0xff]++;
        bins[1][(c >> 8) & 0xff]++;
        bins[2][(c >> 16) & 0xff]++;
    }

    // A tad hacky, we just ignore the fact that in grayscale images, 2 channels are 0
    int mb = 0;
    for (int i = 1; i < 255; i++) {
        for (int c = 0; c < 3; c++) {
            if (bins[c][i] > mb) mb = bins[c][i];
        }
    }

    // histogram_max skips #000, so this might happen
    if (mb == 0) return null;

    PGraphics result = createGraphics(254, height);
    result.beginDraw();
    if (image.kind == ImageKind.COLOR) {
        color[] colors = {#0000ff, #00ff00, #ff0000};
        for (int c = 0; c < 3; c++) {
            drawBin(result, colors[c], bins[c], height, mb);
        }
    } else {
        drawBin(result, #ffffff, bins[0], height, mb);
    }

    result.endDraw();
    return result.get();
}
