import processing.video.*;

PImage staticImage;
Capture camera;
boolean frameResized;
int gridPosition;
int lastOperation = 0;
boolean looping = true;
int sampleCount = 0;

final int GOAL_SIZE = 240;
final int GRID_WIDTH = 4;
final int GRID_HEIGHT = 2;
final int GRID_HEADER = 60;
float[] mean = new float[GRID_WIDTH * GRID_HEIGHT];

void resize(int width, int height) {
    int ratio = (height + GRID_HEADER) / GOAL_SIZE;
    surface.setSize(width / ratio * GRID_WIDTH, (GRID_HEADER + height / ratio) * GRID_HEIGHT);
    frameResized = true;
}

void keyPressed() {
    if (key == ' ' && staticImage == null) {
        looping = !looping;
        if (looping) {
            camera.start();
            loop();
        } else {
            camera.stop();
            noLoop();
        }
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

    image(img, 0, GRID_HEADER, w, h - GRID_HEADER);
    image(histogram(img, GRID_HEADER / 2 - 1), 0, 0, w, GRID_HEADER / 2);

    fill(255);
    textSize(GRID_HEADER / 4);
    textAlign(LEFT, CENTER);
    text(desc, 10, 3 * GRID_HEADER / 4 - 1);
    textAlign(RIGHT, CENTER);
    text(String.format("%.0f/%.0f ms", took, mean[gridPosition]), w - 10, 3 * GRID_HEADER / 4 - 1);

    lastOperation = millis();
    popMatrix();
    gridPosition++;
    return img;
}

void setup() {
    size(0, 0);
    frameRate(10);
    surface.setTitle("S*Code");
    if (args != null && args.length > 0) {
        staticImage = loadImage(args[0]);
        resize(staticImage.width, staticImage.height);
    } else {
        String[] cameras = Capture.list();
        camera = new Capture(this, cameras[0]);
        camera.start();
    }
}

void draw() {
    gridPosition = 0;
    clear();

    PImage frameImage;
    if (staticImage != null) {
        frameImage = staticImage;
    } else if (camera.available()) {
        camera.read();
        if (!frameResized) {
            resize(camera.width, camera.height);
            // We must skip the frame to fix up or pixels array
            return;
        }
        frameImage = camera;
    } else return;

    sampleCount++;
    lastOperation = millis();
    drawGrid("Original", frameImage);
    frameImage = drawGrid("Greyscale", greyscale(frameImage));
    frameImage = drawGrid("Resized", resize(frameImage, 0.40));
    frameImage = drawGrid("Blur", gaussian(frameImage, 1.0));

    PImage maskImage = drawGrid("Edge mask", edges(frameImage));
    maskImage = drawGrid("Binarize mask", binarize(maskImage, 3));

    frameImage = drawGrid("Sobel operator", sobel(frameImage));
    drawGrid("Masked", mask(frameImage, maskImage));
    // if (staticImage != null) noLoop();
}
