// Based on Adaptive Thresholding Using the Integral Image
class Binarize extends ManagedFilter {
    void runWithStore(PImage image, PImage result) {
        // 12 just works well
        int k = min(image.width, image.height) / 12;
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

                int avg = (t0 - t1 - t2 + t3) * 90 / 100;
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
    float[][] kernel;

    Gaussian(float sigma) {
        // Thanks https://patrickfuller.github.io/gaussian-blur-image-processing-for-scientists-and-engineers-part-4/
        kernel = new float[10][10];
        int uc, vc;
        float g, sum = 0;

        int t = millis();
        for(int u=0; u<kernel.length; u++) {
            for(int v=0; v<kernel[0].length; v++) {
                // Center the Gaussian sample so max is at u,v = 10,10
                uc = u - (kernel.length-1)/2;
                vc = v - (kernel[0].length-1)/2;
                // Calculate and save
                g = exp(-(uc*uc+vc*vc)/(2*sigma*sigma));
                sum += g;
                kernel[u][v] = g;
            }
        }
        // Normalize it
        for(int u=0; u<kernel.length; u++) {
            for(int v=0; v<kernel[0].length; v++) {
                kernel[u][v] /= sum;
            }
        }
    }

    int width(PImage image) {
        return image.width - kernel[0].length;
    };
    int height(PImage image) {
        return image.height - kernel.length;
    };

    void runWithStore(PImage image, PImage result) {
        int w = kernel[0].length / 2;
        int h = kernel.length / 2;
        for (int y = h; y < image.height - h; y++) {
            for (int x = w; x < image.width - w; x++) {
                float sum = 0;
                for (int ky = 0; ky < kernel.length; ky++) {
                    for (int kx = 0; kx < kernel[0].length; kx++) {
                        sum += (image.pixels[(y - h + ky) * image.width + x - w + kx] & 0xff) * kernel[ky][kx];
                    }
                }
                result.pixels[(y - h) * result.width + x - w] = (int)sum;
            }
        }
    }
}

class Edges extends ManagedFilter {
    void runWithStore(PImage image, PImage result) {
        int mn = Integer.MAX_VALUE, mx = Integer.MIN_VALUE;

        for (int y = 1; y < image.height - 1; y++) {
            for (int x = 1; x < image.width - 1; x++) {
                int ix = y * image.width + x;
                int t00 = image.pixels[ix - image.width - 1];
                int t10 = image.pixels[ix - image.width];
                int t20 = image.pixels[ix - image.width + 1];
                int t01 = image.pixels[ix - 1];
                int t21 = image.pixels[ix + 1];
                int t02 = image.pixels[ix + image.width - 1];
                int t12 = image.pixels[ix + image.width];
                int t22 = image.pixels[ix + image.width + 1];

                int dy = (t00 + 2*t01 + t02 - t20 - 2*t21 - t22) / 4;
                int dx = (t00 + 2*t10 + t20 - t02 - 2*t12 - t22) / 4;
                int v = (int)sqrt(dy * dy + dx * dx);
                result.pixels[ix] = v;
                mn = min(mn, v);
                mx = max(mx, v);
            }
        }

        float d = mx - mn;
        for (int i = 0; i < image.pixels.length; i++) {
            result.pixels[i] = (int)(0xff * ((result.pixels[i] - mn) / d));
        }
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
