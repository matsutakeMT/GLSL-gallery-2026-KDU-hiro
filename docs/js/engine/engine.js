// Minimal Shadertoy-compatible fullscreen-quad GLSL renderer.
// Shader source files only need to define mainImage(out vec4 fragColor, in vec2 fragCoord) —
// precision, uniforms, and main() are supplied automatically, exactly like on shadertoy.com.
//
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
uniform float iTimeDelta;
uniform float iFrameRate;
uniform int iFrame;
uniform vec4 iMouse;
uniform vec4 iDate;
uniform sampler2D iChannel0;
uniform sampler2D iChannel1;
uniform sampler2D iChannel2;
uniform sampler2D iChannel3;
uniform vec3 iChannelResolution[4];
`;

const FOOTER = `
void main() {
  vec4 color;
  mainImage(color, gl_FragCoord.xy);
  gl_FragColor = color;
}
`;

const CHANNEL_COUNT = 4;

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

// A 1x1 placeholder so iChannelN can be sampled safely even when no texture is bound to it.
function createPlaceholderTexture(gl) {
  const texture = gl.createTexture();
  gl.bindTexture(gl.TEXTURE_2D, texture);
  gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, 1, 1, 0, gl.RGBA, gl.UNSIGNED_BYTE, new Uint8Array([0, 0, 0, 255]));
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
  return texture;
}

export function createRenderer(canvas, fragmentSource, options = {}) {
  const gl = canvas.getContext("webgl") || canvas.getContext("experimental-webgl");
  if (!gl) throw new Error("WebGL is not supported in this browser.");

  const source = HEADER + fragmentSource + FOOTER;
  const program = createProgram(gl, VERTEX_SHADER, source);

  const positionBuffer = gl.createBuffer();
  gl.bindBuffer(gl.ARRAY_BUFFER, positionBuffer);
  gl.bufferData(
    gl.ARRAY_BUFFER,
    new Float32Array([-1, -1, 1, -1, -1, 1, 1, 1]),
    gl.STATIC_DRAW
  );

  const positionLocation = gl.getAttribLocation(program, "a_position");
  const uniforms = {
    iResolution: gl.getUniformLocation(program, "iResolution"),
    iTime: gl.getUniformLocation(program, "iTime"),
    iTimeDelta: gl.getUniformLocation(program, "iTimeDelta"),
    iFrameRate: gl.getUniformLocation(program, "iFrameRate"),
    iFrame: gl.getUniformLocation(program, "iFrame"),
    iMouse: gl.getUniformLocation(program, "iMouse"),
    iDate: gl.getUniformLocation(program, "iDate"),
    iChannelResolution: gl.getUniformLocation(program, "iChannelResolution"),
    iChannels: [0, 1, 2, 3].map((i) => gl.getUniformLocation(program, `iChannel${i}`)),
  };

  // channels[i] = { texture, width, height }; defaults to a 1x1 placeholder.
  const channels = Array.from({ length: CHANNEL_COUNT }, () => ({
    texture: createPlaceholderTexture(gl),
    width: 1,
    height: 1,
  }));

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
  let lastFrameMs = null;
  let frame = 0;
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

  function bindChannels() {
    for (let i = 0; i < CHANNEL_COUNT; i++) {
      gl.activeTexture(gl.TEXTURE0 + i);
      gl.bindTexture(gl.TEXTURE_2D, channels[i].texture);
      if (uniforms.iChannels[i]) gl.uniform1i(uniforms.iChannels[i], i);
    }
    if (uniforms.iChannelResolution) {
      const res = channels.flatMap((c) => [c.width, c.height, 1]);
      gl.uniform3fv(uniforms.iChannelResolution, new Float32Array(res));
    }
  }

  function renderFrame(timeSeconds, deltaSeconds) {
    resize();
    gl.useProgram(program);

    gl.enableVertexAttribArray(positionLocation);
    gl.bindBuffer(gl.ARRAY_BUFFER, positionBuffer);
    gl.vertexAttribPointer(positionLocation, 2, gl.FLOAT, false, 0, 0);

    const now = new Date();
    const secondsOfDay = now.getHours() * 3600 + now.getMinutes() * 60 + now.getSeconds() + now.getMilliseconds() / 1000;

    gl.uniform3f(uniforms.iResolution, canvas.width, canvas.height, 1.0);
    gl.uniform1f(uniforms.iTime, timeSeconds);
    gl.uniform1f(uniforms.iTimeDelta, deltaSeconds);
    gl.uniform1f(uniforms.iFrameRate, deltaSeconds > 0 ? 1 / deltaSeconds : 0);
    gl.uniform1i(uniforms.iFrame, frame);
    gl.uniform4f(uniforms.iMouse, mouse.x, mouse.y, mouse.down ? 1 : 0, 0);
    gl.uniform4f(uniforms.iDate, now.getFullYear(), now.getMonth() + 1, now.getDate(), secondsOfDay);
    bindChannels();

    gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
    frame++;
  }

  function loop(nowMs) {
    const t = fixedTime !== undefined ? fixedTime : (nowMs - startTime) / 1000;
    const delta = lastFrameMs === null ? 0 : (nowMs - lastFrameMs) / 1000;
    lastFrameMs = nowMs;
    renderFrame(t, delta);
    if (fixedTime === undefined) {
      rafId = requestAnimationFrame(loop);
    }
  }

  return {
    start() {
      startTime = performance.now();
      lastFrameMs = null;
      frame = 0;
      loop(startTime);
    },
    stop() {
      if (rafId !== null) {
        cancelAnimationFrame(rafId);
        rafId = null;
      }
    },
    renderOnce(timeSeconds = 0) {
      renderFrame(timeSeconds, 0);
    },
    // src: HTMLImageElement | HTMLCanvasElement | ImageBitmap
    setChannelTexture(index, src) {
      const channel = channels[index];
      if (!channel) return;
      gl.bindTexture(gl.TEXTURE_2D, channel.texture);
      gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, src);
      gl.generateMipmap(gl.TEXTURE_2D);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
      channel.width = src.width || src.videoWidth || 1;
      channel.height = src.height || src.videoHeight || 1;
    },
    dispose() {
      this.stop();
      canvas.removeEventListener("mousemove", onMouseMove);
      canvas.removeEventListener("mousedown", onMouseDown);
      canvas.removeEventListener("mouseup", onMouseUp);
      gl.deleteProgram(program);
      gl.deleteBuffer(positionBuffer);
      channels.forEach((c) => gl.deleteTexture(c.texture));
    },
    gl,
  };
}
