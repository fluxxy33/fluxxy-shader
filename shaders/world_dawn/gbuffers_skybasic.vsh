#version 120

#define DAWN_SHADER

void main() {
	gl_Position = ftransform();
}
