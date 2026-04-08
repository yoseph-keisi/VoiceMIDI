#ifndef YIN_H
#define YIN_H

#include <stdint.h>

typedef struct {
    float *buffer;
    int32_t bufferSize;
    float threshold;     // Typically 0.10–0.15
    float probability;   // Output: confidence 0.0–1.0
    float frequency;     // Output: detected frequency in Hz
} YIN;

YIN *yin_create(int32_t bufferSize, float threshold);
void yin_destroy(YIN *yin);
float yin_detect(YIN *yin, const float *audioBuffer, int32_t sampleRate);

#endif
