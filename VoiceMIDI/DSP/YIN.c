#include "YIN.h"
#include <stdlib.h>
#include <math.h>
#include <float.h>

YIN *yin_create(int32_t bufferSize, float threshold) {
    YIN *yin = (YIN *)malloc(sizeof(YIN));
    if (!yin) return NULL;
    yin->bufferSize = bufferSize;
    yin->threshold = threshold;
    yin->probability = 0.0f;
    yin->frequency = 0.0f;
    yin->buffer = (float *)calloc(bufferSize, sizeof(float));
    if (!yin->buffer) {
        free(yin);
        return NULL;
    }
    return yin;
}

void yin_destroy(YIN *yin) {
    if (yin) {
        free(yin->buffer);
        free(yin);
    }
}

// Step 1: Difference function
static void difference_function(const float *audioBuffer, float *yinBuffer, int32_t bufferSize) {
    int32_t halfSize = bufferSize / 2;
    for (int32_t tau = 0; tau < halfSize; tau++) {
        yinBuffer[tau] = 0.0f;
        for (int32_t i = 0; i < halfSize; i++) {
            float delta = audioBuffer[i] - audioBuffer[i + tau];
            yinBuffer[tau] += delta * delta;
        }
    }
}

// Step 2: Cumulative mean normalized difference
static void cumulative_mean_normalized_difference(float *yinBuffer, int32_t halfSize) {
    yinBuffer[0] = 1.0f;
    float runningSum = 0.0f;
    for (int32_t tau = 1; tau < halfSize; tau++) {
        runningSum += yinBuffer[tau];
        if (runningSum == 0.0f) {
            yinBuffer[tau] = 1.0f;
        } else {
            yinBuffer[tau] *= (float)tau / runningSum;
        }
    }
}

// Step 3: Absolute threshold — find first tau below threshold
static int32_t absolute_threshold(const float *yinBuffer, int32_t halfSize, float threshold) {
    int32_t tau;
    for (tau = 2; tau < halfSize; tau++) {
        if (yinBuffer[tau] < threshold) {
            // Find local minimum
            while (tau + 1 < halfSize && yinBuffer[tau + 1] < yinBuffer[tau]) {
                tau++;
            }
            return tau;
        }
    }
    // No threshold crossing — find global minimum
    float minVal = FLT_MAX;
    int32_t minTau = 2;
    for (tau = 2; tau < halfSize; tau++) {
        if (yinBuffer[tau] < minVal) {
            minVal = yinBuffer[tau];
            minTau = tau;
        }
    }
    return minTau;
}

// Step 4: Parabolic interpolation for sub-sample refinement
static float parabolic_interpolation(const float *yinBuffer, int32_t tau, int32_t halfSize) {
    if (tau <= 0 || tau >= halfSize - 1) {
        return (float)tau;
    }
    float s0 = yinBuffer[tau - 1];
    float s1 = yinBuffer[tau];
    float s2 = yinBuffer[tau + 1];
    float denom = 2.0f * s1 - s0 - s2;
    if (fabsf(denom) < 1e-7f) {
        return (float)tau;
    }
    return (float)tau + 0.5f * (s0 - s2) / denom;
}

float yin_detect(YIN *yin, const float *audioBuffer, int32_t sampleRate) {
    int32_t halfSize = yin->bufferSize / 2;

    // Step 1: Difference function (stored in yin->buffer)
    difference_function(audioBuffer, yin->buffer, yin->bufferSize);

    // Step 2: CMND
    cumulative_mean_normalized_difference(yin->buffer, halfSize);

    // Step 3: Threshold search
    int32_t tau = absolute_threshold(yin->buffer, halfSize, yin->threshold);

    // Step 4: Parabolic interpolation
    float interpolatedTau = parabolic_interpolation(yin->buffer, tau, halfSize);

    // Step 5: Convert to frequency
    if (interpolatedTau < 2.0f) {
        yin->frequency = 0.0f;
        yin->probability = 0.0f;
        return 0.0f;
    }

    yin->frequency = (float)sampleRate / interpolatedTau;

    // Step 6: Probability
    yin->probability = 1.0f - yin->buffer[tau];
    if (yin->probability < 0.0f) yin->probability = 0.0f;
    if (yin->probability > 1.0f) yin->probability = 1.0f;

    return yin->frequency;
}
