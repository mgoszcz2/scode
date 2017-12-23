static Image polygon(int width, int height, Point[] pts) {
  if (pts.length < 3) return null;
  Image result = new Image(width, height, ImageKind.BINARY);

  final class Scan {
    int start, end;
  }

  int ymax = pts[0].y, ymin = pts[0].y;
  for (int i = 1; i < pts.length; i++) {
    if (pts[i].y > ymax) {
      ymax = pts[i].y;
    } else if (pts[i].y < ymin) {
      ymin = pts[i].y;
    }
  }


  int h = ymax - ymin;
  Scan[] scans = new Scan[h+1];
  for (int i = 0; i < scans.length; i++) {
    scans[i] = new Scan();
    scans[i].start = Integer.MAX_VALUE;
    scans[i].end = Integer.MIN_VALUE;
  }

  for (int i = 0; i < pts.length; i++) {
    Point p0 = pts[i], p1 = pts[(i+1) % pts.length];
    int sx = p1.x > p0.x ? 1 : -1;
    int sy = p1.y > p0.y ? 1 : -1;
    int dx = abs(p1.x - p0.x), dy = abs(p1.y - p0.y);
    int err = dx - dy;
    int x = p0.x, y = p0.y;

    for (;;) {
      int ix = y-ymin;
      if (x >= 0 || y >= 0 || x < width || y < height) {
        if (scans[ix].end < x) {
          scans[ix].end = x;
        }
        if (scans[ix].start > x) {
          scans[ix].start = x;
        }
      }

      if (x == p1.x && y == p1.y) break;
      int e2 = err * 2;
      if (e2 < dx) {
        y += sy;
        err += dx;
      }
      if (e2 > -dy) {
        x += sx;
        err -= dy;
      }
    }
  }

  for (int y = 0; y < scans.length; y++) {
    if (ymin + y < 0 || ymin + y > height) continue;
    int ix = (ymin + y)*result.width;
    for (int x = scans[y].start; x <= scans[y].end; x++) {
      result.pixels[ix + x] = 255;
    }
  }
  return result;
}
