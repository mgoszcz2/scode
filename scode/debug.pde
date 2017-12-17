class DebugData {
    static private final int SIZE = 300;
    static private final int GRID_WIDTH = 2;
    static private final int GRID_HEIGHT = 2;
    static private final int GRID_HEADER = 60;

    private int gridPosition;
    private int lastOperation;

    private float[] mean = new float[GRID_WIDTH * GRID_HEIGHT];
    private int sampleCount;

    boolean showHeaders = true;

    void resize() {
        int w = (int)(frameImage.width * ((float)SIZE / frameImage.height) * GRID_WIDTH);
        int h = debugData.showHeaders ? (GRID_HEADER + SIZE) * GRID_HEIGHT : SIZE * GRID_HEIGHT;
        surface.setSize(w, h);
    }

    class Drawer {
        private int lastOperation;
        private int gridPosition;
        private PApplet applet;

        Drawer(PApplet applet) {
            this.applet = applet;
        }

        void begin() {
            clear();
            sampleCount++;
            lastOperation = millis();
        }

        Image draw(String desc, Image img) {
            assert gridPosition < GRID_WIDTH * GRID_HEIGHT;
            float took = millis() - lastOperation;
            mean[gridPosition] = mean[gridPosition] * (sampleCount - 1) / sampleCount + took / sampleCount;

            int w = width / GRID_WIDTH;
            int h = height / GRID_HEIGHT;

            pushMatrix();
            translate(w * (gridPosition % GRID_WIDTH), h * (gridPosition / GRID_WIDTH));
            noStroke();

            if (showHeaders) {
                image(img.get(applet), 0, GRID_HEADER, w, h - GRID_HEADER);
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
                image(img.get(applet), 0, 0, w, h);
            }

            popMatrix();
            lastOperation = millis();
            gridPosition++;
            return img;
        }

        void end() {
            while (gridPosition < GRID_WIDTH * GRID_HEIGHT) {
                int w = width / GRID_WIDTH;
                int h = height / GRID_HEIGHT;
                textAlign(CENTER, CENTER);
                text("No image", w * (0.5 + gridPosition % GRID_WIDTH), h * (0.5 + gridPosition / GRID_WIDTH));
                gridPosition++;
            }
        }
    }
}
