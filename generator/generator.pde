String typed = "🍕";
byte[] typedUtf8 = {};
final int TEXT_SIZE = 10;
final int MARGIN = 20;
final int TIMING_RADIUS = 8;
final color[] COLORS = {#ff3b30, #ff9500, #ffcc00, #4cd964, #5ac8fa, #007aff, #5856d6, #ff2d55};
boolean simpleMode = false;
boolean showGrid = false;
boolean showColors = false;

void resize() {
    try {
        typedUtf8 = typed.getBytes("UTF-8");
    } catch (Exception e) {};
    int len = (typedUtf8.length + 1) & ~1;
    int w = MARGIN*2 + TIMING_RADIUS*21;
    int h = TEXT_SIZE + MARGIN*3 + len*TIMING_RADIUS*2 + TIMING_RADIUS*5;
    surface.setSize(w, h);
}

void setup() {
    size(200, 200);
    pixelDensity(displayDensity());
    surface.setTitle("S*Code generator");
    resize();
    noLoop();
}

void keyPressed() {
    if (key == RETURN) {
        typed = "";
    } else if (key == BACKSPACE) {
        if (typed.length() > 0) typed = typed.substring(0, typed.length() - 1);
    } else if (key != CODED) {
        if (key == 7) showGrid = !showGrid; // C-c
        else if (key == 19) simpleMode = !simpleMode; // C-s
        else if (key == 3) showColors = !showColors; // C-c
        else typed += key;
    }
    resize();
    redraw();
}

void finderDot(int x, int y) {
    float r0 = TIMING_RADIUS * 1.50;
    float r1 = TIMING_RADIUS * 0.60;
    fill(0);
    ellipse(x, y, r0, r0);
    fill(255);
    ellipse(x, y, r1, r1);
}

void finderDotMain(int x, int y) {
    float r0 = TIMING_RADIUS * 2.80;
    float r1 = TIMING_RADIUS * 1.70;
    float r2 = TIMING_RADIUS * 1.00;
    fill(0);
    ellipse(x, y, r0, r0);
    fill(255);
    ellipse(x, y, r1, r1);
    fill(0);
    ellipse(x, y, r2, r2);
}

int lfsr = 0;
void drawChar(byte t, int i) {
    if (i == 0) lfsr = 1;
    if (!simpleMode) t ^= lfsr;
    for (int j = 0; j < 8; j++) {
        if ((t & (1 << (7 - j))) == 0) continue;
        int x = TIMING_RADIUS*5 + j*TIMING_RADIUS*2;
        int y = TIMING_RADIUS*5 + i*TIMING_RADIUS*2;
        if (showColors) fill(COLORS[(lfsr + j) % COLORS.length]);
        ellipse(x, y, TIMING_RADIUS - 1, TIMING_RADIUS - 1);
    }
    boolean lb = (lfsr & 1) == 1;
    lfsr >>= 1;
    if (lb) lfsr ^= 0x574a86f5;
}

void draw() {
    int len = (typedUtf8.length + 1) & ~1;
    background(255);
    noStroke();
    ellipseMode(RADIUS);

    if (typedUtf8.length == 0) return;

    translate(0, MARGIN);
    fill(0);
    textAlign(CENTER, TOP);
    textSize(TEXT_SIZE);
    text(typed, width / 2, 0);
    translate(MARGIN, MARGIN + TEXT_SIZE);

    finderDot(TIMING_RADIUS*2, TIMING_RADIUS*(3+2*len));
    finderDot(TIMING_RADIUS*19, TIMING_RADIUS*2);
    finderDotMain(TIMING_RADIUS*2, TIMING_RADIUS*2);

    fill(0);
    for (int i = 0; i < 3; i++) {
        ellipse(TIMING_RADIUS*7 + i*TIMING_RADIUS*4, TIMING_RADIUS*2, TIMING_RADIUS, TIMING_RADIUS);
    }
    for (int i = 0; i < (len - 1) / 2; i++) {
        ellipse(TIMING_RADIUS*2, TIMING_RADIUS*7 + i*TIMING_RADIUS*4, TIMING_RADIUS, TIMING_RADIUS);
    }

    for (int i = 0; i < typedUtf8.length; i++) {
        drawChar(typedUtf8[i], i);
    }
    if ((typedUtf8.length & 1) > 0) {
        drawChar((byte)0, typedUtf8.length);
    }

    if (showGrid) {
        strokeWeight(0.5);
        stroke(#cccccc);
        for (int i = 0; i < 21; i++) {
            line(i * TIMING_RADIUS, 0, i * TIMING_RADIUS, TIMING_RADIUS*(4+len*2));
        }
        for (int i = 0; i < 5+len*2; i++) {
            line(0, i * TIMING_RADIUS, TIMING_RADIUS*20, i * TIMING_RADIUS);
        }
    }
}
