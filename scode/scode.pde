import processing.video.*;

PImage staticImage;
Capture camera;
boolean frameResized;
int gridPosition;
final int GOAL_SIZE = 250;
final int GRID_WIDTH = 3;
final int GRID_HEIGHT = 2;
final int GRID_HEADER = 30;

void resize(int width, int height) {
    int ratio = (height + GRID_HEADER) / GOAL_SIZE;
    surface.setSize(width / ratio * GRID_WIDTH, (GRID_HEADER + height / ratio) * GRID_HEIGHT);
    frameResized = true;
}

PImage drawGrid(String desc, PImage img) {
    assert gridPosition < GRID_WIDTH * GRID_HEIGHT;
    int w = width / GRID_WIDTH;
    int h = height / GRID_HEIGHT;
    int x = w * (gridPosition % GRID_WIDTH);
    int y = h * (gridPosition / GRID_WIDTH);
    gridPosition++;
    image(img, x, y + GRID_HEADER, w, h - GRID_HEADER);
    textAlign(LEFT, TOP);

    strokeWeight(0);
    stroke(0); // Necessery even with weight 0 for some reason (otherwise weird red lines happen)
    fill(0);
    rect(x, y, w, GRID_HEADER);
    strokeWeight(1);
    stroke(255);
    rect(x + w - 256, y, 256 - 1, GRID_HEADER - 1);
    image(histogram(img, GRID_HEADER - 2), x + w - 256, y + 1);

    fill(255);
    textSize(16);
    text(desc, x + 10, y + 10);
    return img;
}

void setup() {
    size(0, 0);
    // frameRate(10);
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

    // frameImage = drawGrid("Greyscale", greyscale(frameImage));
    // frameImage = drawGrid("Downscale", downscale_nearest(frameImage, 4));
    // frameImage = downscale_nearest(frameImage, 4);
    frameImage = drawGrid("Binarize", binarize(frameImage, 5));
    frameImage = drawGrid("Resized", bw_resize(frameImage, 0.40));
    frameImage = drawGrid("Median blur", median(frameImage, 2));
    frameImage = drawGrid("Sobel operator", edge(frameImage));
    // frameImage = drawGrid("Median blur", median(frameImage, 2));
    // frameImage = drawGrid("Equalize",  equalize(frameImage));
    // frameImage = drawGrid("Treshold", treshold(frameImage, 50));
    println("Looping");
    if (staticImage != null) noLoop();
}
