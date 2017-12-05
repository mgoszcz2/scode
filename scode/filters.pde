// Based on Adaptive Thresholding Using the Integral Image
class Binarize extends ManagedFilter {
    void runWithStore(PImage image, PImage result) {
        // 12 just works well
        int k = min(image.width, image.height) / 3;
        // int k = 3;
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

                //FIXME WTF?
                int avg = (t0 - t1 - t2 + t3) * 900 / 100;
                int bw = (image.pixels[ix] & 0xff) * window;
                result.pixels[y * result.width + x] = bw >= avg ? 255 : 0;
            }
        }
    }
}

class Greyscale extends InPlaceFilter {
    void runWithStore(PImage image, PImage result) {
        for (int i = 0; i < image.pixels.length; i++) {
            color c = image.pixels[i];
            result.pixels[i] = ((c & 0xff) + ((c >> 8) & 0xff) + ((c >> 16) & 0xff)) / 3;
        }
    }
}

class Resize extends ManagedFilter {
    float scale;

    Resize(float scale) {
        this.scale = scale;
    }

    int width(PImage image) {
        // Hack, always shrinks image by 1px even at s=1.0
        return ceil(image.width * scale) - 1;
    }
    int height(PImage image) {
        return ceil(image.height * scale) - 1;
    }

    void runWithStore(PImage image, PImage result) {
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
    }
}

class Gaussian extends ManagedFilter {
    float[] kernel;

    Gaussian(float sigma) {
        // Thanks patrickfuller.github.io/gaussian-blur-image-processing-for-scientists-and-engineers-part-4/
        kernel = new float[ceil(sigma) * 6 + 1];
        float sum = 0;

        for(int i = 0; i < kernel.length; i++) {
            float x = i - (kernel.length-1)/2;
            float g = exp(-(x*x) / (2*sigma*sigma));
            sum += g;
            kernel[i] = g;
        }
        for(int i = 0; i < kernel.length; i++) {
            kernel[i] /= sum;
        }
    }

    int height(PImage image) {
        return image.height - kernel.length + 1;
    };

    int width(PImage image) {
        return image.width - kernel.length + 1;
    };

    void runWithStore(PImage input, PImage store) {
        int[] convoluted = new int[store.width * input.height];
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
    }
}

class Edges extends Filter {
    int height(PImage image) {
        return image.height - 2;
    };

    int width(PImage image) {
        return image.width - 2;
    };

    // void runWithStore(PImage image, PImage result) {
    PImage run(PImage image) {
        PGraphics result = createGraphics(image.width - 2, image.height - 2);
        result.beginDraw();
        float[][] gradient = new float[2][height(image) * width(image)];
        float[] mag = new float[height(image) * width(image)];

        // We could separate this but we don't bother
        for (int y = 1; y < image.height - 1; y++) {
            for (int x = 1; x < image.width - 1; x++) {
                int ix = y*image.width + x;
                int t00 = image.pixels[ix - image.width - 1];
                int t10 = image.pixels[ix - image.width];
                int t20 = image.pixels[ix - image.width + 1];
                int t01 = image.pixels[ix - 1];
                int t21 = image.pixels[ix + 1];
                int t02 = image.pixels[ix + image.width - 1];
                int t12 = image.pixels[ix + image.width];
                int t22 = image.pixels[ix + image.width + 1];

                float dy = (t00 + 2*t01 + t02 - t20 - 2*t21 - t22) / 4.0;
                float dx = (t00 + 2*t10 + t20 - t02 - 2*t12 - t22) / 4.0;

                int gix = (y - 1)*result.width + x - 1;
                gradient[0][gix] = dy;
                gradient[1][gix] = dx;
                mag[gix] = sqrt(dy*dy + dx*dx);
            }
        }

        final color[] COLORS = {#ff0000, #00ff00, #0000ff, #ffffff};
        final int[][] DIRS = {{0, 1}, {-1, 1}, {1, 0}, {1, 1}};
        int mn = 255, mx = 0;
        for (int y = 1; y < result.height - 1; y++) {
            for (int x = 1; x < result.width - 1; x++) {
                int ix = y*result.width + x;
                float t00 = mag[ix - result.width - 1];
                float t10 = mag[ix - result.width];
                float t20 = mag[ix - result.width + 1];
                float t01 = mag[ix - 1];
                float t11 = mag[ix];
                float t21 = mag[ix + 1];
                float t02 = mag[ix + result.width - 1];
                float t12 = mag[ix + result.width];
                float t22 = mag[ix + result.width + 1];

                float t = atan2(gradient[0][ix], gradient[1][ix]);
                int dir = (int)(((t + PI / 8) / PI * 4) + 4) % 4;
                if ((dir == 2 && t01 < t11 && t11 > t21) ||
                    (dir == 3 && t02 < t11 && t11 > t20) ||
                    (dir == 0 && t10 < t11 && t11 > t12) ||
                    (dir == 1 && t00 < t11 && t11 > t22)) {

                    if (mag[ix] > 6 && x > 6 && x < result.width - 6 && y > 6 && y < result.height - 6) {
                        result.stroke(COLORS[dir]);
                        result.line(x, y, x + gradient[0][ix], y + gradient[1][ix]);
                    }
                    // if (mag[ix] > 1) {
                    //     vectors.stroke(255);
                    //     vectors.point(x, y);
                    // }
                        // result.pixels[ix] = mag[ix] > 6 ? COLORS[dir] : 0;
                        // result.pixels[ix] = COLORS[dir];
                }
                mn = min(mn, (int)mag[ix]);
                mx = max(mx, (int)mag[ix]);
            }
        }
        // float d = mx - mn;
        // for (int i = 0; i < result.pixels.length; i++) {
        //     result.pixels[i] = (int)((result.pixels[i] & 0xff) * 3.5);
        // }
        result.endDraw();
        return result;
    }
}

class Histogram extends Filter {
    int height;

    Histogram(int height) {
        this.height = height;
    }

    PImage run(PImage image) {
        image.loadPixels();

        int[][] bins = new int[3][256];
        for (int i = 0; i < image.pixels.length; i++) {
            color c = image.pixels[i];
            bins[0][c & 0xff]++;
            bins[1][(c >> 8) & 0xff]++;
            bins[2][(c >> 16) & 0xff]++;
        }

        int mb = 0;
        for (int i = 1; i < 255; i++) {
            for (int c = 0; c < 3; c++) {
                if (bins[c][i] > mb) mb = bins[c][i];
            }
        }

        PGraphics result = createGraphics(254, height);
        result.beginDraw();
        color[] colors = {#0000ff, #00ff00, #ff0000};
        // histogram_max skips #000, so this might happen
        if (mb == 0) return result.get();
        for (int c = 0; c < 3; c++) {
            result.beginShape();
            result.stroke(colors[c]);
            result.fill(colors[c], 128);
            result.strokeWeight(1);
            for (int i = 1; i < 255; i++) {
                // Plus 1 important on high density displays
                result.vertex(i - 1, height + 1 - height * min(mb, bins[c][i]) / mb);
            }
            result.vertex(253, height + 2);
            result.vertex(0, height + 2);
            result.endShape();
        }

        result.endDraw();
        return result.get();
    }
}
