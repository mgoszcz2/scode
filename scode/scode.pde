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

final int SIZE = 300;
final int GRID_WIDTH = 2;
final int GRID_HEIGHT = 2;
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

void drawGrid(String desc, Image img) {
    assert gridPosition < GRID_WIDTH * GRID_HEIGHT;
    float took = millis() - lastOperation;
    mean[gridPosition] = mean[gridPosition] * (sampleCount - 1) / sampleCount + took / sampleCount;

    int w = width / GRID_WIDTH;
    int h = height / GRID_HEIGHT;

    pushMatrix();
    translate(w * (gridPosition % GRID_WIDTH), h * (gridPosition / GRID_WIDTH));
    noStroke();

    if (showHeaders) {
        image(img.get(), 0, GRID_HEADER, w, h - GRID_HEADER);
        PImage hist = histogram(img, GRID_HEADER / 2 - 1);
        if (hist != null) {
            image(hist, 0, 0, w, GRID_HEADER / 2);
        }
        fill(255);
        textSize(GRID_HEADER / 4);
        textAlign(LEFT, BOTTOM);
        text(desc, 5, GRID_HEADER);
        textAlign(RIGHT, BOTTOM);
        textSize(GRID_HEADER / 10);
        text(String.format("%dx%d  %.0f/%.0f ms", img.width, img.height, took, mean[gridPosition]), w - 5, GRID_HEADER);
    } else {
        image(img.get(), 0, 0, w, h);
    }

    popMatrix();
    lastOperation = millis();
    gridPosition++;
}

void setup() {
    size(0, 0);
    // pixelDensity(displayDensity());
    noSmooth();
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

    Image image = grayscale(new Image(frameImage));
    image = resize(image, 0.3);
    Image blurred = gaussian(image, 2.0);
    clear();
    drawGrid("Processed", image);
    // drawGrid("Binarized", binarize(image, blurred));
    Image edges = spokes(edges(blurred));
    Image edgesInverted = spokes(edges(invert(blurred)));
    drawGrid("Edges", edges);
    drawGrid("Edges (inverted)", edgesInverted);
    // drawGrid("Edge", edges);
    drawGrid("Spoke combined", hackySqrt(image, edges, edgesInverted));

    while (gridPosition < GRID_WIDTH * GRID_HEIGHT) {
        int w = width / GRID_WIDTH;
        int h = height / GRID_HEIGHT;
        textAlign(CENTER, CENTER);
        text("No image", w * (0.5 + gridPosition % GRID_WIDTH), h * (0.5 + gridPosition / GRID_WIDTH));
        gridPosition++;
    }
    if (staticImage) noLoop();
}
