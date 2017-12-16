String typed = "To be, or not to be";
byte[] typedUtf8 = {};
final int TEXT_SIZE = 10;
final int MARGIN = 15;
final int TIMING_RADIUS = 8;
final color[] COLORS = {#ff3b30, #ff9500, #ffcc00, #4cd964, #5ac8fa, #007aff, #5856d6, #ff2d55};
final int lfsrTap = 0x7ae;
boolean simpleMode = false;
boolean showGrid = false;
boolean showColors = true;

int rowCount() {
    // 2 headers plus even number for data
    return 2 + (typedUtf8.length + 1) & ~1;
}

void resize() {
    try {
        typedUtf8 = typed.getBytes("UTF-8");
    } catch (Exception e) {};
    int w = MARGIN*2 + TIMING_RADIUS*29;
    int h = TEXT_SIZE + MARGIN*3 + rowCount()*TIMING_RADIUS*2 + TIMING_RADIUS*9;
    surface.setSize(w, h);
}

void setup() {
    size(200, 200);
    pixelDensity(displayDensity());
    surface.setTitle("S*Code generator");
    resize();
    noLoop();
}

String fileName() {
    String tmp = typed.toLowerCase();
    String result = "";
    for (int i = 0; i < tmp.length(); i++) {
        char c = tmp.charAt(i);
        if ((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9')) result += c;
    }
    return result + ".png";
}

void keyPressed() {
    if (key == RETURN) {
        typed = "";
    } else if (key == BACKSPACE) {
        if (typed.length() > 0) typed = typed.substring(0, typed.length() - 1);
    } else if (key != CODED) {
        if (key == 7) showGrid = !showGrid; // C-c
        else if (key == 19) simpleMode = !simpleMode; // C-s
        else if (key == 5) save(fileName()); // C-e
        else if (key == 3) showColors = !showColors; // C-c
        else typed += key;
    }
    resize();
    redraw();
}

void finderDot(int x, int y) {
    // ####    #####    ####
    // 1.2  0.8  1  0.8  1.2
    //         <-1->
    //     <--- 1.8 --->
    // <-------- 3 -------->
    // Since first bar ratios: {1.0, 0.666.., 0.833.., 0.666.., 1.0}
    float r0 = TIMING_RADIUS * 3;
    float r1 = TIMING_RADIUS * 1.8;
    float r2 = TIMING_RADIUS * 1;
    fill(0);
    ellipse(x, y, r0, r0);
    fill(255);
    ellipse(x, y, r1, r1);
    fill(0);
    ellipse(x, y, r2, r2);
}

int evenParity(int x) {
    x ^= x >> 4;
    x ^= x >> 2;
    x ^= x >> 1;
    return (~x) & 1;
}

int lfsr = 0;
void drawChar(boolean mask, byte t, int i) {
    if (i == 0) lfsr = 1;
    int val = t | (evenParity(t) << 8);
    if (mask && !simpleMode) val ^= lfsr;
    for (int j = 0; j < 9; j++) {
        if ((val & (1 << (8 - j))) == 0) continue;
        int x = TIMING_RADIUS*6 + j*TIMING_RADIUS*2;
        int y = TIMING_RADIUS*6 + i*TIMING_RADIUS*2;
        if (showColors) fill(COLORS[(lfsr + j) % COLORS.length]);
        ellipse(x, y, TIMING_RADIUS - 1, TIMING_RADIUS - 1);
    }
    textAlign(RIGHT, CENTER);
    boolean lb = (lfsr & 1) == 1;
    lfsr >>= 1;
    if (lb) lfsr ^= lfsrTap;
}

void draw() {
    int len = rowCount();
    background(255);
    noStroke();
    ellipseMode(RADIUS);

    translate(0, MARGIN);
    fill(0);
    textAlign(CENTER, TOP);
    textSize(TEXT_SIZE);

    text(typed, width / 2, 0);
    translate(MARGIN, MARGIN + TEXT_SIZE);

    finderDot(TIMING_RADIUS*2, TIMING_RADIUS*(6+2*len));
    finderDot(TIMING_RADIUS*26, TIMING_RADIUS*2);
    finderDot(TIMING_RADIUS*2, TIMING_RADIUS*2);
    finderDot(TIMING_RADIUS*26, TIMING_RADIUS*(6+2*len));

    fill(0);
    for (int i = 0; i < 4; i++) {
        ellipse(TIMING_RADIUS*8 + i*TIMING_RADIUS*4, TIMING_RADIUS*2, TIMING_RADIUS, TIMING_RADIUS);
    }
    for (int i = 0; i < (len - 1) / 2; i++) {
        ellipse(TIMING_RADIUS*2, TIMING_RADIUS*8 + i*TIMING_RADIUS*4, TIMING_RADIUS, TIMING_RADIUS);
    }
    for (int i = 0; i < (len - 1) / 2; i++) {
        ellipse(TIMING_RADIUS*26, TIMING_RADIUS*8 + i*TIMING_RADIUS*4, TIMING_RADIUS, TIMING_RADIUS);
    }

    int row;
    for (row = 0; row < typedUtf8.length; row++) {
        drawChar(true, typedUtf8[row], row);
    }
    if ((row & 1) > 0) {
        drawChar(true, (byte)0, row++);
    }
    drawChar(false, (byte)1, row++);

    textAlign(CENTER, CENTER);
    textSize(TIMING_RADIUS*2);
    fill(0);
    text("Scan me!", TIMING_RADIUS*14, TIMING_RADIUS*(6+len*2));
    if (showGrid) {
        strokeWeight(0.5);
        stroke(#cccccc);
        for (int i = 0; i < 29; i++) {
            line(i * TIMING_RADIUS, 0, i * TIMING_RADIUS, TIMING_RADIUS*(8+len*2));
        }
        for (int i = 0; i < 9+len*2; i++) {
            line(0, i * TIMING_RADIUS, TIMING_RADIUS*28, i * TIMING_RADIUS);
        }
    }
}
