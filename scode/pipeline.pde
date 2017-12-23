static class DecoderData {
    Image capture, debugView;
    Point[] corners;
    String content;
    String error;
    boolean silentError;

    boolean success() {
        return content != null;
    }

    static DecoderData localisationError(String error) {
        DecoderData data = new DecoderData();
        data.error = error;
        data.silentError = true;
        return data;
    }

    static DecoderData decodingError(String error) {
        DecoderData data = new DecoderData();
        data.error = error;
        data.silentError = true;
        return data;
    }
}

static class Pipeline implements Callable<DecoderData> {
    final PImage input;

    Pipeline(PImage input) {
        this.input = input;
    }

    DecoderData call() {
        Image original = new Image(input);
        Image blurred = gaussian(grayscale(original), 1.0);
        Image extraBlurred = mean(blurred, (int)(blurred.width * 0.04));
        Image binary = binarize(blurred, extraBlurred, 0.8);
        Image colorBinary = binarize(blurred, extraBlurred, 1.0);

        Point[] corners = scanFinder(binary);
        if (corners == null) {
            return DecoderData.localisationError("Not enough fips");
        }
        orderCorners(corners);
        Point[] originalCorners = new Point[corners.length];
        arrayCopy(corners, originalCorners);

        DecoderData result = decodeWithCorners(colorBinary, corners);
        if (result.error != null) {
            for (int i = 0; i < 3; i++) {
                shiftArray(corners);
                DecoderData r = decodeWithCorners(colorBinary, corners);
                if (r.error == null) {
                    result = r;
                    break;
                }
            }
        }
        result.debugView = colorBinary;
        if (result.error == null) {
            result.corners = originalCorners;
            result.capture = evenCrop(original, binary.width, binary.height);
        }
        return result;
    }

    private DecoderData decodeWithCorners(Image input, Point[] positions) {
        // Must be right to left like bits
        ArrayList<Point> bits = timingDots(input, positions[1], positions[0]);
        // Timing lines must be top to bottom
        ArrayList<Point> right = timingDots(input, positions[1], positions[2]);
        ArrayList<Point> left = timingDots(input, positions[0], positions[3]);

        if (left.size() != right.size()) {
            return DecoderData.localisationError("Unequal timing");
        }

        // Must be the same direction
        Line top = new Line(positions[0], positions[1]);
        Line bottom = new Line(positions[3], positions[2]);
        int[] bytes = new int[left.size() - 4];
        int currentByte = 0;

        // Image debugView = new Image(input, ImageKind.COLOR);
        // for (int i = 0; i < left.size(); i++) {
        //     debugView.drawLine(#ff0000, new Line(left.get(i), right.get(i)));
        // }
        // for (int j = 2; j < bits.size() - 2; j++) {
        //     Point p = bits.get(j);
        //     debugView.drawLine(#00ff00, new Line(p, bottom.atRatio(top.ratio(p))));
        // }

        for (int j = 2; j < bits.size() - 2; j++) {
            Point p = bits.get(j);
            Line bitLine = new Line(p, bottom.atRatio(top.ratio(p)));

            for (int i = 2; i < left.size() - 2; i++) {
                Point isect = new Line(left.get(i), right.get(i)).intersection(bitLine);
                if (isect != null) {
                    if (input.at(isect) == 0) {
                        bytes[i-2] |= 1 << (j - 2);
                    }
                }
            }
        }


        Result<String, String> decoded = decodeBytes(bytes);
        if (decoded.error != null) {
            return DecoderData.decodingError(decoded.error);
        }
        DecoderData result = new DecoderData();
        result.content = decoded.result;
        return result;
    }

    static private <T> void shiftArray(T[] arr) {
        T t = arr[0];
        for (int i = 0; i < arr.length - 1; i++) {
            arr[i] = arr[i + 1];
        }
        arr[arr.length - 1] = t;
    }

    static private void reverseBits(int[] bytes) {
        for (int i = 0; i < bytes.length; i++) {
            int r = 0, t = bytes[i];
            for (int j = 0; j < 9; j++) {
                r |= ((t >> j) & 1) << (8 - j);
            }
            bytes[i] = r;
        }
    }

    private Result<String, String> decodeBytes(int[] bytes) {
        final int lfsrTap = 0x7ae;
        String r = "";

        if (bytes[bytes.length - 1] != 1) {
            return new Result(null, "Not version 1");
        }

        int lfsr = 1;
        for (int i = 0; i < bytes.length - 1; i++) {
            int b = bytes[i] ^ lfsr;
            if (evenParity(b & 0xff) != ((b >> 8) & 1)) {
                return new Result(null, "Parity error");
            }

            // Ignore padding null bytes
            if ((b & 0xff) != 0) {
                r += (char)(b & 0xff);
            }
            boolean lb = (lfsr & 1) == 1;
            lfsr >>= 1;
            if (lb) lfsr ^= lfsrTap;
        }

        return new Result(r, null);
    }

    private ArrayList<Point> scanRatio(Image input, Point start, Point end) {
        input.ensureBinary();

        final float[] ratios = {0.667, 1.667, 0.667, 1.0};
        ArrayList<Point> result = new ArrayList();
        Point[] buffer = new Point[ratios.length + 2];
        int lastv = input.at(start);
        int runs = 0;
        Point lastp = null;

        for (Point p : input.line(start, end)) {
            int v = input.at(p);
            if (v != lastv) {
                lastv = v;
                // Evens out BWBW transitions
                ringPush(buffer, v > 0 ? lastp : p);
                runs++;
                if (v > 0 && runs >= 6 && approxEqual(ratios, buffer)) {
                    result.add(buffer[0].midpoint(buffer[buffer.length - 1]));
                }
            }
            lastp = p;
        }
        return result;
    }

    private Point[] scanFinder(Image input) {
        input.ensureBinary();
        HashSet<Point> h = new HashSet<Point>(), v = new HashSet<Point>();
        for (int i = 0; i < input.height; i++) {
            h.addAll(scanRatio(input, new Point(0, i), new Point(input.width - 1, i)));
        }
        for (int i = 0; i < input.width; i++) {
            v.addAll(scanRatio(input, new Point(i, 0), new Point(i, input.height - 1)));
        }
        h.retainAll(v);
        return h.size() == 4 ? h.toArray(new Point[0]) : null;
    }

    private ArrayList<Point> timingDots(Image input, Point start, Point end) {
        input.ensureBinary();
        ArrayList<Point> result = new ArrayList<Point>();
        Point lastp = null;
        int lastv = input.at(start);
        // We don't actually know when the first change is so set it to null

        for (Point p : input.line(start, end)) {
            int v = input.at(p);
            if (v != lastv) {
                if (lastp != null) {
                    result.add(lastp.midpoint(p));
                }
                lastv = v;
                lastp = p;
            }
        }
        return result;
    }
}
