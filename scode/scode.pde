import processing.video.*;
import java.util.concurrent.*;

final class AnimationState {
    private final static int FADE_TIME = 500;
    // private final static int REVERSE_TIME = 900;
    private final static int REVERSE_TIME = 900;
    // final static int ANIMATION_TIME = 1250;
    final static int ANIMATION_TIME = REVERSE_TIME + 300;

    private DecoderData data;
    private int animationStart;
    private Image codeMask, capture;
    private Point textLoc;
    private boolean leftText;

    AnimationState(DecoderData data) {
        this.data = data;
        animationStart = millis();
        capture = resize(data.capture, width, height);

        Point[] mpts = new Point[4];
        for (int i = 0; i < 4; i++) {
            mpts[i] = data.corners[i].map(data.capture.width, data.capture.height, width, height);
        }
        Point mean = Point.mean(mpts);
        for (int i = 0; i < 4; i++) {
            mpts[i] = mpts[i].add(mpts[i].subtract(mean).divide(5));
        }
        Point left = Point.mean(new Point[]{mpts[0], mpts[3]});
        Point right = Point.mean(new Point[]{mpts[1], mpts[2]});

        int ynudge = height / 8;
        int xnudge = width / 10;
        if (left.x > width - right.x) {
            textLoc = new Point(left.x - xnudge, left.y - ynudge);
            leftText = true;
        } else {
            textLoc = new Point(right.x + xnudge, right.y - ynudge);
            leftText = false;
        }
        codeMask = polygon(width, height, mpts);
    }

    void draw(PApplet app, PImage currentImage) {
        int t = millis() - animationStart;
        Image input = new Image(currentImage);
        float blur = 0.0;
        float saturation = 1.0;
        boolean mask = true;
        int opacity = 255;

        if (t <= FADE_TIME) {
            float progress = t / (float)FADE_TIME;
            saturation = 1.0 + progress * 0.4;
            blur = progress*progress;
        } else if (t <= REVERSE_TIME) {
            saturation = 1.4;
            blur = 1.0;
        } else {
            float progress = 1.0 - (t - REVERSE_TIME) / (float)(ANIMATION_TIME - REVERSE_TIME);
            saturation = 1.0 + progress * 0.4;
            blur = progress;
            mask = false;
        }

        Image res = vibrantBlur(input, blur, saturation, width, height);
        if (mask) maskCombineInPlace(res, capture, codeMask);
        image(res.get(app), 0, 0, width, height);
        textAlign(leftText ? RIGHT : LEFT, CENTER);
        textSize(30);
        text(data.content, textLoc.x, textLoc.y);
    }

    boolean running() {
        return millis() - animationStart < ANIMATION_TIME;
    }
}

void resize() {
    float w = currentImage.width * (GOAL_HEIGHT / (float)currentImage.height);
    surface.setSize((int)w, GOAL_HEIGHT);
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
    }
}

Capture camera;
boolean frameResized;
PImage currentImage;
PImage debugView;
boolean staticImage = false;
boolean looping = true;
FutureTask<DecoderData> decoderResult;
final ExecutorService pool = Executors.newSingleThreadExecutor();
final int GOAL_HEIGHT = 500;
int lastDetection = millis();
AnimationState animation;


void setup() {
    PFont font = loadFont("futura.vlw");
    textFont(font, 30);
    size(0, 0);
    pixelDensity(displayDensity());
    // An issue with processing, changing pixelDensity breaks
    // textAlign function, known bug https://github.com/processing/processing/issues/4674
    // Setting textSize fixes it back
    textSize(12);
    noSmooth();
    frameRate(24);
    surface.setTitle("S*Code");
    if (args != null && args.length > 0) {
        staticImage = true;
        currentImage = loadImage(args[0]);
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
        currentImage = camera;
        if (!frameResized) {
            resize();
            // We must skip the frame to fix up or pixels array
            return;
        }
        currentImage = camera;
    }

    clear();
    stroke(255);
    if (animation != null && animation.running()) {
        animation.draw(this, currentImage);

    } else {
        if (decoderResult == null) {
            decoderResult = new FutureTask(new Pipeline(currentImage));
            pool.submit(decoderResult);
        }

        noStroke();
        image(currentImage, 0, 0, width, height);
        if (debugView != null) {
            image(debugView, 0, 0, width / 1.5, height / 1.5);
        }
        textSize(12);
        textAlign(LEFT, CENTER);
        text(round(frameRate) + " fps", 15, 15);
        if (decoderResult.isDone()) {
            try {
                DecoderData data = decoderResult.get();
                if (data.success()) {
                    animation = new AnimationState(data);
                }
                decoderResult = null;
                // if (data.debugView != null) {
                //     debugView = data.debugView.get(this);
                // }
                fill(255);
                textAlign(RIGHT, CENTER);
                text(data.error == null ? "Decoded" : data.error, width - 30, height - 15);
                ellipse(width - 15, height - 15, 10, 10);
            } catch (InterruptedException e) {
                println(e);
                println("Well feck");
            } catch (ExecutionException e) {
                println(e);
                println("Well feck");
            }
        }
    }

    if (staticImage) noLoop();
}
