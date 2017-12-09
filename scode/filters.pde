import java.util.*;

Image mean(Image image, int k) {
    image.ensureGrayscale();
    int[] summed = new int[image.height * image.width];
    Image result = new Image(image.width, image.height);

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
Image binarize(Image image, Image values) {
    image.ensureGrayscale();
    values.ensureGrayscale();
    assert image.width == values.width && image.height == values.height;
    Image result = new Image(image.width, image.height);
    for (int i = 0; i < image.pixels.length; i++) {
        result.pixels[i] = image.pixels[i] > values.pixels[i] + 10 ? 255 : 0;
    }
    return result;
}

Image grayscale(Image image) {
    Image result = new Image(image.width, image.height);
    for (int i = 0; i < image.pixels.length; i++) {
        color c = image.pixels[i];
        result.pixels[i] = ((c & 0xff) + ((c >> 8) & 0xff) + ((c >> 16) & 0xff)) / 3;
    }
    return result;
}

Image resize(Image image, float scale) {
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

Image gaussian(Image input, float sigma) {
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

Image circleDetect(Image input, boolean inverted) {
    input.ensureData();
    IntList[] angles = new IntList[181];
    Image result = new Image(input.width, input.height, ImageKind.DATA);

    for (int i = 0; i < input.pixels.length; i++) {
        // Only accumate half the circle
        if (input.pixels[i] > 0 && input.pixels[i] <= 181) {
            int a = input.pixels[i] - 1;
            if (angles[a] == null) {
                angles[a] = new IntList();
            }
            angles[a].append(i);
        }
    }

    for (int i = 0; i < input.pixels.length; i++) {
        if (input.pixels[i] > 181) {
            int a = (input.pixels[i] - 1) % 180;
            if (angles[a] == null) continue;

            int x0 = i % input.width;
            int y0 = i / input.width;
            for (int j : angles[a]) {
                int x1 = j % input.width;
                int y1 = j / input.width;
                int mx = (x0 + x1)/2;
                int my = (y0 + y1)/2;
                int b = ((int)((atan2(mx - x0, my - y0) + PI) * 180 / PI) + (inverted ? 270 : 90)) % 360;
                // println(a, b);
                if (abs(a - b) < 3) result.pixels[my*input.width + mx]++;
            }
        }
    }
    return result;
}

// Should be blurred by this point
Image edges(Image image) {
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

    mask.normalizeData();
    mask = binarize(mask, mean(mask, 3));
    for (int i = 0; i < mask.pixels.length; i++) {
        if (mask.pixels[i] > 0) {
            //FIXME: Not sure why +270 needed?
            mask.pixels[i] = 1 + ((int)((atan2(gradient[0][i], gradient[1][i]) + PI) * 180 / PI) + 270) % 360;
        }
    }
    mask.kind = ImageKind.DATA;
    return mask;
}

Image invert(Image input) {
    input.ensureGrayscale();
    Image result = new Image(input.width, input.height);
    for (int i = 0; i < input.pixels.length; i++) {
        result.pixels[i] = 0xff - input.pixels[i];
    }
    return result;
}

void drawBin(PGraphics result, color cl, int[] bin, int height, int mb) {
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
