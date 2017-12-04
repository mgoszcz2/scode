import processing.video.*;

Capture camera;
boolean frameResized;
PImage frameImage;
int gridPosition;
int lastOperation = 0;
boolean staticImage = false;
boolean looping = true;
int sampleCount = 0;
boolean showHeaders = true;

final int SIZE = 200;
final int GRID_WIDTH = 4;
final int GRID_HEIGHT = 3;
final int GRID_HEADER = 60;
float[] mean = new float[GRID_WIDTH * GRID_HEIGHT];

void resize() {
    int w = (int)(frameImage.width * ((float)SIZE / frameImage.height) * GRID_WIDTH);
    int h = showHeaders ? (GRID_HEADER + SIZE) * GRID_HEIGHT : SIZE * GRID_HEIGHT;
    surface.setSize(w, h);
    frameResized = true;
}

void keyPressed() {
    if (key == ' ') {
        if (staticImage) {
            redraw();
            return;
        }

        looping = !looping;
        if (looping) {
            camera.start();
            loop();
        } else {
            camera.stop();
            noLoop();
        }

    } else if (key == 19) { // C-s
        showHeaders = !showHeaders;
        resize();
    }
}

PImage drawGrid(String desc, PImage img) {
    assert gridPosition < GRID_WIDTH * GRID_HEIGHT;
    float took = millis() - lastOperation;
    mean[gridPosition] = mean[gridPosition] * (sampleCount - 1) / sampleCount + took / sampleCount;

    int w = width / GRID_WIDTH;
    int h = height / GRID_HEIGHT;

    pushMatrix();
    translate(w * (gridPosition % GRID_WIDTH), h * (gridPosition / GRID_WIDTH));
    noStroke();

    if (showHeaders) {
        image(img, 0, GRID_HEADER, w, h - GRID_HEADER);
        image(new Histogram(GRID_HEADER / 2 - 1).run(img), 0, 0, w, GRID_HEADER / 2);
        fill(255);
        textSize(GRID_HEADER / 4);
        textAlign(LEFT, BOTTOM);
        text(desc, 5, GRID_HEADER);
        textAlign(RIGHT, BOTTOM);
        textSize(GRID_HEADER / 10);
        text(String.format("%dx%d  %.0f/%.0f ms", img.width, img.height, took, mean[gridPosition]), w - 5, GRID_HEADER);
    } else {
        image(img, 0, 0, w, h);
    }

    popMatrix();
    lastOperation = millis();
    gridPosition++;
    return img;
}

void setup() {
    size(0, 0);
    pixelDensity(displayDensity());
    surface.setTitle("S*Code");
    if (args != null && args.length > 0) {
        staticImage = true;
        frameImage = loadImage(args[0]);
        resize();
    } else {
        String[] cameras = Capture.list();
        camera = new Capture(this, cameras[0]);
        camera.start();
    }
}

void draw() {
    gridPosition = 0;
    clear();

    if (!staticImage) {
        if (!camera.available()) return;
        camera.read();
        frameImage = camera;
        if (!frameResized) {
            resize();
            // We must skip the frame to fix up or pixels array
            return;
        }
        frameImage = camera;
    }

    sampleCount++;
    lastOperation = millis();

    PImage image = new Resize(0.2).run(frameImage);

    drawGrid("Original", image);
    image = drawGrid("Greyscale", new Greyscale().run(image));
    image = drawGrid("Blur", new Gaussian(2.0).run(image));
    drawGrid("Binarize", new Binarize().run(image));
    PImage edges = drawGrid("Edges", new Edges().run(image));
    drawGrid("Edges -> Binarize", new Binarize().run(edges));

    while (gridPosition < GRID_WIDTH * GRID_HEIGHT) {
        int w = width / GRID_WIDTH;
        int h = height / GRID_HEIGHT;
        textAlign(CENTER, CENTER);
        text("No image", w * (0.5 + gridPosition % GRID_WIDTH), h * (0.5 + gridPosition / GRID_WIDTH));
        gridPosition++;
    }
    if (staticImage) noLoop();
}
