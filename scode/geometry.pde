final static class Point {
    final int x, y;
    Point(int x, int y) {
        this.x = x;
        this.y = y;
    }

    float hypot(Point h) {
        return (float)Math.hypot(h.x - x, h.y - y);
    }

    Point add(int dx, int dy) {
        return new Point(x + dx, y + dy);
    }

    Point add(Point h) {
        return new Point(x + h.x, y + h.y);
    }

    Point subtract(Point h) {
        return new Point(x - h.x, y - h.y);
    }

    Point midpoint(Point h) {
        return new Point((x + h.x)/2, (y + h.y)/2);
    }

    Point divide(int c) {
        return new Point(x / c, y / c);
    }

    double atan2() {
        return Math.atan2(y, x);
    }

    Point mean(Point h) {
        return new Point((x + h.x) / 2, (y + h.y) / 2);
    }

    String toString() {
        return String.format("(%d, %d)", x, y);
    }

    Point map(int oldWidth, int oldHeight, int width, int height) {
        return new Point((int)(width * x / (float)oldWidth),
                         (int)(height * y / (float)oldHeight));
    }

    boolean equals(Object h) {
        if (h == null || !(h instanceof Point)) return false;
        Point hp = (Point)h;
        return hp.x == x && hp.y == y;
    }

    int hashCode() {
        return x << 16 | y & 0xffff;
    }

    static Point mean(Point[] hs) {
        int sx = 0, sy = 0;
        for (Point p : hs) {
            sx += p.x;
            sy += p.y;
        }
        return new Point(sx / hs.length, sy / hs.length);
    }
}

final static class Line implements Iterable<Point> {
    final int width, height;
    final Point start, end;

    class LineIterator implements Iterator<Point> {
        private final int dx, dy, sx, sy;
        private int x0 = start.x, y0 = start.y;
        private boolean finished = false;
        private float error;

        private LineIterator() {
            dx = abs(end.x - x0);
            dy = abs(end.y - y0);
            sx = x0 < end.x ? 1 : -1;
            sy = y0 < end.y ? 1 : -1;
            error = (dx > dy ? dx : -dy) / 2.0;
        }

        Point next() {
            if (finished || invalid()) {
                finished = true;
                throw new NoSuchElementException();
            }

            Point r = new Point(x0, y0);
            if (x0 == end.x && y0 == end.y) {
                finished = true;
                return r;
            }

            float e2 = error;
            if (e2 > -dx) {
                error -= dy;
                x0 += sx;
            }
            if (e2 < dy) {
                error += dx;
                y0 += sy;
            }

            return r;
        }

        private boolean invalid() {
            return x0 < 0 || y0 < 0 || x0 >= width || y0 >= height;
        }

        boolean hasNext() {
            return !finished && !invalid();
        }
    }

    Line(Point start, Point end, int width, int height) {
        this.start = start;
        this.end = end;
        this.width = width;
        this.height = height;
    }

    Line(Point start, Point end) {
        this(start, end, Integer.MAX_VALUE, Integer.MAX_VALUE);
    }

    LineIterator iterator() {
        return new LineIterator();
    }

    float ratio(Point h) {
        if (start.x != end.x) {
            return (h.x - start.x) / (float)(end.x - start.x);
        }
        return (h.y - start.y) / (float)(end.y - start.y);
    }

    Point atRatio(float r) {
        return new Point((int)(start.x + (end.x - start.x)*r), (int)(start.y + (end.y - start.y)*r));
    }

    // Ripped stackoverflow.com/questions/563198
    Point intersection(Line h) {
        float p0_x = start.x, p0_y = start.y;
        float p1_x = end.x, p1_y = end.y;
        float p2_x = h.start.x, p2_y = h.start.y;
        float p3_x = h.end.x, p3_y = h.end.y;

        float s1_x = p1_x - p0_x;
        float s1_y = p1_y - p0_y;
        float s2_x = p3_x - p2_x;
        float s2_y = p3_y - p2_y;

        float s = (-s1_y * (p0_x - p2_x) + s1_x * (p0_y - p2_y)) / (-s2_x * s1_y + s1_x * s2_y);
        float t = ( s2_x * (p0_y - p2_y) - s2_y * (p0_x - p2_x)) / (-s2_x * s1_y + s1_x * s2_y);

        if (s >= 0 && s <= 1 && t >= 0 && t <= 1) {
            return new Point((int)(p0_x + (t * s1_x)), (int)(p0_y + (t * s1_y)));
        }

        return null;
    }
}
