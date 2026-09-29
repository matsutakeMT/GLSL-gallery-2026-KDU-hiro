// Minimal Shadertoy-like fullscreen-quad GLSL renderer.
// Usage:
//   import { createRenderer } from "./engine/engine.js";
//   const renderer = createRenderer(canvas, fragmentShaderSource);
//   renderer.start();
//   renderer.stop();

const VERTEX_SHADER = `
attribute vec2 a_position;
void main() {
  gl_Position = vec4(a_position, 0.0, 1.0);
}
`;

const HEADER = `
precision highp float;
uniform vec3 iResolution;
uniform float iTime;
uniform vec4 iMouse;
`;

function compileShader(gl, type, source) {
  const shader = gl.createShader(type);
  gl.shaderSource(shader, source);
  gl.compileShader(shader);
  if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
    const info = gl.getShaderInfoLog(shader);
    gl.deleteShader(shader);
    throw new Error(`Shader compile error: ${info}`);
  }
  return shader;
}

function createProgram(gl, vertexSource, fragmentSource) {
  const vertexShader = compileShader(gl, gl.VERTEX_SHADER, vertexSource);
  const fragmentShader = compileShader(gl, gl.FRAGMENT_SHADER, fragmentSource);
  const program = gl.createProgram();
  gl.attachShader(program, vertexShader);
  gl.attachShader(program, fragmentShader);
  gl.linkProgram(program);
  if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
    const info = gl.getProgramInfoLog(program);
    gl.deleteProgram(program);
    throw new Error(`Program link error: ${info}`);
  }
  return program;
}

export function createRenderer(canvas, fragmentSource, options = {}) {
  const gl = canvas.getContext("webgl") || canvas.getContext("experimental-webgl");
  if (!gl) throw new Error("WebGL is not supported in this browser.");

  const needsHeader = !fragmentSource.includes("iResolution");
  const source = needsHeader ? HEADER + fragmentSource : fragmentSource;
  const program = createProgram(gl, VERTEX_SHADER, source);

  const positionBuffer = gl.createBuffer();
  gl.bindBuffer(gl.ARRAY_BUFFER, positionBuffer);
  gl.bufferData(
    gl.ARRAY_BUFFER,
    new Float32Array([-1, -1, 1, -1, -1, 1, 1, 1]),
    gl.STATIC_DRAW
  );

  const positionLocation = gl.getAttribLocation(program, "a_position");
  const iResolutionLocation = gl.getUniformLocation(program, "iResolution");
  const iTimeLocation = gl.getUniformLocation(program, "iTime");
  const iMouseLocation = gl.getUniformLocation(program, "iMouse");

  const mouse = { x: 0, y: 0, down: false };
  const onMouseMove = (e) => {
    const rect = canvas.getBoundingClientRect();
    mouse.x = e.clientX - rect.left;
    mouse.y = rect.height - (e.clientY - rect.top);
  };
  const onMouseDown = () => (mouse.down = true);
  const onMouseUp = () => (mouse.down = false);
  canvas.addEventListener("mousemove", onMouseMove);
  canvas.addEventListener("mousedown", onMouseDown);
  canvas.addEventListener("mouseup", onMouseUp);

  let rafId = null;
  let startTime = performance.now();
  const fixedTime = options.fixedTime; // if set, render a single static frame at this time (for thumbnails)

  function resize() {
    const dpr = options.pixelRatio || 1;
    const width = Math.round(canvas.clientWidth * dpr);
    const height = Math.round(canvas.clientHeight * dpr);
    if (canvas.width !== width || canvas.height !== height) {
      canvas.width = width || canvas.width;
      canvas.height = height || canvas.height;
    }
    gl.viewport(0, 0, canvas.width, canvas.height);
  }

  function renderFrame(timeSeconds) {
    resize();
    gl.useProgram(program);

    gl.enableVertexAttribArray(positionLocation);
    gl.bindBuffer(gl.ARRAY_BUFFER, positionBuffer);
    gl.vertexAttribPointer(positionLocation, 2, gl.FLOAT, false, 0, 0);

    gl.uniform3f(iResolutionLocation, canvas.width, canvas.height, 1.0);
    gl.uniform1f(iTimeLocation, timeSeconds);
    gl.uniform4f(iMouseLocation, mouse.x, mouse.y, mouse.down ? 1 : 0, 0);

    gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
  }

  function loop() {
    const t = fixedTime !== undefined ? fixedTime : (performance.now() - startTime) / 1000;
    renderFrame(t);
    if (fixedTime === undefined) {
      rafId = requestAnimationFrame(loop);
    }
  }

  return {
    start() {
      startTime = performance.now();
      loop();
    },
    stop() {
      if (rafId !== null) {
        cancelAnimationFrame(rafId);
        rafId = null;
      }
    },
    renderOnce(timeSeconds = 0) {
      renderFrame(timeSeconds);
    },
    dispose() {
      this.stop();
      canvas.removeEventListener("mousemove", onMouseMove);
      canvas.removeEventListener("mousedown", onMouseDown);
      canvas.removeEventListener("mouseup", onMouseUp);
      gl.deleteProgram(program);
      gl.deleteBuffer(positionBuffer);
    },
    gl,
  };
}
