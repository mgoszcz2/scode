private static ArrayList<Position> scanRatio(Image input, Position start, Position end) {
    input.ensureBinary();

    final float[] ratios = {0.667, 1.667, 0.667, 1.0};
    ArrayList<Position> result = new ArrayList();
    Position[] buffer = new Position[ratios.length + 2];
    int lastv = input.at(start);
    int runs = 0;
    Position lastp = null;

    for (Position p : input.line(start, end)) {
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

private static Position[] scanFinder(Image input) {
    input.ensureBinary();
    HashSet<Position> h = new HashSet<Position>(), v = new HashSet<Position>();
    for (int i = 0; i < input.height; i++) {
        h.addAll(scanRatio(input, new Position(0, i), new Position(input.width - 1, i)));
    }
    for (int i = 0; i < input.width; i++) {
        v.addAll(scanRatio(input, new Position(i, 0), new Position(i, input.height - 1)));
    }
    h.retainAll(v);
    return h.size() == 4 ? h.toArray(new Position[0]) : null;
}

private static ArrayList<Position> timingDots(Image input, Position start, Position end) {
    input.ensureBinary();
    ArrayList<Position> result = new ArrayList<Position>();
    Position lastp = start;
    int lastv = input.at(start);

    for (Position p : input.line(start, end)) {
        int v = input.at(p);
        if (v != lastv) {
            result.add(lastp.midpoint(p));
            lastv = v;
            lastp = p;
        }
    }
    return result;
}

private static void orderCorners(Position[] positions) {
    final Position m = Position.mean(positions);
    Arrays.sort(positions, new Comparator<Position>(){
        public int compare(Position a, Position b) {
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

private static String decodeBytes(int[] bytes) {
    final int lfsrTap = 0x7ae;
    String r = "";

    if (bytes[bytes.length - 1] != 1) {
        return "Not version 1";
    }

    int lfsr = 1;
    for (int i = 0; i < bytes.length - 1; i++) {
        int b = bytes[i] ^ lfsr;
        if (evenParity(b & 0xff) != ((b >> 8) & 1)) {
            return "Wrong parity";
        }

        r += (char)(b & 0xff);
        boolean lb = (lfsr & 1) == 1;
        lfsr >>= 1;
        if (lb) lfsr ^= lfsrTap;
    }

    return r;
}

static Tuple<Image, String> drawOutline(Image bg, Image input) {
    input.ensureBinary();
    Position[] positions = scanFinder(input);
    Image result = new Image(bg, ImageKind.COLOR);
    if (positions == null) {
        return new Tuple(result, null);
    }

    final int[] colors = {#ff0000, #00ff00, #0000ff, #ff00ff};
    orderCorners(positions);
    for (int i = 0; i < positions.length; i++) {
        result.drawCross(colors[i], positions[i], 30);
    }
    ArrayList<Position> bits = timingDots(input, positions[0], positions[3]);
    ArrayList<Position> right = timingDots(input, positions[0], positions[1]);
    ArrayList<Position> left = timingDots(input, positions[3], positions[2]);
    result.drawLine(#00ffff, positions[2], positions[1]);

    if (left.size() != right.size()) {
        return new Tuple(result, null);
    }
    // for (int i = 0; i < left.size(); i++) {
    //     result.drawLine(#3300cc, left.get(i), right.get(i));
    // }

    Line top = new Line(positions[0], positions[3]);
    Line bottom = new Line(positions[1], positions[2]);
    int[] bytes = new int[left.size() - 5];
    int currentByte = 0;

    for (int j = 3; j < bits.size() - 2; j++) {
        Position p = bits.get(j);
        Line bitLine = new Line(p, bottom.atRatio(top.ratio(p)));
        // result.drawLine(#cc3300, bitLine);

        for (int i = 3; i < left.size() - 2; i++) {
            Position isect = new Line(left.get(i), right.get(i)).intersection(bitLine);
            if (isect != null) {
                if (input.at(isect) == 0) {
                    result.drawCross(#FF1493, isect, 3);
                    bytes[i-3] |= 1 << (j - 3);
                }
            }
        }
    }

    return new Tuple(result, decodeBytes(bytes));
}
