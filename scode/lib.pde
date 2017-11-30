import java.util.*;

PImage makeImage(int width, int height) {
    PImage result = createImage(width, height, RGB);
    result.loadPixels();
    return result;
}

PImage makeImage(PImage template) {
    return makeImage(template.width, template.height);
}

PImage binarize(PImage image, int k) {
    //TODO: Use integer image here
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
            int avg = (int)(total / (nbhd * nbhd) + 10) & 0xff;
            int bw = image.pixels[y * image.width + x] & 0xff;
            result.pixels[y * result.width + x] = bw > avg ? 255 : 0;
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
        result.pixels[i] = ((c & 0xff) + ((c >> 8) & 0xff) + ((c >> 16) & 0xff)) / 3;
    }
    result.updatePixels();
    return result;
}

PImage resize(PImage image, float scale) {
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
            result.pixels[y * result.width + x] = gray;
        }
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
            result.pixels[(y - h) * result.width + x - w] = (int)sum;
        }
    }
    result.updatePixels();
    return result;
}

PImage gaussian(PImage image, float sigma) {
    // Thanks https://patrickfuller.github.io/gaussian-blur-image-processing-for-scientists-and-engineers-part-4/
    float[][] kernel = new float[10][10];
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

    return convolute(image, kernel);
}

void normalize(PImage image) {
    int mn = image.pixels[0], mx = mn;
    for (int i = 1; i < image.pixels.length; i++) {
        mn = min(mn, image.pixels[i]);
        mx = max(mx, image.pixels[i]);
    }
    float d = mx - mn;
    for (int i = 0; i < image.pixels.length; i++) {
        image.pixels[i] = (int)(0xff * ((image.pixels[i] - mn) / d));
    }
    image.updatePixels();
}

void absolute(PImage image) {
    for (int i = 0; i < image.pixels.length; i++) {
        image.pixels[i] = Math.abs(image.pixels[i]);
    }
    image.updatePixels();
}

//FIXME Just copy of paste of sobel
PImage edges(PImage image) {
    float[][] xkernel = {{1, 0, -1},
                         {2, 0, -2},
                         {1, 0, -1}};
    float[][] ykernel = {{1, 2, 1},
                         {0, 0, 0},
                         {-1, -2, -1}};
    PImage ix = convolute(image, xkernel);
    PImage iy = convolute(image, ykernel);
    absolute(ix);
    absolute(iy);
    normalize(ix);
    normalize(iy);
    for (int i = 0; i < ix.pixels.length; i++) {
        int x = ix.pixels[i];
        int y = iy.pixels[i];
        ix.pixels[i] = (int)Math.sqrt(x * x + y * y);
    }
    return ix;
}

PImage sobel(PImage image) {
    float[][] xkernel = {{1, 0, -1},
                         {2, 0, -2},
                         {1, 0, -1}};
    float[][] ykernel = {{1, 2, 1},
                         {0, 0, 0},
                         {-1, -2, -1}};
    PImage ix = convolute(image, xkernel);
    PImage iy = convolute(image, ykernel);
    normalize(ix);
    normalize(iy);
    for (int i = 0; i < ix.pixels.length; i++) {
        int x = ix.pixels[i];
        int y = iy.pixels[i];
        ix.pixels[i] = (x << 16) | (y << 8) | 0xff;
    }
    return ix;
}

PImage mask(PImage image, PImage mask) {
    PImage result = makeImage(min(image.width, mask.width), min(image.height, mask.height));
    mask.loadPixels();
    image.loadPixels();
    for (int y = 0; y < result.height; y++) {
        for (int x = 0; x < result.width; x++) {
            result.pixels[y*result.width + x] = (mask.pixels[y*mask.width + x] & 0xff) > 0 ? image.pixels[y*image.width + x] : 0;
        }
    }
    result.updatePixels();
    return result;
}

PImage histogram(PImage image, int h) {
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

    PGraphics result = createGraphics(254, h);
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
            result.vertex(i - 1, h - h * min(mb, bins[c][i]) / mb);
        }
        result.vertex(253, h);
        result.vertex(0, h);
        result.endShape();
    }

    result.endDraw();
    return result.get();
}
