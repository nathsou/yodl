/// Host-facing sinks live outside the execution kernel. They consume logical
/// values produced by the simulator and do not participate in scheduling.
pub(all) struct Framebuffer {
  width: Int
  height: Int
  pixels: Array[Int]
}

pub fn Framebuffer::new(width: Int, height: Int) -> Framebuffer {
  let pixels = Array::new(capacity=width * height)
  for _ in 0..<(width * height) { pixels.push(0) }
  { width, height, pixels }
}

pub fn Framebuffer::width(self: Framebuffer) -> Int { self.width }
pub fn Framebuffer::height(self: Framebuffer) -> Int { self.height }

pub fn Framebuffer::clear(self: Framebuffer, color~: Int = 0) -> Unit {
  for i in 0..<self.pixels.length() { self.pixels[i] = color }
}

pub fn Framebuffer::write(self: Framebuffer, x: Int, y: Int, red: Int, green: Int, blue: Int) -> Unit {
  if x < 0 || x >= self.width || y < 0 || y >= self.height { return }
  self.pixels[y * self.width + x] = ((red & 255) << 16) | ((green & 255) << 8) | (blue & 255)
}

pub fn Framebuffer::pixel(self: Framebuffer, x: Int, y: Int) -> Int {
  if x < 0 || x >= self.width || y < 0 || y >= self.height { return 0 }
  self.pixels[y * self.width + x]
}

pub fn Framebuffer::pixels(self: Framebuffer) -> Array[Int] { self.pixels }

pub(all) struct TextSink {
  mut bytes: Array[Int]
}

pub fn TextSink::new() -> TextSink { { bytes: [] } }
pub fn TextSink::write(self: TextSink, byte: Int) -> Unit { self.bytes.push(byte & 255) }
pub fn TextSink::bytes(self: TextSink) -> Array[Int] { self.bytes }

pub fn TextSink::text(self: TextSink) -> String {
  let builder = StringBuilder()
  for byte in self.bytes { builder.write_char(byte.to_char().unwrap_or('\u{0}')) }
  builder.to_string()
}
