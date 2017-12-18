import processing.video.*;

Capture camera;
boolean frameResized;
PImage frameImage;
boolean staticImage = false;
boolean looping = true;
DebugData debugData = new DebugData(300, 2, 2);

void resize() {
    debugData.resize();
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
        debugData.showHeaders = !debugData.showHeaders;
        resize();
    }
}

void setup() {
    size(0, 0);
    pixelDensity(displayDensity());
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

    DebugData.Drawer drawer = debugData.new Drawer(this);
    drawer.begin();

    Image orignal = new Image(frameImage);
    drawer.draw("Original", orignal);
    orignal.grayscale();
    Image resized = gaussian(orignal, 1.0);
    drawer.draw("Processed", resized);
    Image blurred = mean(resized, (int)(resized.width * 0.04));
    Image binary = binarize(resized, blurred, 0.8);
    drawer.draw("Binarized", binary);
    DecoderData decoded = decodeCode(resized, binary);
    drawer.draw("Outline", vibrantBlur(new Image(frameImage), debugData.windowWidth(), debugData.windowHeight()));

    drawer.end();
    if (staticImage) noLoop();
}
