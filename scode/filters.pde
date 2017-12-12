import java.util.*;

static Image mean(Image image, int k) {
    image.ensureGrayscale();
    int[] summed = new int[image.height * image.width];
    Image result = Image.withSize(image);

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

            result.pixels[y * result.width + x] = (t0 - t1 - t2 + t3) / window;
        }
    }

    return result;
}

// Negtaive nudge makes more white
static Image binarize(Image image, Image values, int nudge) {
    image.ensureGrayscale();
    values.ensureGrayscale();
    assert image.equalSize(values);
    Image result = Image.withSize(image);
    for (int i = 0; i < image.pixels.length; i++) {
        result.pixels[i] = image.pixels[i] > values.pixels[i] + nudge ? 255 : 0;
    }
    result.kind = ImageKind.BINARY;
    return result;
}

static private boolean approxEqual(RingBuffer ring, float[] ratios, float error) {
    if (ring.items < ring.buffer.length) return false;
    float gap = ring.buffer[1].hypot(ring.buffer[0]);

    for (int i = 1; i < ring.buffer.length - 2; i++) {
        float mgap = ring.buffer[i + 1].hypot(ring.buffer[i]);
        if (Math.abs(ratios[i - 1] - mgap / gap) > error) return false;
    }

    return true;
}

static private void lineCheck(Image result, Image input, float[] ratios, float error, int x0, int y0, int x1, int y1) {
    input.ensureGrayscale();
    result.ensureGrayscale();
    RingBuffer ring = new RingBuffer(ratios.length + 2);
    int lastVal = input.pixels[y0*input.width + x0];

    int dx = abs(x1 - x0);
    int dy = abs(y1 - y0);
    int sx = x0 < x1 ? 1 : -1;
    int sy = y0 < y1 ? 1 : -1;
    float err = (dx > dy ? dx : -dy) / 2.0;

    for (;;) {
        if (input.invalid(x0, y0) || (x0 == x1 && y0 == y1)) break;
        int val = input.pixels[y0*input.width + x0];
        if (val != lastVal) {
            ring.push(new Position(x0, y0));
            lastVal = val;
            if (val > 0 && approxEqual(ring, ratios, error)) {
                result.line(255, ring.buffer[0].x, ring.buffer[0].y, ring.buffer[ring.buffer.length-1].x, ring.buffer[ring.buffer.length-1].y);
            }
        }

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

static Image findFinder(Image input) {
    input.ensureBinary();
    final float[] ratios = {0.63, 1.82, 0.63, 1.00};

    Image rx = Image.withSize(input, ImageKind.BINARY);
    Image ry = Image.withSize(input, ImageKind.BINARY);

    for (int y = 0; y < input.height; y++) {
        lineCheck(rx, input, ratios, 0.35, 0, y, input.width, y);
    }
    for (int x = 0; x < input.width; x++) {
        lineCheck(ry, input, ratios, 0.35, x, 0, x, input.height);
    }
    return combine(rx, ry, true);
}

static Image findAuxFinder(Image input, Image components) {
    // final float[] ratios = {1.00, 1.00, 1.00, 1.00, 1.00};
    final float[] ratios = {1.00, 1.00, 1.00, 1.00, 0.80, 0.45, 0.50, 0.45};
    input.ensureBinary();
    components.ensureBinary();
    assert input.equalSize(components);

    int d = input.width * 3 / 4;
    Image result = Image.withSize(input, ImageKind.BINARY);

    for (int y = 0; y < input.height; y++) {
        for (int x = 0; x < input.width; x++) {
            if (components.pixels[y*input.width + x] > 0) {
                result.pixels[y*input.width + x] = 255;
                result.pixels[y*input.width + x + 1] = 255;
                result.pixels[y*input.width + x - 1] = 255;
                result.pixels[y*input.width + x + input.width] = 255;
                result.pixels[y*input.width + x - input.width] = 255;
                for (int i = 0; i < 720; i++) {
                    // result.line(255, x, y, (int)(x + d * cos(i*PI/360)), (int)(y + d * sin(i*PI/360)));
                    lineCheck(result, input, ratios, 0.35, x, y, (int)(x + d * cos(i*PI/360)), (int)(y + d * sin(i*PI/360)));
                }
            }
        }
    }
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

static Image components(Image input) {
    input.ensureGrayscale();
    Image result = Image.withSize(input, ImageKind.BINARY);
    boolean[] store = new boolean[input.width * input.height];
    int component = 1;

    for (int y = 0; y < input.height; y++) {
        for (int x = 0; x < input.width; x++) {
            int ix = y*input.width + x;
            if (!store[ix] && input.pixels[ix] > 0) {
                flood(store, input, x, y);
                result.pixels[ix] = 255;
            }
        }
    }
    return result;
}

static Image resize(Image image, float scale) {
    image.ensureGrayscale();
    // Hack, always shrinks image by 1px even at s=1.0
    Image result = new Image(ceil(image.width * scale) - 1, ceil(image.height * scale) - 1);
    for (int y = 0; y < result.height; y++) {
        for (int x = 0; x < result.width; x++) {
            int px = (int)(x / scale);
            int py = (int)(y / scale);
            float dx = x / scale - px;
            float dy = y / scale - py;

            int ix = py * image.width + px;
            int a = image.pixels[ix] & 0xff;
            int b = image.pixels[ix + 1] & 0xff;
            int c = image.pixels[ix + image.width] & 0xff;
            int d = image.pixels[ix + image.width + 1] & 0xff;
            int gray = (int)(a*(1-dx)*(1-dy) +  b*dx*(1-dy) + c*dy*(1-dx) + d*dx*dy);
            result.pixels[y * result.width + x] = gray;
        }
    }
    return result;
}

static Image evenCrop(Image input, int width, int height) {
    Image result = new Image(width, height);
    int d = (input.width - width)/2 + ((input.height - height)/2)*input.width;
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            result.pixels[y*width + x] = input.pixels[y*input.width + x + d];
        }
    }
    return result;
}

static Image gaussian(Image input, float sigma) {
    input.ensureGrayscale();
    float[] kernel = new float[ceil(sigma) * 6 + 1];
    Image store = new Image(input.width - kernel.length + 1, input.height - kernel.length + 1);
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

static int angle(int x, int y) {
    return ((int)((atan2(x, y) + PI) * 180 / PI) + 90) % 360;
}

// all means erode
static Image morph(Image input, boolean allMode) {
    input.ensureBinary();
    Image result = Image.withSize(input, ImageKind.BINARY);
    for (int y = 1; y < input.height - 1; y++) {
        for (int x = 1; x < input.width - 1; x++) {
            int ix = y*input.width + x;
            boolean t0 = input.pixels[ix - input.width] > 0;
            boolean t1 = input.pixels[ix - 1] > 0;
            boolean t2 = input.pixels[ix + 1] > 0;
            boolean t3 = input.pixels[ix + input.width] > 0;
            if (allMode) {
                result.pixels[ix] = t0 && t1 && t2 && t3 ? 255 : 0;
            } else {
                result.pixels[ix] = t0 || t1 || t2 || t3 ? 255 : 0;
            }
        }
    }
    return result;
}

// Should be blurred by this point
static Image edges(Image image) {
    image.ensureGrayscale();
    Image mask = new Image(image.width - 2, image.height - 2, ImageKind.DATA);
    int[][] gradient = new int[2][mask.height * mask.width];
    int[] mag = new int[mask.height * mask.width];

    // We could separate this but we don't bother
    for (int y = 1; y < image.height - 1; y++) {
        for (int x = 1; x < image.width - 1; x++) {
            int ix = y*image.width + x;
            int t00 = image.pixels[ix - image.width - 1] & 0xff;
            int t10 = image.pixels[ix - image.width] & 0xff;
            int t20 = image.pixels[ix - image.width + 1] & 0xff;
            int t01 = image.pixels[ix - 1] & 0xff;
            int t21 = image.pixels[ix + 1] & 0xff;
            int t02 = image.pixels[ix + image.width - 1] & 0xff;
            int t12 = image.pixels[ix + image.width] & 0xff;
            int t22 = image.pixels[ix + image.width + 1] & 0xff;

            int dy = t00 + 2*t01 + t02 - t20 - 2*t21 - t22;
            int dx = t00 + 2*t10 + t20 - t02 - 2*t12 - t22;

            int gix = (y - 1)*mask.width + x - 1;
            gradient[0][gix] = dy;
            gradient[1][gix] = dx;
            mag[gix] = (int)sqrt(dy*dy + dx*dx);
        }
    }

    for (int y = 1; y < mask.height - 1; y++) {
        for (int x = 1; x < mask.width - 1; x++) {
            int ix = y*mask.width + x;
            float t00 = mag[ix - mask.width - 1];
            float t10 = mag[ix - mask.width];
            float t20 = mag[ix - mask.width + 1];
            float t01 = mag[ix - 1];
            float t11 = mag[ix];
            float t21 = mag[ix + 1];
            float t02 = mag[ix + mask.width - 1];
            float t12 = mag[ix + mask.width];
            float t22 = mag[ix + mask.width + 1];

            float t = atan2(gradient[0][ix], gradient[1][ix]);
            int dir = (int)(((t + PI / 8) / PI * 4) + 4) % 4;
            if ((dir == 2 && t01 < t11 && t11 > t21) ||
                (dir == 3 && t02 < t11 && t11 > t20) ||
                (dir == 0 && t10 < t11 && t11 > t12) ||
                (dir == 1 && t00 < t11 && t11 > t22)) {

                mask.pixels[ix] = mag[ix];
            }
        }
    }

    mask.grayscale();
    mask = binarize(mask, mean(mask, 3), 5);
    for (int i = 0; i < mask.pixels.length; i++) {
        if (mask.pixels[i] > 0) {
            mask.pixels[i] = 1 + angle(gradient[0][i], gradient[1][i]);
        }
    }
    mask.kind = ImageKind.DATA;
    return mask;
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
