import java.util.*;

PImage makeImage(int width, int height) {
    PImage result = createImage(width, height, ARGB);
    result.loadPixels();
    return result;
}

PImage makeImage(PImage template) {
    return makeImage(template.width, template.height);
}

color bwpixel(int val) {
    return val | val << 8 | val << 16 | 0xff << 24;
}

int channel(color col, int c) {
    return (col >> 16 - c * 8 & 0xff);
}

int[][] histogram_bins(PImage image) {
    int[][] bins = new int[3][256];
    image.loadPixels();
    for (int i = 0; i < image.pixels.length; i++) {
        for (int c = 0; c < 3; c++) bins[c][channel(image.pixels[i], c)]++;
    }
    return bins;
}

int histogram_max(int[][] bins) {
    int mb = 0;
    for (int i = 1; i < 256; i++) {
        for (int c = 0; c < 3; c++) {
            if (bins[c][i] > mb) mb = bins[c][i];
        }
    }
    return mb;
}

PImage binarize(PImage image, int k) {
    int nbhd = k*2 + 1;
    PImage result = makeImage(image.width - nbhd, image.height - nbhd);
    image.loadPixels();
    for (int y = 0; y < result.height; y++) {
        for (int x = 0; x < result.width; x++) {
            int total = 0;
            for (int ky = 0; ky <= nbhd; ky++) {
                for (int kx = 0; kx <= nbhd; kx++) {
                    total += image.pixels[(y + ky)*image.width + x + kx] & 0xff;
                }
            }
            int avg = (int)(total / (nbhd * nbhd));
            int bw = image.pixels[y * result.height + x] & 0xff;
            result.pixels[y * result.width + x] = bwpixel(bw > avg ? 0 : 255);
        }
    }
    result.updatePixels();
    return result;
}

PImage greyscale(PImage image) {
    PImage result = makeImage(image);
    image.loadPixels();
    for (int i = 0; i < image.pixels.length; i++) {
        color c = image.pixels[i];
        int v = (channel(c, 0) + channel(c, 1) + channel(c, 2)) / 3;
        result.pixels[i] = bwpixel(v);
    }
    result.updatePixels();
    return result;
}

PImage bw_resize(PImage image, float scale) {
    PImage result = makeImage(ceil(image.width * scale)-1, ceil(image.height * scale)-1);
    image.loadPixels();
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
            result.pixels[y * result.width + x] = bwpixel(gray);
        }
    }
    result.updatePixels();
    return result;
}

// Assumes b/w
PImage equalize(PImage image) {
    PImage result = makeImage(image);
    image.loadPixels();
    int[][] bins = histogram_bins(image);
    int mb = histogram_max(bins);
    float[] cumulative = new float[256];
    int greyCount = image.pixels.length - bins[0][0];

    // We keep absolute black, black and do not count in total pixels
    // which stretches the white properly
    cumulative[0] = 0;
    for (int i = 1; i < 256; i++) {
        cumulative[i] = (float)bins[0][i] / greyCount + cumulative[i - 1];
    }
    for (int i = 0; i < image.pixels.length; i++) {
        result.pixels[i] = bwpixel((int)(cumulative[image.pixels[i] & 0xff] * 255));
    }

    result.updatePixels();
    return result;
}

PImage treshold(PImage image, int val) {
    PImage result = makeImage(image);
    image.loadPixels();
    for (int i = 0; i < result.pixels.length; i++) {
        result.pixels[i] = bwpixel((image.pixels[i] & 0xff) < val ? 0 : image.pixels[i] & 0xff);
    }
    result.updatePixels();
    return result;
}

// Assumes b/w
PImage convolute(PImage image, float[][] kernel) {
    image.loadPixels();
    int w = kernel[0].length / 2;
    int h = kernel.length / 2;
    PImage result = makeImage(image.width - w * 2, image.height - h * 2);

    for (int y = h; y < image.height - h; y++) {
        for (int x = w; x < image.width - w; x++) {
            float sum = 0;
            for (int ky = 0; ky < kernel.length; ky++) {
                for (int kx = 0; kx < kernel[0].length; kx++) {
                    sum += (image.pixels[(y - h + ky) * image.width + x - w + kx] & 0xff) * kernel[ky][kx];
                }
            }
            result.pixels[(y - h) * result.width + x - w] = bwpixel((int)Math.abs(sum) & 0xff);
        }
    }
    result.updatePixels();
    return result;
}

PImage median(PImage image, int wh) {
    int w = wh * 2;
    PImage result = makeImage(image.width - w, image.height - w);
    int[] window = new int[w * w];
    image.loadPixels();

    for (int y = wh; y < image.height - wh; y++) {
        for (int x = wh; x < image.width - wh; x++) {
            int i = 0;
            for (int ky = 0; ky < w; ky++) {
                for (int kx = 0; kx < w; kx++) {
                    window[i++] = image.pixels[(y - wh + ky) * image.width + x - wh + kx] & 0xff;
                }
            }
            Arrays.sort(window);
            result.pixels[(y - wh) * result.width + x - wh] = bwpixel(window[window.length / 2]);
        }
    }
    result.updatePixels();
    return result;
}

PImage gaussian(PImage image, float sigma) {
    // Thanks https://patrickfuller.github.io/gaussian-blur-image-processing-for-scientists-and-engineers-part-4/
    float[][] kernel = new float[15][15];
    int uc, vc;
    float g, sum = 0;

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

    return convolute(image, kernel);
}

PImage edge(PImage image) {
    float[][] xkernel = {{1, 0, -1},
                         {2, 0, -2},
                         {1, 0, -1}};
    float[][] ykernel = {{1, 2, 1},
                         {0, 0, 0},
                         {-1, -2, -1}};
    PImage ix = convolute(image, xkernel);
    PImage iy = convolute(image, ykernel);
    for (int i = 0; i < ix.pixels.length; i++) {
        ix.pixels[i] = bwpixel((int)(sqrt(pow(ix.pixels[i] & 0xff, 2) + pow(iy.pixels[i] & 0xff, 2))));
    }
    return ix;
}

PImage histogram(PImage image, int h) {
    int[][] bins = histogram_bins(image);
    int mb = histogram_max(bins);
    PImage result = makeImage(256, h);
    color[] colors = {#0000ff, #00ff00, #ff0000};

    // histogram_max skips #000, so this might happen
    if (mb == 0) return result;
    for (int i = 1; i < 256; i++) {
        for (int c = 0; c < 3; c++) {
            for (int k = 0; k < h * bins[c][i] / mb; k++) {
                result.pixels[(h - k - 1) * result.width + i] |= colors[c];
            }
        }
    }

    result.updatePixels();
    return result;
}
