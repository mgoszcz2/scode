static class DecoderData {
    Point[] corners;
    String content;
    String error;
    boolean silentError;

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

private static ArrayList<Point> scanRatio(Image input, Point start, Point end) {
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

private static Point[] scanFinder(Image input) {
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

private static ArrayList<Point> timingDots(Image input, Point start, Point end) {
    input.ensureBinary();
    ArrayList<Point> result = new ArrayList<Point>();
    Point lastp = start;
    int lastv = input.at(start);

    for (Point p : input.line(start, end)) {
        int v = input.at(p);
        if (v != lastv) {
            result.add(lastp.midpoint(p));
            lastv = v;
            lastp = p;
        }
    }
    return result;
}

private static void orderCorners(Point[] positions) {
    final Point m = Point.mean(positions);
    Arrays.sort(positions, new Comparator<Point>(){
        public int compare(Point a, Point b) {
            return Double.compare(a.subtract(m).atan2(), b.subtract(m).atan2());
        }
    });
}

private static int evenParity(int x) {
    x ^= x >> 4;
    x ^= x >> 2;
    x ^= x >> 1;
    return (~x) & 1;
}

static DecoderData decodeCode(Image bg, Image input) {
    input.ensureBinary();
    Point[] positions = scanFinder(input);
    if (positions == null) {
        return DecoderData.localisationError("Not enough fips");
    }

    final int[] colors = {#ff0000, #00ff00, #0000ff, #ff00ff};
    orderCorners(positions);
    ArrayList<Point> bits = timingDots(input, positions[0], positions[3]);
    ArrayList<Point> right = timingDots(input, positions[0], positions[1]);
    ArrayList<Point> left = timingDots(input, positions[3], positions[2]);

    if (left.size() != right.size()) {
        return DecoderData.localisationError("Unequal timing");
    }

    Line top = new Line(positions[0], positions[3]);
    Line bottom = new Line(positions[1], positions[2]);
    int[] bytes = new int[left.size() - 5];
    int currentByte = 0;

    for (int j = 3; j < bits.size() - 2; j++) {
        Point p = bits.get(j);
        Line bitLine = new Line(p, bottom.atRatio(top.ratio(p)));

        for (int i = 3; i < left.size() - 2; i++) {
            Point isect = new Line(left.get(i), right.get(i)).intersection(bitLine);
            if (isect != null) {
                if (input.at(isect) == 0) {
                    bytes[i-3] |= 1 << (j - 3);
                }
            }
        }
    }

    final int lfsrTap = 0x7ae;
    String r = "";

    if (bytes[bytes.length - 1] != 1) {
        return DecoderData.decodingError("Not version 1");
    }

    int lfsr = 1;
    for (int i = 0; i < bytes.length - 1; i++) {
        int b = bytes[i] ^ lfsr;
        if (evenParity(b & 0xff) != ((b >> 8) & 1)) {
            return DecoderData.decodingError("Parity error");
        }

        r += (char)(b & 0xff);
        boolean lb = (lfsr & 1) == 1;
        lfsr >>= 1;
        if (lb) lfsr ^= lfsrTap;
    }

    DecoderData result = new DecoderData();
    result.content = r;
    result.corners = positions;
    return result;
}
