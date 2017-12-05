size(220, 220);
final color[] COLORS = {#ff0000, #00ff00, #0000ff, #ffffff};

for (int i = 0; i < 360; i++) {
  float a = i * PI / 180;
  float t = atan2(cos(a), sin(a));
  stroke(COLORS[(int)(((t + PI * 1 / 8) / PI * 4) + 4) % 4]);
  point(110 + 90 * cos(a), 110 + 90 * sin(a));
}

stroke(0);
line(0, 110, 220, 110);
line(110, 0, 110, 220);